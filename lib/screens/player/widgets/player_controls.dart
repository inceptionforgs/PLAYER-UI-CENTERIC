// File: lib/screens/player/widgets/player_controls.dart
//
// Dispatcher — picks per-theme player controls. `accent` is the
// album-art colour for Apple Green play triangle + ring.

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_themes.dart';
import '../../../providers/theme_provider.dart';
import 'player_controls/cyber_black_player_controls.dart';
import 'player_controls/silver_chrome_player_controls.dart';
import 'player_controls/walkman_orange_player_controls.dart';

class PlayerControls extends StatelessWidget {
  final Color? accent;

  const PlayerControls({Key? key, this.accent}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final themeId = context.watch<ThemeProvider>().theme.id;

    switch (themeId) {
      case AppThemeId.cyberBlack:
        return const CyberBlackPlayerControls();
      case AppThemeId.silverChrome:
        return SilverChromePlayerControls(accent: accent);
      case AppThemeId.walkmanOrange:
      case AppThemeId.custom:
        return const WalkmanOrangePlayerControls();
    }
  }
}