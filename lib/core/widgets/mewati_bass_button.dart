import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../services/bass_energy.dart';

/// Locked Mewati Bass now-playing button.
/// Off: gold + MB, outer ring empty (arc space reserved).
/// On: same layout, blue arcs pulse (2 / 3 / 4 from bass energy).
class MewatiBassButton extends StatefulWidget {
  final double size;
  final bool active;
  final VoidCallback? onPressed;

  const MewatiBassButton({
    super.key,
    this.size = 52,
    this.active = true,
    this.onPressed,
  });

  @override
  State<MewatiBassButton> createState() => _MewatiBassButtonState();
}

class _MewatiBassButtonState extends State<MewatiBassButton>
    with SingleTickerProviderStateMixin {
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
      _target *= 0.55;
    }
    _energy += (_target - _energy) * 0.55;
    if (_energy < 0.05) _energy = 0;
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
    return SizedBox(
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
                painter: _BassButtonPainter(
                  energy: widget.active ? _energy : 0,
                  active: widget.active,
                  phase: _pulse.value,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _BassButtonPainter extends CustomPainter {
  final double energy;
  final bool active;
  final double phase;

  _BassButtonPainter({
    required this.energy,
    required this.active,
    required this.phase,
  });

  // LOCKED layout — do not retune without owner.
  static const _gold = Color(0xFFD4AF37);
  static const _blue = Color(0xFF2F6BFF);
  static const _gray = Color(0xFFB8B8B8);
  static const _ink = Color(0xFF1A1208);
  static const _refR = 132.0;
  static const _refW = [15.0, 24.0, 36.0, 48.0];
  static const _refD = [154.5, 198.0, 264.0, 354.0];
  static const _refOuter = 354.0 + 24.0;
  static const _sweepDeg = [140.0, 162.0, 188.0, 214.0];

  static int _level(double e) {
    if (e < 0.07) return 0;
    if (e < 0.38) return 2;
    if (e < 0.48) return 3;
    return 4;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height / 2);
    final maxR = math.min(size.width, size.height) / 2;
    canvas.drawCircle(c, maxR, Paint()..color = _gray);

    final r = maxR * 0.48;
    canvas.drawCircle(c, r, Paint()..color = _gold);

    final sized = TextPainter(
      text: TextSpan(
        text: 'MB',
        style: TextStyle(
          color: _ink,
          fontSize: r * 0.88,
          fontWeight: FontWeight.w900,
          height: 1,
          letterSpacing: -0.5,
        ),
      ),
      textAlign: TextAlign.center,
      textDirection: ui.TextDirection.ltr,
    )..layout();
    sized.paint(
      canvas,
      Offset(c.dx - sized.width / 2, c.dy - sized.height / 2),
    );

    final n = active ? math.max(2, _level(energy.clamp(0.0, 1.0))) : 0;
    if (n == 0) return;

    final k = (maxR - 1 - r) / (_refOuter - _refR);
    final pulse = 0.72 + 0.28 * (0.5 + 0.5 * math.sin(phase * math.pi * 2));
    for (var i = 0; i < n; i++) {
      final w = math.max(1.1, _refW[i] * k);
      final dist = r + (_refD[i] - _refR) * k;
      final paint = Paint()
        ..color = _blue.withOpacity(pulse)
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..strokeWidth = math.max(1.0, w);
      _paren(canvas, paint, c, dist, _sweepDeg[i], left: true);
      _paren(canvas, paint, c, dist, _sweepDeg[i], left: false);
    }
  }

  void _paren(
    Canvas canvas,
    Paint paint,
    Offset c,
    double dist,
    double sweepDeg, {
    required bool left,
  }) {
    final rect = Rect.fromCircle(center: c, radius: dist);
    final sweep = sweepDeg * math.pi / 180;
    final half = sweep / 2;
    if (left) {
      canvas.drawArc(rect, math.pi - half, sweep, false, paint);
    } else {
      canvas.drawArc(rect, -half, sweep, false, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _BassButtonPainter oldDelegate) =>
      oldDelegate.energy != energy ||
      oldDelegate.active != active ||
      oldDelegate.phase != phase;
}