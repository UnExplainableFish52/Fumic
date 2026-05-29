enum VisualizerGlowStrength {
  off('Off', 0.0),
  low('Low', 0.42),
  medium('Medium', 0.74),
  high('High', 1.08);

  const VisualizerGlowStrength(this.label, this.amount);

  final String label;
  final double amount;

  static VisualizerGlowStrength fromJson(Object? value) {
    final name = value?.toString();
    return VisualizerGlowStrength.values.firstWhere(
      (entry) => entry.name == name,
      orElse: () => VisualizerGlowStrength.medium,
    );
  }
}

enum VisualizerIntensity {
  low('Low', 0.72),
  medium('Medium', 1.0),
  high('High', 1.32);

  const VisualizerIntensity(this.label, this.scale);

  final String label;
  final double scale;

  VisualizerIntensity step(int delta) {
    final next = (index + delta).clamp(0, values.length - 1);
    return values[next];
  }

  static VisualizerIntensity fromJson(Object? value) {
    final name = value?.toString();
    return VisualizerIntensity.values.firstWhere(
      (entry) => entry.name == name,
      orElse: () => VisualizerIntensity.medium,
    );
  }
}

enum VisualizerQuality {
  low(
    label: 'Low',
    fps: 30,
    waveformBars: 64,
    particleCount: 40,
    glowStrength: VisualizerGlowStrength.low,
    intensity: VisualizerIntensity.low,
  ),
  medium(
    label: 'Medium',
    fps: 30,
    waveformBars: 96,
    particleCount: 90,
    glowStrength: VisualizerGlowStrength.medium,
    intensity: VisualizerIntensity.medium,
  ),
  high(
    label: 'High',
    fps: 60,
    waveformBars: 128,
    particleCount: 150,
    glowStrength: VisualizerGlowStrength.high,
    intensity: VisualizerIntensity.high,
  );

  const VisualizerQuality({
    required this.label,
    required this.fps,
    required this.waveformBars,
    required this.particleCount,
    required this.glowStrength,
    required this.intensity,
  });

  final String label;
  final int fps;
  final int waveformBars;
  final int particleCount;
  final VisualizerGlowStrength glowStrength;
  final VisualizerIntensity intensity;

  VisualizerQuality get next => values[(index + 1) % values.length];

  static VisualizerQuality fromJson(Object? value) {
    final name = value?.toString();
    return VisualizerQuality.values.firstWhere(
      (entry) => entry.name == name,
      orElse: () => VisualizerQuality.medium,
    );
  }
}
