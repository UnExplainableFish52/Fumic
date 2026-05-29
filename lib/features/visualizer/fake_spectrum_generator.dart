import 'dart:math' as math;

import 'spectrum_frame.dart';
import 'visualizer_settings.dart';

class FakeSpectrumGenerator {
  FakeSpectrumGenerator(int seed) : _seed = seed {
    _random = math.Random(seed);
  }

  int _seed;
  late math.Random _random;
  var _values = <double>[];
  var _noiseSeeds = <double>[];
  var _bass = 0.0;
  var _mids = 0.0;
  var _highs = 0.0;
  var _energy = 0.0;
  var _beatPulse = 0.0;
  var _lastBeatIndex = -1;
  var _lastElapsedSeconds = 0.0;
  var _timeSeconds = 0.0;

  void reset(int seed) {
    _seed = seed;
    _random = math.Random(seed);
    _values = <double>[];
    _noiseSeeds = <double>[];
    _bass = 0;
    _mids = 0;
    _highs = 0;
    _energy = 0;
    _beatPulse = 0;
    _lastBeatIndex = -1;
    _lastElapsedSeconds = 0;
    _timeSeconds = 0;
  }

  SpectrumFrame nextFrame({
    required Duration elapsed,
    required VisualizerSettings settings,
    required bool playing,
    required double volume,
  }) {
    final bars = settings.effectiveWaveformBars;
    _ensureBars(bars);

    final elapsedSeconds =
        elapsed.inMicroseconds / Duration.microsecondsPerSecond;
    final deltaSeconds = _lastElapsedSeconds == 0
        ? 0.0
        : (elapsedSeconds - _lastElapsedSeconds).clamp(0.0, 0.10).toDouble();
    _lastElapsedSeconds = elapsedSeconds;

    final active = playing && volume > 0.001;
    if (!active) {
      return _decayToSilence(bars);
    }

    _timeSeconds += deltaSeconds;
    final time = _timeSeconds;
    final seedTempoOffset = ((_seed & 0x7f) / 127.0) * 0.12;
    final tempo = 1.82 + seedTempoOffset;
    final beatIndex = (time * tempo).floor();
    final beatProgress = (time * tempo) - beatIndex;
    final beatEnvelope = math
        .pow((1 - beatProgress * 3.85).clamp(0.0, 1.0), 2.7)
        .toDouble();
    final beatDetected = beatIndex != _lastBeatIndex && beatProgress < 0.10;
    if (beatDetected) {
      _lastBeatIndex = beatIndex;
    }

    final dropProgress = (time % 18.0) / 18.0;
    final dropPulse = math
        .pow((1 - (dropProgress - 0.08).abs() * 12).clamp(0.0, 1.0), 2.2)
        .toDouble();
    final playFactor = 0.82 + volume.clamp(0.0, 1.0) * 0.24;
    final intensity = settings.intensity.scale;

    final bassTarget =
        (0.24 +
            math.sin(time * 2.7) * 0.08 +
            beatEnvelope * 0.70 +
            dropPulse * 0.34) *
        playFactor *
        intensity;
    final midsTarget =
        (0.32 +
            math.sin(time * 4.8 + 1.7) * 0.10 +
            beatEnvelope * 0.28 +
            dropPulse * 0.18) *
        playFactor *
        intensity;
    final highsTarget =
        (0.28 +
            math.sin(time * 8.4 + 0.8) * 0.12 +
            beatEnvelope * 0.14 +
            dropPulse * 0.12) *
        playFactor *
        intensity;

    _bass = _lerp(_bass, bassTarget.clamp(0.0, 1.0), 0.22);
    _mids = _lerp(_mids, midsTarget.clamp(0.0, 1.0), 0.18);
    _highs = _lerp(_highs, highsTarget.clamp(0.0, 1.0), 0.15);
    _energy = _lerp(
      _energy,
      ((_bass * 0.46) + (_mids * 0.34) + (_highs * 0.20)).clamp(0.0, 1.0),
      0.24,
    );
    _beatPulse = _lerp(
      _beatPulse,
      (beatEnvelope * 0.85 + dropPulse * 0.45).clamp(0.0, 1.0),
      beatDetected ? 0.58 : 0.20,
    );

    for (var index = 0; index < bars; index++) {
      final t = index / bars;
      final angle = t * math.pi * 2;
      final mirror = 1 - ((t - 0.5).abs() * 2).clamp(0.0, 1.0);
      final wideWave = math.sin(angle * 3.0 + time * 2.1) * 0.5 + 0.5;
      final midWave = math.sin(angle * 9.0 - time * 3.4) * 0.5 + 0.5;
      final highWave = math.sin(angle * 27.0 + time * 6.6) * 0.5 + 0.5;
      final shimmer =
          math.sin(time * (2.2 + (index % 9) * 0.18) + _noiseSeeds[index]) *
              0.5 +
          0.5;
      final stereoBias = 0.76 + math.pow(mirror, 1.4).toDouble() * 0.36;
      final target =
          (_bass * (0.46 + wideWave * 0.72) * stereoBias) +
          (_mids * (0.20 + midWave * 0.46)) +
          (_highs * (0.10 + highWave * 0.30) * shimmer) +
          (_beatPulse * 0.24);
      final smoothing = beatDetected ? 0.32 : 0.18;
      _values[index] = _lerp(_values[index], target.clamp(0.0, 1.0), smoothing);
    }

    return SpectrumFrame(
      values: List<double>.from(_values, growable: false),
      bass: _bass,
      mids: _mids,
      highs: _highs,
      energy: _energy,
      beatPulse: _beatPulse,
      beatDetected: beatDetected,
      timeSeconds: time,
    );
  }

  SpectrumFrame _decayToSilence(int bars) {
    _bass = _lerp(_bass, 0, 0.18);
    _mids = _lerp(_mids, 0, 0.18);
    _highs = _lerp(_highs, 0, 0.18);
    _energy = _lerp(_energy, 0, 0.22);
    _beatPulse = _lerp(_beatPulse, 0, 0.28);
    for (var index = 0; index < bars; index++) {
      _values[index] = _lerp(_values[index], 0, 0.24);
    }
    return SpectrumFrame(
      values: List<double>.from(_values, growable: false),
      bass: _bass,
      mids: _mids,
      highs: _highs,
      energy: _energy,
      beatPulse: _beatPulse,
      beatDetected: false,
      timeSeconds: _timeSeconds,
    );
  }

  void _ensureBars(int bars) {
    if (_values.length == bars && _noiseSeeds.length == bars) {
      return;
    }
    _values = List<double>.filled(bars, 0, growable: false);
    _noiseSeeds = List<double>.generate(
      bars,
      (_) => _random.nextDouble() * math.pi * 2,
      growable: false,
    );
  }

  double _lerp(num a, num b, double t) {
    return a + (b - a) * t;
  }
}
