import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Decorative green waves (Spotify-style) for hero / login headers.
class GreenWaveHeader extends StatelessWidget {
  const GreenWaveHeader({super.key, required this.height, this.child});

  final double height;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      width: double.infinity,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(
            child: CustomPaint(painter: _WavePainter()),
          ),
          if (child != null)
            Positioned(
              left: 0,
              right: 0,
              bottom: 24,
              child: child!,
            ),
        ],
      ),
    );
  }
}

class _WavePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromLTWH(0, 0, size.width, size.height);
    final g = RadialGradient(
      center: const Alignment(-0.2, -0.6),
      radius: 1.2,
      colors: [
        AppColors.spotifyGreenBright.withValues(alpha: 0.95),
        AppColors.spotifyGreen,
        const Color(0xFF006B3F),
      ],
      stops: const [0.0, 0.45, 1.0],
    );
    canvas.drawRect(rect, Paint()..shader = g.createShader(rect));

    final path = Path();
    for (var i = 0; i < 3; i++) {
      path.reset();
      final yBase = size.height * (0.55 + i * 0.12);
      path.moveTo(0, yBase);
      for (double x = 0; x <= size.width; x += 8) {
        final wave = math.sin(x / size.width * math.pi * 2 + i) * 18;
        path.lineTo(x, yBase + wave);
      }
      path.lineTo(size.width, size.height);
      path.lineTo(0, size.height);
      path.close();
      canvas.drawPath(
        path,
        Paint()
          ..color = Colors.black.withValues(alpha: 0.08 + i * 0.04)
          ..style = PaintingStyle.fill,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
