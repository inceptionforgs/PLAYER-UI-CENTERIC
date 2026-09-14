import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';

class VoiceEvent {
  final String type;
  final double? rms;
  final String? text;
  final int? code;

  VoiceEvent(this.type, {this.rms, this.text, this.code});
}

class VoiceInputService {
  static const _m = MethodChannel('mewati.voice/input');
  static const _e = EventChannel('mewati.voice/events');

  static Stream<VoiceEvent> events() {
    return _e.receiveBroadcastStream().map((raw) {
      final m = Map<String, dynamic>.from(raw as Map);
      return VoiceEvent(
        m['type'] as String? ?? '',
        rms: (m['v'] as num?)?.toDouble(),
        text: m['text'] as String?,
        code: m['code'] as int?,
      );
    });
  }

  static Future<bool> start({String lang = 'hi-IN'}) async {
    if (!Platform.isAndroid) return false;
    try {
      await _m.invokeMethod('start', {'lang': lang});
      return true;
    } catch (_) {
      return false;
    }
  }

  static Future<void> stop() async {
    if (!Platform.isAndroid) return;
    try {
      await _m.invokeMethod('stop');
    } catch (_) {}
  }

  static Future<void> releasePlayback() async {
    if (!Platform.isAndroid) return;
    try {
      await _m.invokeMethod('releasePlayback');
    } catch (_) {}
  }

  static Future<void> restorePlayback() async {
    if (!Platform.isAndroid) return;
    try {
      await _m.invokeMethod('restorePlayback');
    } catch (_) {}
  }
}