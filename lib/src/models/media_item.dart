import 'package:flutter/material.dart';

import 'media_kind.dart';

class MediaItem {
  const MediaItem({
    required this.path,
    required this.title,
    required this.artist,
    required this.kind,
    required this.colors,
    this.duration,
    this.thumbnailPath,
  });

  final String path;
  final String title;
  final String artist;
  final MediaKind kind;
  final List<Color> colors;
  final Duration? duration;
  final String? thumbnailPath;

  String get id => path;

  String get durationLabel {
    final value = duration;
    if (value == null) {
      return 'Loading duration...';
    }
    return formatDuration(value);
  }

  MediaItem copyWith({
    String? path,
    String? title,
    String? artist,
    MediaKind? kind,
    List<Color>? colors,
    Duration? duration,
    bool clearDuration = false,
    String? thumbnailPath,
    bool clearThumbnailPath = false,
  }) {
    return MediaItem(
      path: path ?? this.path,
      title: title ?? this.title,
      artist: artist ?? this.artist,
      kind: kind ?? this.kind,
      colors: colors ?? this.colors,
      duration: clearDuration ? null : duration ?? this.duration,
      thumbnailPath: clearThumbnailPath
          ? null
          : thumbnailPath ?? this.thumbnailPath,
    );
  }
}

String formatDuration(Duration value) {
  final hours = value.inHours;
  final minutes = value.inMinutes.remainder(60);
  final seconds = value.inSeconds.remainder(60);
  if (hours > 0) {
    return '$hours:${minutes.toString().padLeft(2, '0')}:'
        '${seconds.toString().padLeft(2, '0')}';
  }
  return '$minutes:${seconds.toString().padLeft(2, '0')}';
}
