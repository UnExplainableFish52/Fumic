import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../src/theme/fumic_theme.dart';
import 'visualizer_controller.dart';

class TrapVisualizerPainter extends CustomPainter {
  TrapVisualizerPainter({required this.controller, required this.colors})
    : super(repaint: controller);

  final TrapVisualizerController controller;
  final List<Color> colors;

  @override
  void paint(Canvas canvas, Size size) {
    final settings = controller.settings;
    final frame = controller.frame;
    final center = size.center(Offset.zero);
    final minSide = math.min(size.width, size.height);
    final artRadius = minSide * 0.185;
    final ringRadius = artRadius + minSide * 0.092;
    final phase = frame.timeSeconds;
    final accent = colors.length > 1 ? colors[1] : FumicTheme.accent;
    final glow = settings.glowStrength.amount;

    _paintBackdropBloom(canvas, size, center, accent);
    if (!settings.enabled) {
      _paintDisabledShell(canvas, center, artRadius, ringRadius);
      return;
    }

    if (settings.backgroundMotion) {
      _paintMotionField(canvas, size, center, ringRadius, phase);
    }
    _paintGlow(canvas, center, ringRadius, accent, glow);
    _paintParticles(canvas, size, center, accent, glow);
    _paintWaveSkin(canvas, center, ringRadius, phase);
    _paintCircularBars(canvas, center, ringRadius, phase);
    _paintAccentArcs(canvas, center, artRadius, ringRadius, phase);
    _paintCenterHalo(canvas, center, artRadius, accent, glow);
  }

  void _paintBackdropBloom(
    Canvas canvas,
    Size size,
    Offset center,
    Color accent,
  ) {
    final frame = controller.frame;
    final radius = math.min(size.width, size.height) * 0.58;
    final paint = Paint()
      ..shader = RadialGradient(
        colors: [
          Color.lerp(
            accent,
            const Color(0xFFFF4FD8),
            0.35,
          )!.withValues(alpha: 0.16 + frame.energy * 0.10),
          const Color(0xFF1B2844).withValues(alpha: 0.10),
          Colors.transparent,
        ],
        stops: const [0, 0.48, 1],
      ).createShader(Rect.fromCircle(center: center, radius: radius));
    canvas.drawCircle(center, radius, paint);
  }

  void _paintMotionField(
    Canvas canvas,
    Size size,
    Offset center,
    double ringRadius,
    double phase,
  ) {
    final frame = controller.frame;
    final minSide = math.min(size.width, size.height);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);

    for (var index = 0; index < 7; index++) {
      final radius = ringRadius + 58 + index * minSide * 0.034;
      final start = phase * (0.16 + index * 0.012) + index * math.pi * 0.42;
      final sweep = 0.22 + frame.mids * 0.30 + (index.isEven ? 0.12 : 0);
      paint
        ..strokeWidth = 1.2 + index * 0.16
        ..color = _neonColor(
          index / 7,
        ).withValues(alpha: 0.035 + frame.energy * 0.055);
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        start,
        sweep,
        false,
        paint,
      );
    }

    final linePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = Colors.white.withValues(alpha: 0.025 + frame.highs * 0.035);
    for (var index = 0; index < 9; index++) {
      final y = size.height * (0.18 + index * 0.08);
      final path = Path()..moveTo(0, y);
      for (var x = 0.0; x <= size.width; x += 42) {
        path.lineTo(
          x,
          y +
              math.sin(x / 84 + phase * (0.7 + frame.mids) + index * 0.62) *
                  (8 + frame.energy * 16),
        );
      }
      canvas.drawPath(path, linePaint);
    }
  }

  void _paintGlow(
    Canvas canvas,
    Offset center,
    double ringRadius,
    Color accent,
    double glow,
  ) {
    if (glow <= 0) {
      return;
    }
    final frame = controller.frame;
    final pulse = frame.beatPulse;
    final outer = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 28 + frame.bass * 30
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, 24 + glow * 18)
      ..color = accent.withValues(alpha: (0.10 + pulse * 0.16) * glow);
    canvas.drawCircle(center, ringRadius + 42 + pulse * 26, outer);

    final burst = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 12 + pulse * 18
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 34)
      ..color = const Color(0xFFFFD45C).withValues(alpha: pulse * 0.12 * glow);
    canvas.drawCircle(center, ringRadius + 82 + pulse * 54, burst);
  }

  void _paintParticles(
    Canvas canvas,
    Size size,
    Offset center,
    Color accent,
    double glow,
  ) {
    final frame = controller.frame;
    final particles = controller.particles;
    if (particles.isEmpty) {
      return;
    }

    final paint = Paint()..style = PaintingStyle.fill;
    final glowPaint = Paint()
      ..style = PaintingStyle.fill
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
    for (final particle in particles) {
      final location = particle.resolve(size, center);
      final shimmer = math.sin(particle.shimmerPhase) * 0.5 + 0.5;
      final alpha =
          (particle.opacity * (0.62 + frame.energy * 0.50) +
                  frame.beatPulse * 0.18)
              .clamp(0.0, 0.90);
      final color = Color.lerp(
        Color.lerp(colors.first, accent, particle.colorMix),
        _neonColor(shimmer),
        0.45,
      )!;
      final radius = particle.size * (0.82 + shimmer * 0.42 + frame.highs);

      if (glow > 0) {
        glowPaint.color = color.withValues(alpha: alpha * 0.18 * glow);
        canvas.drawCircle(location, radius * (2.4 + glow), glowPaint);
      }
      paint.color = color.withValues(alpha: alpha);
      canvas.drawCircle(location, radius, paint);
    }
  }

  void _paintWaveSkin(
    Canvas canvas,
    Offset center,
    double ringRadius,
    double phase,
  ) {
    final frame = controller.frame;
    final values = frame.values;
    if (values.isEmpty) {
      return;
    }

    final path = Path();
    for (var index = 0; index <= values.length; index++) {
      final value = values[index % values.length];
      final t = index / values.length;
      final angle = t * math.pi * 2 - math.pi / 2;
      final ripple = math.sin(angle * 6 + phase * 1.4) * frame.mids * 7;
      final radius =
          ringRadius + 18 + value * 76 + frame.beatPulse * 18 + ripple;
      final point = center + Offset(math.cos(angle), math.sin(angle)) * radius;
      if (index == 0) {
        path.moveTo(point.dx, point.dy);
      } else {
        path.lineTo(point.dx, point.dy);
      }
    }
    path.close();

    final fill = Paint()
      ..style = PaintingStyle.fill
      ..color = FumicTheme.accent.withValues(
        alpha: 0.035 + frame.energy * 0.035,
      );
    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.4
      ..strokeJoin = StrokeJoin.round
      ..strokeCap = StrokeCap.round
      ..color = Colors.white.withValues(alpha: 0.22 + frame.beatPulse * 0.18);
    canvas.drawPath(path, fill);
    canvas.drawPath(path, stroke);
  }

  void _paintCircularBars(
    Canvas canvas,
    Offset center,
    double ringRadius,
    double phase,
  ) {
    final settings = controller.settings;
    final frame = controller.frame;
    final values = frame.values;
    if (values.isEmpty) {
      return;
    }

    final paint = Paint()..strokeCap = StrokeCap.round;
    final intensity = settings.intensity.scale;
    final activity = (frame.energy * 8).clamp(0.0, 1.0).toDouble();
    for (var index = 0; index < values.length; index++) {
      final t = index / values.length;
      final angle = t * math.pi * 2 - math.pi / 2;
      final value = values[index];
      final waveLift = math.sin(phase * 2.2 + index * 0.19) * 0.5 + 0.5;
      final length =
          20 * activity +
          value * (88 * intensity) +
          frame.bass * 20 +
          frame.beatPulse * 24 +
          waveLift * frame.highs * 14;
      final direction = Offset(math.cos(angle), math.sin(angle));
      final start = center + direction * (ringRadius + 14);
      final end = center + direction * (ringRadius + 14 + length);
      final color = Color.lerp(
        _neonColor(t),
        colors.length > 2 ? colors[2] : FumicTheme.brand,
        0.20 + frame.mids * 0.18,
      )!;
      paint
        ..strokeWidth = (2.8 + value * 2.2 + frame.beatPulse * 1.5) * activity
        ..color = color.withValues(
          alpha: (0.64 + frame.energy * 0.28) * activity,
        );
      if (activity <= 0.01) {
        continue;
      }
      canvas.drawLine(start, end, paint);

      if (index.isEven) {
        paint
          ..strokeWidth = 1.4
          ..color = Colors.white.withValues(alpha: 0.12 + value * 0.18);
        canvas.drawLine(
          center + direction * (ringRadius - 3),
          center + direction * (ringRadius + 5 + value * 9),
          paint,
        );
      }
    }
  }

  void _paintAccentArcs(
    Canvas canvas,
    Offset center,
    double artRadius,
    double ringRadius,
    double phase,
  ) {
    final frame = controller.frame;
    final whiteRing = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6
      ..color = Colors.white.withValues(alpha: 0.34 + frame.energy * 0.18);
    canvas.drawCircle(center, artRadius + 20 + frame.bass * 8, whiteRing);
    canvas.drawCircle(center, ringRadius + 7, whiteRing..strokeWidth = 1.0);

    final arcPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 3.0 + frame.beatPulse * 2.0;
    for (var index = 0; index < 4; index++) {
      arcPaint.color = _neonColor(
        index / 4,
      ).withValues(alpha: 0.48 + frame.beatPulse * 0.28);
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: ringRadius + 20 + index * 3),
        phase * (0.8 + index * 0.08) + index * math.pi * 0.55,
        0.44 + frame.mids * 0.34,
        false,
        arcPaint,
      );
    }
  }

  void _paintCenterHalo(
    Canvas canvas,
    Offset center,
    double artRadius,
    Color accent,
    double glow,
  ) {
    final frame = controller.frame;
    final halo = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 16 + frame.beatPulse * 13
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 18)
      ..color = accent.withValues(alpha: (0.08 + frame.bass * 0.12) * glow);
    canvas.drawCircle(center, artRadius + 14 + frame.beatPulse * 9, halo);
  }

  void _paintDisabledShell(
    Canvas canvas,
    Offset center,
    double artRadius,
    double ringRadius,
  ) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 2
      ..color = Colors.white.withValues(alpha: 0.16);
    canvas.drawCircle(center, artRadius + 20, paint);
    paint
      ..strokeWidth = 1.4
      ..color = FumicTheme.muted.withValues(alpha: 0.20);
    canvas.drawCircle(center, ringRadius + 26, paint);
  }

  Color _neonColor(double t) {
    final normalized = t % 1.0;
    if (normalized < 0.34) {
      return Color.lerp(
        const Color(0xFF21F6E8),
        const Color(0xFFFFD95C),
        normalized / 0.34,
      )!;
    }
    if (normalized < 0.68) {
      return Color.lerp(
        const Color(0xFFFFD95C),
        const Color(0xFFFF42D6),
        (normalized - 0.34) / 0.34,
      )!;
    }
    return Color.lerp(
      const Color(0xFFFF42D6),
      const Color(0xFF4A7DFF),
      (normalized - 0.68) / 0.32,
    )!;
  }

  @override
  bool shouldRepaint(covariant TrapVisualizerPainter oldDelegate) {
    return oldDelegate.controller != controller || oldDelegate.colors != colors;
  }
}
