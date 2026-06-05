import 'package:flutter/material.dart';

import '../core/theme/tokens.dart';

/// aria brand mark: a stylised tulip in a soft clay-gradient badge, optionally
/// followed by the "aria" wordmark. Tunable size; colours come from tokens.
class AriaLogo extends StatelessWidget {
  const AriaLogo({super.key, this.size = 40, this.showWordmark = true});

  final double size;
  final bool showWordmark;

  @override
  Widget build(BuildContext context) {
    final badge = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: AppColors.accentGradient,
        borderRadius: BorderRadius.circular(size * 0.32),
        boxShadow: AppShadows.card,
      ),
      child: Padding(
        padding: EdgeInsets.all(size * 0.22),
        child: CustomPaint(painter: _TulipPainter(Colors.white)),
      ),
    );

    if (!showWordmark) return badge;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        badge,
        SizedBox(width: size * 0.28),
        Text(
          'aria',
          style: TextStyle(
            fontSize: size * 0.62,
            fontWeight: FontWeight.w800,
            color: AppColors.ink,
            letterSpacing: -0.5,
          ),
        ),
      ],
    );
  }
}

/// A simple three-petal tulip on a short stem, drawn to fill its canvas.
class _TulipPainter extends CustomPainter {
  _TulipPainter(this.color);
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final cx = w / 2;
    final fill = Paint()
      ..color = color
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;
    final stroke = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * 0.07
      ..strokeCap = StrokeCap.round;

    final base = Offset(cx, h * 0.60);

    // Stem.
    canvas.drawLine(base, Offset(cx, h * 0.92), stroke);

    // A leaning leaf/petal: pointed tip, rounded toward the base.
    Path petal(Offset tip, double halfWidth) {
      final mid = Offset((tip.dx + base.dx) / 2, (tip.dy + base.dy) / 2);
      return Path()
        ..moveTo(base.dx, base.dy)
        ..quadraticBezierTo(mid.dx - halfWidth, mid.dy, tip.dx, tip.dy)
        ..quadraticBezierTo(mid.dx + halfWidth, mid.dy, base.dx, base.dy)
        ..close();
    }

    // Three petals fanning from the base: left, centre (tallest), right.
    canvas.drawPath(petal(Offset(cx - w * 0.26, h * 0.22), w * 0.16), fill);
    canvas.drawPath(petal(Offset(cx + w * 0.26, h * 0.22), w * 0.16), fill);
    canvas.drawPath(petal(Offset(cx, h * 0.06), w * 0.16), fill);
  }

  @override
  bool shouldRepaint(covariant _TulipPainter old) => old.color != color;
}
