import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Original, restrained vector tooling inspired by traditional book bindings.
/// Decoration only: no scripture, religious markers or remote image assets.
class MushafCoverOrnament extends CustomPainter {
  const MushafCoverOrnament();

  static const gold = Color(0xffd7b873);

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 216, size.height / 292);
    final line = Paint()
      ..color = gold
      ..style = PaintingStyle.stroke
      ..strokeWidth = .65
      ..strokeCap = StrokeCap.round;
    final muted = Paint()
      ..color = gold.withValues(alpha: .30)
      ..style = PaintingStyle.stroke
      ..strokeWidth = .45;

    // Keep the accepted green leather spine and fine double perimeter frame.
    canvas.drawRect(
      const Rect.fromLTWH(0, 0, 16, 292),
      Paint()
        ..shader = const LinearGradient(
          colors: [Color(0xff071f1a), Color(0xff35594a), Color(0xff113b30)],
        ).createShader(const Rect.fromLTWH(0, 0, 16, 292)),
    );
    canvas.drawLine(const Offset(16, 5), const Offset(16, 287), muted);
    for (final y in [24.0, 30.0, 261.0, 267.0]) {
      canvas.drawLine(Offset(3, y), Offset(12, y), line);
    }
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(23, 12, 181, 268),
        const Radius.circular(7),
      ),
      line,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(27, 16, 173, 260),
        const Radius.circular(4),
      ),
      muted,
    );

    // Quiet side rules replace the busy repeated diamond chain.
    for (final x in [31.0, 196.0]) {
      canvas.drawLine(Offset(x, 65), Offset(x, 101), muted);
      canvas.drawLine(Offset(x, 191), Offset(x, 227), muted);
      canvas.drawCircle(
        Offset(x, 146),
        1,
        Paint()..color = gold.withValues(alpha: .5),
      );
    }

    // Four identical, mirrored leaf corners: no nested curls or tight loops.
    for (final corner in [
      const Offset(31, 20),
      const Offset(196, 20),
      const Offset(31, 272),
      const Offset(196, 272),
    ]) {
      canvas.save();
      canvas.translate(corner.dx, corner.dy);
      canvas.scale(corner.dx > 100 ? -1.0 : 1.0, corner.dy > 150 ? -1.0 : 1.0);
      canvas.drawPath(
        Path()
          ..moveTo(0, 27)
          ..quadraticBezierTo(0, 0, 27, 0),
        line,
      );
      _leaf(canvas, const Offset(4, 4), math.pi / 4, 11, line);
      _leaf(canvas, const Offset(12, 2), 0, 8, muted);
      _leaf(canvas, const Offset(2, 12), math.pi / 2, 8, muted);
      canvas.restore();
    }

    // A single smooth oval replaces the pointed, multi-lobed medallion.
    const oval = Rect.fromLTRB(65, 51, 161, 171);
    canvas.drawOval(oval, Paint()..color = const Color(0xff082e26));
    canvas.drawOval(oval, line..strokeWidth = .8);

    // One small tulip sprig replaces the eight-petal rosette and dotted halo.
    // It remains purely botanical, with generous empty space around it.
    final tulip = Path()
      ..moveTo(113, 109)
      ..cubicTo(101, 106, 100, 96, 103, 89)
      ..quadraticBezierTo(107, 91, 109, 96)
      ..quadraticBezierTo(109, 87, 113, 82)
      ..quadraticBezierTo(117, 87, 117, 96)
      ..quadraticBezierTo(119, 91, 123, 89)
      ..cubicTo(126, 96, 125, 106, 113, 109)
      ..close();
    canvas.drawPath(tulip, Paint()..color = gold.withValues(alpha: .09));
    canvas.drawPath(tulip, line);
    canvas.drawPath(
      Path()
        ..moveTo(113, 99)
        ..cubicTo(110, 114, 116, 128, 113, 140),
      line,
    );
    final leaves = Path()
      ..moveTo(113, 128)
      ..cubicTo(101, 128, 100, 120, 100, 116)
      ..cubicTo(109, 117, 112, 122, 113, 128)
      ..moveTo(114, 121)
      ..cubicTo(124, 120, 127, 114, 126, 110)
      ..cubicTo(118, 112, 115, 116, 114, 121);
    canvas.drawPath(leaves, line..strokeWidth = .65);
    final bead = Paint()..color = gold.withValues(alpha: .65);
    canvas.drawCircle(const Offset(113, 64), 1, bead);
    canvas.drawCircle(const Offset(113, 158), 1, bead);

    // Retain the light divider beneath the unchanged Türkmen title.
    for (final side in [-1.0, 1.0]) {
      canvas.drawLine(
        Offset(113 + side * 10, 240),
        Offset(113 + side * 40, 240),
        muted,
      );
    }
    _leaf(canvas, const Offset(109, 240), 0, 8, line);
    canvas.restore();
  }

  void _leaf(
    Canvas canvas,
    Offset origin,
    double angle,
    double length,
    Paint paint,
  ) {
    canvas.save();
    canvas.translate(origin.dx, origin.dy);
    canvas.rotate(angle);
    final leaf = Path()
      ..moveTo(0, 0)
      ..quadraticBezierTo(length * .45, -length * .45, length, 0)
      ..quadraticBezierTo(length * .45, length * .45, 0, 0);
    canvas.drawPath(leaf, paint);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant MushafCoverOrnament oldDelegate) => false;
}
