import 'package:flutter/foundation.dart';
import 'package:media_kit_video/media_kit_video.dart';

import '../models/media_item.dart';

class PlaybackSnapshot {
  const PlaybackSnapshot({
    this.currentItem,
    this.playing = false,
    this.shuffle = false,
    this.loop = false,
    this.volume = 0.52,
    this.speed = 1.0,
    this.position = Duration.zero,
    this.duration = Duration.zero,
    this.buffered = Duration.zero,
    this.buffering = false,
    this.error,
  });

  final MediaItem? currentItem;
  final bool playing;
  final bool shuffle;
  final bool loop;
  final double volume;
  final double speed;
  final Duration position;
  final Duration duration;
  final Duration buffered;
  final bool buffering;
  final String? error;

  PlaybackSnapshot copyWith({
    MediaItem? currentItem,
    bool clearCurrentItem = false,
    bool? playing,
    bool? shuffle,
    bool? loop,
    double? volume,
    double? speed,
    Duration? position,
    Duration? duration,
    Duration? buffered,
    bool? buffering,
    String? error,
    bool clearError = false,
  }) {
    return PlaybackSnapshot(
      currentItem: clearCurrentItem ? null : currentItem ?? this.currentItem,
      playing: playing ?? this.playing,
      shuffle: shuffle ?? this.shuffle,
      loop: loop ?? this.loop,
      volume: volume ?? this.volume,
      speed: speed ?? this.speed,
      position: position ?? this.position,
      duration: duration ?? this.duration,
      buffered: buffered ?? this.buffered,
      buffering: buffering ?? this.buffering,
      error: clearError ? null : error ?? this.error,
    );
  }
}

abstract class PlaybackService extends ChangeNotifier {
  PlaybackSnapshot get snapshot;

  VideoController? get videoController => null;

  Future<void> openQueue(List<MediaItem> queue, int index, {bool play = true});

  Future<void> togglePlay();
  Future<void> playNext();
  Future<void> playPrevious();
  Future<void> seekRelative(Duration delta);
  Future<void> setVolume(double value);
  Future<void> setSpeed(double value);
  Future<void> setLoop(bool value);
  Future<void> setShuffle(bool value);
  Future<void> setSoundReactiveVisualizer(bool value) async {}
  void updateCurrentItem(MediaItem item) {}
}
