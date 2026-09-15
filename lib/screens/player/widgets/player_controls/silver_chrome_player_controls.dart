import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:provider/provider.dart';
import '../../../../providers/player_provider.dart';
import '../../../../providers/theme_provider.dart';

Color _ink(Color c) {
  final hsl = HSLColor.fromColor(c);

  if (hsl.lightness <= 0.42) return c;

  return hsl
      .withSaturation(
        (hsl.saturation < 0.4 ? 0.55 : hsl.saturation).clamp(0.4, 1.0),
      )
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
    final isLoading =
        context.select<PlayerProvider, bool>((p) => p.isLoading);

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
                BoxShadow(
                  color: const Color(0x47000000),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
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
                      valueColor:
                          AlwaysStoppedAnimation<Color>(playColor),
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

  const SilverChromePlayerControls({
    Key? key,
    this.accent,
  }) : super(key: key);

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

    return Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _ChromeSideButton(
          icon: Icons.shuffle,
          iconSize: 28,
          color: shuffleOn ? t.accent : t.textPrimary,
          label: shuffleOn ? 'Shuffle on' : 'Shuffle',
          onPressed: playerProvider.toggleShuffle,
        ),

        const SizedBox(width: 13),

        _ChromeSideButton(
          icon: Icons.skip_previous,
          iconSize: 50,
          color: t.textPrimary,
          label: 'Previous',
          onPressed: playerProvider.previous,
        ),

        const SizedBox(width: 27),

        SilverChromePlayButton(
          accent: accent,
        ),

        const SizedBox(width: 27),

        _ChromeSideButton(
          icon: Icons.skip_next,
          iconSize: 50,
          color: t.textPrimary,
          label: 'Next',
          onPressed: playerProvider.next,
        ),

        const SizedBox(width: 13),

        _ChromeSideButton(
          icon: loop == LoopMode.one
              ? Icons.repeat_one
              : Icons.repeat,
          iconSize: 28,
          color: loop != LoopMode.off
              ? t.accent
              : t.textPrimary,
          label: loop == LoopMode.one
              ? 'Repeat one'
              : loop == LoopMode.all
                  ? 'Repeat all'
                  : 'Repeat off',
          onPressed: () => _cycleRepeat(playerProvider),
        ),
      ],
    );
  }
}

class _ChromeSideButton extends StatelessWidget {
  final IconData icon;
  final double iconSize;
  final Color color;
  final String label;
  final VoidCallback onPressed;

  const _ChromeSideButton({
    required this.icon,
    required this.iconSize,
    required this.color,
    required this.label,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    // Visual icon remains compact, but the actual touch target
    // is large enough for comfortable tapping.
    const double touchSize = 48;

    return Semantics(
      button: true,
      label: label,
      child: SizedBox(
        width: touchSize,
        height: touchSize,
        child: Tooltip(
          message: label,
          child: Center(
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: onPressed,
                child: SizedBox(
                  width: touchSize,
                  height: touchSize,
                  child: Center(
                    child: Icon(
                      icon,
                      color: color,
                      size: iconSize,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}