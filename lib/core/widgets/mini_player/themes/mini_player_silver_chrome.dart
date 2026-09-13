import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../../../models/song.dart';
import '../../../../routes/app_router.dart';
import '../../../../routes/route_names.dart';
import '../../../../screens/player/widgets/player_controls/silver_chrome_player_controls.dart';
import '../../../../screens/search/search_screen.dart';
import '../../../../screens/search/voice_search_sheet.dart';
import '../../../../services/app_cache_manager.dart';
import '../../../../services/cover_color_service.dart';
import '../../../../core/utils/home_nav.dart';
import '../../../../core/widgets/hold_mic_button.dart';
import '../mini_player_data.dart';

class MiniPlayerSilverChrome extends StatefulWidget {
  final MiniPlayerData data;

  const MiniPlayerSilverChrome({Key? key, required this.data}) : super(key: key);

  @override
  State<MiniPlayerSilverChrome> createState() => _MiniPlayerSilverChromeState();
}

class _MiniPlayerSilverChromeState extends State<MiniPlayerSilverChrome> {
  String? _boundId;
  String? _boundCover;
  Color? _artColor;

  MiniPlayerData get data => widget.data;

  Future<void> _openVoice(BuildContext context) async {
    final phrase = await VoiceSearchSheet.show(context);
    if (!context.mounted) return;
    final q = phrase?.trim() ?? '';
    if (q.isEmpty) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => SearchScreen(initialQuery: q),
        fullscreenDialog: true,
        settings: const RouteSettings(name: RouteNames.search),
      ),
    );
  }

  void _goHome() {
    HomeNav.goTab(HomeNav.trending);
    AppRouter.navigatorKey.currentState?.popUntil((route) {
      return route.settings.name == RouteNames.home || route.isFirst;
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
        _artColor = mem;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) setState(() {});
        });
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
    final song = data.song is Song ? data.song as Song : null;
    _bindSong(song);
    final playerProvider = data.playerProvider;
    final cover = song?.coverImageUrl;
    final singer = song?.singerName ?? '';
    final hasHindi = (song?.titleHindi?.trim().isNotEmpty ?? false);
    final primaryTitle = song == null
        ? ''
        : (hasHindi ? song.titleHindi! : song.title);
    final t = data.theme;
    final bottom = MediaQuery.paddingOf(context).bottom;
    final accent = _playAccent();
    final barColor = _artColor == null
        ? t.surface
        : Color.alphaBlend(_artColor!.withOpacity(0.18), t.surface);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOut,
      color: barColor,
      child: Padding(
        padding: EdgeInsets.only(bottom: bottom),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (song != null)
              ValueListenableBuilder<Duration>(
                valueListenable: playerProvider.durationNotifier,
                builder: (context, duration, _) {
                  return ValueListenableBuilder<Duration>(
                    valueListenable: playerProvider.positionNotifier,
                    builder: (context, position, __) {
                      final pct = duration.inMilliseconds == 0
                          ? 0.0
                          : (position.inMilliseconds / duration.inMilliseconds)
                              .clamp(0.0, 1.0);
                      return LayoutBuilder(
                        builder: (context, box) {
                          return GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTapDown: (d) {
                              if (duration.inMilliseconds == 0 ||
                                  box.maxWidth <= 0) {
                                return;
                              }
                              final r = (d.localPosition.dx / box.maxWidth)
                                  .clamp(0.0, 1.0);
                              playerProvider.seek(Duration(
                                milliseconds:
                                    (r * duration.inMilliseconds).round(),
                              ));
                            },
                            child: SizedBox(
                              height: 8,
                              width: double.infinity,
                              child: Align(
                                alignment: Alignment.topCenter,
                                child: SizedBox(
                                  height: 3,
                                  child: Stack(
                                    children: [
                                      const ColoredBox(
                                        color: Color(0xFF1A1F1A),
                                        child: SizedBox.expand(),
                                      ),
                                      FractionallySizedBox(
                                        widthFactor: pct,
                                        heightFactor: 1,
                                        alignment: Alignment.centerLeft,
                                        child: ColoredBox(
                                          color: accent ?? t.accent,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      );
                    },
                  );
                },
              )
            else
              const SizedBox(height: 3),
            SizedBox(
              height: 64,
              child: Row(
                children: [
                  Expanded(
                    child: ValueListenableBuilder<int>(
                      valueListenable: HomeNav.tabIndex,
                      builder: (context, tab, _) {
                        final homeOn = tab == HomeNav.trending;
                        return InkWell(
                          onTap: _goHome,
                          child: Icon(
                            Icons.home,
                            size: 26,
                            color: homeOn ? t.accent : t.textSecondary,
                          ),
                        );
                      },
                    ),
                  ),
                  if (song != null) ...[
                    GestureDetector(
                      onTap: () => AppRouter.navigatorKey.currentState
                          ?.pushNamed(RouteNames.nowPlaying),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: SizedBox(
                          width: 48,
                          height: 48,
                          child: AnimatedSwitcher(
                            duration: const Duration(milliseconds: 200),
                            child: cover != null && cover.isNotEmpty
                                ? CachedNetworkImage(
                                    key: ValueKey(cover),
                                    imageUrl: cover,
                                    fit: BoxFit.cover,
                                    width: 48,
                                    height: 48,
                                    cacheManager: AppCacheManager.instance,
                                    memCacheWidth: 112,
                                    memCacheHeight: 112,
                                  )
                                : ColoredBox(
                                    key: const ValueKey('empty'),
                                    color: t.background,
                                    child: Icon(Icons.music_note,
                                        color: t.accent),
                                  ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      flex: 3,
                      child: GestureDetector(
                        onTap: () => AppRouter.navigatorKey.currentState
                            ?.pushNamed(RouteNames.nowPlaying),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              primaryTitle,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: t.textPrimary,
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                decoration: TextDecoration.none,
                              ),
                            ),
                            if (singer.isNotEmpty)
                              Text(
                                singer,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: t.textSecondary,
                                  fontSize: 12,
                                  decoration: TextDecoration.none,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                    SizedBox(
                      width: 44,
                      height: 44,
                      child: Center(
                        child: SilverChromePlayButton(
                          size: 28,
                          iconSize: 15,
                          accent: accent,
                        ),
                      ),
                    ),
                  ] else
                    const Spacer(),
                  Expanded(
                    child: HoldMicButton(
                      idleColor: t.textSecondary,
                      holdColor: t.accent,
                      onArmed: () => _openVoice(context),
                      builder: (color, progress) => Icon(
                        Icons.mic,
                        size: 26,
                        color: color,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}