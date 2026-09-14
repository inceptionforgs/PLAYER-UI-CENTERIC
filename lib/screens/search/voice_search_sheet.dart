import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import 'package:speech_to_text/speech_to_text.dart';

import '../../providers/theme_provider.dart';
import '../../routes/app_router.dart';
import '../../services/voice_audio_gate.dart';
import '../../services/voice_input_service.dart';

class VoiceSearchSheet extends StatefulWidget {
  const VoiceSearchSheet({Key? key}) : super(key: key);

  static Future<String?> show(BuildContext context) {
    final navContext = AppRouter.navigatorKey.currentContext ?? context;
    return showDialog<String>(
      context: navContext,
      useRootNavigator: true,
      barrierDismissible: true,
      barrierColor: Colors.black.withOpacity(0.92),
      builder: (_) => const VoiceSearchSheet(),
    );
  }

  @override
  State<VoiceSearchSheet> createState() => _VoiceSearchSheetState();
}

class _VoiceSearchSheetState extends State<VoiceSearchSheet>
    with SingleTickerProviderStateMixin {
  final SpeechToText _speech = SpeechToText();
  final VoiceAudioGate _gate = VoiceAudioGate();
  String _status = 'Listening...';
  bool _listening = false;
  bool _failed = false;
  bool _busy = false;
  bool _closing = false;
  double _level = 0.22;
  Timer? _watch;
  StreamSubscription<VoiceEvent>? _events;
  late final AnimationController _idle;

  @override
  void initState() {
    super.initState();
    _idle = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
    WidgetsBinding.instance.addPostFrameCallback((_) => _start());
  }

  @override
  void dispose() {
    _watch?.cancel();
    _events?.cancel();
    _idle.dispose();
    unawaited(_gate.restore());
    if (_speech.isListening) {
      _speech.stop();
    }
    super.dispose();
  }

  void _armWatch() {
    _watch?.cancel();
    _watch = Timer(const Duration(seconds: 8), () {
      if (!mounted || _closing) return;
      _busy = false;
      VoiceInputService.stop();
      if (_speech.isListening) {
        _speech.stop();
      }
      _fail("Didn't catch that. Tap the mic and try again.");
    });
  }

  void _fail(String message) {
    if (!mounted || _closing) return;
    _watch?.cancel();
    _busy = false;
    _listening = false;
    _idle.stop();
    VoiceInputService.stop();
    unawaited(_gate.restore());
    setState(() {
      _failed = true;
      _status = message;
    });
  }

  void _popWith(String phrase) {
    final q = phrase.trim();
    if (!mounted || _closing || q.isEmpty) return;
    _watch?.cancel();
    _closing = true;
    _busy = false;
    _listening = false;
    VoiceInputService.stop();
    unawaited(_gate.restore());
    Navigator.of(context).pop(q);
  }

  void _onNative(VoiceEvent e) {
    if (!mounted || _closing) return;
    switch (e.type) {
      case 'rms':
        final v = ((e.rms ?? -2) + 2) / 12;
        setState(() => _level = v.clamp(0.18, 1.0));
        break;
      case 'partial':
        final t = e.text?.trim() ?? '';
        if (t.isNotEmpty) {
          _armWatch();
          setState(() => _status = t);
        }
        break;
      case 'final':
        final t = e.text?.trim() ?? '';
        if (t.isNotEmpty) {
          _popWith(t);
        } else {
          _fail("Didn't catch that. Tap the mic and try again.");
        }
        break;
      case 'error':
        if (e.code == 9) {
          _fail('Microphone is blocked. Allow it in Settings.');
          return;
        }
        if (e.code == 2 || e.code == 1) {
          _fail('Voice search needs internet. Check your connection.');
          return;
        }
        _fail("Didn't catch that. Tap the mic and try again.");
        break;
    }
  }

  Future<void> _start() async {
    if (_closing || _busy) return;
    _busy = true;
    _watch?.cancel();
    await _events?.cancel();
    setState(() {
      _failed = false;
      _status = 'Listening...';
      _listening = true;
      _level = 0.22;
    });
    _idle.repeat(reverse: true);
    _armWatch();

    try {
      final mic = await Permission.microphone
          .request()
          .timeout(const Duration(seconds: 6));
      if (!mounted || _closing) return;
      if (!mic.isGranted) {
        _fail(
          mic.isPermanentlyDenied
              ? 'Microphone permission is off. Open Settings to allow it.'
              : 'Allow the microphone to search by voice.',
        );
        return;
      }

      await _gate.release();
      if (!mounted || _closing) return;

      if (Platform.isAndroid) {
        _events = VoiceInputService.events().listen(_onNative);
        final ok = await VoiceInputService.start(lang: 'hi-IN');
        if (!mounted || _closing) return;
        if (!ok) {
          _fail(
            'Voice search is not available on this phone. Install Google app.',
          );
          return;
        }
        return;
      }

      final ready = await _speech
          .initialize()
          .timeout(const Duration(seconds: 4), onTimeout: () => false);
      if (!mounted || _closing) return;
      if (!ready) {
        _fail('Voice search is not available on this phone.');
        return;
      }
      await _speech.listen(
        onResult: (result) {
          if (!mounted || _closing) return;
          final words = result.recognizedWords.trim();
          if (words.isEmpty) return;
          setState(() => _status = words);
          if (result.finalResult) _popWith(words);
        },
        onSoundLevelChange: (level) {
          if (!mounted || !_listening) return;
          setState(() => _level = ((level + 8) / 18).clamp(0.18, 1.0));
        },
        listenOptions: SpeechListenOptions(
          listenFor: const Duration(seconds: 6),
          pauseFor: const Duration(seconds: 2),
          partialResults: true,
          localeId: 'hi_IN',
        ),
      );
    } on TimeoutException {
      if (!mounted || _closing) return;
      _fail("Didn't catch that. Tap the mic and try again.");
    } catch (_) {
      if (!mounted || _closing) return;
      _fail('Voice search is not available on this phone. Install Google app.');
    } finally {
      _busy = false;
    }
  }

  void _onMicTap() {
    if (_closing) return;
    if (_busy || _listening) {
      _watch?.cancel();
      _busy = false;
      _listening = false;
      VoiceInputService.stop();
      if (_speech.isListening) {
        _speech.stop();
      }
      _fail("Didn't catch that. Tap the mic and try again.");
      return;
    }
    _start();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.watch<ThemeProvider>().theme;

    return Dialog.fullscreen(
      backgroundColor: t.background,
      child: SafeArea(
        child: Column(
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: IconButton(
                icon: Icon(Icons.close, color: t.textPrimary, size: 28),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ),
            const Spacer(flex: 2),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 28),
              child: Text(
                _status,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: t.textPrimary,
                  fontSize: 28,
                  fontWeight: FontWeight.w600,
                  height: 1.25,
                ),
              ),
            ),
            const Spacer(flex: 3),
            GestureDetector(
              onTap: _onMicTap,
              child: AnimatedBuilder(
                animation: _idle,
                builder: (context, _) {
                  final breathe = _listening ? 0.12 + 0.10 * _idle.value : 0;
                  final energy =
                      _listening ? (_level + breathe).clamp(0.18, 1.0) : 0.0;
                  return SizedBox(
                    width: 220,
                    height: 220,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        _WaveRing(
                          size: 88 + 118 * energy,
                          color: t.accent.withOpacity(0.10 + 0.10 * energy),
                        ),
                        _WaveRing(
                          size: 88 + 78 * energy,
                          color: t.accent.withOpacity(0.16 + 0.14 * energy),
                        ),
                        _WaveRing(
                          size: 88 + 40 * energy,
                          color: t.accent.withOpacity(0.22 + 0.18 * energy),
                        ),
                        Container(
                          width: 76,
                          height: 76,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: _failed ? t.textSecondary : t.accent,
                          ),
                          child: Icon(
                            _failed ? Icons.mic_off : Icons.mic,
                            color: t.background,
                            size: 36,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 14),
            Text(
              _listening ? 'Speak now' : 'Tap the mic to try again',
              style: TextStyle(color: t.textSecondary, fontSize: 14),
            ),
            if (_failed && _status.contains('Settings'))
              TextButton(
                onPressed: () => openAppSettings(),
                child: Text('Open Settings', style: TextStyle(color: t.accent)),
              ),
            const SizedBox(height: 36),
          ],
        ),
      ),
    );
  }
}

class _WaveRing extends StatelessWidget {
  final double size;
  final Color color;

  const _WaveRing({required this.size, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color,
      ),
    );
  }
}