import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/media_item.dart';
import '../models/visualizer_settings.dart';
import '../services/audio_analysis_service.dart';
import '../services/playback_service.dart';
import '../theme/fumic_theme.dart';
import 'shared.dart';

class TrapNationVisualizer extends StatefulWidget {
  const TrapNationVisualizer({
    super.key,
    required this.item,
    required this.playback,
    required this.settings,
  });

  final MediaItem item;
  final PlaybackSnapshot playback;
  final VisualizerSettings settings;

  @override
  State<TrapNationVisualizer> createState() => _TrapNationVisualizerState();
}

class _TrapNationVisualizerState extends State<TrapNationVisualizer>
    with SingleTickerProviderStateMixin {
  static const _stylisticSignalGain = 1.95;
  static const _stylisticBeatGain = 2.35;
  static const _performanceSignalGain = 1.45;

  late final AnimationController _animation;
  late math.Random _random;

  AudioAnalysisTimeline _timeline = const AudioAnalysisTimeline.unavailable();
  VisualizerAudioSignal _displaySignal = const VisualizerAudioSignal.silence();
  Duration _positionAnchor = Duration.zero;
  DateTime _positionAnchorTime = DateTime.now();
  DateTime? _lastFrameTime;
  List<VisualizerParticle> _particles = const [];
  int _analysisGeneration = 0;

  bool get _active => widget.playback.playing && widget.settings.enabled;

  @override
  void initState() {
    super.initState();
    _animation = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _random = math.Random(widget.item.path.hashCode);
    _positionAnchor = widget.playback.position;
    _configureParticles();
    _loadAnalysis();
    _syncAnimation();
  }

  @override
  void didUpdateWidget(covariant TrapNationVisualizer oldWidget) {
    super.didUpdateWidget(oldWidget);
    final itemChanged = oldWidget.item.path != widget.item.path;
    if (itemChanged) {
      _timeline = const AudioAnalysisTimeline.unavailable();
      _displaySignal = const VisualizerAudioSignal.silence();
      _random = math.Random(widget.item.path.hashCode);
      _configureParticles();
      _loadAnalysis();
    } else if (oldWidget.settings.particles != widget.settings.particles ||
        oldWidget.settings.performanceMode != widget.settings.performanceMode) {
      _configureParticles();
    }

    if (itemChanged ||
        oldWidget.playback.position != widget.playback.position ||
        oldWidget.playback.playing != widget.playback.playing ||
        oldWidget.playback.speed != widget.playback.speed) {
      _positionAnchor = widget.playback.position;
      _positionAnchorTime = DateTime.now();
    }
    _syncAnimation();
  }

  @override
  void dispose() {
    _analysisGeneration++;
    _animation.dispose();
    super.dispose();
  }

  void _syncAnimation() {
    if (_active) {
      if (!_animation.isAnimating) {
        _animation.repeat();
      }
    } else {
      _animation.stop();
      _lastFrameTime = null;
    }
  }

  void _configureParticles() {
    if (!widget.settings.particles || widget.settings.performanceMode) {
      _particles = const [];
      return;
    }
    final count = 88;
    _particles = [
      for (var index = 0; index < count; index++)
        VisualizerParticle.seed(_random, index),
    ];
  }

  void _loadAnalysis() {
    final generation = ++_analysisGeneration;
    AudioAnalysisService.instance.analyze(widget.item).then((timeline) {
      if (!mounted || generation != _analysisGeneration) {
        return;
      }
      setState(() {
        _timeline = timeline;
      });
      _syncAnimation();
    });
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 620,
      height: 620,
      child: RepaintBoundary(
        child: AnimatedBuilder(
          animation: _animation,
          builder: (context, _) {
            final now = DateTime.now();
            final deltaSeconds = _lastFrameTime == null
                ? 1 / 60
                : now.difference(_lastFrameTime!).inMicroseconds / 1000000;
            _lastFrameTime = now;

            final useStylistic =
                widget.settings.enabled &&
                !widget.settings.performanceMode &&
                _timeline.available;
            final target = useStylistic
                ? _maxStrengthSignal(
                    _timeline.sample(_extrapolatedPosition(now)),
                  )
                : _performanceSignal();
            _displaySignal = VisualizerAudioSignal.lerp(
              _displaySignal,
              target,
              _active ? 0.34 : 0.08,
            );

            return Stack(
              alignment: Alignment.center,
              children: [
                CustomPaint(
                  size: const Size.square(620),
                  painter: VisualizerPainter(
                    colors: widget.item.colors,
                    signal: _displaySignal,
                    phase: _animation.value,
                    active: _active,
                    stylistic: useStylistic,
                    particles: _particles,
                    deltaSeconds: deltaSeconds.clamp(0.0, 0.05).toDouble(),
                  ),
                ),
                _ArtworkDisc(item: widget.item, settings: widget.settings),
              ],
            );
          },
        ),
      ),
    );
  }

  Duration _extrapolatedPosition(DateTime now) {
    if (!widget.playback.playing) {
      return widget.playback.position;
    }
    final elapsed = now.difference(_positionAnchorTime).inMilliseconds;
    final projected =
        _positionAnchor.inMilliseconds +
        (elapsed * widget.playback.speed).round();
    final duration = widget.playback.duration;
    if (duration > Duration.zero) {
      return Duration(
        milliseconds: projected.clamp(0, duration.inMilliseconds).toInt(),
      );
    }
    return Duration(milliseconds: math.max(0, projected));
  }

  VisualizerAudioSignal _performanceSignal() {
    final volume = widget.playback.volume.clamp(0.0, 1.0).toDouble();
    final motion = _active ? 1.0 : 0.0;
    final phase = _animation.value * math.pi * 2;
    final pulse =
        (0.34 + math.sin(phase * 1.3) * 0.08) *
        volume *
        motion *
        _performanceSignalGain;
    return VisualizerAudioSignal(
      bassEnergy: pulse.clamp(0.0, 1.0).toDouble(),
      midEnergy: (pulse * 0.82).clamp(0.0, 1.0).toDouble(),
      highEnergy: (pulse * 0.58).clamp(0.0, 1.0).toDouble(),
      overallAmplitude: pulse.clamp(0.0, 1.0).toDouble(),
      smoothedAmplitude: pulse.clamp(0.0, 1.0).toDouble(),
      beatPulse: (pulse * 0.56).clamp(0.0, 1.0).toDouble(),
    );
  }

  VisualizerAudioSignal _maxStrengthSignal(VisualizerAudioSignal signal) {
    final overall = (signal.overallAmplitude * _stylisticSignalGain).clamp(
      0.0,
      1.0,
    );
    return signal.copyWith(
      bassEnergy: (signal.bassEnergy * 2.15).clamp(0.0, 1.0).toDouble(),
      midEnergy: (signal.midEnergy * 1.95).clamp(0.0, 1.0).toDouble(),
      highEnergy: (signal.highEnergy * 1.85).clamp(0.0, 1.0).toDouble(),
      overallAmplitude: overall.toDouble(),
      smoothedAmplitude: (signal.smoothedAmplitude * _stylisticSignalGain)
          .clamp(0.0, 1.0)
          .toDouble(),
      beatPulse: (signal.beatPulse * _stylisticBeatGain + overall * 0.18)
          .clamp(0.0, 1.0)
          .toDouble(),
    );
  }
}

class VisualizerPainter extends CustomPainter {
  VisualizerPainter({
    required this.colors,
    required this.signal,
    required this.phase,
    required this.active,
    required this.stylistic,
    required this.particles,
    required this.deltaSeconds,
  });

  final List<Color> colors;
  final VisualizerAudioSignal signal;
  final double phase;
  final bool active;
  final bool stylistic;
  final List<VisualizerParticle> particles;
  final double deltaSeconds;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final minSide = math.min(size.width, size.height);
    final baseRadius = minSide * 0.205;
    final accent = colors.length > 1 ? colors[1] : FumicTheme.accent;
    final phaseRadians = phase * math.pi * 2;

    if (stylistic) {
      _paintParticles(canvas, size, center, accent);
      _paintGlow(canvas, center, baseRadius, accent);
      _paintReactiveRing(canvas, center, baseRadius, accent, phaseRadians);
      _paintRadialBars(canvas, center, baseRadius, accent, phaseRadians);
    } else {
      _paintPerformanceRing(canvas, center, baseRadius, accent, phaseRadians);
    }
  }

  void _paintParticles(Canvas canvas, Size size, Offset center, Color accent) {
    if (particles.isEmpty) {
      return;
    }
    final paint = Paint()..style = PaintingStyle.fill;
    final speed =
        0.28 + signal.smoothedAmplitude * 1.75 + signal.beatPulse * 2.25;
    final brightness = 0.34 + signal.smoothedAmplitude * 0.52;
    final minSide = math.min(size.width, size.height);

    for (final particle in particles) {
      particle.angle += particle.drift * deltaSeconds * speed;
      particle.position += particle.velocity * deltaSeconds * speed;
      if (particle.position.dx.abs() > 1.18) {
        particle.velocity = Offset(-particle.velocity.dx, particle.velocity.dy);
      }
      if (particle.position.dy.abs() > 1.18) {
        particle.velocity = Offset(particle.velocity.dx, -particle.velocity.dy);
      }

      final orbital = Offset(
        math.cos(particle.angle),
        math.sin(particle.angle),
      );
      final location =
          center +
          orbital * (minSide * particle.distance) +
          particle.position * (minSide * 0.055);
      final color = Color.lerp(colors.first, accent, particle.colorMix)!;
      paint.color = color.withValues(
        alpha: (particle.opacity + signal.beatPulse * 0.38).clamp(0.0, 0.88),
      );
      canvas.drawCircle(
        location,
        particle.size * (1 + signal.beatPulse * 1.08 + brightness * 0.34),
        paint,
      );
    }
  }

  void _paintGlow(Canvas canvas, Offset center, double radius, Color accent) {
    final glow = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 20 + signal.bassEnergy * 24
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 22)
      ..color = accent.withValues(
        alpha: 0.14 + signal.smoothedAmplitude * 0.22,
      );
    canvas.drawCircle(center, radius + 37 + signal.beatPulse * 24, glow);
  }

  void _paintReactiveRing(
    Canvas canvas,
    Offset center,
    double radius,
    Color accent,
    double phaseRadians,
  ) {
    const points = 192;
    final path = Path();
    for (var index = 0; index <= points; index++) {
      final t = index / points;
      final angle = t * math.pi * 2 - math.pi / 2;
      final bass =
          math.sin(angle * 3 + phaseRadians * 0.85) * signal.bassEnergy;
      final mids = math.sin(angle * 9 - phaseRadians * 1.2) * signal.midEnergy;
      final highs =
          math.sin(angle * 23 + phaseRadians * 2.2) * signal.highEnergy;
      final pulse =
          signal.bassEnergy * 54 +
          signal.midEnergy * 30 +
          signal.highEnergy * 18 +
          signal.beatPulse * 46;
      final offset = (pulse + bass * 34 + mids * 22 + highs * 16).clamp(
        0.0,
        136.0,
      );
      final point =
          center + Offset(math.cos(angle), math.sin(angle)) * (radius + offset);
      if (index == 0) {
        path.moveTo(point.dx, point.dy);
      } else {
        path.lineTo(point.dx, point.dy);
      }
    }
    path.close();

    final fill = Paint()
      ..style = PaintingStyle.fill
      ..color = accent.withValues(
        alpha: 0.05 + signal.smoothedAmplitude * 0.08,
      );
    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.4
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..color = accent.withValues(alpha: 0.76 + signal.beatPulse * 0.24);
    canvas.drawPath(path, fill);
    canvas.drawPath(path, stroke);

    final inner = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..color = Colors.white.withValues(alpha: 0.22);
    canvas.drawCircle(center, radius + 8 + signal.bassEnergy * 16, inner);
  }

  void _paintRadialBars(
    Canvas canvas,
    Offset center,
    double radius,
    Color accent,
    double phaseRadians,
  ) {
    const bars = 132;
    for (var index = 0; index < bars; index++) {
      final t = index / bars;
      final angle = t * math.pi * 2 - math.pi / 2;
      final bass =
          (math.sin(t * math.pi * 8 + phaseRadians) * 0.5 + 0.5) *
          signal.bassEnergy;
      final mids =
          (math.sin(t * math.pi * 28 - phaseRadians * 1.6) * 0.5 + 0.5) *
          signal.midEnergy;
      final highs =
          (math.sin(t * math.pi * 56 + phaseRadians * 2.4) * 0.5 + 0.5) *
          signal.highEnergy;
      final length = 20 + bass * 92 + mids * 56 + highs * 44;
      final color = Color.lerp(colors.first, accent, t)!;
      final paint = Paint()
        ..strokeWidth = 2.8 + signal.beatPulse * 2.5
        ..strokeCap = StrokeCap.round
        ..color = color.withValues(
          alpha: 0.54 + signal.smoothedAmplitude * 0.42,
        );
      final direction = Offset(math.cos(angle), math.sin(angle));
      canvas.drawLine(
        center + direction * (radius + 58),
        center + direction * (radius + 58 + length),
        paint,
      );
    }
  }

  void _paintPerformanceRing(
    Canvas canvas,
    Offset center,
    double radius,
    Color accent,
    double phaseRadians,
  ) {
    const bars = 52;
    for (var index = 0; index < bars; index++) {
      final t = index / bars;
      final angle = -math.pi * 1.12 + t * math.pi * 2.24;
      final wave = math.sin(phaseRadians + index * 0.48);
      final length =
          20 +
          (active
              ? wave.abs() *
                    (36 * signal.smoothedAmplitude + 18 * signal.beatPulse)
              : 0);
      final direction = Offset(math.cos(angle), math.sin(angle));
      final paint = Paint()
        ..strokeWidth = 5
        ..strokeCap = StrokeCap.square
        ..color = Color.lerp(
          FumicTheme.accent,
          accent,
          t,
        )!.withValues(alpha: active ? 0.72 : 0.24);
      canvas.drawLine(
        center + direction * (radius + 38),
        center + direction * (radius + 38 + length),
        paint,
      );
    }

    final ring = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..color = accent.withValues(alpha: active ? 0.42 : 0.20);
    canvas.drawCircle(center, radius + 18, ring);
  }

  @override
  bool shouldRepaint(covariant VisualizerPainter oldDelegate) {
    return oldDelegate.colors != colors ||
        oldDelegate.signal != signal ||
        oldDelegate.phase != phase ||
        oldDelegate.active != active ||
        oldDelegate.stylistic != stylistic ||
        oldDelegate.particles != particles ||
        oldDelegate.deltaSeconds != deltaSeconds;
  }
}

class VisualizerParticle {
  VisualizerParticle({
    required this.position,
    required this.velocity,
    required this.size,
    required this.opacity,
    required this.drift,
    required this.angle,
    required this.distance,
    required this.colorMix,
  });

  factory VisualizerParticle.seed(math.Random random, int index) {
    final angle = random.nextDouble() * math.pi * 2;
    return VisualizerParticle(
      position: Offset(
        random.nextDouble() * 2 - 1,
        random.nextDouble() * 2 - 1,
      ),
      velocity: Offset(
        (random.nextDouble() - 0.5) * 0.20,
        (random.nextDouble() - 0.5) * 0.20,
      ),
      size: 1.3 + random.nextDouble() * 3.2,
      opacity: 0.16 + random.nextDouble() * 0.28,
      drift: (index.isEven ? 1 : -1) * (0.22 + random.nextDouble() * 0.50),
      angle: angle,
      distance: 0.32 + random.nextDouble() * 0.40,
      colorMix: random.nextDouble(),
    );
  }

  Offset position;
  Offset velocity;
  double size;
  double opacity;
  double drift;
  double angle;
  double distance;
  double colorMix;
}

class _ArtworkDisc extends StatelessWidget {
  const _ArtworkDisc({required this.item, required this.settings});

  final MediaItem item;
  final VisualizerSettings settings;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 232,
      height: 232,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: const Color(0xFF101822),
        border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
        boxShadow: [
          BoxShadow(
            color: item.colors.first.withValues(alpha: 0.38),
            blurRadius: 54,
          ),
          BoxShadow(
            color: FumicTheme.accent.withValues(alpha: 0.12),
            blurRadius: 28,
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: settings.showArtwork
          ? _ArtworkImage(item: item)
          : _ArtworkFallback(item: item),
    );
  }
}

class _ArtworkImage extends StatelessWidget {
  const _ArtworkImage({required this.item});

  final MediaItem item;

  @override
  Widget build(BuildContext context) {
    final thumbnailPath = item.thumbnailPath;
    if (thumbnailPath == null) {
      return _ArtworkFallback(item: item);
    }
    return Image.file(
      File(thumbnailPath),
      width: 232,
      height: 232,
      fit: BoxFit.cover,
      filterQuality: FilterQuality.medium,
      gaplessPlayback: true,
      errorBuilder: (context, error, stackTrace) =>
          _ArtworkFallback(item: item),
    );
  }
}

class _ArtworkFallback extends StatelessWidget {
  const _ArtworkFallback({required this.item});

  final MediaItem item;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: item.colors,
        ),
      ),
      child: Center(
        child: Icon(
          kindIcon(item),
          size: 82,
          color: Colors.white.withValues(alpha: 0.86),
        ),
      ),
    );
  }
}
