import 'package:flutter_test/flutter_test.dart';
import 'package:mewati_tune_player/config/media_config.dart';

void main() {
  const host = 'vryngmkjnposksoaknik.supabase.co';

  group('MediaConfig.isAllowedAudioUrl', () {
    test('allows https URL on the exact CDN host', () {
      expect(
        MediaConfig.isAllowedAudioUrl(
          'https://$host/storage/v1/object/public/audio/song.mp3',
        ),
        isTrue,
      );
    });

    test('allows http URL on the exact CDN host (host check only)', () {
      expect(
        MediaConfig.isAllowedAudioUrl('http://$host/audio/song.mp3'),
        isTrue,
      );
    });

    test('matches host case-insensitively', () {
      expect(
        MediaConfig.isAllowedAudioUrl(
          'https://VRYNGMKJNPOSKSOAKNIK.SUPABASE.CO/a.mp3',
        ),
        isTrue,
      );
    });

    test('ignores path, query and fragment', () {
      expect(
        MediaConfig.isAllowedAudioUrl(
          'https://$host/x/y.mp3?token=abc#clip',
        ),
        isTrue,
      );
    });

    test('allows a URL with an explicit port (host still exact)', () {
      expect(
        MediaConfig.isAllowedAudioUrl('https://$host:443/a.mp3'),
        isTrue,
      );
    });

    test('rejects empty string', () {
      expect(MediaConfig.isAllowedAudioUrl(''), isFalse);
    });

    test('rejects whitespace-only string', () {
      expect(MediaConfig.isAllowedAudioUrl('   '), isFalse);
    });

    test('rejects a path with no host', () {
      expect(MediaConfig.isAllowedAudioUrl('/audio/song.mp3'), isFalse);
      expect(MediaConfig.isAllowedAudioUrl('song.mp3'), isFalse);
    });

    test('rejects file, data and javascript URLs', () {
      expect(MediaConfig.isAllowedAudioUrl('file:///sdcard/song.mp3'), isFalse);
      expect(MediaConfig.isAllowedAudioUrl('data:audio/mpeg;base64,AAA'), isFalse);
      expect(MediaConfig.isAllowedAudioUrl('javascript:alert(1)'), isFalse);
    });

    test('rejects a different host', () {
      expect(
        MediaConfig.isAllowedAudioUrl('https://evil.example/song.mp3'),
        isFalse,
      );
    });

    test('rejects a CDN subdomain (prefix spoof)', () {
      expect(
        MediaConfig.isAllowedAudioUrl('https://cdn.$host/song.mp3'),
        isFalse,
      );
    });

    test('rejects host that only starts with the CDN name', () {
      expect(
        MediaConfig.isAllowedAudioUrl(
          'https://$host.attacker.com/song.mp3',
        ),
        isFalse,
      );
    });

    test('rejects CDN host in the path of another origin', () {
      expect(
        MediaConfig.isAllowedAudioUrl('https://evil.com/$host/song.mp3'),
        isFalse,
      );
    });

    test('rejects userinfo spoof (cdn@evil.com)', () {
      expect(
        MediaConfig.isAllowedAudioUrl('https://$host@evil.com/song.mp3'),
        isFalse,
      );
    });

    test('rejects null-ish parse failures without throwing', () {
      expect(MediaConfig.isAllowedAudioUrl('://'), isFalse);
      expect(MediaConfig.isAllowedAudioUrl('https://'), isFalse);
    });
  });
}
