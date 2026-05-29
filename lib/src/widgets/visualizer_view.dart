import 'dart:io';
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

class VisualizerView extends StatelessWidget {
  const VisualizerView({
    super.key,
    required this.item,
    required this.playback,
    required this.videoController,
    required this.settings,
    required this.onClose,
    required this.onPlayPause,
    required this.onNext,
    required this.onPrevious,
    required this.onLoop,
    required this.onShuffle,
    required this.onVolumeChanged,
    required this.onSpeedChanged,
    required this.onSeekFraction,
  });

  final MediaItem item;
  final PlaybackSnapshot playback;
  final VideoController? videoController;
  final VisualizerSettings settings;
  final VoidCallback onClose;
  final VoidCallback onPlayPause;
  final VoidCallback onNext;
  final VoidCallback onPrevious;
  final VoidCallback onLoop;
  final VoidCallback onShuffle;
  final ValueChanged<double> onVolumeChanged;
  final ValueChanged<double> onSpeedChanged;
  final ValueChanged<double> onSeekFraction;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned.fill(
          child: _Background(
            item: item,
            controller: videoController,
            settings: settings,
          ),
        ),
        Positioned.fill(
          child: DecoratedBox(
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
        ),
        if (item.kind == MediaKind.audio)
          Center(
            child: TrapVisualizerView(
              item: item,
              playback: playback,
              settings: settings,
            ),
          ),
        Positioned(top: 28, right: 30, child: _CloseButton(onTap: onClose)),
        Positioned(
          left: 40,
          right: 40,
          bottom: 34,
          child: _FullPlayerControls(
            item: item,
            playback: playback,
            onPlayPause: onPlayPause,
            onNext: onNext,
            onPrevious: onPrevious,
            onLoop: onLoop,
            onShuffle: onShuffle,
            onVolumeChanged: onVolumeChanged,
            onSpeedChanged: onSpeedChanged,
            onSeekFraction: onSeekFraction,
          ),
        ),
      ],
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
          _PresetBackground(settings: settings)
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
          child: ColoredBox(color: Colors.black.withValues(alpha: 0.50)),
        ),
        if (settings.enabled && settings.backgroundMotion)
          CustomPaint(painter: _VisualizerBackgroundPainter(item.colors)),
      ],
    );
  }
}

class _PresetBackground extends StatelessWidget {
  const _PresetBackground({required this.settings});

  final VisualizerSettings settings;

  @override
  Widget build(BuildContext context) {
    final preset = Image.asset(
      _presetBackgroundFor(settings),
      fit: BoxFit.cover,
      filterQuality: FilterQuality.medium,
    );
    final customPath = settings.customBackgroundPath;
    if (customPath == null) {
      return preset;
    }
    return Image.file(
      File(customPath),
      fit: BoxFit.cover,
      filterQuality: FilterQuality.medium,
      errorBuilder: (context, error, stackTrace) => preset,
    );
  }

  String _presetBackgroundFor(VisualizerSettings settings) {
    final index = settings.backgroundIndex.clamp(0, 5);
    return 'icons/viz_bg${index + 1}.jpg';
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
    required this.onVolumeChanged,
    required this.onSpeedChanged,
    required this.onSeekFraction,
  });

  final MediaItem item;
  final PlaybackSnapshot playback;
  final VoidCallback onPlayPause;
  final VoidCallback onNext;
  final VoidCallback onPrevious;
  final VoidCallback onLoop;
  final VoidCallback onShuffle;
  final ValueChanged<double> onVolumeChanged;
  final ValueChanged<double> onSpeedChanged;
  final ValueChanged<double> onSeekFraction;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          item.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 8),
        Text(
          mediaKindLabel(item.kind),
          style: const TextStyle(color: Color(0xFFB8C0CF), fontSize: 16),
        ),
        const SizedBox(height: 18),
        Row(
          children: [
            Text(formatDuration(playback.position)),
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
            Text(
              playback.duration > Duration.zero
                  ? formatDuration(playback.duration)
                  : item.durationLabel,
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            RoundIconButton(
              icon: Icons.shuffle_rounded,
              active: playback.shuffle,
              tooltip: 'Shuffle',
              onTap: onShuffle,
            ),
            const SizedBox(width: 10),
            RoundIconButton(
              icon: Icons.skip_previous_rounded,
              tooltip: 'Previous',
              onTap: onPrevious,
            ),
            const SizedBox(width: 10),
            PlayButton(isPlaying: playback.playing, onTap: onPlayPause),
            const SizedBox(width: 10),
            RoundIconButton(
              icon: Icons.skip_next_rounded,
              tooltip: 'Next',
              onTap: onNext,
            ),
            const SizedBox(width: 10),
            RoundIconButton(
              icon: Icons.repeat_rounded,
              active: playback.loop,
              tooltip: 'Loop',
              onTap: onLoop,
            ),
            const SizedBox(width: 20),
            PlaybackSpeedControl(
              speed: playback.speed,
              onChanged: onSpeedChanged,
            ),
            const SizedBox(width: 14),
            const Icon(Icons.volume_up_rounded),
            SizedBox(
              width: 140,
              child: Slider(
                value: playback.volume.clamp(0, 1),
                onChanged: onVolumeChanged,
                activeColor: Colors.white,
                inactiveColor: Colors.white.withValues(alpha: 0.24),
              ),
            ),
            Text(
              '${(playback.volume * 100).round()}%',
              style: const TextStyle(fontWeight: FontWeight.w900),
            ),
          ],
        ),
      ],
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

class _CloseButton extends StatelessWidget {
  const _CloseButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 58,
      height: 58,
      child: IconButton(
        tooltip: 'Close player',
        style: IconButton.styleFrom(
          backgroundColor: Colors.black.withValues(alpha: 0.30),
          foregroundColor: Colors.white,
          shape: CircleBorder(
            side: BorderSide(color: Colors.white.withValues(alpha: 0.22)),
          ),
        ),
        onPressed: onTap,
        icon: const Icon(Icons.close_rounded, size: 32),
      ),
    );
  }
}
