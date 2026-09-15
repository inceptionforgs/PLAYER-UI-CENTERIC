import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:just_audio_background/just_audio_background.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

import 'app.dart';
import 'config/environment.dart';
import 'providers/auth_provider.dart';
import 'providers/downloads_provider.dart';
import 'services/debug_log_service.dart';
import 'services/local_cache_service.dart';
import 'services/supabase_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await dotenv.load(fileName: '.env');
  } catch (e) {
    debugPrint('Optional .env not loaded: $e');
  }

  // MUST complete before runApp / AudioPlayer() so Android Auto binds
  // to the same player instance that actually plays audio.
  await _initJustAudioBackground();
  await _initSupabase();

  final downloadsProvider = DownloadsProvider();
  final authProvider = AuthProvider();

  runApp(
    MewatiTunePlayerApp(
      authProvider: authProvider,
      downloadsProvider: downloadsProvider,
    ),
  );

  unawaited(_initializeRest(downloadsProvider));
}

Future<void> _initializeRest(DownloadsProvider downloadsProvider) async {
  try {
    await Future.wait<void>([
      _initLocalCache(),
      _initDownloads(downloadsProvider),
      _initSentry(),
    ]);
    DebugLogService().info('App initialized successfully');
  } catch (e) {
    DebugLogService().error('App initialization failed: $e');
  }
}

Future<void> _initJustAudioBackground() async {
  await JustAudioBackground.init(
    androidNotificationChannelId: 'com.mewatitune.player.channel.audio',
    androidNotificationChannelName: 'Mewati Music Player Playback',
    androidNotificationOngoing: true,
    androidStopForegroundOnPause: true,
    androidBrowsableRootExtras: const {
      'android.media.browse.SEARCH_SUPPORTED': true,
    },
  );
}

Future<void> _initSupabase() async {
  try {
    await SupabaseService().initialize().timeout(
      const Duration(seconds: 10),
      onTimeout: () {
        throw TimeoutException('Supabase initialization timed out.');
      },
    );
    DebugLogService().info('Supabase initialized successfully');
  } catch (e) {
    debugPrint('Supabase init failed/timed out: $e');
    DebugLogService().error('Supabase initialization failed: $e');
  }
}

Future<void> _initLocalCache() async {
  try {
    await LocalCacheService().initialize().timeout(
      const Duration(seconds: 5),
    );
    DebugLogService().info('Local cache initialized successfully');
  } catch (e) {
    debugPrint('LocalCacheService.initialize failed/timed out: $e');
    DebugLogService().error('Local cache initialization failed: $e');
  }
}

Future<void> _initDownloads(DownloadsProvider downloadsProvider) async {
  try {
    await downloadsProvider.initialize().timeout(
      const Duration(seconds: 5),
    );
    DebugLogService().info('DownloadsProvider initialized successfully');
  } catch (e) {
    debugPrint('DownloadsProvider.initialize failed/timed out: $e');
    DebugLogService().error('DownloadsProvider initialization failed: $e');
  }
}

Future<void> _initSentry() async {
  if (Environment.sentryDsn.isEmpty) return;
  try {
    await SentryFlutter.init(
      (options) {
        options.dsn = Environment.sentryDsn;
        options.tracesSampleRate = Environment.sentryTracesSampleRate;
      },
    ).timeout(const Duration(seconds: 5));
    DebugLogService().info('Sentry initialized successfully');
  } catch (e) {
    debugPrint('SentryFlutter.init failed/timed out: $e');
    DebugLogService().error('Sentry initialization failed: $e');
  }
}