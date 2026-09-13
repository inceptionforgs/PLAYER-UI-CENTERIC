import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/constants/app_strings.dart';
import '../../../providers/custom_song_provider.dart';
import '../../../providers/theme_provider.dart';

class SingerStep extends StatelessWidget {
  const SingerStep({Key? key}) : super(key: key);

  String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+')).take(2);
    final out = parts.map((p) => p.isEmpty ? '' : p[0].toUpperCase()).join();
    return out.isEmpty ? 'S' : out;
  }

  String _mask(String mobile) {
    if (mobile.length < 10) return mobile;
    return '+91 •••• ••${mobile.substring(mobile.length - 4)}';
  }

  @override
  Widget build(BuildContext context) {
    final p = context.watch<CustomSongProvider>();
    final t = context.watch<ThemeProvider>().theme;

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      children: [
        Text(
          AppStrings.customSongPickSingerHi,
          style: TextStyle(
            color: t.textPrimary,
            fontSize: 14,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          AppStrings.customSongPickSingerEn,
          style: TextStyle(
            color: t.textSecondary,
            fontSize: 12,
          ),
        ),
        const SizedBox(height: 14),
        if (p.loadingSingers)
          Text(
            'गायक आ रहे हैं… / Loading…',
            style: TextStyle(color: t.textSecondary, fontSize: 13),
          )
        else if (p.singers.isEmpty)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
            decoration: BoxDecoration(
              color: t.surface,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              'अभी कोई गायक रजिस्टर्ड नहीं है।\nNo registered singers yet.',
              style: TextStyle(color: t.textSecondary, fontSize: 13),
            ),
          )
        else
          ...p.singers.map((s) {
            final selected = p.singerId == s.id;
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Material(
                color: t.surface,
                borderRadius: BorderRadius.circular(14),
                child: InkWell(
                  onTap: () => p.setSinger(s.id),
                  borderRadius: BorderRadius.circular(14),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(14),
                      border: selected
                          ? Border.all(color: t.accent, width: 2)
                          : null,
                    ),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 22,
                          backgroundColor: t.accent,
                          child: Text(
                            _initials(s.name),
                            style: const TextStyle(
                              color: Color(0xFF101214),
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                s.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: t.textPrimary,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              Text(
                                _mask(s.mobile),
                                style: TextStyle(
                                  color: t.textSecondary,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (selected)
                          Icon(Icons.check, size: 18, color: t.accent),
                      ],
                    ),
                  ),
                ),
              ),
            );
          }),
      ],
    );
  }
}