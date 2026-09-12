import 'package:flutter_test/flutter_test.dart';
import 'package:mewati_tune_player/models/song.dart';
import 'package:mewati_tune_player/providers/favorites_provider.dart';
import 'package:mewati_tune_player/services/favorites_service.dart';

class FakeFavoritesService implements FavoritesService {
  final Set<String> ids = {};
  int addCount = 0;
  int removeCount = 0;
  int inFlight = 0;
  int maxInFlight = 0;
  Duration? delay;

  @override
  Future<void> addFavorite(String songId) async {
    addCount++;
    inFlight++;
    if (inFlight > maxInFlight) maxInFlight = inFlight;
    try {
      if (delay != null) await Future<void>.delayed(delay!);
      ids.add(songId);
    } finally {
      inFlight--;
    }
  }

  @override
  Future<void> removeFavorite(String songId) async {
    removeCount++;
    inFlight++;
    if (inFlight > maxInFlight) maxInFlight = inFlight;
    try {
      if (delay != null) await Future<void>.delayed(delay!);
      ids.remove(songId);
    } finally {
      inFlight--;
    }
  }

  @override
  Future<bool> isFavorite(String songId) async => ids.contains(songId);

  @override
  Future<List<Song>> fetchFavoriteSongs() async => [];
}

Song _song(String id) =>
    Song(id: id, title: 'Song $id', audioUrl: 'https://example.com/$id.mp3');

void main() {
  test('concurrent favorite taps serialize and match the fake server', () async {
    final fake = FakeFavoritesService()
      ..delay = const Duration(milliseconds: 20);
    final provider = FavoritesProvider(favoritesService: fake);
    final song = _song('s1');

    await Future.wait([
      provider.toggleFavorite(song),
      provider.toggleFavorite(song),
    ]);

    expect(fake.maxInFlight, 1);
    expect(provider.isFavoriteSync('s1'), fake.ids.contains('s1'));
    expect(fake.addCount + fake.removeCount, 2);
  });
}
