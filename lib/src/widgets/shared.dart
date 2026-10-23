import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/media_item.dart';
import '../models/media_kind.dart';
import '../models/playback_speed.dart';
import '../services/playback_service.dart';
import '../theme/fumic_theme.dart';

IconData kindIcon(MediaItem item) {
  return item.kind == MediaKind.audio
      ? Icons.music_note_rounded
      : Icons.movie_rounded;
}

class Artwork extends StatelessWidget {
  const Artwork({
    super.key,
    required this.colors,
    required this.size,
    this.icon,
    this.thumbnailPath,
  });

  final List<Color> colors;
  final double size;
  final IconData? icon;
  final String? thumbnailPath;

  @override
  Widget build(BuildContext context) {
    final fallback = _ArtworkFallback(colors: colors, size: size, icon: icon);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: colors,
        ),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
      ),
      clipBehavior: Clip.antiAlias,
      child: thumbnailPath == null
          ? fallback
          : Image.file(
              File(thumbnailPath!),
              fit: BoxFit.cover,
              width: size,
              height: size,
              cacheWidth: (size * MediaQuery.devicePixelRatioOf(context))
                  .round(),
              cacheHeight: (size * MediaQuery.devicePixelRatioOf(context))
                  .round(),
              filterQuality: FilterQuality.medium,
              gaplessPlayback: true,
              frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
                if (wasSynchronouslyLoaded || frame != null) {
                  return child;
                }
                return fallback;
              },
              errorBuilder: (context, error, stackTrace) {
                return fallback;
              },
            ),
    );
  }
}

class _ArtworkFallback extends StatelessWidget {
  const _ArtworkFallback({
    required this.colors,
    required this.size,
    required this.icon,
  });

  final List<Color> colors;
  final double size;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: colors,
        ),
      ),
      child: icon == null
          ? const SizedBox.expand()
          : Center(
              child: Icon(
                icon,
                color: Colors.white.withValues(alpha: 0.80),
                size: math.max(24, size * 0.34),
              ),
            ),
    );
  }
}

class RoundIconButton extends StatelessWidget {
  const RoundIconButton({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onTap,
    this.active,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  final bool? active;

  @override
  Widget build(BuildContext context) {
    final isActive = active ?? false;
    return Tooltip(
      message: tooltip,
      child: SizedBox(
        width: 40,
        height: 40,
        child: IconButton(
          onPressed: onTap,
          isSelected: active,
          style: IconButton.styleFrom(
            backgroundColor: isActive
                ? const Color(0xD12E625B)
                : const Color(0x99101828),
            foregroundColor: isActive
                ? const Color(0xFFD6FFF6)
                : const Color(0xFFE3E8F2),
            hoverColor: FumicTheme.accent.withValues(alpha: 0.10),
            focusColor: FumicTheme.accent.withValues(alpha: 0.18),
            side: BorderSide(
              color: isActive ? FumicTheme.accent : const Color(0x33FFFFFF),
              width: isActive ? 1.5 : 1,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          icon: Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.center,
            children: [
              Icon(icon, size: 22),
              if (isActive)
                Positioned(
                  bottom: -5,
                  child: Container(
                    width: 3,
                    height: 3,
                    decoration: const BoxDecoration(
                      color: FumicTheme.accent,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class PlayButton extends StatelessWidget {
  const PlayButton({
    super.key,
    required this.isPlaying,
    required this.onTap,
    this.size = 50,
  });

  final bool isPlaying;
  final VoidCallback onTap;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: isPlaying ? 'Pause' : 'Play',
      child: SizedBox(
        width: size,
        height: size,
        child: IconButton.filled(
          style: IconButton.styleFrom(
            backgroundColor: FumicTheme.accent,
            foregroundColor: const Color(0xFF062B30),
            hoverColor: Colors.white.withValues(alpha: 0.18),
            focusColor: Colors.white.withValues(alpha: 0.28),
            shape: const CircleBorder(),
          ),
          onPressed: onTap,
          icon: Icon(
            isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
            size: 30,
          ),
        ),
      ),
    );
  }
}

class PlaybackTransport extends StatelessWidget {
  const PlaybackTransport({
    super.key,
    required this.playback,
    required this.onPlayPause,
    required this.onPrevious,
    required this.onNext,
    required this.onShuffle,
    required this.onLoop,
    this.large = false,
  });

  final PlaybackSnapshot playback;
  final VoidCallback onPlayPause;
  final VoidCallback onPrevious;
  final VoidCallback onNext;
  final VoidCallback onShuffle;
  final VoidCallback onLoop;
  final bool large;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      RoundIconButton(
        icon: Icons.shuffle_rounded,
        tooltip: 'Shuffle',
        active: playback.shuffle,
        onTap: onShuffle,
      ),
      SizedBox(width: large ? 12 : 8),
      RoundIconButton(
        icon: Icons.skip_previous_rounded,
        tooltip: 'Previous',
        onTap: onPrevious,
      ),
      SizedBox(width: large ? 12 : 8),
      PlayButton(
        isPlaying: playback.playing,
        onTap: onPlayPause,
        size: large ? 56 : 48,
      ),
      SizedBox(width: large ? 12 : 8),
      RoundIconButton(
        icon: Icons.skip_next_rounded,
        tooltip: 'Next',
        onTap: onNext,
      ),
      SizedBox(width: large ? 12 : 8),
      RoundIconButton(
        icon: Icons.repeat_rounded,
        tooltip: 'Loop',
        active: playback.loop,
        onTap: onLoop,
      ),
    ],
  );
}

class PlaybackMuteButton extends StatelessWidget {
  const PlaybackMuteButton({
    super.key,
    required this.volume,
    required this.onTap,
  });
  final double volume;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final muted = volume <= 0.001;
    final level = (volume.clamp(0.0, 1.0) * 100).round();
    return SizedBox(
      width: 84,
      height: 40,
      child: IconButton(
        tooltip: muted ? 'Unmute' : 'Mute',
        isSelected: muted,
        iconSize: 20,
        onPressed: onTap,
        icon: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(muted ? Icons.volume_off_rounded : Icons.volume_up_rounded),
            const SizedBox(width: 6),
            SizedBox(
              width: 36,
              child: Text(
                '$level',
                textAlign: TextAlign.center,
                maxLines: 1,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        style: IconButton.styleFrom(
          foregroundColor: muted ? FumicTheme.accent : FumicTheme.text,
          backgroundColor: muted
              ? const Color(0xD12E625B)
              : const Color(0x99101828),
          side: BorderSide(
            color: muted ? FumicTheme.accent : const Color(0x33FFFFFF),
            width: muted ? 1.5 : 1,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }
}

class PlaybackSpeedControl extends StatelessWidget {
  const PlaybackSpeedControl({
    super.key,
    required this.speed,
    required this.onChanged,
    this.compact = false,
  });

  final double speed;
  final ValueChanged<double> onChanged;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final active = (speed - 1.0).abs() > 0.01;
    return PopupMenuButton<double>(
      tooltip: 'Playback speed',
      initialValue: _nearestSpeed(speed),
      onSelected: onChanged,
      position: PopupMenuPosition.over,
      itemBuilder: (context) {
        return [
          for (final option in playbackSpeedOptions)
            PopupMenuItem<double>(
              value: option,
              child: Row(
                children: [
                  Icon(
                    (speed - option).abs() < 0.01
                        ? Icons.check_rounded
                        : Icons.speed_rounded,
                    size: 18,
                    color: (speed - option).abs() < 0.01
                        ? FumicTheme.accent
                        : FumicTheme.muted,
                  ),
                  const SizedBox(width: 10),
                  Text(_formatSpeed(option)),
                ],
              ),
            ),
        ];
      },
      child: Container(
        height: compact ? 34 : 38,
        padding: EdgeInsets.symmetric(horizontal: compact ? 9 : 12),
        decoration: BoxDecoration(
          color: active ? const Color(0xD12E625B) : const Color(0x99101828),
          border: Border.all(
            color: active ? FumicTheme.accent : const Color(0x33FFFFFF),
            width: active ? 1.5 : 1,
          ),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.speed_rounded,
              size: compact ? 15 : 17,
              color: active ? FumicTheme.accent : const Color(0xFFB8C0CF),
            ),
            const SizedBox(width: 6),
            Text(
              _formatSpeed(speed),
              style: TextStyle(
                color: active ? FumicTheme.accent : Colors.white,
                fontSize: compact ? 12 : 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  double _nearestSpeed(double value) {
    return playbackSpeedOptions.reduce((a, b) {
      return (value - a).abs() <= (value - b).abs() ? a : b;
    });
  }

  String _formatSpeed(double value) {
    if ((value - value.round()).abs() < 0.01) {
      return '${value.toStringAsFixed(0)}x';
    }
    if ((value * 10 - (value * 10).round()).abs() < 0.01) {
      return '${value.toStringAsFixed(1)}x';
    }
    return '${value.toStringAsFixed(2)}x';
  }
}

class ProgressTrack extends StatelessWidget {
  const ProgressTrack({
    super.key,
    required this.position,
    required this.duration,
    this.buffered = Duration.zero,
    this.onSeekFraction,
    this.height = 18,
  });

  final Duration position;
  final Duration duration;
  final Duration buffered;
  final ValueChanged<double>? onSeekFraction;
  final double height;

  @override
  Widget build(BuildContext context) {
    final factor = duration.inMilliseconds <= 0
        ? 0.0
        : (position.inMilliseconds / duration.inMilliseconds).clamp(0.0, 1.0);
    final bufferedFactor = duration.inMilliseconds <= 0
        ? 0.0
        : (buffered.inMilliseconds / duration.inMilliseconds).clamp(0.0, 1.0);
    return LayoutBuilder(
      builder: (context, constraints) {
        void seekAt(Offset localPosition) {
          final width = constraints.maxWidth;
          if (width <= 0 || onSeekFraction == null) {
            return;
          }
          onSeekFraction!(
            (localPosition.dx / width).clamp(0.0, 1.0).toDouble(),
          );
        }

        return MouseRegion(
          cursor: onSeekFraction == null
              ? MouseCursor.defer
              : SystemMouseCursors.click,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapDown: onSeekFraction == null
                ? null
                : (details) => seekAt(details.localPosition),
            onHorizontalDragUpdate: onSeekFraction == null
                ? null
                : (details) => seekAt(details.localPosition),
            child: SizedBox(
              height: height,
              child: Stack(
                alignment: Alignment.centerLeft,
                children: [
                  Container(
                    height: 3,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                  FractionallySizedBox(
                    widthFactor: bufferedFactor,
                    child: Container(
                      height: 3,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.22),
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                  ),
                  FractionallySizedBox(
                    widthFactor: factor,
                    child: Container(
                      height: 3,
                      decoration: BoxDecoration(
                        color: FumicTheme.accent,
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                  ),
                  Positioned(
                    left: math.max(
                      0,
                      math.min(
                        constraints.maxWidth - 12,
                        factor * constraints.maxWidth - 6,
                      ),
                    ),
                    child: Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class SectionTitle extends StatelessWidget {
  const SectionTitle(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          text,
          style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 14),
        Divider(color: Colors.white.withValues(alpha: 0.08)),
      ],
    );
  }
}

class SoftBadge extends StatelessWidget {
  const SoftBadge({super.key, required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.045),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: Color(0xFFB8C0CF),
          fontSize: 13,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}
