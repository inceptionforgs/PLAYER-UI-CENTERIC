// File: lib/screens/player/widgets/album_art.dart
//
// Per-theme corner radius matching the prototype's --thumb-radius token
// (Walkman Orange: 12, Deep Black/cyber: 0 — sharp square, Apple
// Green/silver-chrome: 8).
//
// Now Playing album is 331 max (original 230, +25% then +15%).
// Cover crossfades in 200ms when the song changes.
// Horizontal swipe on the art skips track. Vertical swipe is left to the
// parent so the queue dock still opens.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_themes.dart';
import '../../../models/song.dart';
import '../../../providers/player_provider.dart';
import '../../../services/app_cache_manager.dart';

class AlbumArt extends StatelessWidget {
  final Song song;
  final AppThemeData t;

  const AlbumArt({Key? key, required this.song, required this.t}) : super(key: key);

  static const double maxArtSize = 331;

  static double _radius(AppThemeId id) {
    switch (id) {
      case AppThemeId.cyberBlack:
        return 0;
      case AppThemeId.silverChrome:
        return 8;
      default:
        return 12;
    }
  }

  void _tick() {
    HapticFeedback.mediumImpact();
    Future.delayed(const Duration(milliseconds: 70), () {
      HapticFeedback.mediumImpact();
    });
  }

  void _onHorizontalSwipe(BuildContext context, DragEndDetails details) {
    final v = details.primaryVelocity ?? 0;
    if (v.abs() < 180) return;
    _tick();
    final player = context.read<PlayerProvider>();
    if (v < 0) {
      player.next();
    } else {
      player.previous(forceSkip: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final radius = _radius(t.id);
    final screenWidth = MediaQuery.of(context).size.width;
    final size = (screenWidth - 48).clamp(160.0, maxArtSize);
    final cover = song.coverImageUrl;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onHorizontalDragEnd: (d) => _onHorizontalSwipe(context, d),
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(radius),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [t.surface, t.background],
          ),
          border: Border.all(
            color: t.textPrimary.withOpacity(0.28),
            width: 2,
          ),
          boxShadow: const [
            BoxShadow(
              color: Colors.black38,
              blurRadius: 45,
              offset: Offset(0, 20),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(radius > 2 ? radius - 2 : 0),
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            switchInCurve: Curves.easeOut,
            switchOutCurve: Curves.easeOut,
            child: (cover != null && cover.isNotEmpty)
                ? CachedNetworkImage(
                    key: ValueKey(cover),
                    imageUrl: cover,
                    fit: BoxFit.cover,
                    width: size,
                    height: size,
                    cacheManager: AppCacheManager.instance,
                    memCacheWidth: 512,
                    memCacheHeight: 512,
                    placeholder: (context, url) =>
                        Icon(Icons.music_note, color: t.textPrimary, size: 64),
                    errorWidget: (context, url, error) =>
                        Icon(Icons.music_note, color: t.textPrimary, size: 64),
                  )
                : Icon(
                    key: const ValueKey('empty'),
                    Icons.music_note,
                    color: t.textPrimary.withOpacity(0.85),
                    size: 64,
                  ),
          ),
        ),
      ),
    );
  }
}