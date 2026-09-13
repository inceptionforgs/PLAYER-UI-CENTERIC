import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../../core/constants/app_strings.dart';
import '../../../providers/custom_song_provider.dart';
import '../../../providers/theme_provider.dart';

class DetailsStep extends StatefulWidget {
  const DetailsStep({Key? key}) : super(key: key);

  @override
  State<DetailsStep> createState() => _DetailsStepState();
}

class _DetailsStepState extends State<DetailsStep> {
  late final TextEditingController _name;
  late final TextEditingController _mobile;

  @override
  void initState() {
    super.initState();
    final p = context.read<CustomSongProvider>();
    _name = TextEditingController(text: p.name);
    _mobile = TextEditingController(text: p.mobile);
  }

  @override
  void dispose() {
    _name.dispose();
    _mobile.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = context.watch<CustomSongProvider>();
    final t = context.watch<ThemeProvider>().theme;

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      children: [
        _BiLabel(hi: AppStrings.customSongNameHi, en: AppStrings.customSongNameEn),
        const SizedBox(height: 8),
        TextField(
          controller: _name,
          onChanged: p.setName,
          textCapitalization: TextCapitalization.words,
          style: TextStyle(color: t.textPrimary, fontSize: 15),
          decoration: _input(t, AppStrings.customSongNameHint),
        ),
        const SizedBox(height: 20),
        _BiLabel(
          hi: AppStrings.customSongMobileHi,
          en: AppStrings.customSongMobileEn,
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _mobile,
          onChanged: p.setMobile,
          keyboardType: TextInputType.phone,
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
            LengthLimitingTextInputFormatter(10),
          ],
          style: TextStyle(color: t.textPrimary, fontSize: 15),
          decoration: _input(t, AppStrings.customSongMobileHint),
        ),
      ],
    );
  }

  InputDecoration _input(dynamic t, String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(color: t.textSecondary, fontSize: 13),
      filled: true,
      fillColor: t.surface,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
    );
  }
}

class _BiLabel extends StatelessWidget {
  final String hi;
  final String en;

  const _BiLabel({required this.hi, required this.en});

  @override
  Widget build(BuildContext context) {
    final t = context.watch<ThemeProvider>().theme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          hi,
          style: TextStyle(
            color: t.textPrimary,
            fontSize: 14,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          en,
          style: TextStyle(
            color: t.textSecondary,
            fontSize: 12,
            fontWeight: FontWeight.w400,
          ),
        ),
      ],
    );
  }
}