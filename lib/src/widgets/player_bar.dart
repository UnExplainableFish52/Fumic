import 'dart:math' as math;

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
    required this.onMute,
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
  final VoidCallback onMute;
  final ValueChanged<double> onSpeedChanged;
  final ValueChanged<double> onSeekFraction;
  final VoidCallback onFullPlayer;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 1000;
        final nowPlaying = item == null
            ? const _NowPlayingPlaceholder()
            : _NowPlaying(item: item!, playback: playback);
        final transport = PlaybackTransport(
          playback: playback,
          onPlayPause: onPlayPause,
          onPrevious: onPrevious,
          onNext: onNext,
          onShuffle: onShuffle,
          onLoop: onLoop,
        );
        final progress = Row(
          children: [
            SizedBox(
              width: 52,
              child: Text(
                formatDuration(playback.position),
                maxLines: 1,
                style: const TextStyle(color: FumicTheme.muted, fontSize: 11),
              ),
            ),
            Expanded(
              child: ProgressTrack(
                position: playback.position,
                duration: playback.duration,
                buffered: playback.buffered,
                onSeekFraction: onSeekFraction,
              ),
            ),
            SizedBox(
              width: 52,
              child: Text(
                playback.duration > Duration.zero
                    ? formatDuration(playback.duration)
                    : item?.durationLabel ?? '0:00',
                maxLines: 1,
                textAlign: TextAlign.right,
                style: const TextStyle(color: FumicTheme.muted, fontSize: 11),
              ),
            ),
          ],
        );
        final utilities = Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            PlaybackSpeedControl(
              speed: playback.speed,
              onChanged: onSpeedChanged,
              compact: true,
            ),
            const SizedBox(width: 4),
            PlaybackMuteButton(volume: playback.volume, onTap: onMute),
            const SizedBox(width: 4),
            RoundIconButton(
              icon: Icons.fullscreen_rounded,
              tooltip: 'Full screen player',
              onTap: onFullPlayer,
            ),
          ],
        );
        return Container(
          height: compact ? 150 : 108,
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
          decoration: BoxDecoration(
            color: FumicTheme.cardFill(context),
            border: const Border(top: BorderSide(color: FumicTheme.edge)),
          ),
          child: compact
              ? Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SizedBox(
                      height: 48,
                      child: Row(
                        children: [
                          Expanded(child: nowPlaying),
                          const SizedBox(width: 12),
                          utilities,
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    progress,
                    const SizedBox(height: 4),
                    transport,
                  ],
                )
              : Row(
                  children: [
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(right: 20),
                        child: nowPlaying,
                      ),
                    ),
                    SizedBox(
                      width: math.min(560, constraints.maxWidth * 0.40),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          progress,
                          const SizedBox(height: 8),
                          transport,
                        ],
                      ),
                    ),
                    Expanded(
                      child: Align(
                        alignment: Alignment.centerRight,
                        child: utilities,
                      ),
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
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: const Color(0xFF151B28),
              borderRadius: BorderRadius.circular(6),
            ),
            child: const Icon(
              Icons.music_note_rounded,
              color: FumicTheme.muted,
            ),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'Ready when you are',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                ),
                SizedBox(height: 4),
                Text(
                  'Choose a track or video to get started.',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: FumicTheme.muted, fontSize: 12),
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
            size: 48,
            icon: kindIcon(item),
            thumbnailPath: item.thumbnailPath,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  item.title.replaceAll('_', ' '),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Tooltip(
                  message: playback.error ?? '',
                  child: Text(
                    playback.error != null
                        ? 'Playback failed. Try another file.'
                        : playback.buffering
                        ? 'Loading media…'
                        : '${playback.currentItem?.path == item.path
                                  ? playback.playing
                                        ? "Playing"
                                        : "Paused"
                                  : "Selected"} · '
                              '${mediaKindLabel(item.kind)} · '
                              '${playback.duration > Duration.zero ? formatDuration(playback.duration) : item.durationLabel}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      color: playback.error != null
                          ? const Color(0xFFFFCC80)
                          : FumicTheme.muted,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
