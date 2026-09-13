import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_strings.dart';
import '../../core/utils/home_nav.dart';
import '../../models/song.dart';
import '../../providers/downloads_provider.dart';
import '../../providers/favorites_provider.dart';
import '../../providers/player_provider.dart';
import '../../providers/singers_provider.dart';
import '../../providers/songs_provider.dart';
import '../../providers/theme_provider.dart';
import 'widgets/library_column.dart';

class MusicLibraryScreen extends StatefulWidget {
  const MusicLibraryScreen({Key? key}) : super(key: key);

  @override
  State<MusicLibraryScreen> createState() => _MusicLibraryScreenState();
}

class _MusicLibraryScreenState extends State<MusicLibraryScreen> {
  int? _branch;
  String? _singerId;
  String? _singerName;

  static const _folders = [
    (HomeNav.songs, Icons.music_note, AppStrings.navSongs),
    (HomeNav.singers, Icons.mic, AppStrings.navSingers),
    (HomeNav.trending, Icons.trending_up, AppStrings.navTrending),
    (HomeNav.favorites, Icons.favorite, AppStrings.navFavorites),
    (HomeNav.downloads, Icons.download, 'Downloaded'),
  ];

  @override
  Widget build(BuildContext context) {
    final t = context.watch<ThemeProvider>().theme;

    return Scaffold(
      backgroundColor: t.background,
      appBar: AppBar(
        backgroundColor: t.background,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.chevron_left, color: t.textPrimary),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'Music Library',
          style: TextStyle(
            color: t.textPrimary,
            fontSize: 17,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          LibraryColumn(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final f in _folders)
                  LibraryFolderRow(
                    icon: f.$2,
                    label: f.$3,
                    selected: _branch == f.$1,
                    onTap: () => setState(() {
                      _branch = f.$1;
                      _singerId = null;
                      _singerName = null;
                    }),
                  ),
              ],
            ),
          ),
          if (_branch == null)
            const Expanded(child: SizedBox.expand())
          else
            LibraryColumn(
              fill: true,
              child: _branch == HomeNav.singers
                  ? (_singerId == null
                      ? _SingerList(
                          onPick: (id, name) => setState(() {
                            _singerId = id;
                            _singerName = name;
                          }),
                        )
                      : _SingerSongs(
                          singerId: _singerId!,
                          singerName: _singerName ?? '',
                          onBack: () => setState(() {
                            _singerId = null;
                            _singerName = null;
                          }),
                        ))
                  : _SongList(tab: _branch!),
            ),
        ],
      ),
    );
  }
}

class _SongList extends StatelessWidget {
  final int tab;

  const _SongList({required this.tab});

  List<Song> _songs(BuildContext context) {
    final all = context.watch<SongsProvider>().allSongs;
    if (tab == HomeNav.trending) {
      final copy = [...all];
      copy.sort((a, b) => b.playCount.compareTo(a.playCount));
      return copy;
    }
    if (tab == HomeNav.favorites) {
      return context.watch<FavoritesProvider>().favoriteSongs;
    }
    if (tab == HomeNav.downloads) {
      return context.watch<DownloadsProvider>().downloadedSongsList;
    }
    return all;
  }

  @override
  Widget build(BuildContext context) {
    final songs = _songs(context);
    final currentId = context.select<PlayerProvider, String?>((p) => p.currentSong?.id);
    if (songs.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(16),
        child: Text('Empty'),
      );
    }
    return ListView.builder(
      itemCount: songs.length,
      itemBuilder: (context, i) {
        final song = songs[i];
        return LibraryFileRow(
          title: (song.titleHindi?.trim().isNotEmpty ?? false)
              ? song.titleHindi!
              : song.title,
          coverUrl: song.coverImageUrl,
          selected: currentId == song.id,
          onTap: () => context
              .read<PlayerProvider>()
              .setPlaylist(songs: songs, startIndex: i),
        );
      },
    );
  }
}

class _SingerList extends StatelessWidget {
  final void Function(String id, String name) onPick;

  const _SingerList({required this.onPick});

  @override
  Widget build(BuildContext context) {
    final singers = [...context.watch<SingersProvider>().allSingers]
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    if (singers.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(16),
        child: Text('Empty'),
      );
    }
    return ListView.builder(
      itemCount: singers.length,
      itemBuilder: (context, i) {
        final s = singers[i];
        return LibraryFileRow(
          title: s.name,
          coverUrl: s.photoUrl,
          folder: true,
          onTap: () => onPick(s.id, s.name),
        );
      },
    );
  }
}

class _SingerSongs extends StatefulWidget {
  final String singerId;
  final String singerName;
  final VoidCallback onBack;

  const _SingerSongs({
    required this.singerId,
    required this.singerName,
    required this.onBack,
  });

  @override
  State<_SingerSongs> createState() => _SingerSongsState();
}

class _SingerSongsState extends State<_SingerSongs> {
  late Future<List<Song>> _future;

  @override
  void initState() {
    super.initState();
    _future = context.read<SongsProvider>().fetchSongsBySinger(widget.singerId);
  }

  @override
  Widget build(BuildContext context) {
    final t = context.watch<ThemeProvider>().theme;
    final currentId = context.select<PlayerProvider, String?>((p) => p.currentSong?.id);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: widget.onBack,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Row(
                children: [
                  Icon(Icons.chevron_left, size: 18, color: t.textPrimary),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      widget.singerName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: t.textPrimary,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        Expanded(
          child: FutureBuilder<List<Song>>(
            future: _future,
            builder: (context, snap) {
              if (!snap.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              final songs = snap.data!;
              if (songs.isEmpty) {
                return const Padding(
                  padding: EdgeInsets.all(16),
                  child: Text('Empty'),
                );
              }
              return ListView.builder(
                itemCount: songs.length,
                itemBuilder: (context, i) {
                  final song = songs[i];
                  return LibraryFileRow(
                    title: (song.titleHindi?.trim().isNotEmpty ?? false)
                        ? song.titleHindi!
                        : song.title,
                    coverUrl: song.coverImageUrl,
                    selected: currentId == song.id,
                    onTap: () => context
                        .read<PlayerProvider>()
                        .setPlaylist(songs: songs, startIndex: i),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}