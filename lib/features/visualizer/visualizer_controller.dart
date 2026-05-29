import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';

import 'fake_spectrum_generator.dart';
import 'particle.dart';
import 'spectrum_frame.dart';
import 'visualizer_settings.dart';

class TrapVisualizerController extends ChangeNotifier {
  TrapVisualizerController({
    required TickerProvider vsync,
    required this.settings,
    required int seed,
    required this.playing,
    required double volume,
  }) : _seed = _safeSeed(seed),
       volume = volume.clamp(0.0, 1.0).toDouble(),
       _generator = FakeSpectrumGenerator(_safeSeed(seed)),
       frame = SpectrumFrame.silence(settings.effectiveWaveformBars) {
    _particleRandom = math.Random(_seed ^ 0x2c57);
    _ticker = vsync.createTicker(_tick);
    _configureParticles();
    _syncTicker();
  }

  late final Ticker _ticker;
  late math.Random _particleRandom;
  final FakeSpectrumGenerator _generator;
  int _seed;
  Duration _lastFrameElapsed = Duration.zero;

  VisualizerSettings settings;
  bool playing;
  double volume;
  SpectrumFrame frame;
  List<VisualizerParticle> particles = const [];

  double get logoScale {
    if (!settings.enabled || !settings.logoPulse) {
      return 1;
    }
    return 1 + frame.bass * 0.045 + frame.beatPulse * 0.055;
  }

  void update({
    VisualizerSettings? settings,
    int? seed,
    bool? playing,
    double? volume,
  }) {
    final oldBars = this.settings.effectiveWaveformBars;
    final oldParticleCount = this.settings.effectiveParticleCount;
    final oldEnabled = this.settings.enabled;

    if (settings != null) {
      this.settings = settings;
    }
    if (playing != null) {
      this.playing = playing;
    }
    if (volume != null) {
      this.volume = volume.clamp(0.0, 1.0).toDouble();
    }
    final nextSeed = seed == null ? _seed : _safeSeed(seed);
    if (nextSeed != _seed) {
      _seed = nextSeed;
      _generator.reset(_seed);
      _particleRandom = math.Random(_seed ^ 0x2c57);
      _configureParticles();
      frame = SpectrumFrame.silence(this.settings.effectiveWaveformBars);
    } else if (oldParticleCount != this.settings.effectiveParticleCount) {
      _configureParticles();
    }

    if (oldBars != this.settings.effectiveWaveformBars) {
      frame = SpectrumFrame.silence(this.settings.effectiveWaveformBars);
    }

    _syncTicker();
    if (oldEnabled != this.settings.enabled || !_ticker.isActive) {
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  void _tick(Duration elapsed) {
    if (!settings.enabled) {
      return;
    }
    final interval = settings.frameInterval;
    if (_lastFrameElapsed != Duration.zero &&
        elapsed - _lastFrameElapsed < interval) {
      return;
    }

    final delta = _lastFrameElapsed == Duration.zero
        ? interval.inMicroseconds / Duration.microsecondsPerSecond
        : (elapsed - _lastFrameElapsed).inMicroseconds /
              Duration.microsecondsPerSecond;
    _lastFrameElapsed = elapsed;

    frame = _generator.nextFrame(
      elapsed: elapsed,
      settings: settings,
      playing: playing,
      volume: volume,
    );
    _advanceParticles(delta.clamp(0.0, 0.08).toDouble());
    notifyListeners();
  }

  void _advanceParticles(double deltaSeconds) {
    if (particles.isEmpty || !settings.enabled) {
      return;
    }
    for (final particle in particles) {
      particle.advance(
        deltaSeconds: deltaSeconds,
        frame: frame,
        settings: settings,
        random: _particleRandom,
      );
    }
  }

  void _configureParticles() {
    final count = settings.effectiveParticleCount;
    if (count <= 0 || !settings.enabled) {
      particles = const [];
      return;
    }
    particles = [
      for (var index = 0; index < count; index++)
        VisualizerParticle.seed(_particleRandom, index),
    ];
  }

  void _syncTicker() {
    if (settings.enabled) {
      if (!_ticker.isActive) {
        _lastFrameElapsed = Duration.zero;
        _ticker.start();
      }
      return;
    }
    if (_ticker.isActive) {
      _ticker.stop();
    }
    _lastFrameElapsed = Duration.zero;
    frame = SpectrumFrame.silence(settings.effectiveWaveformBars);
  }

  static int _safeSeed(int seed) => seed & 0x3fffffff;
}
