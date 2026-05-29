import 'dart:math' as math;
import 'dart:ui';

import 'spectrum_frame.dart';
import 'visualizer_settings.dart';

class VisualizerParticle {
  VisualizerParticle({
    required this.angle,
    required this.radius,
    required this.size,
    required this.opacity,
    required this.angularVelocity,
    required this.radialVelocity,
    required this.colorMix,
    required this.shimmerPhase,
  });

  factory VisualizerParticle.seed(math.Random random, int index) {
    return VisualizerParticle(
      angle: random.nextDouble() * math.pi * 2,
      radius: 0.20 + random.nextDouble() * 0.66,
      size: 1.2 + random.nextDouble() * 3.4,
      opacity: 0.16 + random.nextDouble() * 0.36,
      angularVelocity:
          (index.isEven ? 1 : -1) * (0.08 + random.nextDouble() * 0.22),
      radialVelocity: 0.018 + random.nextDouble() * 0.055,
      colorMix: random.nextDouble(),
      shimmerPhase: random.nextDouble() * math.pi * 2,
    );
  }

  double angle;
  double radius;
  double size;
  double opacity;
  double angularVelocity;
  double radialVelocity;
  double colorMix;
  double shimmerPhase;

  Offset resolve(Size size, Offset center) {
    final minSide = math.min(size.width, size.height);
    return center +
        Offset(math.cos(angle), math.sin(angle)) * (minSide * radius * 0.48);
  }

  void advance({
    required double deltaSeconds,
    required SpectrumFrame frame,
    required VisualizerSettings settings,
    required math.Random random,
  }) {
    final speed =
        frame.energy * 0.78 + frame.bass * 0.54 + frame.beatPulse * 1.22;
    angle += angularVelocity * deltaSeconds * speed * settings.intensity.scale;
    radius += radialVelocity * deltaSeconds * speed;
    shimmerPhase += deltaSeconds * (1.2 + frame.highs * 4.2);

    if (radius > 1.08) {
      angle = random.nextDouble() * math.pi * 2;
      radius = 0.18 + random.nextDouble() * 0.18;
      size = 1.2 + random.nextDouble() * 3.4;
      opacity = 0.16 + random.nextDouble() * 0.36;
      angularVelocity =
          (random.nextBool() ? 1 : -1) * (0.08 + random.nextDouble() * 0.22);
      radialVelocity = 0.018 + random.nextDouble() * 0.055;
      colorMix = random.nextDouble();
      shimmerPhase = random.nextDouble() * math.pi * 2;
    }
  }
}
