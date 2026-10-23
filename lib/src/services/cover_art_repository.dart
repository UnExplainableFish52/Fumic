import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

enum CoverArtAction { chooseSong, chooseFolder, restoreSong, restoreFolder }

abstract class CoverArtRepository {
  Future<Map<String, String>> load();
  Future<void> save(Map<String, String> covers);
  Future<String?> pickAndStore();
  Future<void> deleteManagedCover(String path);
}

class JsonCoverArtRepository implements CoverArtRepository {
  const JsonCoverArtRepository({Directory? supportDirectory})
    : _supportDirectory = supportDirectory;

  final Directory? _supportDirectory;

  Future<Directory> _directory() async {
    final support = _supportDirectory ?? await getApplicationSupportDirectory();
    return Directory(p.join(support.path, 'custom_covers'));
  }

  @override
  Future<Map<String, String>> load() async {
    try {
      final directory = await _directory();
      final file = File(p.join(directory.path, 'covers.json'));
      if (!await file.exists()) return {};
      final decoded = jsonDecode(await file.readAsString());
      if (decoded is! Map) return {};
      final result = <String, String>{};
      for (final entry in decoded.entries) {
        if (entry.key is String &&
            entry.value is String &&
            await File(entry.value as String).exists()) {
          result[entry.key as String] = entry.value as String;
        }
      }
      return result;
    } on Object {
      return {};
    }
  }

  @override
  Future<void> save(Map<String, String> covers) async {
    final directory = await _directory();
    await directory.create(recursive: true);
    await File(
      p.join(directory.path, 'covers.json'),
    ).writeAsString(jsonEncode(covers), flush: true);
  }

  @override
  Future<String?> pickAndStore() async {
    final result = await FilePicker.pickFiles(
      dialogTitle: 'Choose cover artwork',
      type: FileType.custom,
      allowedExtensions: const ['jpg', 'jpeg', 'png', 'webp'],
      lockParentWindow: true,
    );
    final source = result?.files.single.path;
    if (source == null) return null;
    return storeCover(File(source));
  }

  Future<String> storeCover(File source) async {
    if (await source.length() > 24 * 1024 * 1024) {
      throw const FormatException('Choose an image smaller than 24 MB.');
    }
    final bytes = await compute(_prepareCover, await source.readAsBytes());
    if (bytes == null) {
      throw const FormatException(
        'This image could not be opened. Try a JPG, PNG, or WebP image.',
      );
    }
    final directory = await _directory();
    await directory.create(recursive: true);
    // A new path also makes Flutter refresh its decoded image cache.
    final suffix = Random().nextInt(0x7fffffff).toRadixString(16);
    final target = File(
      p.join(
        directory.path,
        'cover_${DateTime.now().microsecondsSinceEpoch}_$suffix.jpg',
      ),
    );
    await target.writeAsBytes(bytes, flush: true);
    return target.path;
  }

  @override
  Future<void> deleteManagedCover(String path) async {
    final directory = await _directory();
    final target = File(path).absolute;
    if (!p.equals(p.dirname(target.path), directory.absolute.path) ||
        !RegExp(r'^cover_\d+_[a-f0-9]+\.jpg$').hasMatch(p.basename(path))) {
      return;
    }
    if (await target.exists()) await target.delete();
  }
}

Uint8List? _prepareCover(Uint8List bytes) {
  try {
    final decoded = img.decodeImage(bytes);
    if (decoded == null || decoded.width < 8 || decoded.height < 8) return null;
    final oriented = img.bakeOrientation(decoded);
    final image = max(oriented.width, oriented.height) <= 1000
        ? oriented
        : oriented.width >= oriented.height
        ? img.copyResize(oriented, width: 1000)
        : img.copyResize(oriented, height: 1000);
    return Uint8List.fromList(img.encodeJpg(image, quality: 90));
  } on Object {
    return null;
  }
}

class MemoryCoverArtRepository implements CoverArtRepository {
  MemoryCoverArtRepository({
    Map<String, String> covers = const {},
    this.nextPath,
  }) : covers = Map.of(covers);

  Map<String, String> covers;
  String? nextPath;
  final deletedPaths = <String>[];

  @override
  Future<Map<String, String>> load() async => Map.of(covers);
  @override
  Future<void> save(Map<String, String> value) async => covers = Map.of(value);
  @override
  Future<String?> pickAndStore() async => nextPath;
  @override
  Future<void> deleteManagedCover(String path) async => deletedPaths.add(path);
}
