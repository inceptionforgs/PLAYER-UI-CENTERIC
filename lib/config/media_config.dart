class MediaConfig {
  static const String _audioCdnHost = String.fromEnvironment(
    'AUDIO_CDN_HOST',
    defaultValue: 'pub-31576cb95c8740c8816316f85181ecdd.r2.dev',
  );

  static const String _r2AudioHost =
      'pub-31576cb95c8740c8816316f85181ecdd.r2.dev';
  static const String _supabaseAudioHost = 'vryngmkjnposksoaknik.supabase.co';

  static String get allowedAudioHost => _audioCdnHost;

  static bool isAllowedAudioUrl(String url) {
    final uri = Uri.tryParse(url);
    if (uri == null || uri.host.isEmpty) return false;
    final host = uri.host.toLowerCase();
    return host == _audioCdnHost.toLowerCase() ||
        host == _r2AudioHost.toLowerCase() ||
        host == _supabaseAudioHost.toLowerCase();
  }
}