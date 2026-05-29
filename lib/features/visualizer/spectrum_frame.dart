class SpectrumFrame {
  const SpectrumFrame({
    required this.values,
    required this.bass,
    required this.mids,
    required this.highs,
    required this.energy,
    required this.beatPulse,
    required this.beatDetected,
    required this.timeSeconds,
  });

  factory SpectrumFrame.silence(int bars) {
    return SpectrumFrame(
      values: List<double>.filled(bars, 0, growable: false),
      bass: 0,
      mids: 0,
      highs: 0,
      energy: 0,
      beatPulse: 0,
      beatDetected: false,
      timeSeconds: 0,
    );
  }

  final List<double> values;
  final double bass;
  final double mids;
  final double highs;
  final double energy;
  final double beatPulse;
  final bool beatDetected;
  final double timeSeconds;
}
