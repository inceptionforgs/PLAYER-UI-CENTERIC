import 'package:supabase_flutter/supabase_flutter.dart';

import 'supabase_service.dart';

class RegisteredSinger {
  final String id;
  final String name;
  final String mobile;

  const RegisteredSinger({
    required this.id,
    required this.name,
    required this.mobile,
  });
}

class CustomSongSubmitResult {
  final bool ok;
  final String? reason;

  const CustomSongSubmitResult({required this.ok, this.reason});
}

class CustomSongService {
  static const int limit = 3;
  static const int windowHours = 6;

  SupabaseClient get _db => SupabaseService().client;

  String? _tenDigit(String raw) {
    final digits = raw.replaceAll(RegExp(r'\D'), '');
    final ten = digits.length >= 12 && digits.startsWith('91')
        ? digits.substring(digits.length - 10)
        : (digits.length >= 10 ? digits.substring(digits.length - 10) : digits);
    return ten.length == 10 ? ten : null;
  }

  Future<List<RegisteredSinger>> listSingers() async {
    final raw = await _db.rpc('list_registered_singers');
    final rows = (raw as List<dynamic>?) ?? const [];
    final seen = <String>{};
    final out = <RegisteredSinger>[];
    for (final row in rows) {
      if (row is! Map) continue;
      final mobile = _tenDigit('${row['mobile_number'] ?? ''}');
      if (mobile == null || seen.contains(mobile)) continue;
      seen.add(mobile);
      final name = '${row['name'] ?? ''}'.trim();
      out.add(RegisteredSinger(
        id: mobile,
        name: name.isEmpty ? 'Unknown Singer' : name,
        mobile: mobile,
      ));
    }
    out.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    return out;
  }

  Future<CustomSongSubmitResult> submit({
    required String name,
    required String mobile,
    required String singerId,
    required String singerName,
    required String singerPhone,
    required String length,
    String? lyrics,
  }) async {
    final since = DateTime.now()
        .toUtc()
        .subtract(const Duration(hours: windowHours))
        .toIso8601String();
    final existing = await _db
        .from('gana_requests')
        .select('id')
        .eq('customer_mobile', mobile)
        .gt('created_at', since);
    final used = (existing as List).length;
    if (used >= limit) {
      return const CustomSongSubmitResult(ok: false, reason: 'limit');
    }
    await _db.from('gana_requests').insert({
      'customer_name': name,
      'customer_mobile': mobile,
      'singer_id': singerId,
      'singer_name': singerName,
      'singer_phone': singerPhone,
      'length': length,
      'lyrics': lyrics,
    });
    return const CustomSongSubmitResult(ok: true);
  }
}