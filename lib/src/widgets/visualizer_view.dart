import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:media_kit_video/media_kit_video.dart';

import '../../features/visualizer/trap_visualizer_view.dart';
import '../models/media_item.dart';
import '../models/media_kind.dart';
import '../models/visualizer_settings.dart';
import '../services/playback_service.dart';
import '../theme/fumic_theme.dart';
import 'shared.dart';
import 'wallpaper_image.dart';
import 'full_player_surface.dart';

class VisualizerView extends StatelessWidget {
  const VisualizerView({
    super.key,
    required this.item,
    required this.playback,
    required this.playbackProgress,
    required this.videoController,
    required this.settings,
    required this.onBackToLibrary,
    this.activity,
    required this.onPlayPause,
    required this.onNext,
    required this.onPrevious,
    required this.onLoop,
    required this.onShuffle,
    required this.onMute,
    required this.onSpeedChanged,
    required this.onSeekFraction,
  });

  final MediaItem item;
  final PlaybackSnapshot playback;
  final ValueNotifier<PlaybackSnapshot> playbackProgress;
  final VideoController? videoController;
  final VisualizerSettings settings;
  final VoidCallback onBackToLibrary;
  final Listenable? activity;
  final VoidCallback onPlayPause;
  final VoidCallback onNext;
  final VoidCallback onPrevious;
  final VoidCallback onLoop;
  final VoidCallback onShuffle;
  final VoidCallback onMute;
  final ValueChanged<double> onSpeedChanged;
  final ValueChanged<double> onSeekFraction;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 808;
        return FullPlayerSurface(
          settings: settings,
          activity: activity,
          controlsBackdrop: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withValues(
                    alpha: item.kind == MediaKind.video ? 0.08 : 0.12,
                  ),
                  Colors.black.withValues(
                    alpha: item.kind == MediaKind.video ? 0.18 : 0.35,
                  ),
                  Colors.black.withValues(alpha: 0.72),
                ],
              ),
            ),
          ),
          content: Stack(
            children: [
              Positioned.fill(
                child: RepaintBoundary(
                  child: _Background(
                    item: item,
                    controller: videoController,
                    settings: settings,
                  ),
                ),
              ),
              if (item.kind == MediaKind.audio && settings.enabled)
                Positioned.fill(
                  top: 32,
                  bottom: compact ? 250 : 208,
                  child: Center(
                    child: TrapVisualizerView(
                      item: item,
                      playback: playback,
                      settings: settings,
                    ),
                  ),
                ),
            ],
          ),
          controls: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1120),
              child: ValueListenableBuilder<PlaybackSnapshot>(
                valueListenable: playbackProgress,
                builder: (context, progress, _) => RepaintBoundary(
                  child: _FullPlayerControls(
                    item: item,
                    playback: progress,
                    onPlayPause: onPlayPause,
                    onNext: onNext,
                    onPrevious: onPrevious,
                    onLoop: onLoop,
                    onShuffle: onShuffle,
                    onMute: onMute,
                    onSpeedChanged: onSpeedChanged,
                    onSeekFraction: onSeekFraction,
                    onBackToLibrary: onBackToLibrary,
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _Background extends StatelessWidget {
  const _Background({
    required this.item,
    required this.controller,
    required this.settings,
  });

  final MediaItem item;
  final VideoController? controller;
  final VisualizerSettings settings;

  @override
  Widget build(BuildContext context) {
    if (item.kind == MediaKind.video && controller != null) {
      return ColoredBox(
        color: Colors.black,
        child: Video(
          controller: controller!,
          fit: BoxFit.contain,
          controls: null,
        ),
      );
    }

    return Stack(
      fit: StackFit.expand,
      children: [
        if (settings.showBackgroundImage)
          WallpaperImage(settings: settings)
        else
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: item.colors,
              ),
            ),
          ),
        Positioned.fill(
          child: ColoredBox(
            color: FumicTheme.background.withValues(
              alpha: settings.effectiveBackgroundOpacity,
            ),
          ),
        ),
        if (settings.enabled && settings.backgroundMotion)
          CustomPaint(painter: _VisualizerBackgroundPainter(item.colors)),
      ],
    );
  }
}

class _FullPlayerControls extends StatelessWidget {
  const _FullPlayerControls({
    required this.item,
    required this.playback,
    required this.onPlayPause,
    required this.onNext,
    required this.onPrevious,
    required this.onLoop,
    required this.onShuffle,
    required this.onMute,
    required this.onSpeedChanged,
    required this.onSeekFraction,
    required this.onBackToLibrary,
  });

  final MediaItem item;
  final PlaybackSnapshot playback;
  final VoidCallback onPlayPause;
  final VoidCallback onNext;
  final VoidCallback onPrevious;
  final VoidCallback onLoop;
  final VoidCallback onShuffle;
  final VoidCallback onMute;
  final ValueChanged<double> onSpeedChanged;
  final ValueChanged<double> onSeekFraction;
  final VoidCallback onBackToLibrary;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 760;
        final transport = PlaybackTransport(
          playback: playback,
          onPlayPause: onPlayPause,
          onPrevious: onPrevious,
          onNext: onNext,
          onLoop: onLoop,
          onShuffle: onShuffle,
          large: true,
        );
        final utilities = Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            PlaybackSpeedControl(
              speed: playback.speed,
              onChanged: onSpeedChanged,
              compact: true,
            ),
            const SizedBox(width: 12),
            PlaybackMuteButton(volume: playback.volume, onTap: onMute),
            const SizedBox(width: 12),
            RoundIconButton(
              icon: Icons.grid_view_rounded,
              tooltip: 'Back to library (F / E / Esc)',
              onTap: onBackToLibrary,
            ),
          ],
        );
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 840),
              child: Text(
                item.title.replaceAll('_', ' '),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: compact ? 18 : 20,
                  fontWeight: FontWeight.w600,
                  letterSpacing: -0.3,
                ),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              item.artist.isEmpty
                  ? (item.kind == MediaKind.audio ? 'Audio' : 'Video')
                  : item.artist,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: const TextStyle(color: FumicTheme.muted, fontSize: 13),
            ),
            const SizedBox(height: 14),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 840),
              child: Row(
                children: [
                  SizedBox(
                    width: 56,
                    child: Text(
                      formatDuration(playback.position),
                      maxLines: 1,
                      style: const TextStyle(
                        fontSize: 12,
                        color: FumicTheme.muted,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ProgressTrack(
                      position: playback.position,
                      duration: playback.duration,
                      buffered: playback.buffered,
                      onSeekFraction: onSeekFraction,
                    ),
                  ),
                  const SizedBox(width: 12),
                  SizedBox(
                    width: 56,
                    child: Text(
                      playback.duration > Duration.zero
                          ? formatDuration(playback.duration)
                          : item.durationLabel,
                      maxLines: 1,
                      textAlign: TextAlign.right,
                      style: const TextStyle(
                        fontSize: 12,
                        color: FumicTheme.muted,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            if (compact) ...[
              transport,
              const SizedBox(height: 12),
              utilities,
            ] else
              SizedBox(
                height: 56,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Align(alignment: Alignment.center, child: transport),
                    Align(alignment: Alignment.centerRight, child: utilities),
                  ],
                ),
              ),
          ],
        );
      },
    );
  }
}

class _VisualizerBackgroundPainter extends CustomPainter {
  const _VisualizerBackgroundPainter(this.colors);

  final List<Color> colors;

  @override
  void paint(Canvas canvas, Size size) {
    final ridgePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..color = Colors.white.withValues(alpha: 0.08);
    for (var i = 0; i < 9; i++) {
      final y = size.height * (0.36 + i * 0.055);
      final path = Path()..moveTo(0, y);
      for (var x = 0.0; x <= size.width; x += 80) {
        path.lineTo(x, y + math.sin((x / 120) + i) * 36);
      }
      canvas.drawPath(path, ridgePaint);
    }

    final dotPaint = Paint()..style = PaintingStyle.fill;
    for (var i = 0; i < 100; i++) {
      final x = (i * 73 % size.width).toDouble();
      final y = (i * 41 % size.height).toDouble();
      dotPaint.color = Color.lerp(
        const Color(0xFFFFD765),
        FumicTheme.accent,
        (i % 7) / 7,
      )!.withValues(alpha: 0.18 + (i % 5) * 0.04);
      canvas.drawCircle(Offset(x, y), 3 + (i % 6).toDouble(), dotPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _VisualizerBackgroundPainter oldDelegate) {
    return oldDelegate.colors != colors;
  }
}
