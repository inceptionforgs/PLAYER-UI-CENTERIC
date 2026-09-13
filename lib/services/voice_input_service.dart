import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';

class VoiceInputService {
  static const _ch = MethodChannel('mewati.voice/input');

  static Future<String?> listen({String lang = 'hi-IN'}) async {
    if (!Platform.isAndroid) return null;
    try {
      final text = await _ch
          .invokeMethod<String>('listen', {'lang': lang})
          .timeout(const Duration(seconds: 25));
      final t = text?.trim();
      if (t == null || t.isEmpty) return null;
      return t;
    } on PlatformException {
      return null;
    } on TimeoutException {
      return null;
    } catch (_) {
      return null;
    }
  }
}