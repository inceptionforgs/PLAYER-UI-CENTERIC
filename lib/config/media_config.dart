class MediaConfig {
  // Host allowlist for audio playback and downloads. Only URLs whose host
  // exactly matches this value are ever passed to the player or the
  // downloader — protects against a malformed/tampered audioUrl pointing
  // somewhere other than the project's own CDN (Supabase storage).
  // Override at build time:
  //   flutter build apk --release \
  //     --dart-define=AUDIO_CDN_HOST=vryngmkjnposksoaknik.supabase.co
  static const String _audioCdnHost = String.fromEnvironment(
    'AUDIO_CDN_HOST',
    defaultValue: 'vryngmkjnposksoaknik.supabase.co',
  );

  static String get allowedAudioHost => _audioCdnHost;

  /// Returns true only if [url] parses to a URI whose host exactly matches
  /// the allowlisted CDN host (case-insensitive).
  static bool isAllowedAudioUrl(String url) {
    final uri = Uri.tryParse(url);
    if (uri == null || uri.host.isEmpty) return false;
    return uri.host.toLowerCase() == allowedAudioHost.toLowerCase();
  }
}

