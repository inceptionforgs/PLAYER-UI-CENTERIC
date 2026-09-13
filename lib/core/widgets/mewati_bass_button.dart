import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../services/bass_energy.dart';

class MewatiBassButton extends StatefulWidget {
  final double size;
  final bool active;
  final VoidCallback? onPressed;

  const MewatiBassButton({
    super.key,
    this.size = 44,
    this.active = true,
    this.onPressed,
  });

  @override
  State<MewatiBassButton> createState() => _MewatiBassButtonState();
}

class _MewatiBassButtonState extends State<MewatiBassButton>
    with SingleTickerProviderStateMixin {
  static const _gold = Color(0xFFF3D59A);

  late final AnimationController _pulse;
  StreamSubscription<double>? _sub;
  double _energy = 0;
  double _target = 0;
  int _lastEventMs = 0;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..repeat();
    _pulse.addListener(_tick);
    _sub = BassEnergy.stream.listen((v) {
      _target = v;
      _lastEventMs = DateTime.now().millisecondsSinceEpoch;
    });
  }

  void _tick() {
    final now = DateTime.now().millisecondsSinceEpoch;
    if (now - _lastEventMs > 90) {
      _target *= 0.86;
    }
    _energy += (_target - _energy) * 0.38;
    if (_energy < 0.004) _energy = 0;
  }

  @override
  void dispose() {
    _sub?.cancel();
    _pulse.removeListener(_tick);
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.size;
    final energy = widget.active ? _energy : 0.0;
    return Opacity(
      opacity: widget.active ? 1 : 0.42,
      child: SizedBox(
        width: s,
        height: s,
        child: AnimatedBuilder(
          animation: _pulse,
          builder: (context, _) {
            return Material(
              color: Colors.transparent,
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: widget.onPressed,
                child: CustomPaint(
                  painter: _ConePainter(energy: energy),
                  child: Center(
                    child: Text(
                      'MB',
                      style: TextStyle(
                        color: _gold,
                        fontSize: s * 0.32,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.4,
                        height: 1,
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _ConePainter extends CustomPainter {
  final double energy;

  _ConePainter({required this.energy});

  static const double _tilt = 0.80;
  static const Color _gold = Color(0xFFF3D59A);
  static const Color _goldDeep = Color(0xFFC9A15C);
  static const Color _dark = Color(0xFF12100C);

  @override
  void paint(Canvas canvas, Size size) {
    final pulse = energy.clamp(0.0, 1.0);
    final c = Offset(size.width / 2, size.height / 2);
    final maxRByWidth = size.width / 2 - 1.2;
    final maxRByHeight = (size.height / 2 - 1.2) / _tilt;
    final maxR = math.min(maxRByWidth, maxRByHeight);

    Rect ovalRect(double r) => Rect.fromCenter(
          center: c,
          width: r * 2,
          height: r * 2 * _tilt,
        );

    canvas.drawOval(
      ovalRect(maxR),
      Paint()
        ..shader = RadialGradient(
          colors: [_dark.withOpacity(0.97), const Color(0xFF07060A)],
        ).createShader(ovalRect(maxR)),
    );

    canvas.drawOval(
      ovalRect(maxR * 0.97),
      Paint()
        ..color = _gold.withOpacity(0.85)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4,
    );

    const pleatFractions = [0.85, 0.71, 0.58, 0.46, 0.35];
    for (var i = 0; i < pleatFractions.length; i++) {
      final excursion = 0.02 + i * 0.014;
      final r = maxR * (pleatFractions[i] + excursion * pulse);
      final shade =
          (i.isEven ? _goldDeep : _gold).withOpacity(0.28 + 0.42 * pulse);
      canvas.drawOval(
        ovalRect(r),
        Paint()
          ..color = shade
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.15,
      );
    }

    canvas.drawOval(
      ovalRect(maxR),
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(-0.35, -0.6),
          radius: 0.55,
          colors: [
            Colors.white.withOpacity(0.09 + 0.06 * pulse),
            Colors.transparent,
          ],
        ).createShader(ovalRect(maxR)),
    );

    final hubR = maxR * (0.42 + 0.03 * pulse);
    canvas.drawOval(
      ovalRect(hubR),
      Paint()
        ..shader = RadialGradient(
          colors: [const Color(0xFF1C1912), _dark],
        ).createShader(ovalRect(hubR)),
    );
    canvas.drawOval(
      ovalRect(hubR),
      Paint()
        ..color = _gold.withOpacity(0.70 + 0.30 * pulse)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2,
    );
  }

  @override
  bool shouldRepaint(covariant _ConePainter oldDelegate) =>
      oldDelegate.energy != energy;
}