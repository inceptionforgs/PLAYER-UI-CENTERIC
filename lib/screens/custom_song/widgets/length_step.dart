import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/constants/app_strings.dart';
import '../../../providers/custom_song_provider.dart';
import '../../../providers/theme_provider.dart';

class LengthStep extends StatelessWidget {
  const LengthStep({Key? key}) : super(key: key);

  static const _hi = {
    '5–10 minutes': '5–10 मिनट',
    '10–15 minutes': '10–15 मिनट',
    '15–20 minutes': '15–20 मिनट',
    '20–25 minutes': '20–25 मिनट',
    '25–30 minutes': '25–30 मिनट',
  };

  String _mask(String mobile) {
    if (mobile.length < 10) return mobile;
    return '+91 •••• ••${mobile.substring(mobile.length - 4)}';
  }

  @override
  Widget build(BuildContext context) {
    final p = context.watch<CustomSongProvider>();
    final t = context.watch<ThemeProvider>().theme;
    final singer = p.singer;

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      children: [
        if (singer != null) ...[
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: t.surface,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'इनके WhatsApp पर जाएगा',
                  style: TextStyle(
                    color: t.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Sending to',
                  style: TextStyle(color: t.textSecondary, fontSize: 12),
                ),
                const SizedBox(height: 6),
                Text(
                  singer.name,
                  style: TextStyle(
                    color: t.textPrimary,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  _mask(singer.mobile),
                  style: TextStyle(color: t.textSecondary, fontSize: 12),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
        ],
        Text(
          AppStrings.customSongLengthHi,
          style: TextStyle(
            color: t.textPrimary,
            fontSize: 14,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          AppStrings.customSongLengthEn,
          style: TextStyle(color: t.textSecondary, fontSize: 12),
        ),
        const SizedBox(height: 10),
        ...CustomSongProvider.lengths.map((id) {
          final selected = p.length == id;
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Material(
              color: t.surface,
              borderRadius: BorderRadius.circular(12),
              child: InkWell(
                onTap: () => p.setLength(id),
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: selected
                        ? Border.all(color: t.accent, width: 2)
                        : null,
                  ),
                  child: Row(
                    children: [
                      Radio<String>(
                        value: id,
                        groupValue: p.length,
                        onChanged: (v) {
                          if (v != null) p.setLength(v);
                        },
                        activeColor: t.accent,
                      ),
                      const SizedBox(width: 4),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _hi[id] ?? id,
                            style: TextStyle(
                              color: t.textPrimary,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Text(
                            id,
                            style: TextStyle(
                              color: t.textSecondary,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        }),
        const SizedBox(height: 12),
        Text(
          AppStrings.customSongLyricsHi,
          style: TextStyle(
            color: t.textPrimary,
            fontSize: 14,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          AppStrings.customSongLyricsEn,
          style: TextStyle(color: t.textSecondary, fontSize: 12),
        ),
        const SizedBox(height: 10),
        TextField(
          minLines: 6,
          maxLines: 8,
          onChanged: p.setLyrics,
          style: TextStyle(color: t.textPrimary, fontSize: 14),
          decoration: InputDecoration(
            hintText: 'यहाँ लिखें / Enter here',
            hintStyle: TextStyle(color: t.textSecondary, fontSize: 13),
            filled: true,
            fillColor: t.surface,
            contentPadding: const EdgeInsets.all(14),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
          ),
        ),
      ],
    );
  }
}