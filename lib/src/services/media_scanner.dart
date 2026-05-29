import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;

import '../models/media_item.dart';
import '../models/media_kind.dart';

abstract class MediaScanner {
  Future<List<MediaItem>> scanFolders(List<String> folders);
}

class FileSystemMediaScanner implements MediaScanner {
  const FileSystemMediaScanner();

  static const _audioExtensions = {
    '.aac',
    '.aif',
    '.aiff',
    '.alac',
    '.flac',
    '.m4a',
    '.m4b',
    '.mp3',
    '.oga',
    '.ogg',
    '.opus',
    '.wav',
    '.wma',
  };
  static const _videoExtensions = {
    '.avi',
    '.m4v',
    '.mkv',
    '.mov',
    '.mp4',
    '.webm',
    '.wmv',
  };

  @override
  Future<List<MediaItem>> scanFolders(List<String> folders) async {
    final items = <MediaItem>[];
    for (final folder in folders) {
      final root = Directory(folder);
      if (!await root.exists()) {
        continue;
      }
      await for (final entity in root.list(
        recursive: true,
        followLinks: false,
      )) {
        if (entity is! File) {
          continue;
        }
        final item = _mediaItemForFile(entity.path);
        if (item != null) {
          items.add(item);
        }
      }
    }

    items.sort(
      (a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()),
    );
    return items;
  }

  MediaItem? _mediaItemForFile(String path) {
    final extension = p.extension(path).toLowerCase();
    final kind = _audioExtensions.contains(extension)
        ? MediaKind.audio
        : _videoExtensions.contains(extension)
        ? MediaKind.video
        : null;
    if (kind == null) {
      return null;
    }

    return MediaItem(
      path: path,
      title: p.basenameWithoutExtension(path),
      artist: kind == MediaKind.audio ? _parentFolderName(path) : 'VIDEO',
      kind: kind,
      colors: _colorsForPath(path),
    );
  }

  String _parentFolderName(String path) {
    final name = p.basename(p.dirname(path));
    return name.isEmpty ? 'Audio Library' : name;
  }

  List<Color> _colorsForPath(String path) {
    final hash = path.codeUnits.fold<int>(0, (value, unit) {
      return (value * 31 + unit) & 0x7fffffff;
    });
    final hue = (hash % 360).toDouble();
    return [
      HSLColor.fromAHSL(1, hue, 0.74, 0.58).toColor(),
      HSLColor.fromAHSL(
        1,
        (hue + 55 + math.sqrt(hash % 97)) % 360,
        0.78,
        0.44,
      ).toColor(),
      HSLColor.fromAHSL(1, (hue + 205) % 360, 0.50, 0.18).toColor(),
    ];
  }
}

class StaticMediaScanner implements MediaScanner {
  const StaticMediaScanner(this.items);

  final List<MediaItem> items;

  @override
  Future<List<MediaItem>> scanFolders(List<String> folders) async {
    if (folders.isEmpty) {
      return const [];
    }
    return List<MediaItem>.from(items);
  }
}
