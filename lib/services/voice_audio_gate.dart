import 'package:audio_session/audio_session.dart';

import 'player_service.dart';
import 'voice_input_service.dart';

class VoiceAudioGate {
  static final VoiceAudioGate _i = VoiceAudioGate._();
  factory VoiceAudioGate() => _i;
  VoiceAudioGate._();

  bool _held = false;
  bool _wasPlaying = false;

  Future<void> release() async {
    if (_held) return;
    final player = PlayerService().player;
    _wasPlaying = player.playing;
    if (_wasPlaying) {
      try {
        await player.pause();
      } catch (_) {}
    }
    try {
      final session = await AudioSession.instance;
      await session.setActive(false);
    } catch (_) {}
    await VoiceInputService.releasePlayback();
    await Future<void>.delayed(const Duration(milliseconds: 600));
    _held = true;
  }

  Future<void> restore() async {
    if (!_held) return;
    _held = false;
    await VoiceInputService.stop();
    await VoiceInputService.restorePlayback();
    try {
      final session = await AudioSession.instance;
      await session.setActive(true);
    } catch (_) {}
    if (_wasPlaying) {
      _wasPlaying = false;
      try {
        await PlayerService().player.play();
      } catch (_) {}
    }
  }
}