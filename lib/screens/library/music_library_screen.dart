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
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final songs = context.read<SongsProvider>();
      if (songs.allSongs.isEmpty) songs.loadSongs();
      final singers = context.read<SingersProvider>();
      if (singers.allSingers.isEmpty) singers.loadSingers();
      context.read<FavoritesProvider>().loadFavorites();
    });
  }

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

class _SongList extends StatefulWidget {
  final int tab;

  const _SongList({required this.tab});

  @override
  State<_SongList> createState() => _SongListState();
}

class _SongListState extends State<_SongList> {
  final _scroll = ScrollController();

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (widget.tab != HomeNav.songs && widget.tab != HomeNav.trending) return;
    if (!_scroll.hasClients) return;
    if (_scroll.position.pixels < _scroll.position.maxScrollExtent - 200) {
      return;
    }
    context.read<SongsProvider>().loadMoreSongs();
  }

  List<Song> _songs(BuildContext context) {
    final all = context.watch<SongsProvider>().allSongs;
    if (widget.tab == HomeNav.trending) {
      final copy = [...all];
      copy.sort((a, b) => b.playCount.compareTo(a.playCount));
      return copy;
    }
    if (widget.tab == HomeNav.favorites) {
      return context.watch<FavoritesProvider>().favoriteSongs;
    }
    if (widget.tab == HomeNav.downloads) {
      return context.watch<DownloadsProvider>().downloadedSongsList;
    }
    return all;
  }

  @override
  Widget build(BuildContext context) {
    final songsProv = context.watch<SongsProvider>();
    final songs = _songs(context);
    final currentId =
        context.select<PlayerProvider, String?>((p) => p.currentSong?.id);
    final t = context.watch<ThemeProvider>().theme;

    if (songsProv.isLoading && songs.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (songsProv.errorMessage != null && songs.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(16),
        child: Text(
          songsProv.errorMessage!,
          style: TextStyle(color: t.textSecondary, fontSize: 13),
        ),
      );
    }
    if (songs.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(16),
        child: Text(
          'Empty',
          style: TextStyle(color: t.textSecondary, fontSize: 13),
        ),
      );
    }
    return ListView.builder(
      controller: _scroll,
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
    final prov = context.watch<SingersProvider>();
    final t = context.watch<ThemeProvider>().theme;
    if (prov.isLoading && prov.allSingers.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (prov.errorMessage != null && prov.allSingers.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(16),
        child: Text(
          prov.errorMessage!,
          style: TextStyle(color: t.textSecondary, fontSize: 13),
        ),
      );
    }
    final singers = [...prov.allSingers]
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    if (singers.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(16),
        child: Text(
          'Empty',
          style: TextStyle(color: t.textSecondary, fontSize: 13),
        ),
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
    final currentId =
        context.select<PlayerProvider, String?>((p) => p.currentSong?.id);
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
              if (snap.connectionState != ConnectionState.done) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snap.hasError) {
                return Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    '${snap.error}',
                    style: TextStyle(color: t.textSecondary, fontSize: 13),
                  ),
                );
              }
              final songs = snap.data ?? const <Song>[];
              if (songs.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    'Empty',
                    style: TextStyle(color: t.textSecondary, fontSize: 13),
                  ),
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