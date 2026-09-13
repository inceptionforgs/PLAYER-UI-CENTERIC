import 'package:flutter/foundation.dart';

import '../services/custom_song_service.dart';

class CustomSongProvider extends ChangeNotifier {
  CustomSongProvider({CustomSongService? service})
      : _service = service ?? CustomSongService();

  final CustomSongService _service;

  static const lengths = [
    '5–10 minutes',
    '10–15 minutes',
    '15–20 minutes',
    '20–25 minutes',
    '25–30 minutes',
  ];

  int step = 0;
  String name = '';
  String mobile = '';
  String? singerId;
  String? length;
  String lyrics = '';
  List<RegisteredSinger> singers = [];
  bool loadingSingers = false;
  bool submitting = false;
  String? errorMessage;

  RegisteredSinger? get singer {
    final id = singerId;
    if (id == null) return null;
    for (final s in singers) {
      if (s.id == id) return s;
    }
    return null;
  }

  void setName(String v) {
    name = v;
    notifyListeners();
  }

  void setMobile(String v) {
    mobile = v.replaceAll(RegExp(r'\D'), '');
    if (mobile.length > 10) mobile = mobile.substring(0, 10);
    notifyListeners();
  }

  void setSinger(String id) {
    singerId = id;
    notifyListeners();
  }

  void setLength(String v) {
    length = v;
    notifyListeners();
  }

  void setLyrics(String v) {
    lyrics = v;
    notifyListeners();
  }

  void back() {
    if (step == 0) return;
    errorMessage = null;
    step -= 1;
    notifyListeners();
  }

  Future<bool> next() async {
    errorMessage = null;
    if (step == 0) {
      if (name.trim().length < 2) {
        errorMessage = 'अपना नाम लिखें। / Please enter your name.';
        notifyListeners();
        return false;
      }
      if (!RegExp(r'^\d{10}$').hasMatch(mobile.trim())) {
        errorMessage = 'सही मोबाइल नंबर लिखें। / Please enter your mobile no.';
        notifyListeners();
        return false;
      }
      step = 1;
      notifyListeners();
      await loadSingers();
      return true;
    }
    if (step == 1) {
      if (singerId == null) {
        errorMessage = 'एक गायक चुनें। / Please choose a singer.';
        notifyListeners();
        return false;
      }
      step = 2;
      notifyListeners();
      return true;
    }
    return false;
  }

  Future<void> loadSingers() async {
    loadingSingers = true;
    errorMessage = null;
    notifyListeners();
    try {
      singers = await _service.listSingers();
    } catch (_) {
      singers = [];
      errorMessage = 'गायक सूची नहीं खुली। / Could not load singers.';
    } finally {
      loadingSingers = false;
      notifyListeners();
    }
  }

  String whatsappBody() {
    final lines = <String>[
      '🌼 🌹 New Song Request From Mewati Music Player 🌷 🌺',
      '',
      'Details :',
      '',
      'Naam: ${name.trim()}',
      'Mobile number: ${mobile.trim()}',
      'Gaane ki lambaai: ${length ?? ''}',
    ];
    final shayari = lyrics.trim();
    if (shayari.isNotEmpty) {
      lines.add('');
      lines.add('Requested lyrics: $shayari');
    }
    return lines.join('\n');
  }

  Future<String?> submit() async {
    final picked = singer;
    final len = length;
    if (picked == null || len == null) {
      errorMessage = 'गाने की लंबाई चुनें। / Please choose a song length.';
      notifyListeners();
      return null;
    }
    if (submitting) return null;
    submitting = true;
    errorMessage = null;
    notifyListeners();
    try {
      final shayari = lyrics.trim();
      final result = await _service.submit(
        name: name.trim(),
        mobile: mobile.trim(),
        singerId: picked.id,
        singerName: picked.name,
        singerPhone: picked.mobile,
        length: len,
        lyrics: shayari.isEmpty ? null : shayari,
      );
      if (!result.ok) {
        errorMessage = 'अभी अनुरोध नहीं भेज सकते। / Please try again later.';
        return null;
      }
      return 'https://wa.me/91${picked.mobile}?text=${Uri.encodeComponent(whatsappBody())}';
    } catch (_) {
      errorMessage = 'अनुरोध नहीं गया। / Please try again.';
      return null;
    } finally {
      submitting = false;
      notifyListeners();
    }
  }
}