import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:provider/provider.dart';
import '../../../../providers/player_provider.dart';
import '../../../../providers/theme_provider.dart';

Color _ink(Color c) {
  final hsl = HSLColor.fromColor(c);
  if (hsl.lightness <= 0.42) return c;
  return hsl
      .withSaturation((hsl.saturation < 0.4 ? 0.55 : hsl.saturation).clamp(0.4, 1.0))
      .withLightness(0.34)
      .toColor();
}

class SilverChromePlayButton extends StatelessWidget {
  final double size;
  final double iconSize;
  final Color? accent;
  final bool decorative;

  const SilverChromePlayButton({
    Key? key,
    this.size = 66,
    this.iconSize = 38,
    this.accent,
    this.decorative = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final player = context.watch<PlayerProvider>();
    final t = context.watch<ThemeProvider>().theme;
    final isLoading = context.select<PlayerProvider, bool>((p) => p.isLoading);
    final playColor = _ink(accent ?? t.accent);
    final ring = (size / 66) * 3;

    final icon = decorative
        ? Icons.play_arrow
        : isLoading
            ? null
            : (player.isPlaying ? Icons.pause : Icons.play_arrow);

    return Semantics(
      button: !decorative,
      excludeSemantics: decorative,
      label: decorative
          ? null
          : (player.isPlaying ? 'Pause' : 'Play'),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: decorative ? null : () => player.togglePlayPause(),
          child: Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white,
              boxShadow: [
                const BoxShadow(
                  color: Color(0x47000000),
                  blurRadius: 8,
                  offset: Offset(0, 2),
                ),
                BoxShadow(
                  color: Colors.white,
                  spreadRadius: ring * 2,
                  blurRadius: 0,
                ),
                BoxShadow(
                  color: playColor,
                  spreadRadius: ring,
                  blurRadius: 0,
                ),
              ],
            ),
            alignment: Alignment.center,
            child: icon == null
                ? SizedBox(
                    width: iconSize,
                    height: iconSize,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      valueColor: AlwaysStoppedAnimation<Color>(playColor),
                    ),
                  )
                : Icon(
                    icon,
                    color: playColor,
                    size: iconSize,
                  ),
          ),
        ),
      ),
    );
  }
}

class SilverChromePlayerControls extends StatelessWidget {
  final Color? accent;

  const SilverChromePlayerControls({Key? key, this.accent}) : super(key: key);

  void _cycleRepeat(PlayerProvider player) {
    final current = player.loopMode;
    final next = current == LoopMode.off
        ? LoopMode.all
        : current == LoopMode.all
            ? LoopMode.one
            : LoopMode.off;
    player.setLoopMode(next);
  }

  @override
  Widget build(BuildContext context) {
    final playerProvider = context.watch<PlayerProvider>();
    final t = context.watch<ThemeProvider>().theme;
    final shuffleOn = playerProvider.shuffleMode;
    final loop = playerProvider.loopMode;

    // spaceEvenly divides the row's free horizontal space into equal
    // chunks: edge→Shuffle, Shuffle→Previous, Previous→Play, Play→Next,
    // Next→Repeat, and Repeat→edge are all the same width, regardless
    // of screen size. Fixed-size boxes on every button keep each gap
    // a true equal gap (not skewed by different icon/button sizes).
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        Semantics(
          button: true,
          label: shuffleOn ? 'Shuffle on' : 'Shuffle',
          child: SizedBox(
            width: 60,
            height: 60,
            child: IconButton(
              icon: Icon(
                Icons.shuffle,
                color: shuffleOn ? t.accent : t.textPrimary,
                size: 28,
              ),
              padding: EdgeInsets.zero,
              tooltip: shuffleOn ? 'Shuffle on' : 'Shuffle',
              onPressed: () => playerProvider.toggleShuffle(),
            ),
          ),
        ),
        Semantics(
          button: true,
          label: 'Previous',
          child: SizedBox(
            width: 80,
            height: 80,
            child: IconButton(
              icon: Icon(Icons.skip_previous, color: t.textPrimary, size: 50),
              padding: EdgeInsets.zero,
              onPressed: () => playerProvider.previous(),
            ),
          ),
        ),
        SilverChromePlayButton(accent: accent),
        Semantics(
          button: true,
          label: 'Next',
          child: SizedBox(
            width: 80,
            height: 80,
            child: IconButton(
              icon: Icon(Icons.skip_next, color: t.textPrimary, size: 50),
              padding: EdgeInsets.zero,
              onPressed: () => playerProvider.next(),
            ),
          ),
        ),
        Semantics(
          button: true,
          label: loop == LoopMode.one
              ? 'Repeat one'
              : loop == LoopMode.all
                  ? 'Repeat all'
                  : 'Repeat off',
          child: SizedBox(
            width: 60,
            height: 60,
            child: IconButton(
              icon: Icon(
                loop == LoopMode.one ? Icons.repeat_one : Icons.repeat,
                color: loop != LoopMode.off ? t.accent : t.textPrimary,
                size: 28,
              ),
              padding: EdgeInsets.zero,
              tooltip: loop == LoopMode.one
                  ? 'Repeat one'
                  : loop == LoopMode.all
                      ? 'Repeat all'
                      : 'Repeat',
              onPressed: () => _cycleRepeat(playerProvider),
            ),
          ),
        ),
      ],
    );
  }
}