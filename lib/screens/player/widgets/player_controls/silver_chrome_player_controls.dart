import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../providers/player_provider.dart';
import '../../../../providers/theme_provider.dart';

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
    final playColor = accent ?? t.textPrimary;
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

  @override
  Widget build(BuildContext context) {
    final playerProvider = context.watch<PlayerProvider>();
    final t = context.watch<ThemeProvider>().theme;

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
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
        const SizedBox(width: 36),
        SilverChromePlayButton(accent: accent),
        const SizedBox(width: 36),
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
      ],
    );
  }
}