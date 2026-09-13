import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import 'package:speech_to_text/speech_to_text.dart';

import '../../providers/player_provider.dart';
import '../../providers/theme_provider.dart';
import '../../routes/app_router.dart';

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
  String _heard = '';
  String _status = 'Listening...';
  bool _listening = false;
  bool _failed = false;
  bool _busy = false;
  bool _closing = false;
  bool _inited = false;
  double _level = 0.28;
  Timer? _settle;
  Timer? _watch;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _start());
  }

  @override
  void dispose() {
    _settle?.cancel();
    _watch?.cancel();
    if (_speech.isListening) {
      _speech.stop();
    }
    super.dispose();
  }

  Future<void> _hushPlayer() async {
    try {
      final player = context.read<PlayerProvider>();
      if (player.isPlaying) await player.togglePlayPause();
    } catch (_) {}
  }

  void _armWatch() {
    _watch?.cancel();
    _watch = Timer(const Duration(seconds: 9), () {
      if (!mounted || _closing || _failed) return;
      if (_speech.isListening) {
        _speech.stop();
      }
      _maybeFinish(forceFail: true);
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
    _listening = false;
    _busy = false;
    Navigator.of(context).pop(q);
  }

  void _maybeFinish({required bool forceFail}) {
    if (!mounted || _closing) return;
    final phrase = _heard.trim();
    if (phrase.isNotEmpty) {
      _popWith(phrase);
      return;
    }
    if (forceFail) {
      _fail("Didn't catch that. Tap the mic and try again.");
    }
  }

  void _onStatus(String status) {
    if (!mounted || _closing) return;
    final done = status == 'done' || status == 'notListening';
    if (!done) return;
    _listening = false;
    _settle?.cancel();
    _settle = Timer(const Duration(milliseconds: 280), () {
      _maybeFinish(forceFail: true);
    });
  }

  void _onError(dynamic error) {
    if (!mounted || _closing) return;
    final id = error.errorMsg?.toString() ?? '';
    if (id == 'error_no_match' ||
        id == 'error_speech_timeout' ||
        id == 'error_none') {
      _settle?.cancel();
      _settle = Timer(const Duration(milliseconds: 280), () {
        _maybeFinish(forceFail: true);
      });
      return;
    }
    if (id == 'error_network' || id == 'error_network_timeout') {
      _fail('Voice search needs internet. Check your connection.');
      return;
    }
    if (id == 'error_permission' || id == 'error_audio') {
      _fail('Microphone is blocked. Allow it in Settings.');
      return;
    }
    _fail("Didn't catch that. Tap the mic and try again.");
  }

  Future<bool> _hasConnection() async {
    try {
      final result = await Connectivity().checkConnectivity();
      return result != ConnectivityResult.none;
    } catch (_) {
      return true;
    }
  }

  Future<String?> _pickLocale() async {
    try {
      final locales = await _speech.locales();
      const prefer = ['hi_IN', 'hi-IN', 'en_IN', 'en-IN', 'en_US', 'en-US'];
      for (final want in prefer) {
        final norm = want.replaceAll('-', '_').toLowerCase();
        for (final loc in locales) {
          if (loc.localeId.replaceAll('-', '_').toLowerCase() == norm) {
            return loc.localeId;
          }
        }
      }
      final sys = await _speech.systemLocale();
      return sys?.localeId;
    } catch (_) {
      return null;
    }
  }

  Future<void> _listenWith(String? localeId) {
    return _speech.listen(
      onResult: (result) {
        if (!mounted || _closing) return;
        final words = result.recognizedWords.trim();
        setState(() {
          _heard = words;
          if (words.isNotEmpty) _status = words;
        });
        if (result.finalResult && words.isNotEmpty) {
          _popWith(words);
        }
      },
      onSoundLevelChange: (level) {
        if (!mounted || !_listening) return;
        setState(() => _level = ((level + 8) / 18).clamp(0.22, 1.0));
      },
      listenOptions: SpeechListenOptions(
        listenFor: const Duration(seconds: 8),
        pauseFor: const Duration(seconds: 3),
        partialResults: true,
        cancelOnError: false,
        listenMode: ListenMode.confirmation,
        localeId: localeId,
        onDevice: false,
      ),
    );
  }

  Future<void> _start() async {
    if (_busy || _closing) return;
    _busy = true;
    _settle?.cancel();
    _watch?.cancel();
    setState(() {
      _failed = false;
      _heard = '';
      _status = 'Listening...';
      _listening = false;
      _level = 0.28;
    });

    final online = await _hasConnection();
    if (!mounted) return;
    if (!online) {
      _fail('Voice search needs internet. Check your connection.');
      return;
    }

    final mic = await Permission.microphone.request();
    if (!mounted) return;
    if (!mic.isGranted) {
      _fail(
        mic.isPermanentlyDenied
            ? 'Microphone permission is off. Open Settings to allow it.'
            : 'Allow the microphone to search by voice.',
      );
      return;
    }

    await _hushPlayer();
    if (!mounted) return;
    await Future<void>.delayed(const Duration(milliseconds: 450));
    if (!mounted) return;

    if (!_inited) {
      final ok = await _speech.initialize(
        onStatus: _onStatus,
        onError: _onError,
      );
      if (!mounted) return;
      if (!ok) {
        _fail('Voice search is not available on this phone. Install Google app.');
        return;
      }
      _inited = true;
    }

    if (_speech.isListening) {
      await _speech.stop();
    }

    final localeId = await _pickLocale();
    if (!mounted) return;

    setState(() {
      _listening = true;
      _status = 'Listening...';
    });
    _armWatch();

    try {
      await _listenWith(localeId);
      if (mounted && !_speech.isListening && _heard.isEmpty && !_failed) {
        await Future<void>.delayed(const Duration(milliseconds: 200));
        if (mounted && !_speech.isListening && _heard.isEmpty && !_failed) {
          _fail('Voice search is not available on this phone. Install Google app.');
          return;
        }
      }
    } catch (_) {
      if (!mounted) return;
      try {
        await _listenWith(null);
      } catch (_) {
        _fail("Didn't catch that. Tap the mic and try again.");
        return;
      }
    }
    _busy = false;
  }

  void _onMicTap() {
    if (_listening) {
      _speech.stop();
      _maybeFinish(forceFail: true);
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
                _failed ? _status : (_heard.isEmpty ? 'Listening...' : _heard),
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
                          _failed && !_listening ? Icons.mic_off : Icons.mic,
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