import 'package:flutter/material.dart';

import '../models/media_item.dart';
import '../models/media_kind.dart';
import '../services/playback_service.dart';
import '../theme/fumic_theme.dart';
import 'shared.dart';

class PlayerBar extends StatelessWidget {
  const PlayerBar({
    super.key,
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
    required this.onFullPlayer,
  });

  final MediaItem? item;
  final PlaybackSnapshot playback;
  final VoidCallback onPlayPause;
  final VoidCallback onNext;
  final VoidCallback onPrevious;
  final VoidCallback onLoop;
  final VoidCallback onShuffle;
  final ValueChanged<double> onVolumeChanged;
  final ValueChanged<double> onSpeedChanged;
  final ValueChanged<double> onSeekFraction;
  final VoidCallback onFullPlayer;

  @override
  Widget build(BuildContext context) {
    final current = item;
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 980;
        return Container(
          height: 112,
          padding: const EdgeInsets.fromLTRB(18, 8, 18, 8),
          decoration: BoxDecoration(
            color: const Color(0xF20E131D),
            border: Border(
              top: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
            ),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  Text(
                    formatDuration(playback.position),
                    style: const TextStyle(color: FumicTheme.muted),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ProgressTrack(
                      position: playback.position,
                      duration: playback.duration,
                      buffered: playback.buffered,
                      onSeekFraction: onSeekFraction,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    playback.duration > Duration.zero
                        ? formatDuration(playback.duration)
                        : current?.durationLabel ?? '0:00',
                    style: const TextStyle(color: FumicTheme.muted),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Flexible(
                    flex: compact ? 3 : 2,
                    child: current == null
                        ? const _NowPlayingPlaceholder()
                        : _NowPlaying(item: current, playback: playback),
                  ),
                  const SizedBox(width: 12),
                  if (!compact) const Spacer(),
                  RoundIconButton(
                    icon: Icons.shuffle_rounded,
                    active: playback.shuffle,
                    tooltip: 'Shuffle',
                    onTap: onShuffle,
                  ),
                  const SizedBox(width: 8),
                  RoundIconButton(
                    icon: Icons.skip_previous_rounded,
                    tooltip: 'Previous',
                    onTap: onPrevious,
                  ),
                  const SizedBox(width: 8),
                  PlayButton(isPlaying: playback.playing, onTap: onPlayPause),
                  const SizedBox(width: 8),
                  RoundIconButton(
                    icon: Icons.skip_next_rounded,
                    tooltip: 'Next',
                    onTap: onNext,
                  ),
                  const SizedBox(width: 8),
                  RoundIconButton(
                    icon: Icons.repeat_rounded,
                    active: playback.loop,
                    tooltip: 'Loop',
                    onTap: onLoop,
                  ),
                  const SizedBox(width: 8),
                  PlaybackSpeedControl(
                    speed: playback.speed,
                    onChanged: onSpeedChanged,
                    compact: compact,
                  ),
                  if (!compact) ...[
                    const Spacer(),
                    const Icon(
                      Icons.volume_up_rounded,
                      color: Color(0xFFB8C0CF),
                    ),
                    SizedBox(
                      width: 150,
                      child: Slider(
                        value: playback.volume.clamp(0, 1),
                        onChanged: onVolumeChanged,
                        activeColor: Colors.white,
                        inactiveColor: Colors.white.withValues(alpha: 0.15),
                      ),
                    ),
                    SizedBox(
                      width: 48,
                      child: Text(
                        '${(playback.volume * 100).round()}%',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(width: 8),
                  RoundIconButton(
                    icon: Icons.fullscreen_rounded,
                    tooltip: 'Full screen player',
                    onTap: onFullPlayer,
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

class _NowPlayingPlaceholder extends StatelessWidget {
  const _NowPlayingPlaceholder();

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 420),
      child: Row(
        children: [
          Container(
            width: 62,
            height: 62,
            decoration: BoxDecoration(
              color: const Color(0xFF151B28),
              borderRadius: BorderRadius.circular(6),
            ),
          ),
          const SizedBox(width: 20),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'None',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
                ),
                SizedBox(height: 8),
                Text(
                  'Select media and press Play.',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: FumicTheme.muted),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _NowPlaying extends StatelessWidget {
  const _NowPlaying({required this.item, required this.playback});

  final MediaItem item;
  final PlaybackSnapshot playback;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 420),
      child: Row(
        children: [
          Artwork(
            colors: item.colors,
            size: 62,
            icon: kindIcon(item),
            thumbnailPath: item.thumbnailPath,
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  item.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '${mediaKindLabel(item.kind)} - '
                  '${playback.duration > Duration.zero ? formatDuration(playback.duration) : item.durationLabel}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: FumicTheme.muted),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
