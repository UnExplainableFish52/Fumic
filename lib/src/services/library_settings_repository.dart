import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

abstract class LibrarySettingsRepository {
  Future<List<String>> loadFolders();
  Future<void> saveFolders(List<String> folders);
  Future<bool> hasStoredLibraryFolders();
  Future<bool> hasInitializedDefaultLibraries();
  Future<void> saveFoldersWithDefaultInitialization(List<String> folders);
}

class JsonLibrarySettingsRepository implements LibrarySettingsRepository {
  const JsonLibrarySettingsRepository();

  static const _fileName = 'fumic_settings.json';

  @override
  Future<List<String>> loadFolders() async {
    final file = await _settingsFile();
    final payload = await _readPayload(file);
    final folders = payload['libraryFolders'];
    if (folders is! List) {
      return const [];
    }
    return folders.whereType<String>().toList(growable: false);
  }

  @override
  Future<void> saveFolders(List<String> folders) async {
    final file = await _settingsFile();
    final payload = await _readPayload(file);
    payload['libraryFolders'] = folders;
    payload['hasInitializedDefaultLibraries'] = true;
    await file.parent.create(recursive: true);
    const encoder = JsonEncoder.withIndent('  ');
    await file.writeAsString(encoder.convert(payload), flush: true);
  }

  @override
  Future<bool> hasStoredLibraryFolders() async {
    final payload = await _readPayload(await _settingsFile());
    return payload.containsKey('libraryFolders');
  }

  @override
  Future<bool> hasInitializedDefaultLibraries() async {
    final payload = await _readPayload(await _settingsFile());
    return payload['hasInitializedDefaultLibraries'] == true;
  }

  @override
  Future<void> saveFoldersWithDefaultInitialization(
    List<String> folders,
  ) async {
    final file = await _settingsFile();
    final payload = await _readPayload(file);
    payload['libraryFolders'] = folders;
    payload['hasInitializedDefaultLibraries'] = true;
    await file.parent.create(recursive: true);
    const encoder = JsonEncoder.withIndent('  ');
    await file.writeAsString(encoder.convert(payload), flush: true);
  }

  Future<Map<String, dynamic>> _readPayload(File file) async {
    if (!await file.exists()) {
      return <String, dynamic>{};
    }
    try {
      final decoded = jsonDecode(await file.readAsString());
      if (decoded is Map<String, dynamic>) {
        return Map<String, dynamic>.from(decoded);
      }
    } on Object {
      return <String, dynamic>{};
    }
    return <String, dynamic>{};
  }

  Future<File> _settingsFile() async {
    final directory = await getApplicationSupportDirectory();
    return File(p.join(directory.path, _fileName));
  }
}

class MemoryLibrarySettingsRepository implements LibrarySettingsRepository {
  MemoryLibrarySettingsRepository([List<String> folders = const []])
    : _folders = List<String>.from(folders),
      _hasStoredLibraryFolders = true,
      _hasInitializedDefaultLibraries = true;

  MemoryLibrarySettingsRepository.uninitialized([
    List<String> folders = const [],
  ]) : _folders = List<String>.from(folders),
       _hasStoredLibraryFolders = false,
       _hasInitializedDefaultLibraries = false;

  List<String> _folders;
  bool _hasStoredLibraryFolders;
  bool _hasInitializedDefaultLibraries;

  @override
  Future<List<String>> loadFolders() async => List<String>.from(_folders);

  @override
  Future<void> saveFolders(List<String> folders) async {
    _folders = List<String>.from(folders);
    _hasStoredLibraryFolders = true;
    _hasInitializedDefaultLibraries = true;
  }

  @override
  Future<bool> hasStoredLibraryFolders() async => _hasStoredLibraryFolders;

  @override
  Future<bool> hasInitializedDefaultLibraries() async {
    return _hasInitializedDefaultLibraries;
  }

  @override
  Future<void> saveFoldersWithDefaultInitialization(
    List<String> folders,
  ) async {
    _folders = List<String>.from(folders);
    _hasStoredLibraryFolders = true;
    _hasInitializedDefaultLibraries = true;
  }
}
