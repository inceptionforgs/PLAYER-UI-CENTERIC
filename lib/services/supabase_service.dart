import 'package:supabase_flutter/supabase_flutter.dart';
import '../config/supabase_config.dart';

class SupabaseService {
  static final SupabaseService _instance = SupabaseService._internal();
  factory SupabaseService() => _instance;
  SupabaseService._internal();

  SupabaseClient? _client;
  Future<void>? _initFuture;

  bool get isInitialized => _client != null;

  SupabaseClient get client {
    final client = _client;
    if (client == null) {
      throw Exception('Supabase client not initialized. Call initialize() first.');
    }
    return client;
  }

  Future<void> initialize() async {
    if (_client != null) return;
    final inflight = _initFuture;
    if (inflight != null) {
      await inflight;
      return;
    }
    final future = _initializeOnce();
    _initFuture = future;
    try {
      await future;
    } catch (e) {
      if (_client != null) return;
      if (identical(_initFuture, future)) _initFuture = null;
      rethrow;
    }
  }

  Future<void> _initializeOnce() async {
    if (SupabaseConfig.url.isEmpty || SupabaseConfig.anonKey.isEmpty) {
      throw Exception('Supabase URL or anon key is missing.');
    }

    try {
      await Supabase.initialize(
        url: SupabaseConfig.url,
        anonKey: SupabaseConfig.anonKey,
      );
      _client = Supabase.instance.client;
    } catch (e) {
      try {
        _client = Supabase.instance.client;
        return;
      } catch (_) {
        throw Exception('Failed to initialize Supabase: $e');
      }
    }
  }
}
