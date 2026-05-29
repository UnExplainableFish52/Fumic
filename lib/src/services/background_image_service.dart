import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

abstract class BackgroundImageService {
  Future<String?> pickAndStoreCustomBackground();
  Future<void> deleteCustomBackground(String? path);
}

class FilePickerBackgroundImageService implements BackgroundImageService {
  const FilePickerBackgroundImageService({Directory? supportDirectory})
    : _supportDirectory = supportDirectory;

  static const _backgroundFolder = 'backgrounds';
  static const _backgroundFileName = 'custom_background.jpg';
  static const _maxSide = 1920;

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
    if (!await source.exists()) {
      return null;
    }
    try {
      final decoded = img.decodeImage(await source.readAsBytes());
      if (decoded == null || decoded.width < 8 || decoded.height < 8) {
        return null;
      }
      final normalized = _resizeIfNeeded(decoded);
      final target = await _backgroundFile();
      await target.parent.create(recursive: true);
      await target.writeAsBytes(
        Uint8List.fromList(img.encodeJpg(normalized, quality: 90)),
        flush: true,
      );
      return target.path;
    } on Object {
      return null;
    }
  }

  @override
  Future<void> deleteCustomBackground(String? path) async {
    if (path == null || path.trim().isEmpty) {
      return;
    }
    try {
      final file = File(path);
      final managedFile = await _backgroundFile();
      if (!p.equals(file.absolute.path, managedFile.absolute.path)) {
        return;
      }
      if (await file.exists()) {
        await file.delete();
      }
    } on Object {
      return;
    }
  }

  img.Image _resizeIfNeeded(img.Image source) {
    final longestSide = source.width > source.height
        ? source.width
        : source.height;
    if (longestSide <= _maxSide) {
      return source;
    }
    if (source.width >= source.height) {
      return img.copyResize(source, width: _maxSide);
    }
    return img.copyResize(source, height: _maxSide);
  }

  Future<File> _backgroundFile() async {
    final directory =
        _supportDirectory ?? await getApplicationSupportDirectory();
    return File(p.join(directory.path, _backgroundFolder, _backgroundFileName));
  }
}

class MemoryBackgroundImageService implements BackgroundImageService {
  MemoryBackgroundImageService({this.nextPath});

  String? nextPath;
  final deletedPaths = <String>[];

  @override
  Future<String?> pickAndStoreCustomBackground() async => nextPath;

  @override
  Future<void> deleteCustomBackground(String? path) async {
    if (path != null) {
      deletedPaths.add(path);
    }
  }
}
