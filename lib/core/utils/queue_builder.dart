import '../../models/song.dart';

class BuiltQueue {
  final List<Song> songs;
  final int startIndex;

  const BuiltQueue({required this.songs, required this.startIndex});
}

class QueueBuilder {
  static const int maxQueueWindow = 60;

  static int remapStartIndex({
    required List<Song> original,
    required int originalStartIndex,
    required List<Song> eligible,
  }) {
    if (eligible.isEmpty) return 0;
    if (originalStartIndex >= 0 && originalStartIndex < original.length) {
      final id = original[originalStartIndex].id;
      final found = eligible.indexWhere((s) => s.id == id);
      if (found != -1) return found;
    }
    return 0;
  }

  static BuiltQueue build({
    required List<Song> songs,
    required int startIndex,
    Set<String> locallyAvailableSongIds = const {},
    int windowSize = maxQueueWindow,
  }) {
    if (songs.isEmpty) {
      throw ArgumentError('Playlist is empty.');
    }

    final validSongs = <Song>[];
    for (final song in songs) {
      final hasValidLocalFile = locallyAvailableSongIds.contains(song.id);
      final uri = Uri.tryParse(song.audioUrl);
      final hasValidRemote = uri != null && uri.host.isNotEmpty;

      if (!hasValidLocalFile && !hasValidRemote) {
        continue;
      }
      validSongs.add(song);
    }

    if (validSongs.isEmpty) {
      throw StateError(
          'No playable songs found (missing or invalid audio URLs).');
    }

    int adjustedStart = 0;
    if (startIndex >= 0 && startIndex < songs.length) {
      final requested = songs[startIndex];
      final found = validSongs.indexWhere((s) => s.id == requested.id);
      if (found != -1) {
        adjustedStart = found;
      }
    }

    List<Song> queueSongs = validSongs;
    int queueStartIndex = adjustedStart;
    if (validSongs.length > windowSize) {
      final half = windowSize ~/ 2;
      int lo = (adjustedStart - half).clamp(0, validSongs.length - 1);
      int hi = (lo + windowSize).clamp(0, validSongs.length);
      lo = (hi - windowSize).clamp(0, validSongs.length);
      queueSongs = validSongs.sublist(lo, hi);
      queueStartIndex = adjustedStart - lo;
    }

    return BuiltQueue(songs: queueSongs, startIndex: queueStartIndex);
  }
}