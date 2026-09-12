import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/utils/debouncer.dart';
import '../../../providers/theme_provider.dart';
import '../../../services/equalizer_service.dart';
import '../../../services/eq_presets.dart';

/// 5-band custom EQ. Does not read AndroidEqualizer band count.
class CustomEqualizerSection extends StatefulWidget {
  const CustomEqualizerSection({super.key});

  @override
  State<CustomEqualizerSection> createState() => _CustomEqualizerSectionState();
}

class _CustomEqualizerSectionState extends State<CustomEqualizerSection> {
  final _eq = EqualizerService();
  final _eqDebounce = Debouncer(delay: const Duration(milliseconds: 80));
  bool _loading = true;
  List<double> _bandGains = List<double>.filled(EqPresets.uiBandsHz.length, 0);
  double _bassBoost = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      await _eq.init();
      final saved = await _eq.loadPersistedCustomEq(bandCount: EqPresets.uiBandsHz.length);
      final applyLive =
          mounted && context.read<ThemeProvider>().eqPreset == 'custom';
      if (applyLive) {
        for (var i = 0; i < saved.bandGains.length; i++) {
          await _eq.setBandGain(i, saved.bandGains[i]);
        }
        await _eq.setBassBoost(saved.bassBoostDb);
      }
      if (!mounted) return;
      setState(() {
        _bandGains = List<double>.from(saved.bandGains);
        _bassBoost = saved.bassBoostDb;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  void _markCustom() {
    final theme = context.read<ThemeProvider>();
    if (theme.eqPreset != 'custom') theme.setEqPreset('custom');
  }

  void _scheduleEqPush() {
    _eqDebounce.run(() {
      _eq.applyCustomSnapshot(bandGains: _bandGains, bassBoostDb: _bassBoost);
    });
  }

  @override
  void dispose() {
    _eqDebounce.cancel();
    super.dispose();
  }

  String _label(double hz) {
    if (hz >= 1000) {
      final k = hz / 1000;
      return k == k.roundToDouble() ? '${k.round()}kHz' : '${k.toStringAsFixed(1)}kHz';
    }
    return '${hz.round()}Hz';
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Padding(
        padding: EdgeInsets.all(24),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    return Column(
      children: [
        for (var i = 0; i < EqPresets.uiBandsHz.length; i++)
          ListTile(
            title: Text(_label(EqPresets.uiBandsHz[i])),
            subtitle: Slider(
              min: EqPresets.minDb,
              max: EqPresets.maxDb,
              value: _bandGains[i].clamp(EqPresets.minDb, EqPresets.maxDb),
              onChanged: (v) {
                setState(() => _bandGains[i] = v);
                _markCustom();
                _scheduleEqPush();
              },
            ),
          ),
        ListTile(
          title: const Text('Bass boost'),
          subtitle: Slider(
            min: 0,
            max: EqualizerService.maxBassBoostDb,
            value: _bassBoost.clamp(0, EqualizerService.maxBassBoostDb),
            onChanged: (v) {
              setState(() => _bassBoost = v);
              _markCustom();
              _scheduleEqPush();
            },
          ),
        ),
        TextButton(
          onPressed: () async {
            await _eq.resetCustomEq();
            if (!mounted) return;
            setState(() {
              _bandGains = List<double>.filled(EqPresets.uiBandsHz.length, 0);
              _bassBoost = 0;
            });
          },
          child: const Text('Reset'),
        ),
      ],
    );
  }
}
