import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import 'package:speech_to_text/speech_to_text.dart';

import '../../providers/player_provider.dart';
import '../../providers/theme_provider.dart';
import '../../routes/app_router.dart';
import '../../services/voice_input_service.dart';

class VoiceSearchSheet extends StatefulWidget {
  const VoiceSearchSheet({Key? key}) : super(key: key);

  static Future<String?> show(BuildContext context) {
    final navContext = AppRouter.navigatorKey.currentContext ?? context;
    return showDialog<String>(
      context: navContext,
      useRootNavigator: true,
      barrierDismissible: true,
      barrierColor: Colors.black.withOpacity(0.86),
      builder: (_) => const VoiceSearchSheet(),
    );
  }

  @override
  State<VoiceSearchSheet> createState() => _VoiceSearchSheetState();
}

class _VoiceSearchSheetState extends State<VoiceSearchSheet> {
  final SpeechToText _speech = SpeechToText();
  String _status = 'Listening...';
  bool _listening = false;
  bool _failed = false;
  bool _busy = false;
  bool _closing = false;
  double _level = 0.28;
  Timer? _watch;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _start());
  }

  @override
  void dispose() {
    _watch?.cancel();
    if (_speech.isListening) {
      _speech.stop();
    }
    super.dispose();
  }

  void _armWatch() {
    _watch?.cancel();
    _watch = Timer(const Duration(seconds: 22), () {
      if (!mounted || _closing) return;
      _busy = false;
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
    Navigator.of(context).pop(q);
  }

  Future<void> _hushPlayer() async {
    try {
      final player = context.read<PlayerProvider>();
      if (player.isPlaying) await player.togglePlayPause();
    } catch (_) {}
  }

  Future<void> _start() async {
    if (_closing) return;
    if (_busy) return;
    _busy = true;
    _watch?.cancel();
    setState(() {
      _failed = false;
      _status = 'Listening...';
      _listening = true;
      _level = 0.42;
    });
    _armWatch();

    try {
      final mic = await Permission.microphone.request()
          .timeout(const Duration(seconds: 8));
      if (!mounted || _closing) return;
      if (!mic.isGranted) {
        _fail(
          mic.isPermanentlyDenied
              ? 'Microphone permission is off. Open Settings to allow it.'
              : 'Allow the microphone to search by voice.',
        );
        return;
      }

      await _hushPlayer();
      if (!mounted || _closing) return;
      await Future<void>.delayed(const Duration(milliseconds: 250));
      if (!mounted || _closing) return;

      if (Platform.isAndroid) {
        final spoken = await VoiceInputService.listen(lang: 'hi-IN');
        if (!mounted || _closing) return;
        if (spoken != null && spoken.isNotEmpty) {
          _popWith(spoken);
          return;
        }
        _fail("Didn't catch that. Tap the mic and try again.");
        return;
      }

      final ok = await _speech
          .initialize()
          .timeout(const Duration(seconds: 5), onTimeout: () => false);
      if (!mounted || _closing) return;
      if (!ok) {
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
        listenOptions: SpeechListenOptions(
          listenFor: const Duration(seconds: 8),
          pauseFor: const Duration(seconds: 3),
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
    final ring = 78.0 + 34.0 * _level;

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
              child: SizedBox(
                width: 160,
                height: 160,
                child: Center(
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 70),
                    width: _listening ? ring : 104,
                    height: _listening ? ring : 104,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: (_failed ? t.textSecondary : t.accent)
                          .withOpacity(0.16),
                    ),
                    child: Center(
                      child: Container(
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
                    ),
                  ),
                ),
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