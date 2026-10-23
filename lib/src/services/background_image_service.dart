import 'dart:io';
import 'dart:math' as math;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

abstract class BackgroundImageService {
  Future<String?> pickAndStoreCustomBackground();
  Future<void> deleteCustomBackground(String? path);
  Future<void> cleanupUnusedBackgrounds(String? activePath);
}

class FilePickerBackgroundImageService implements BackgroundImageService {
  const FilePickerBackgroundImageService({Directory? supportDirectory})
    : _supportDirectory = supportDirectory;

  static const _backgroundFolder = 'backgrounds';
  static const maxFileBytes = 24 * 1024 * 1024;
  static final _managedName = RegExp(
    r'^custom_background(?:_\d+_[a-f0-9]+)?\.jpg(?:\.tmp)?$',
  );

  final Directory? _supportDirectory;

  @override
  Future<String?> pickAndStoreCustomBackground() async {
    final result = await FilePicker.pickFiles(
      dialogTitle: 'Choose a Fumic background image',
      type: FileType.custom,
      allowedExtensions: const ['jpg', 'jpeg', 'png', 'webp'],
      lockParentWindow: true,
    );
    final path = result?.files.single.path;
    if (path == null || path.trim().isEmpty) {
      return null;
    }
    return storeCustomBackground(File(path));
  }

  Future<String?> storeCustomBackground(File source) async {
    if (!await source.exists()) return null;
    if (await source.length() > maxFileBytes) {
      throw const FormatException('Choose a wallpaper smaller than 24 MB.');
    }
    final bytes = await compute(_prepareBackground, await source.readAsBytes());
    final directory = await _backgroundDirectory();
    await directory.create(recursive: true);
    final suffix = math.Random.secure().nextInt(0x7fffffff).toRadixString(16);
    final target = File(
      p.join(
        directory.path,
        'custom_background_${DateTime.now().microsecondsSinceEpoch}_$suffix.jpg',
      ),
    );
    final temporary = File('${target.path}.tmp');
    try {
      await temporary.writeAsBytes(bytes, flush: true);
      await temporary.rename(target.path);
      return target.path;
    } finally {
      if (await temporary.exists()) await temporary.delete();
    }
  }

  @override
  Future<void> deleteCustomBackground(String? path) async {
    if (path == null || path.trim().isEmpty) {
      return;
    }
    try {
      final file = File(path);
      final directory = await _backgroundDirectory();
      if (!p.equals(p.dirname(file.absolute.path), directory.absolute.path) ||
          !_managedName.hasMatch(p.basename(file.path))) {
        return;
      }
      if (await file.exists()) {
        await file.delete();
      }
    } on Object {
      return;
    }
  }

  @override
  Future<void> cleanupUnusedBackgrounds(String? activePath) async {
    try {
      final directory = await _backgroundDirectory();
      if (!await directory.exists()) return;
      await for (final entity in directory.list(followLinks: false)) {
        if (entity is File &&
            _managedName.hasMatch(p.basename(entity.path)) &&
            (activePath == null ||
                !p.equals(
                  entity.absolute.path,
                  File(activePath).absolute.path,
                ))) {
          await deleteCustomBackground(entity.path);
        }
      }
    } on Object {
      // Stale-file cleanup must not prevent startup or lose the active image.
    }
  }

  Future<Directory> _backgroundDirectory() async {
    final directory =
        _supportDirectory ?? await getApplicationSupportDirectory();
    return Directory(p.join(directory.path, _backgroundFolder));
  }
}

Uint8List _prepareBackground(Uint8List bytes) {
  const unreadable = FormatException(
    'This wallpaper could not be opened. Try a JPG, PNG, or WebP image.',
  );
  try {
    if (bytes.length > FilePickerBackgroundImageService.maxFileBytes) {
      throw const FormatException('Choose a wallpaper smaller than 24 MB.');
    }
    final decoder = img.findDecoderForData(bytes);
    final info = decoder?.startDecode(bytes);
    if (info == null || info.width < 8 || info.height < 8) throw unreadable;
    if (info.width * info.height > 16 * 1024 * 1024 ||
        info.width > 16384 ||
        info.height > 16384) {
      throw const FormatException(
        'Choose a wallpaper with at most 16 megapixels.',
      );
    }
    // A wallpaper is a still image, including when an animated file is chosen.
    final decoded = decoder!.decodeFrame(0);
    if (decoded == null) throw unreadable;
    final oriented = img.bakeOrientation(decoded);
    final normalized = math.max(oriented.width, oriented.height) <= 1920
        ? oriented
        : oriented.width >= oriented.height
        ? img.copyResize(oriented, width: 1920)
        : img.copyResize(oriented, height: 1920);
    return Uint8List.fromList(img.encodeJpg(normalized, quality: 90));
  } on FormatException {
    rethrow;
  } on Object {
    throw unreadable;
  }
}

class MemoryBackgroundImageService implements BackgroundImageService {
  MemoryBackgroundImageService({this.nextPath});

  String? nextPath;
  final deletedPaths = <String>[];
  final cleanupPaths = <String?>[];

  @override
  Future<String?> pickAndStoreCustomBackground() async => nextPath;

  @override
  Future<void> deleteCustomBackground(String? path) async {
    if (path != null) {
      deletedPaths.add(path);
    }
  }

  @override
  Future<void> cleanupUnusedBackgrounds(String? activePath) async {
    cleanupPaths.add(activePath);
  }
}
