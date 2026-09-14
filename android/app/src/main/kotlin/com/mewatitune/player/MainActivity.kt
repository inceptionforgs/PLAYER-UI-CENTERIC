package com.mewatitune.player

import android.app.Activity
import android.app.KeyguardManager
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.media.AudioAttributes
import android.media.AudioDeviceInfo
import android.media.AudioFocusRequest
import android.media.AudioManager
import android.media.MediaActionSound
import android.os.Build
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.speech.RecognitionListener
import android.speech.RecognizerIntent
import android.speech.SpeechRecognizer
import com.ryanheise.audioservice.AudioServiceActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel

class MainActivity : AudioServiceActivity() {
    private var volumeEvents: EventChannel.EventSink? = null
    private var receiver: BroadcastReceiver? = null
    private var lastAppWriteIndex: Int = -1
    private var voiceSink: EventChannel.EventSink? = null
    private var recognizer: SpeechRecognizer? = null
    private var voiceSession = false
    private var voiceRestarts = 0
    private var lastVoiceIntent: Intent? = null
    private var lastVoiceLang = "hi-IN"
    private var pendingOverlay: MethodChannel.Result? = null
    private var focusRequest: AudioFocusRequest? = null
    private val voiceHandler = Handler(Looper.getMainLooper())

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        flutterEngine.plugins.add(SoftwareEqEngine())

        val am = getSystemService(AUDIO_SERVICE) as AudioManager
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "mewati.sound/volume")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "get" -> result.success(systemVolume(am))
                    "max" -> result.success(
                        am.getStreamMaxVolume(AudioManager.STREAM_MUSIC).coerceAtLeast(1),
                    )
                    "locked" -> result.success(keyguardLocked())
                    "headset" -> result.success(isHeadsetOrBluetooth(am))
                    "set" -> {
                        if (keyguardLocked()) {
                            result.success(systemVolume(am))
                        } else {
                            val args = call.arguments
                            var value = 0.0
                            var silent = true
                            when (args) {
                                is Number -> value = args.toDouble()
                                is Map<*, *> -> {
                                    value = (args["value"] as? Number)?.toDouble() ?: 0.0
                                    silent = args["silent"] as? Boolean ?: true
                                }
                            }
                            val max = am.getStreamMaxVolume(AudioManager.STREAM_MUSIC).coerceAtLeast(1)
                            val idx = (value.coerceIn(0.0, 1.0) * max).toInt()
                            lastAppWriteIndex = idx
                            val flags = if (silent) 0 else AudioManager.FLAG_SHOW_UI
                            am.setStreamVolume(AudioManager.STREAM_MUSIC, idx, flags)
                            result.success(systemVolume(am))
                        }
                    }
                    "playShutter" -> {
                        try {
                            MediaActionSound().play(MediaActionSound.SHUTTER_CLICK)
                            result.success(true)
                        } catch (e: Exception) {
                            result.success(false)
                        }
                    }
                    else -> result.notImplemented()
                }
            }

        EventChannel(flutterEngine.dartExecutor.binaryMessenger, "mewati.sound/volumeEvents")
            .setStreamHandler(object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                    volumeEvents = events
                    if (receiver == null) {
                        receiver = object : BroadcastReceiver() {
                            override fun onReceive(context: Context?, intent: Intent?) {
                                if (intent?.action != "android.media.VOLUME_CHANGED_ACTION") return
                                val type = intent.getIntExtra(
                                    "android.media.EXTRA_VOLUME_STREAM_TYPE",
                                    -1,
                                )
                                if (type != -1 && type != AudioManager.STREAM_MUSIC) return
                                val cur = am.getStreamVolume(AudioManager.STREAM_MUSIC)
                                val fromApp = lastAppWriteIndex >= 0 && cur == lastAppWriteIndex
                                if (fromApp) {
                                    lastAppWriteIndex = -1
                                }
                                volumeEvents?.success(
                                    hashMapOf(
                                        "value" to systemVolume(am),
                                        "fromApp" to fromApp,
                                    ),
                                )
                            }
                        }
                        val filter = IntentFilter("android.media.VOLUME_CHANGED_ACTION")
                        if (Build.VERSION.SDK_INT >= 33) {
                            registerReceiver(receiver, filter, Context.RECEIVER_NOT_EXPORTED)
                        } else {
                            @Suppress("DEPRECATION")
                            registerReceiver(receiver, filter)
                        }
                    }
                }

                override fun onCancel(arguments: Any?) {
                    volumeEvents = null
                    receiver?.let {
                        try {
                            unregisterReceiver(it)
                        } catch (_: Exception) {
                        }
                    }
                    receiver = null
                }
            })

        EventChannel(flutterEngine.dartExecutor.binaryMessenger, "mewati.voice/events")
            .setStreamHandler(object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                    voiceSink = events
                }

                override fun onCancel(arguments: Any?) {
                    voiceSink = null
                }
            })

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "mewati.voice/input")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "start" -> startVoice(call.argument<String>("lang") ?: "hi-IN", result)
                    "stop" -> {
                        stopVoice()
                        result.success(null)
                    }
                    "overlay" -> startOverlay(call.argument<String>("lang") ?: "hi-IN", result)
                    else -> result.notImplemented()
                }
            }
    }

    override fun onDestroy() {
        stopVoice()
        super.onDestroy()
    }

    @Deprecated("Deprecated in Java")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode != VOICE_REQ) return
        val reply = pendingOverlay ?: return
        pendingOverlay = null
        if (resultCode != Activity.RESULT_OK || data == null) {
            reply.success(null)
            return
        }
        val spoken = data.getStringArrayListExtra(RecognizerIntent.EXTRA_RESULTS)
            ?.firstOrNull()
        reply.success(spoken)
    }

    private fun emit(payload: HashMap<String, Any?>) {
        runOnUiThread { voiceSink?.success(payload) }
    }

    private fun takeMicFocus() {
        val am = getSystemService(AUDIO_SERVICE) as AudioManager
        try {
            if (Build.VERSION.SDK_INT >= 26) {
                val req = AudioFocusRequest.Builder(AudioManager.AUDIOFOCUS_GAIN_TRANSIENT)
                    .setAudioAttributes(
                        AudioAttributes.Builder()
                            .setUsage(AudioAttributes.USAGE_ASSISTANT)
                            .setContentType(AudioAttributes.CONTENT_TYPE_SPEECH)
                            .build(),
                    )
                    .build()
                focusRequest = req
                am.requestAudioFocus(req)
            } else {
                @Suppress("DEPRECATION")
                am.requestAudioFocus(
                    null,
                    AudioManager.STREAM_MUSIC,
                    AudioManager.AUDIOFOCUS_GAIN_TRANSIENT,
                )
            }
        } catch (_: Exception) {
        }
    }

    private fun dropMicFocus() {
        val am = getSystemService(AUDIO_SERVICE) as AudioManager
        try {
            if (Build.VERSION.SDK_INT >= 26) {
                focusRequest?.let { am.abandonAudioFocusRequest(it) }
            } else {
                @Suppress("DEPRECATION")
                am.abandonAudioFocus(null)
            }
        } catch (_: Exception) {
        }
        focusRequest = null
    }

    private fun speechIntent(lang: String): Intent {
        return Intent(RecognizerIntent.ACTION_RECOGNIZE_SPEECH).apply {
            putExtra(
                RecognizerIntent.EXTRA_LANGUAGE_MODEL,
                RecognizerIntent.LANGUAGE_MODEL_FREE_FORM,
            )
            putExtra(RecognizerIntent.EXTRA_LANGUAGE, lang)
            putExtra(RecognizerIntent.EXTRA_LANGUAGE_PREFERENCE, lang)
            putExtra(RecognizerIntent.EXTRA_PARTIAL_RESULTS, true)
            putExtra(RecognizerIntent.EXTRA_MAX_RESULTS, 3)
            putExtra(RecognizerIntent.EXTRA_CALLING_PACKAGE, packageName)
            putExtra(RecognizerIntent.EXTRA_PROMPT, "Speak now")
        }
    }

    private fun startVoice(lang: String, result: MethodChannel.Result) {
        if (!SpeechRecognizer.isRecognitionAvailable(this)) {
            result.error("unavailable", "no recognizer", null)
            return
        }
        lastVoiceLang = lang
        voiceRestarts = 0
        voiceSession = true
        takeMicFocus()
        bindRecognizer()
        val intent = speechIntent(lang)
        lastVoiceIntent = intent
        try {
            recognizer?.startListening(intent)
            result.success(true)
        } catch (e: Exception) {
            stopVoice()
            result.error("unavailable", e.message, null)
        }
    }

    private fun bindRecognizer() {
        try {
            recognizer?.destroy()
        } catch (_: Exception) {
        }
        val rec = SpeechRecognizer.createSpeechRecognizer(this)
        recognizer = rec
        rec.setRecognitionListener(object : RecognitionListener {
            override fun onReadyForSpeech(params: Bundle?) {
                emit(hashMapOf("type" to "ready"))
            }

            override fun onBeginningOfSpeech() {}

            override fun onRmsChanged(rmsdB: Float) {
                emit(hashMapOf("type" to "rms", "v" to rmsdB.toDouble()))
            }

            override fun onBufferReceived(buffer: ByteArray?) {}

            override fun onEndOfSpeech() {}

            override fun onError(error: Int) {
                if (!voiceSession) return
                when (error) {
                    SpeechRecognizer.ERROR_NO_MATCH,
                    SpeechRecognizer.ERROR_SPEECH_TIMEOUT,
                    SpeechRecognizer.ERROR_CLIENT,
                    SpeechRecognizer.ERROR_RECOGNIZER_BUSY,
                    -> restartQuietly()
                    SpeechRecognizer.ERROR_INSUFFICIENT_PERMISSIONS ->
                        emit(hashMapOf("type" to "error", "code" to error))
                    SpeechRecognizer.ERROR_NETWORK,
                    SpeechRecognizer.ERROR_NETWORK_TIMEOUT,
                    -> emit(hashMapOf("type" to "error", "code" to error))
                    else -> restartQuietly()
                }
            }

            override fun onResults(results: Bundle?) {
                val text = results
                    ?.getStringArrayList(SpeechRecognizer.RESULTS_RECOGNITION)
                    ?.firstOrNull()
                    ?.trim()
                    ?: ""
                if (text.isNotEmpty()) {
                    emit(hashMapOf("type" to "final", "text" to text))
                    voiceSession = false
                } else {
                    restartQuietly()
                }
            }

            override fun onPartialResults(partialResults: Bundle?) {
                val text = partialResults
                    ?.getStringArrayList(SpeechRecognizer.RESULTS_RECOGNITION)
                    ?.firstOrNull()
                if (!text.isNullOrBlank()) {
                    emit(hashMapOf("type" to "partial", "text" to text))
                }
            }

            override fun onEvent(eventType: Int, params: Bundle?) {}
        })
    }

    private fun restartQuietly() {
        if (!voiceSession) return
        if (voiceRestarts >= 5) {
            emit(hashMapOf("type" to "error", "code" to SpeechRecognizer.ERROR_NO_MATCH))
            return
        }
        voiceRestarts += 1
        val intent = lastVoiceIntent ?: speechIntent(lastVoiceLang)
        lastVoiceIntent = intent
        voiceHandler.postDelayed({
            if (!voiceSession) return@postDelayed
            try {
                if (voiceRestarts >= 2) {
                    bindRecognizer()
                }
                recognizer?.startListening(intent)
            } catch (_: Exception) {
                emit(hashMapOf("type" to "error", "code" to SpeechRecognizer.ERROR_CLIENT))
            }
        }, 220)
    }

    private fun startOverlay(lang: String, result: MethodChannel.Result) {
        if (pendingOverlay != null) {
            result.error("busy", "already listening", null)
            return
        }
        takeMicFocus()
        val intent = speechIntent(lang)
        try {
            pendingOverlay = result
            @Suppress("DEPRECATION")
            startActivityForResult(intent, VOICE_REQ)
        } catch (e: Exception) {
            pendingOverlay = null
            dropMicFocus()
            result.error("unavailable", e.message, null)
        }
    }

    private fun stopVoice() {
        voiceSession = false
        voiceHandler.removeCallbacksAndMessages(null)
        try {
            recognizer?.stopListening()
        } catch (_: Exception) {
        }
        try {
            recognizer?.destroy()
        } catch (_: Exception) {
        }
        recognizer = null
        dropMicFocus()
    }

    private fun keyguardLocked(): Boolean {
        val km = getSystemService(KEYGUARD_SERVICE) as KeyguardManager
        return km.isKeyguardLocked()
    }

    private fun isHeadsetOrBluetooth(am: AudioManager): Boolean {
        @Suppress("DEPRECATION")
        if (am.isBluetoothA2dpOn || am.isWiredHeadsetOn || am.isBluetoothScoOn) {
            return true
        }
        val devices = am.getDevices(AudioManager.GET_DEVICES_OUTPUTS)
        for (d in devices) {
            when (d.type) {
                AudioDeviceInfo.TYPE_WIRED_HEADSET,
                AudioDeviceInfo.TYPE_WIRED_HEADPHONES,
                AudioDeviceInfo.TYPE_USB_HEADSET,
                AudioDeviceInfo.TYPE_BLUETOOTH_A2DP,
                AudioDeviceInfo.TYPE_BLUETOOTH_SCO,
                AudioDeviceInfo.TYPE_HEARING_AID -> return true
            }
            if (Build.VERSION.SDK_INT >= 31) {
                if (d.type == AudioDeviceInfo.TYPE_BLE_HEADSET ||
                    d.type == AudioDeviceInfo.TYPE_BLE_SPEAKER
                ) {
                    return true
                }
            }
        }
        return false
    }

    private fun systemVolume(am: AudioManager): Double {
        val max = am.getStreamMaxVolume(AudioManager.STREAM_MUSIC).coerceAtLeast(1)
        return am.getStreamVolume(AudioManager.STREAM_MUSIC).toDouble() / max
    }

    companion object {
        private const val VOICE_REQ = 9173
    }
}