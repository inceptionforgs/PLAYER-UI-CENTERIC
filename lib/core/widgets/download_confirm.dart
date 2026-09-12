import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/theme_provider.dart';

/// Confirm before a download starts (same pattern as delete).
Future<bool> confirmDownload(BuildContext context, String title) async {
  final t = Provider.of<ThemeProvider>(context, listen: false).theme;
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      backgroundColor: t.surface,
      title: Text('Download this Serial No.?',
          style: TextStyle(color: t.textPrimary)),
      content: Text(
        'Start downloading "$title"?',
        style: TextStyle(color: t.textSecondary),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(false),
          child: Text('Cancel', style: TextStyle(color: t.textSecondary)),
        ),
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(true),
          child: Text('Download', style: TextStyle(color: t.accent)),
        ),
      ],
    ),
  );
  return confirmed == true;
}
