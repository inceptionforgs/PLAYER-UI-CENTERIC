import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../core/widgets/app_drawer.dart';
import '../../models/song.dart';
import '../../providers/player_provider.dart';
import '../../providers/theme_provider.dart';
import '../../routes/route_names.dart';
import '../../services/app_cache_manager.dart';
import '../../services/cover_color_service.dart';
import 'widgets/album_art.dart';
import 'widgets/now_playing_actions.dart';
import 'widgets/player_controls.dart';
import 'widgets/player_controls/silver_chrome_player_controls.dart';
import 'widgets/seek_bar.dart';
import 'widgets/sleep_timer_sheet.dart';

class NowPlayingScreen extends StatefulWidget {
  const NowPlayingScreen({Key? key}) : super(key: key);

  @override
  State<NowPlayingScreen> createState() => _NowPlayingScreenState();
}

class _NowPlayingScreenState extends State<NowPlayingScreen> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  int _drawerEpoch = 0;
  String? _boundId;
  String? _boundCover;
  Color? _artColor;

  bool _queueOpen = false;
  bool _hold = false;
  Timer? _idle;

  @override
  void dispose() {
    _idle?.cancel();
    super.dispose();
  }

  void _tick() {
    HapticFeedback.selectionClick();
  }

  void _openSleepTimerSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => const SleepTimerSheet(),
    );
  }

  void _onHorizontalSwipe(DragEndDetails details) {
    final v = details.primaryVelocity ?? 0;
    if (v.abs() < 180) return;
    final player = context.read<PlayerProvider>();
    _tick();
    if (v < 0) {
      player.next();
    } else {
      player.previous(forceSkip: true);
    }
  }

  void _openEqualizerSettings() {
    Navigator.of(context).pushNamed(RouteNames.soundSettings);
  }

  void _openQueue() {
    if (_queueOpen) return;
    _tick();
    setState(() => _queueOpen = true);
    _armIdle();
  }

  void _closeQueue() {
    _idle?.cancel();
    _hold = false;
    if (!_queueOpen) return;
    setState(() => _queueOpen = false);
  }

  void _armIdle() {
    _idle?.cancel();
    if (!_queueOpen || _hold) return;
    _idle = Timer(const Duration(seconds: 4), () {
      if (!mounted || _hold) return;
      _closeQueue();
    });
  }

  Color? _playAccent() {
    final src = _artColor;
    if (src == null) return null;
    final hsl = HSLColor.fromColor(src);
    return hsl
        .withSaturation((hsl.saturation * 1.55).clamp(0.4, 1.0))
        .withLightness(0.36)
        .toColor();
  }

  void _bindSong(Song? song) {
    if (song == null) {
      if (_boundId != null || _artColor != null) {
        setState(() {
          _boundId = null;
          _boundCover = null;
          _artColor = null;
        });
      }
      return;
    }
    final same = _boundId == song.id && _boundCover == song.coverImageUrl;
    if (same && _artColor != null) return;

    final mem = CoverColorService.instance.cached(song.id, song.coverImageUrl);
    _boundId = song.id;
    _boundCover = song.coverImageUrl;
    if (mem != null) {
      if (_artColor != mem) {
        setState(() => _artColor = mem);
      }
      return;
    }

    CoverColorService.instance
        .colorFor(songId: song.id, coverUrl: song.coverImageUrl)
        .then((c) {
      if (!mounted || c == null) return;
      if (_boundId != song.id) return;
      setState(() => _artColor = c);
    });
  }

  @override
  Widget build(BuildContext context) {
    final t = context.watch<ThemeProvider>().theme;
    final song = context.select<PlayerProvider, Song?>((p) => p.currentSong);
    final errorMessage =
        context.select<PlayerProvider, String?>((p) => p.errorMessage);

    _bindSong(song);
    final playAccent = _playAccent();

    final top = _artColor != null
        ? CoverColorService.backdrop(_artColor!, t.screenGradient.first)
        : t.screenGradient.first;
    final bottom = _artColor != null
        ? CoverColorService.backdropDeep(_artColor!, t.screenGradient.last)
        : t.screenGradient.last;

    if (song == null) {
      return Scaffold(
        body: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: t.screenGradient,
            ),
          ),
          child: SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(10, 6, 10, 0),
                  child: Row(
                    children: [
                      IconButton(
                        icon: Icon(Icons.chevron_left,
                            color: t.textPrimary, size: 28),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Center(
                    child: Text('No song selected',
                        style: TextStyle(color: t.textSecondary)),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      key: _scaffoldKey,
      drawer: AppDrawer(key: ValueKey(_drawerEpoch)),
      onDrawerChanged: (open) {
        if (!open) setState(() => _drawerEpoch++);
      },
      body: Listener(
        onPointerDown: (_) {
          if (!_queueOpen) return;
          _hold = true;
          _idle?.cancel();
        },
        onPointerUp: (_) {
          if (!_hold) return;
          _hold = false;
          _armIdle();
        },
        onPointerCancel: (_) {
          _hold = false;
          _armIdle();
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 380),
          curve: Curves.easeOut,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [top, bottom],
            ),
          ),
          child: SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(10, 6, 16, 0),
                  child: Row(
                    children: [
                      IconButton(
                        icon: Icon(Icons.chevron_left,
                            color: t.textPrimary, size: 28),
                        onPressed: () {
                          if (_queueOpen) {
                            _closeQueue();
                          } else {
                            Navigator.of(context).pop();
                          }
                        },
                      ),
                      SilverChromePlayButton(
                        size: 28,
                        iconSize: 15,
                        accent: playAccent,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          (song.titleHindi?.trim().isNotEmpty ?? false)
                              ? song.titleHindi!
                              : song.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontStyle: FontStyle.italic,
                            fontSize: 24,
                            fontWeight: FontWeight.w600,
                            color: t.textPrimary,
                            height: 1.0,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      return Stack(
                        children: [
                          GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onHorizontalDragEnd: _onHorizontalSwipe,
                            onVerticalDragEnd: (d) {
                              final v = d.primaryVelocity ?? 0;
                              if (!_queueOpen && v < -400) _openQueue();
                            },
                            child: Column(
                              children: [
                                Expanded(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Padding(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 24),
                                        child: Text(
                                          song.singerName ?? 'Unknown Artist',
                                          textAlign: TextAlign.center,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w700,
                                            color: t.textPrimary
                                                .withOpacity(0.72),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(height: 22),
                                      AlbumArt(song: song, t: t),
                                      if (errorMessage != null)
                                        Padding(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 24, vertical: 10),
                                          child: _ErrorBox(
                                            message: errorMessage,
                                            textColor: t.textPrimary,
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 24),
                                NowPlayingActions(
                                  song: song,
                                  onTimerTap: _openSleepTimerSheet,
                                  onEqualizerTap: _openEqualizerSettings,
                                ),
                                Padding(
                                  padding: const EdgeInsets.fromLTRB(
                                      20, 20, 20, 20),
                                  child: PlayerControls(accent: playAccent),
                                ),
                                const Padding(
                                  padding: EdgeInsets.fromLTRB(26, 0, 26, 72),
                                  child: SeekBar(),
                                ),
                              ],
                            ),
                          ),
                          if (_queueOpen)
                            Positioned(
                              top: 0,
                              left: 0,
                              right: 0,
                              height: constraints.maxHeight * 0.20,
                              child: GestureDetector(
                                behavior: HitTestBehavior.opaque,
                                onTap: _closeQueue,
                              ),
                            ),
                          Positioned(
                            left: 0,
                            right: 0,
                            bottom: 0,
                            child: _QueueDock(
                              open: _queueOpen,
                              maxHeight: constraints.maxHeight * 0.80,
                              t: t,
                              onOpen: _openQueue,
                              onClose: _closeQueue,
                              onActivity: _armIdle,
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ErrorBox extends StatelessWidget {
  final String message;
  final Color textColor;

  const _ErrorBox({required this.message, required this.textColor});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.red.withOpacity(0.12),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.error_outline, color: Colors.redAccent, size: 18),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Unable to play this song',
                  style: TextStyle(
                    color: Colors.redAccent,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            message,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: textColor.withOpacity(0.75),
              fontSize: 12,
            ),
          ),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: () {
                final playerProvider = context.read<PlayerProvider>();
                playerProvider.clearError();
                playerProvider.togglePlayPause();
              },
              icon: const Icon(Icons.refresh, size: 16),
              label: const Text('Retry'),
            ),
          ),
        ],
      ),
    );
  }
}

class _QueueDock extends StatelessWidget {
  final bool open;
  final double maxHeight;
  final dynamic t;
  final VoidCallback onOpen;
  final VoidCallback onClose;
  final VoidCallback onActivity;

  const _QueueDock({
    required this.open,
    required this.maxHeight,
    required this.t,
    required this.onOpen,
    required this.onClose,
    required this.onActivity,
  });

  @override
  Widget build(BuildContext context) {
    final player = context.watch<PlayerProvider>();
    final queue = player.queue;
    final active = player.currentQueueIndex;
    if (queue.length <= 1) return const SizedBox.shrink();

    final upcoming = <MapEntry<int, Song>>[];
    for (var i = 1; i < queue.length; i++) {
      final index = (active + i) % queue.length;
      upcoming.add(MapEntry(index, queue[index]));
    }
    if (upcoming.isEmpty) return const SizedBox.shrink();
    final next = upcoming.first;

    return GestureDetector(
      onVerticalDragEnd: open
          ? null
          : (d) {
              final v = d.primaryVelocity ?? 0;
              if (v < -300) onOpen();
            },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 360),
        curve: const Cubic(0.22, 1, 0.36, 1),
        height: open ? maxHeight : 56,
        decoration: const BoxDecoration(
          color: Color(0xC7000000),
          borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
          boxShadow: [
            BoxShadow(
              color: Color(0x66000000),
              blurRadius: 40,
              offset: Offset(0, -16),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          children: [
            SizedBox(
              height: open ? 32 : 56,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onVerticalDragEnd: open
                    ? (d) {
                        if ((d.primaryVelocity ?? 0) > 400) onClose();
                      }
                    : null,
                child: Stack(
                alignment: Alignment.centerLeft,
                children: [
                  const Align(
                    alignment: Alignment.topCenter,
                    child: Padding(
                      padding: EdgeInsets.only(top: 6),
                      child: SizedBox(
                        width: 36,
                        height: 4,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: Color(0x66FFFFFF),
                            borderRadius: BorderRadius.all(Radius.circular(99)),
                          ),
                        ),
                      ),
                    ),
                  ),
                  if (!open)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
                      child: Row(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: _MiniCover(url: next.value.coverImageUrl),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  'UP NEXT',
                                  style: TextStyle(
                                    color: t.textPrimary.withOpacity(0.55),
                                    fontSize: 9,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 1.2,
                                  ),
                                ),
                                Text(
                                  (next.value.titleHindi?.trim().isNotEmpty ??
                                          false)
                                      ? next.value.titleHindi!
                                      : next.value.title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: t.textPrimary,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    height: 1.15,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
              ),
            ),
            Expanded(
              child: open
                  ? NotificationListener<ScrollNotification>(
                      onNotification: (_) {
                        onActivity();
                        return false;
                      },
                      child: ListView.builder(
                        physics: const ClampingScrollPhysics(),
                        itemCount: upcoming.length,
                        itemBuilder: (context, i) {
                          final item = upcoming[i];
                          return _QueueTile(
                            song: item.value,
                            t: t,
                            onTap: () {
                              context
                                  .read<PlayerProvider>()
                                  .jumpToQueueIndex(item.key);
                              onClose();
                            },
                          );
                        },
                      ),
                    )
                  : const SizedBox.shrink(),
            ),
          ],
        ),
      ),
    );
  }
}

class _MiniCover extends StatelessWidget {
  final String? url;

  const _MiniCover({this.url});

  @override
  Widget build(BuildContext context) {
    if (url == null || url!.isEmpty) {
      return const SizedBox(
        width: 36,
        height: 36,
        child: ColoredBox(color: Colors.white10),
      );
    }
    return CachedNetworkImage(
      imageUrl: url!,
      width: 36,
      height: 36,
      fit: BoxFit.cover,
      cacheManager: AppCacheManager.instance,
      memCacheWidth: 72,
      memCacheHeight: 72,
    );
  }
}

class _QueueTile extends StatelessWidget {
  final Song song;
  final dynamic t;
  final VoidCallback onTap;

  const _QueueTile({
    required this.song,
    required this.t,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: SizedBox(
        height: 96,
        child: Row(
          children: [
            if (song.coverImageUrl != null && song.coverImageUrl!.isNotEmpty)
              CachedNetworkImage(
                imageUrl: song.coverImageUrl!,
                width: 96,
                height: 96,
                fit: BoxFit.cover,
                cacheManager: AppCacheManager.instance,
                memCacheWidth: 192,
                memCacheHeight: 192,
              )
            else
              SizedBox(
                width: 96,
                height: 96,
                child: Icon(Icons.music_note, color: t.textPrimary),
              ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      (song.titleHindi?.trim().isNotEmpty ?? false)
                          ? song.titleHindi!
                          : song.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: t.textPrimary,
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        height: 1.2,
                      ),
                    ),
                    if ((song.titleHindi?.trim().isNotEmpty ?? false) &&
                        song.titleHindi != song.title) ...[
                      const SizedBox(height: 2),
                      Text(
                        song.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: t.textPrimary.withOpacity(0.62),
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                    const SizedBox(height: 4),
                    Text(
                      song.singerName ?? 'Unknown Artist',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: t.textPrimary.withOpacity(0.62),
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
