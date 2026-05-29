import 'dart:async';
import 'dart:math' as math;

import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';

import '../models/media_item.dart';
import '../models/playback_speed.dart';
import 'playback_service.dart';

class MediaKitPlaybackService extends PlaybackService {
  MediaKitPlaybackService() {
    _player = Player();
    _videoController = VideoController(_player);
    _subscriptions.addAll([
      _player.stream.playing.listen(
        (value) => _setSnapshot(_snapshot.copyWith(playing: value)),
      ),
      _player.stream.position.listen(
        (value) => _setSnapshot(_snapshot.copyWith(position: value)),
      ),
      _player.stream.duration.listen(
        (value) => _setSnapshot(_snapshot.copyWith(duration: value)),
      ),
      _player.stream.volume.listen(
        (value) => _setSnapshot(_snapshot.copyWith(volume: value / 100)),
      ),
      _player.stream.buffering.listen(
        (value) => _setSnapshot(_snapshot.copyWith(buffering: value)),
      ),
      _player.stream.error.listen(
        (value) => _setSnapshot(_snapshot.copyWith(error: value)),
      ),
      _player.stream.completed.listen((completed) {
        if (completed) {
          unawaited(_handleCompleted());
        }
      }),
    ]);
    unawaited(_player.setVolume(_snapshot.volume * 100));
    unawaited(_applyPlaylistMode());
    unawaited(_player.setShuffle(false));
  }

  late final Player _player;
  late final VideoController _videoController;
  final List<StreamSubscription<Object?>> _subscriptions = [];
  final math.Random _random = math.Random();
  List<MediaItem> _queue = const [];
  List<int> _playbackOrder = const [];
  int _index = -1;
  PlaybackSnapshot _snapshot = const PlaybackSnapshot();

  @override
  PlaybackSnapshot get snapshot => _snapshot;

  @override
  VideoController get videoController => _videoController;

  @override
  Future<void> openQueue(
    List<MediaItem> queue,
    int index, {
    bool play = true,
  }) async {
    if (queue.isEmpty || index < 0 || index >= queue.length) {
      return;
    }
    _queue = List<MediaItem>.from(queue);
    _index = index;
    _rebuildPlaybackOrder(startIndex: index);
    await _openQueueIndex(_index, play: play);
  }

  @override
  Future<void> togglePlay() async {
    if (_snapshot.currentItem == null) {
      return;
    }
    await _player.playOrPause();
  }

  @override
  Future<void> playNext() async {
    if (_queue.isEmpty) {
      return;
    }
    await _advancePlaybackOrder(1);
  }

  @override
  Future<void> playPrevious() async {
    if (_queue.isEmpty) {
      return;
    }
    await _advancePlaybackOrder(-1);
  }

  @override
  Future<void> seekRelative(Duration delta) async {
    final duration = _snapshot.duration;
    var target = _snapshot.position + delta;
    if (target < Duration.zero) {
      target = Duration.zero;
    }
    if (duration > Duration.zero && target > duration) {
      target = duration;
    }
    await _player.seek(target);
  }

  @override
  Future<void> setVolume(double value) async {
    final next = value.clamp(0, 1).toDouble();
    _setSnapshot(_snapshot.copyWith(volume: next));
    await _player.setVolume(next * 100);
  }

  @override
  Future<void> setSpeed(double value) async {
    final next = value.clamp(minPlaybackSpeed, maxPlaybackSpeed).toDouble();
    _setSnapshot(_snapshot.copyWith(speed: next));
    await _player.setRate(next);
  }

  @override
  Future<void> setLoop(bool value) async {
    _setSnapshot(_snapshot.copyWith(loop: value));
    await _applyPlaylistMode();
  }

  @override
  Future<void> setShuffle(bool value) async {
    if (_snapshot.shuffle == value) {
      return;
    }
    _setSnapshot(_snapshot.copyWith(shuffle: value));
    if (_queue.isNotEmpty && _index >= 0) {
      _rebuildPlaybackOrder(startIndex: _index);
    }
    await _player.setShuffle(false);
  }

  @override
  Future<void> setSoundReactiveVisualizer(bool value) async {
    return;
  }

  @override
  void updateCurrentItem(MediaItem item) {
    if (_snapshot.currentItem?.path != item.path) {
      return;
    }
    if (_index >= 0 && _index < _queue.length) {
      _queue[_index] = item;
    }
    _setSnapshot(_snapshot.copyWith(currentItem: item));
  }

  @override
  void dispose() {
    for (final subscription in _subscriptions) {
      unawaited(subscription.cancel());
    }
    unawaited(_player.dispose());
    super.dispose();
  }

  void _setSnapshot(PlaybackSnapshot snapshot) {
    _snapshot = snapshot;
    notifyListeners();
  }

  Future<void> _advancePlaybackOrder(int delta) async {
    if (_queue.isEmpty) {
      return;
    }
    final currentIndex = _index >= 0 && _index < _queue.length ? _index : 0;
    _ensurePlaybackOrder(startIndex: currentIndex);
    if (_playbackOrder.isEmpty) {
      return;
    }
    final playbackIndex = playbackIndexAfterMove(
      _playbackOrder,
      currentIndex,
      delta,
    );
    await _openQueueIndex(_playbackOrder[playbackIndex], play: true);
  }

  Future<void> _handleCompleted() async {
    if (_snapshot.loop) {
      return;
    }
    await _advancePlaybackOrder(1);
  }

  Future<void> _openQueueIndex(int queueIndex, {required bool play}) {
    if (_queue.isEmpty) {
      return Future<void>.value();
    }
    final safeIndex = queueIndex.clamp(0, _queue.length - 1).toInt();
    _index = safeIndex;
    final item = _queue[_index];
    _setSnapshot(
      _snapshot.copyWith(
        currentItem: item,
        playing: play,
        position: Duration.zero,
        duration: Duration.zero,
        buffered: Duration.zero,
        clearError: true,
      ),
    );
    return _player.open(Media(Uri.file(item.path).toString()), play: play);
  }

  Future<void> _applyPlaylistMode() {
    return _player.setPlaylistMode(
      _snapshot.loop ? PlaylistMode.single : PlaylistMode.none,
    );
  }

  void _rebuildPlaybackOrder({required int startIndex}) {
    if (_queue.isEmpty || startIndex < 0 || startIndex >= _queue.length) {
      _playbackOrder = const [];
      return;
    }
    if (!_snapshot.shuffle) {
      _playbackOrder = [for (var i = 0; i < _queue.length; i++) i];
      return;
    }
    final remaining = [
      for (var i = 0; i < _queue.length; i++)
        if (i != startIndex) i,
    ]..shuffle(_random);
    _playbackOrder = [startIndex, ...remaining];
  }

  void _ensurePlaybackOrder({required int startIndex}) {
    if (_playbackOrder.length != _queue.length ||
        !_playbackOrder.contains(startIndex)) {
      _rebuildPlaybackOrder(startIndex: startIndex);
    }
  }
}

int playbackIndexForQueueIndex(List<int> playbackOrder, int queueIndex) {
  final playbackIndex = playbackOrder.indexOf(queueIndex);
  return playbackIndex < 0 ? 0 : playbackIndex;
}

int playbackIndexAfterMove(List<int> playbackOrder, int queueIndex, int delta) {
  if (playbackOrder.isEmpty) {
    return 0;
  }
  final currentIndex = playbackIndexForQueueIndex(playbackOrder, queueIndex);
  return (currentIndex + delta) % playbackOrder.length;
}
