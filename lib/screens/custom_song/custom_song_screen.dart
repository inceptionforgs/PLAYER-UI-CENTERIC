import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/constants/app_strings.dart';
import '../../providers/custom_song_provider.dart';
import '../../providers/theme_provider.dart';
import 'widgets/details_step.dart';
import 'widgets/length_step.dart';
import 'widgets/singer_step.dart';

class CustomSongScreen extends StatelessWidget {
  const CustomSongScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => CustomSongProvider(),
      child: const _CustomSongBody(),
    );
  }
}

class _CustomSongBody extends StatelessWidget {
  const _CustomSongBody();

  static const _stepsHi = ['आपकी जानकारी', 'गायक चुनें', 'गाने की लंबाई'];

  @override
  Widget build(BuildContext context) {
    final p = context.watch<CustomSongProvider>();
    final t = context.watch<ThemeProvider>().theme;

    return Scaffold(
      backgroundColor: t.background,
      appBar: AppBar(
        backgroundColor: t.background,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.chevron_left, color: t.textPrimary),
          onPressed: p.submitting
              ? null
              : () {
                  if (p.step == 0) {
                    Navigator.of(context).maybePop();
                  } else {
                    p.back();
                  }
                },
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              AppStrings.customSongDrawer,
              style: TextStyle(
                color: t.textPrimary,
                fontSize: 17,
                fontWeight: FontWeight.w600,
              ),
            ),
            Text(
              '${AppStrings.customSongTitleEn} · ${p.step + 1}/3 · ${_stepsHi[p.step]}',
              style: TextStyle(
                color: t.textSecondary,
                fontSize: 11,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
            child: Row(
              children: List.generate(3, (i) {
                return Expanded(
                  child: Container(
                    height: 2,
                    margin: EdgeInsets.only(right: i == 2 ? 0 : 6),
                    decoration: BoxDecoration(
                      color: i <= p.step
                          ? t.accent
                          : t.textPrimary.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(99),
                    ),
                  ),
                );
              }),
            ),
          ),
          Expanded(
            child: p.step == 0
                ? const DetailsStep()
                : p.step == 1
                    ? const SingerStep()
                    : const LengthStep(),
          ),
          if (p.errorMessage != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: Text(
                p.errorMessage!,
                style: TextStyle(color: t.textSecondary, fontSize: 12),
              ),
            ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: p.submitting
                      ? null
                      : () async {
                          if (p.step < 2) {
                            await p.next();
                            return;
                          }
                          final url = await p.submit();
                          if (url == null) return;
                          final uri = Uri.parse(url);
                          await launchUrl(
                            uri,
                            mode: LaunchMode.externalApplication,
                          );
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: t.accent,
                    foregroundColor: const Color(0xFF101214),
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: const StadiumBorder(),
                  ),
                  child: p.step == 2
                      ? Column(
                          children: [
                            Text(
                              p.submitting
                                  ? AppStrings.customSongSendingHi
                                  : AppStrings.customSongSendHi,
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            Text(
                              p.submitting
                                  ? AppStrings.customSongSendingEn
                                  : AppStrings.customSongSendEn,
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        )
                      : Column(
                          children: [
                            Text(
                              AppStrings.customSongContinueHi,
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            Text(
                              AppStrings.customSongContinueEn,
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}