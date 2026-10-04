import 'dart:math';
import 'dart:typed_data';

import 'package:flutter/rendering.dart';

enum MoustacheStyle { handlebar, walrus, pencil, chevron, curly }

const _colors = [
  Color(0xFF151515), // black
  Color(0xFF2B1A10), // dark brown
  Color(0xFF4A2C1A), // brown
  Color(0xFF8A4520), // ginger
  Color(0xFF454545), // grey
];

/// Every random parameter of a moustache, derived from a single seed.
class MoustacheGenes {
  MoustacheGenes(int seed) {
    final r = Random(seed);
    double j(double base, double spread) => base + (r.nextDouble() * 2 - 1) * spread;
    style = MoustacheStyle.values[r.nextInt(MoustacheStyle.values.length)];
    color = _colors[r.nextInt(_colors.length)];
    // All values are in a 200 x 100 design box; the philtrum sits at x = 100.
    switch (style) {
      case MoustacheStyle.pencil:
        top = j(40, 2); bottom = top + j(10, 1.5); width = j(58, 8);
        tipY = j(45, 3); droop = j(0, 2); curl = 0;
      case MoustacheStyle.chevron:
        top = j(28, 3); bottom = j(60, 4); width = j(60, 6);
        tipY = j(62, 4); droop = j(6, 3); curl = 0;
      case MoustacheStyle.walrus:
        top = j(26, 3); bottom = j(68, 4); width = j(82, 6);
        tipY = j(82, 5); droop = j(16, 4); curl = 0;
      case MoustacheStyle.handlebar:
        top = j(34, 3); bottom = j(54, 3); width = j(68, 6);
        tipY = j(30, 5); droop = j(4, 3); curl = j(12, 3);
      case MoustacheStyle.curly:
        top = j(34, 3); bottom = j(52, 3); width = j(62, 6);
        tipY = j(38, 4); droop = j(3, 2); curl = j(20, 4);
    }
    lift = j(4, 3);
    strandSeed = r.nextInt(1 << 30);
  }

  late final MoustacheStyle style;
  late final Color color;
  late final double top, bottom, width, tipY, droop, curl, lift;
  late final int strandSeed;

  bool get hairyEdge =>
      style == MoustacheStyle.walrus || style == MoustacheStyle.chevron;
}

class MoustachePainter extends CustomPainter {
  MoustachePainter(this.genes, {this.highlight = false});

  final MoustacheGenes genes;
  final bool highlight;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.scale(size.width / 200, size.height / 100);
    final half = _halfPath();
    final full = Path()
      ..addPath(half, Offset.zero)
      ..addPath(half.transform(_mirror), Offset.zero);

    if (highlight) {
      canvas.drawPath(
        full,
        Paint()
          ..color = const Color(0x88FFFFFF)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 6
          ..strokeJoin = StrokeJoin.round,
      );
    }
    canvas.drawPath(full, Paint()..color = genes.color);
    _drawCurls(canvas);
    _drawStrands(canvas, full);
  }

  static final _mirror = Float64List.fromList([
    -1, 0, 0, 0, //
    0, 1, 0, 0, //
    0, 0, 1, 0, //
    200, 0, 0, 1,
  ]);

  Path _halfPath() {
    final g = genes;
    final tipX = 100 + g.width;
    final mid = (g.top + g.bottom) / 2;
    final p = Path()..moveTo(100, g.top + 3);
    // Upper edge out to the tip.
    p.cubicTo(100 + g.width * 0.3, g.top - g.lift, 100 + g.width * 0.7,
        mid - 4 + g.droop * 0.4, tipX, g.tipY);
    if (g.hairyEdge) {
      // Lower edge back to the centre as a jagged fringe of hair tips.
      const teeth = 9;
      for (var i = 1; i <= teeth; i++) {
        final t = i / teeth;
        final x = tipX - g.width * t;
        final base = g.tipY + (g.bottom - g.tipY) * t;
        p.lineTo(x + g.width / teeth * 0.5, base - 5);
        p.lineTo(x, base + (i.isOdd ? 3 : 0));
      }
      p.lineTo(100, g.bottom);
    } else {
      p.cubicTo(100 + g.width * 0.7, g.tipY + (g.bottom - g.top) * 0.5 + g.droop,
          100 + g.width * 0.3, g.bottom + 3, 100, g.bottom);
    }
    return p..close();
  }

  /// Tapered spirals rolling up from the wing tips (handlebar / curly).
  void _drawCurls(Canvas canvas) {
    final g = genes;
    if (g.curl <= 0) return;
    final paint = Paint()..color = g.color;
    final thickness = (g.bottom - g.top) * 0.3;
    for (final side in [1.0, -1.0]) {
      final tip = Offset(100 + side * g.width, g.tipY);
      final centre = tip + Offset(0, -g.curl);
      const steps = 40;
      final turns = g.style == MoustacheStyle.curly ? 1.3 : 0.75;
      for (var i = 0; i <= steps; i++) {
        final t = i / steps;
        // Starts at the bottom of the loop, sweeps outward, up and back in.
        final angle = pi / 2 - t * turns * 2 * pi;
        final radius = g.curl * (1 - t * 0.7);
        final pt = centre +
            Offset(cos(angle) * radius * side, sin(angle) * radius);
        canvas.drawCircle(pt, max(0.8, thickness * (1 - t)), paint);
      }
    }
  }

  /// Fine hair lines for a bit of texture.
  void _drawStrands(Canvas canvas, Path clip) {
    final g = genes;
    final r = Random(g.strandSeed);
    final light = Color.lerp(g.color, const Color(0xFFFFFFFF), 0.18)!;
    final paint = Paint()
      ..color = light.withValues(alpha: 0.5)
      ..strokeWidth = 0.8
      ..strokeCap = StrokeCap.round;
    canvas.save();
    canvas.clipPath(clip);
    for (var i = 0; i < 40; i++) {
      final side = r.nextBool() ? 1.0 : -1.0;
      final dx = r.nextDouble() * g.width * 0.9;
      final y = g.top + r.nextDouble() * (g.bottom - g.top);
      final start = Offset(100 + side * dx, y);
      // Hair grows outward and downward from the centre.
      final end = start + Offset(side * (4 + r.nextDouble() * 6), 3 + r.nextDouble() * 5);
      canvas.drawLine(start, end, paint);
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(MoustachePainter old) =>
      old.genes != genes || old.highlight != highlight;
}
