import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Exact match of the locked EQ preview:
/// theme-coloured bg, gold blob + "Mewati Bass™", gold crescent moons.
/// Levels: 0 / 2 / 3 / 4 from [energy].
class MewatiBassEqVisual extends StatelessWidget {
  final double energy;
  final Color? background;

  const MewatiBassEqVisual({super.key, required this.energy, this.background});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: MewatiBassEqPainter(energy: energy, background: background),
      child: const SizedBox.expand(),
    );
  }
}

class MewatiBassEqPainter extends CustomPainter {
  final double energy;
  final Color? background;

  MewatiBassEqPainter({required this.energy, this.background});

  static const _gold = Color(0xFFD4AF37);
  static const _gray = Color(0xFFB8B8B8);
  static const _ink = Color(0xFF1A1208);

  static const _dists = [0.508, 0.675, 0.851, 1.010];
  static const _rads = [0.374, 0.506, 0.660, 0.836];
  static const _cutOff = 0.22;
  static const _cutR = 0.93;
  static const _blob = 0.40;

  /// Locked bass pop pattern:
  /// gap → 0 (sirf gola), min → 2, medium → 3, medium+ → 4.
  /// 4→2 drops the outer two; positions stay fixed (no traveling waves).
  static int level(double e) {
    if (e < 0.07) return 0;
    if (e < 0.38) return 2;
    if (e < 0.48) return 3;
    return 4;
  }

  @override
  void paint(Canvas canvas, Size size) {
    // Clip to bounds so the crescents can never bleed past the panel
    // edges, regardless of screen size or the fixed _dists/_rads ratios.
    canvas.save();
    canvas.clipRect(Offset.zero & size);

    final c = Offset(size.width / 2, size.height / 2);
    canvas.drawRect(Offset.zero & size, Paint()..color = background ?? _gray);

    final maxR = math.min(size.width, size.height) / 2 - 4;
    final r = maxR * _blob;
    final n = level(energy.clamp(0.0, 1.0));
    final moon = Paint()..color = _gold;

    for (var i = 0; i < n; i++) {
      final dist = maxR * _dists[i];
      final rad = maxR * _rads[i];
      canvas.drawPath(_crescent(c, dist, rad, left: true), moon);
      canvas.drawPath(_crescent(c, dist, rad, left: false), moon);
    }

    canvas.drawCircle(c, r, Paint()..color = _gold);

    final label = TextPainter(
      text: TextSpan(
        text: 'Mewati\nBass™',
        style: TextStyle(
          color: _ink,
          fontSize: r * 0.28,
          fontWeight: FontWeight.w800,
          height: 1.05,
        ),
      ),
      textAlign: TextAlign.center,
      textDirection: TextDirection.ltr,
    )..layout();
    label.paint(canvas, Offset(c.dx - label.width / 2, c.dy - label.height / 2));
    canvas.restore();
  }

  Path _crescent(Offset blob, double dist, double rad, {required bool left}) {
    final dir = left ? -1.0 : 1.0;
    final moonC = Offset(blob.dx + dir * dist, blob.dy);
    final cutC = Offset(moonC.dx - dir * rad * _cutOff, blob.dy);
    return Path()
      ..fillType = PathFillType.evenOdd
      ..addOval(Rect.fromCircle(center: moonC, radius: rad))
      ..addOval(Rect.fromCircle(center: cutC, radius: rad * _cutR));
  }

  @override
  bool shouldRepaint(covariant MewatiBassEqPainter oldDelegate) =>
      oldDelegate.energy != energy || oldDelegate.background != background;
}