import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../src/models/media_item.dart';
import '../../src/services/playback_service.dart';
import '../../src/theme/fumic_theme.dart';
import 'trap_visualizer_painter.dart';
import 'visualizer_controller.dart';
import 'visualizer_settings.dart';

class TrapVisualizerView extends StatefulWidget {
  const TrapVisualizerView({
    super.key,
    required this.item,
    required this.playback,
    required this.settings,
  });

  final MediaItem item;
  final PlaybackSnapshot playback;
  final VisualizerSettings settings;

  @override
  State<TrapVisualizerView> createState() => _TrapVisualizerViewState();
}

class _TrapVisualizerViewState extends State<TrapVisualizerView>
    with SingleTickerProviderStateMixin {
  late final TrapVisualizerController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TrapVisualizerController(
      vsync: this,
      settings: widget.settings,
      seed: widget.item.path.hashCode,
      playing: widget.playback.playing,
      volume: widget.playback.volume,
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _controller.update(active: TickerMode.valuesOf(context).enabled);
  }

  @override
  void didUpdateWidget(covariant TrapVisualizerView oldWidget) {
    super.didUpdateWidget(oldWidget);
    _controller.update(
      settings: widget.settings,
      seed: widget.item.path.hashCode,
      playing: widget.playback.playing,
      volume: widget.playback.volume,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.settings.enabled) return const SizedBox.shrink();
    return LayoutBuilder(
      builder: (context, constraints) {
        final maxWidth = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : 760.0;
        final maxHeight = constraints.maxHeight.isFinite
            ? constraints.maxHeight
            : 760.0;
        final rawSide = math.min(maxWidth * 0.78, maxHeight * 0.68);
        final side = math.min(760.0, math.max(280.0, rawSide));
        final discDiameter = math.min(260.0, math.max(172.0, side * 0.34));

        return SizedBox.square(
          dimension: side,
          child: RepaintBoundary(
            child: Stack(
              alignment: Alignment.center,
              children: [
                CustomPaint(
                  size: Size.square(side),
                  painter: TrapVisualizerPainter(
                    controller: _controller,
                    colors: _safeColors(widget.item.colors),
                  ),
                ),
                if (widget.settings.showArtwork)
                  AnimatedBuilder(
                    animation: _controller,
                    child: _CenterDisc(
                      item: widget.item,
                      settings: widget.settings,
                      diameter: discDiameter,
                    ),
                    builder: (context, child) {
                      return Transform.scale(
                        scale: _controller.logoScale,
                        child: child,
                      );
                    },
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  List<Color> _safeColors(List<Color> source) {
    if (source.length >= 2) {
      return source;
    }
    return const [FumicTheme.accent, FumicTheme.brand, Color(0xFF111827)];
  }
}

class TrapNationVisualizer extends StatelessWidget {
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
  Widget build(BuildContext context) {
    return TrapVisualizerView(
      item: item,
      playback: playback,
      settings: settings,
    );
  }
}

class _CenterDisc extends StatelessWidget {
  const _CenterDisc({
    required this.item,
    required this.settings,
    required this.diameter,
  });

  final MediaItem item;
  final VisualizerSettings settings;
  final double diameter;

  @override
  Widget build(BuildContext context) {
    final colors = item.colors.length >= 2
        ? item.colors
        : const [FumicTheme.accent, FumicTheme.brand, Color(0xFF111827)];
    return Container(
      width: diameter,
      height: diameter,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: const Color(0xFF0D121B),
        border: Border.all(color: Colors.white.withValues(alpha: 0.34)),
        boxShadow: [
          BoxShadow(
            color: colors.first.withValues(alpha: 0.42),
            blurRadius: 48,
          ),
          BoxShadow(
            color: FumicTheme.accent.withValues(alpha: 0.20),
            blurRadius: 24,
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: _CenterDiscContent(item: item, settings: settings, colors: colors),
    );
  }
}

class _CenterDiscContent extends StatelessWidget {
  const _CenterDiscContent({
    required this.item,
    required this.settings,
    required this.colors,
  });

  final MediaItem item;
  final VisualizerSettings settings;
  final List<Color> colors;

  @override
  Widget build(BuildContext context) {
    final thumbnailPath = item.thumbnailPath;
    if (settings.showArtwork && thumbnailPath != null) {
      return Image.file(
        File(thumbnailPath),
        fit: BoxFit.cover,
        filterQuality: FilterQuality.medium,
        gaplessPlayback: true,
        cacheWidth: (280 * MediaQuery.devicePixelRatioOf(context)).round(),
        cacheHeight: (280 * MediaQuery.devicePixelRatioOf(context)).round(),
        errorBuilder: (context, error, stackTrace) {
          return _LogoFallback(colors: colors);
        },
      );
    }
    return _LogoFallback(colors: colors);
  }
}

class _LogoFallback extends StatelessWidget {
  const _LogoFallback({required this.colors});

  final List<Color> colors;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: RadialGradient(
          center: const Alignment(-0.25, -0.35),
          radius: 1.05,
          colors: [
            Color.lerp(colors.first, Colors.white, 0.08)!,
            colors.length > 1 ? colors[1] : FumicTheme.brand,
            const Color(0xFF0D121B),
          ],
        ),
      ),
      child: Center(
        child: FractionallySizedBox(
          widthFactor: 0.54,
          heightFactor: 0.54,
          child: Image.asset(
            'icons/fumic_logo_trans.png',
            cacheWidth: 256,
            fit: BoxFit.contain,
            filterQuality: FilterQuality.high,
          ),
        ),
      ),
    );
  }
}
