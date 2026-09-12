import 'package:flutter/material.dart';

import 'app_theme_data.dart';
import 'app_theme_id.dart';

/// Golden Byte — Jet Audio gold on dark wood/black. Internal id walkmanOrange.
const AppThemeData walkmanOrangeTheme = AppThemeData(
  id: AppThemeId.walkmanOrange,
  label: 'Golden Byte',
  accent: Color(0xFFFFD24A),
  accentLight: Color(0xFFFFE9A0),
  accentDark: Color(0xFFD4AF37),
  screenGradient: [
    Color(0xFF3D3014),
    Color(0xFF1C1912),
    Color(0xFF12100A),
  ],
  background: Color(0xFF1C1912),
  surface: Color(0xFF3D3014),
  textPrimary: Color(0xFFFFE9A0),
  textSecondary: Color(0xB3FFD24A),
);
