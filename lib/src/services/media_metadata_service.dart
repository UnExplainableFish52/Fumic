import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;
import 'package:media_kit/media_kit.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../models/media_item.dart';
import '../models/media_kind.dart';
import 'embedded_artwork_extractor.dart';

class MediaMetadata {
  const MediaMetadata({required this.path, this.duration, this.thumbnailPath});

  final String path;
  final Duration? duration;
  final String? thumbnailPath;
}

abstract class MediaMetadataService {
  Future<void> enrich({
    required List<MediaItem> items,
    required void Function(MediaMetadata metadata) onMetadata,
    required bool Function() isCancelled,
  });
}

class NoopMediaMetadataService implements MediaMetadataService {
  const NoopMediaMetadataService();

  @override
  Future<void> enrich({
    required List<MediaItem> items,
    required void Function(MediaMetadata metadata) onMetadata,
    required bool Function() isCancelled,
  }) async {}
}

class MediaKitMetadataService implements MediaMetadataService {
  const MediaKitMetadataService({
    this.artworkExtractor = const EmbeddedArtworkExtractor(),
  });

  final EmbeddedArtworkExtractor artworkExtractor;

  static const _cacheVersion = 5;
  static const _cacheFileName = 'fumic_media_metadata_v5.json';
  static const _saveEveryMetadataItems = 16;
  static const _thumbnailFolder = 'thumbnails';

  @override
  Future<void> enrich({
    required List<MediaItem> items,
    required void Function(MediaMetadata metadata) onMetadata,
    required bool Function() isCancelled,
  }) async {
    if (items.isEmpty) {
      return;
    }

    final supportDirectory = await getApplicationSupportDirectory();
    final cacheFile = File(p.join(supportDirectory.path, _cacheFileName));
    final thumbnailDirectory = Directory(
      p.join(supportDirectory.path, _thumbnailFolder),
    );
    await thumbnailDirectory.create(recursive: true);

    final cache = await _loadCache(cacheFile);
    Player? player;
    var changed = false;
    var pendingWrites = 0;

    try {
      for (final item in items) {
        if (isCancelled()) {
          break;
        }
        final signature = await _signatureFor(item.path);
        if (signature == null) {
          continue;
        }

        final cached = cache[item.path];
        if (cached != null && cached.matches(signature)) {
          final thumbnailPath = await _existingThumbnail(cached.thumbnailPath);
          if (thumbnailPath != null) {
            onMetadata(
              MediaMetadata(
                path: item.path,
                duration: cached.duration,
                thumbnailPath: thumbnailPath,
              ),
            );
            continue;
          }
        }

        player ??= Player();
        final metadata = await _readMetadata(
          player: player,
          item: item,
          thumbnailDirectory: thumbnailDirectory,
        );

        cache[item.path] = _CachedMetadata(
          path: item.path,
          modifiedMs: signature.modifiedMs,
          size: signature.size,
          durationMs: metadata.duration?.inMilliseconds,
          thumbnailPath: metadata.thumbnailPath,
        );
        changed = true;
        pendingWrites++;
        onMetadata(metadata);

        if (pendingWrites >= _saveEveryMetadataItems) {
          await _saveCache(cacheFile, cache);
          changed = false;
          pendingWrites = 0;
        }
        await Future<void>.delayed(Duration.zero);
      }
    } finally {
      if (changed) {
        await _saveCache(cacheFile, cache);
      }
      await player?.dispose();
    }
  }

  Future<MediaMetadata> _readMetadata({
    required Player player,
    required MediaItem item,
    required Directory thumbnailDirectory,
  }) async {
    try {
      await player.open(Media(Uri.file(item.path).toString()), play: false);
      final duration = await _waitForDuration(player);
      String? thumbnailPath;
      if (item.kind == MediaKind.audio) {
        thumbnailPath = await _extractEmbeddedArtworkThumbnail(
          item: item,
          thumbnailDirectory: thumbnailDirectory,
        );
      } else {
        thumbnailPath = await _captureThumbnail(
          player: player,
          item: item,
          duration: duration,
          thumbnailDirectory: thumbnailDirectory,
        );
      }
      thumbnailPath ??= await _generateFallbackThumbnail(
        item: item,
        thumbnailDirectory: thumbnailDirectory,
      );

      await player.stop();
      return MediaMetadata(
        path: item.path,
        duration: duration > Duration.zero ? duration : null,
        thumbnailPath: thumbnailPath,
      );
    } on Object {
      await player.stop();
      return MediaMetadata(
        path: item.path,
        thumbnailPath: await _generateFallbackThumbnail(
          item: item,
          thumbnailDirectory: thumbnailDirectory,
        ),
      );
    }
  }

  Future<Duration> _waitForDuration(Player player) async {
    if (player.state.duration > Duration.zero) {
      return player.state.duration;
    }

    try {
      return await player.stream.duration
          .firstWhere((duration) => duration > Duration.zero)
          .timeout(const Duration(seconds: 3));
    } on Object {
      return player.state.duration;
    }
  }

  Future<String?> _captureThumbnail({
    required Player player,
    required MediaItem item,
    required Duration duration,
    required Directory thumbnailDirectory,
  }) async {
    try {
      await _prepareVisualTrack(player);
      final seekTarget = duration > const Duration(seconds: 10)
          ? const Duration(seconds: 5)
          : duration > const Duration(seconds: 2)
          ? const Duration(seconds: 1)
          : Duration.zero;
      if (seekTarget > Duration.zero) {
        await player.seek(seekTarget);
      }
      await Future<void>.delayed(const Duration(milliseconds: 550));
      await _waitForVideoFrame(player);

      final bytes = await player
          .screenshot(format: 'image/jpeg')
          .timeout(const Duration(seconds: 4));
      if (bytes == null || bytes.length < 256) {
        return null;
      }

      final file = File(
        p.join(
          thumbnailDirectory.path,
          '${_stableId('${item.path}:frame')}.jpg',
        ),
      );
      await file.writeAsBytes(Uint8List.fromList(bytes), flush: true);
      return file.path;
    } on Object {
      return null;
    }
  }

  Future<void> _prepareVisualTrack(Player player) async {
    try {
      final platform = player.platform as dynamic;
      await platform.setProperty('vid', 'auto');
      await platform.setProperty('sid', 'no');
    } on Object {
      return;
    }
  }

  Future<void> _waitForVideoFrame(Player player) async {
    final deadline = DateTime.now().add(const Duration(seconds: 3));
    while (DateTime.now().isBefore(deadline)) {
      try {
        final platform = player.platform as dynamic;
        final width = await platform.getProperty('width');
        final height = await platform.getProperty('height');
        if (_propertyAsInt(width) > 1 && _propertyAsInt(height) > 1) {
          return;
        }
      } on Object {
        return;
      }
      await Future<void>.delayed(const Duration(milliseconds: 100));
    }
  }

  int _propertyAsInt(Object? value) {
    if (value is int) {
      return value;
    }
    if (value is double) {
      return value.round();
    }
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  Future<String?> _extractEmbeddedArtworkThumbnail({
    required MediaItem item,
    required Directory thumbnailDirectory,
  }) async {
    try {
      final artwork = await artworkExtractor.extract(item.path);
      if (artwork == null || artwork.bytes.length < 256) {
        return null;
      }
      final decoded = img.decodeImage(artwork.bytes);
      if (decoded == null || decoded.width < 8 || decoded.height < 8) {
        return null;
      }
      final normalized = _resizeArtworkIfNeeded(decoded);
      final file = File(
        p.join(
          thumbnailDirectory.path,
          '${_stableId('${item.path}:embedded-artwork')}.jpg',
        ),
      );
      await file.writeAsBytes(
        img.encodeJpg(normalized, quality: 90),
        flush: true,
      );
      return file.path;
    } on Object {
      return null;
    }
  }

  img.Image _resizeArtworkIfNeeded(img.Image source) {
    const maxSide = 720;
    final longestSide = math.max(source.width, source.height);
    if (longestSide <= maxSide) {
      return source;
    }
    if (source.width >= source.height) {
      return img.copyResize(source, width: maxSide);
    }
    return img.copyResize(source, height: maxSide);
  }

  Future<String?> _generateFallbackThumbnail({
    required MediaItem item,
    required Directory thumbnailDirectory,
  }) async {
    try {
      const size = 360;
      final canvas = img.Image(width: size, height: size);
      final colors = item.colors.isEmpty
          ? const [Color(0xFF1D1B2E), Color(0xFF0C8C8C), Color(0xFFFFC857)]
          : item.colors;
      final start = _rgb(colors.first);
      final end = _rgb(colors.length > 1 ? colors[1] : colors.first);
      final accent = _rgb(
        colors.length > 2 ? colors[2] : const Color(0xFFFFC857),
      );
      final seed = _stableId(
        item.path,
      ).codeUnits.fold<int>(0, (value, unit) => value + unit);

      for (var y = 0; y < size; y++) {
        for (var x = 0; x < size; x++) {
          final sweep = (x + y) / (size * 2);
          final wave = math.sin((x * 0.025) + (y * 0.017) + seed * 0.05) * 0.08;
          final glowDx = (x - size * 0.72) / size;
          final glowDy = (y - size * 0.30) / size;
          final glow = math.max(
            0.0,
            1.0 - math.sqrt(glowDx * glowDx + glowDy * glowDy) * 2.2,
          );
          final shade = math.max(0.0, math.min(1.0, sweep + wave));
          final vignetteDx = (x - size / 2) / (size / 2);
          final vignetteDy = (y - size / 2) / (size / 2);
          final vignette = math.max(
            0.0,
            1.0 - (vignetteDx * vignetteDx + vignetteDy * vignetteDy) * 0.28,
          );
          final r =
              ((_mix(start.r, end.r, shade) + accent.r * glow * 0.28) *
                      vignette)
                  .round();
          final g =
              ((_mix(start.g, end.g, shade) + accent.g * glow * 0.28) *
                      vignette)
                  .round();
          final b =
              ((_mix(start.b, end.b, shade) + accent.b * glow * 0.28) *
                      vignette)
                  .round();
          canvas.setPixelRgb(x, y, _clampByte(r), _clampByte(g), _clampByte(b));
        }
      }

      _drawRing(canvas, size ~/ 2, size ~/ 2, 118, const Color(0xEEFFFFFF));
      if (item.kind == MediaKind.video) {
        _drawPlayMark(canvas, const Color(0xFFFFFFFF));
      } else {
        _drawMusicMark(canvas, const Color(0xFFFFFFFF));
      }

      final file = File(
        p.join(
          thumbnailDirectory.path,
          '${_stableId('${item.path}:fallback')}.jpg',
        ),
      );
      await file.writeAsBytes(img.encodeJpg(canvas, quality: 88), flush: true);
      return file.path;
    } on Object {
      return null;
    }
  }

  ({int r, int g, int b}) _rgb(Color color) {
    final value = color.toARGB32();
    return (r: (value >> 16) & 0xff, g: (value >> 8) & 0xff, b: value & 0xff);
  }

  double _mix(int from, int to, double amount) {
    return from + (to - from) * amount;
  }

  int _clampByte(int value) {
    return math.max(0, math.min(255, value));
  }

  void _drawRing(img.Image canvas, int cx, int cy, int radius, Color color) {
    final rgb = _rgb(color);
    final inner = radius - 9;
    final outer = radius + 9;
    for (var y = cy - outer; y <= cy + outer; y++) {
      for (var x = cx - outer; x <= cx + outer; x++) {
        final distance = math.sqrt(
          math.pow(x - cx, 2).toDouble() + math.pow(y - cy, 2).toDouble(),
        );
        if (distance >= inner && distance <= outer) {
          canvas.setPixelRgb(x, y, rgb.r, rgb.g, rgb.b);
        }
      }
    }
  }

  void _drawPlayMark(img.Image canvas, Color color) {
    final rgb = _rgb(color);
    const left = 150;
    const top = 126;
    const height = 108;
    const width = 86;
    for (var y = 0; y < height; y++) {
      final halfWidth = (width * (1 - (2 * (y / height - 0.5)).abs()) * 0.5)
          .round();
      final xStart = left + y * width ~/ height - halfWidth ~/ 3;
      final xEnd = left + y * width ~/ height + halfWidth;
      for (var x = xStart; x <= xEnd; x++) {
        canvas.setPixelRgb(x, top + y, rgb.r, rgb.g, rgb.b);
      }
    }
  }

  void _drawMusicMark(img.Image canvas, Color color) {
    final rgb = _rgb(color);
    for (var y = 112; y <= 226; y++) {
      for (var x = 206; x <= 222; x++) {
        canvas.setPixelRgb(x, y, rgb.r, rgb.g, rgb.b);
      }
    }
    for (var y = 112; y <= 130; y++) {
      for (var x = 138; x <= 218; x++) {
        canvas.setPixelRgb(x, y, rgb.r, rgb.g, rgb.b);
      }
    }
    _fillCircle(canvas, 142, 228, 32, rgb);
    _fillCircle(canvas, 210, 248, 32, rgb);
  }

  void _fillCircle(
    img.Image canvas,
    int cx,
    int cy,
    int radius,
    ({int r, int g, int b}) rgb,
  ) {
    final radiusSquared = radius * radius;
    for (var y = cy - radius; y <= cy + radius; y++) {
      for (var x = cx - radius; x <= cx + radius; x++) {
        final dx = x - cx;
        final dy = y - cy;
        if (dx * dx + dy * dy <= radiusSquared) {
          canvas.setPixelRgb(x, y, rgb.r, rgb.g, rgb.b);
        }
      }
    }
  }

  Future<Map<String, _CachedMetadata>> _loadCache(File file) async {
    if (!await file.exists()) {
      return {};
    }
    try {
      final decoded = jsonDecode(await file.readAsString());
      if (decoded is! Map<String, dynamic>) {
        return {};
      }
      if (decoded['version'] != _cacheVersion) {
        return {};
      }
      final entries = decoded['entries'];
      if (entries is! List) {
        return {};
      }
      return {
        for (final entry in entries)
          if (entry is Map<String, dynamic>)
            _CachedMetadata.fromJson(entry).path: _CachedMetadata.fromJson(
              entry,
            ),
      };
    } on Object {
      return {};
    }
  }

  Future<void> _saveCache(File file, Map<String, _CachedMetadata> cache) async {
    await file.parent.create(recursive: true);
    const encoder = JsonEncoder.withIndent('  ');
    await file.writeAsString(
      encoder.convert({
        'version': _cacheVersion,
        'entries': cache.values.map((entry) => entry.toJson()).toList(),
      }),
      flush: true,
    );
  }

  Future<_FileSignature?> _signatureFor(String path) async {
    try {
      final stat = await File(path).stat();
      if (stat.type != FileSystemEntityType.file) {
        return null;
      }
      return _FileSignature(
        modifiedMs: stat.modified.millisecondsSinceEpoch,
        size: stat.size,
      );
    } on Object {
      return null;
    }
  }

  Future<String?> _existingThumbnail(String? path) async {
    if (path == null) {
      return null;
    }
    return await File(path).exists() ? path : null;
  }

  String _stableId(String value) {
    const offset = 0xcbf29ce484222325;
    const prime = 0x100000001b3;
    var hash = offset;
    for (final unit in utf8.encode(value)) {
      hash ^= unit;
      hash = (hash * prime) & 0x7fffffffffffffff;
    }
    return hash.toRadixString(16);
  }
}

class _FileSignature {
  const _FileSignature({required this.modifiedMs, required this.size});

  final int modifiedMs;
  final int size;
}

class _CachedMetadata {
  const _CachedMetadata({
    required this.path,
    required this.modifiedMs,
    required this.size,
    required this.durationMs,
    required this.thumbnailPath,
  });

  final String path;
  final int modifiedMs;
  final int size;
  final int? durationMs;
  final String? thumbnailPath;

  Duration? get duration =>
      durationMs == null ? null : Duration(milliseconds: durationMs!);

  bool matches(_FileSignature signature) {
    return modifiedMs == signature.modifiedMs && size == signature.size;
  }

  factory _CachedMetadata.fromJson(Map<String, dynamic> json) {
    return _CachedMetadata(
      path: json['path'] as String? ?? '',
      modifiedMs: json['modifiedMs'] as int? ?? 0,
      size: json['size'] as int? ?? 0,
      durationMs: json['durationMs'] as int?,
      thumbnailPath: json['thumbnailPath'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'path': path,
      'modifiedMs': modifiedMs,
      'size': size,
      'durationMs': durationMs,
      'thumbnailPath': thumbnailPath,
    };
  }
}
