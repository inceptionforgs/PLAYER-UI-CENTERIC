import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../models/song.dart';
import 'supabase_service.dart';

class ListenPingService {
  static final ListenPingService _i = ListenPingService._();
  factory ListenPingService() => _i;
  ListenPingService._();

  static const _sessionKey = 'listen_session_id';
  Timer? _beat;
  String? _sessionId;
  Song? _last;
  Map<String, dynamic>? _geo;
  DateTime? _geoAt;

  Future<void> start(Song? song) async {
    _last = song;
    await ping(song);
    _beat?.cancel();
    _beat = Timer.periodic(const Duration(seconds: 25), (_) {
      unawaited(ping(_last));
    });
  }

  void stop() {
    _beat?.cancel();
    _beat = null;
  }

  Future<void> ping(Song? song) async {
    if (song != null) _last = song;
    final track = _last;
    if (track == null || track.id.isEmpty) return;
    try {
      final id = await _id();
      final geo = await _geoCached();
      await SupabaseService().client.from('listen_sessions').upsert(
        {
          'session_id': id,
          'song_id': track.id,
          'song_title': track.title,
          'category': track.category,
          'ip': geo['ip'],
          'country': geo['country'],
          'region': geo['region'],
          'city': geo['city'],
          'lat': geo['lat'],
          'lon': geo['lon'],
          'last_seen': DateTime.now().toUtc().toIso8601String(),
        },
        onConflict: 'session_id',
      );
    } catch (_) {}
  }

  Future<String> _id() async {
    if (_sessionId != null) return _sessionId!;
    final prefs = await SharedPreferences.getInstance();
    var id = prefs.getString(_sessionKey);
    if (id == null || id.isEmpty) {
      id = _uuid();
      await prefs.setString(_sessionKey, id);
    }
    _sessionId = id;
    return id;
  }

  Future<Map<String, dynamic>> _geoCached() async {
    final fresh = _geo != null &&
        _geoAt != null &&
        DateTime.now().difference(_geoAt!) < const Duration(hours: 6);
    if (fresh) return _geo!;
    try {
      final res = await http.get(Uri.parse('https://ipwho.is/')).timeout(
            const Duration(seconds: 8),
          );
      if (res.statusCode >= 200 && res.statusCode < 300) {
        final j = jsonDecode(res.body);
        if (j is Map && j['success'] != false) {
          _geo = {
            'ip': j['ip'],
            'country': j['country'],
            'region': j['region'],
            'city': j['city'],
            'lat': j['latitude'],
            'lon': j['longitude'],
          };
          _geoAt = DateTime.now();
          return _geo!;
        }
      }
    } catch (_) {}
    return {
      'ip': null,
      'country': null,
      'region': null,
      'city': null,
      'lat': null,
      'lon': null,
    };
  }

  String _uuid() {
    final r = Random.secure();
    final b = List<int>.generate(16, (_) => r.nextInt(256));
    b[6] = (b[6] & 0x0f) | 0x40;
    b[8] = (b[8] & 0x3f) | 0x80;
    String h(int i) => b[i].toRadixString(16).padLeft(2, '0');
    return '${h(0)}${h(1)}${h(2)}${h(3)}-${h(4)}${h(5)}-${h(6)}${h(7)}-${h(8)}${h(9)}-${h(10)}${h(11)}${h(12)}${h(13)}${h(14)}${h(15)}';
  }
}