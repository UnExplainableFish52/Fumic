import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../models/visualizer_settings.dart';

abstract class AppSettingsRepository {
  Future<VisualizerSettings> loadVisualizerSettings();
  Future<void> saveVisualizerSettings(VisualizerSettings settings);
}

class JsonAppSettingsRepository implements AppSettingsRepository {
  const JsonAppSettingsRepository({Directory? supportDirectory})
    : _supportDirectory = supportDirectory;

  static const _fileName = 'fumic_settings.json';
  static Future<void> _writeQueue = Future<void>.value();
  final Directory? _supportDirectory;

  @override
  Future<VisualizerSettings> loadVisualizerSettings() async {
    await _writeQueue;
    final payload = await _readPayload();
    final settings = payload['visualizerSettings'];
    if (settings is Map<String, dynamic>) {
      return VisualizerSettings.fromJson(settings);
    }
    return const VisualizerSettings();
  }

  @override
  Future<void> saveVisualizerSettings(VisualizerSettings settings) {
    // Slider events can arrive before the previous disk write has completed.
    final write = _writeQueue.then((_) => _writeSettings(settings));
    _writeQueue = write.catchError((Object _) {});
    return write;
  }

  Future<void> _writeSettings(VisualizerSettings settings) async {
    final file = await _settingsFile();
    final payload = await _readPayload();
    payload['visualizerSettings'] = settings.toJson();
    await file.parent.create(recursive: true);
    const encoder = JsonEncoder.withIndent('  ');
    final temporary = File('${file.path}.tmp');
    try {
      await temporary.writeAsString(encoder.convert(payload), flush: true);
      await temporary.rename(file.path);
    } finally {
      if (await temporary.exists()) await temporary.delete();
    }
  }

  Future<Map<String, dynamic>> _readPayload() async {
    final file = await _settingsFile();
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
    final directory =
        _supportDirectory ?? await getApplicationSupportDirectory();
    return File(p.join(directory.path, _fileName));
  }
}

class MemoryAppSettingsRepository implements AppSettingsRepository {
  MemoryAppSettingsRepository([VisualizerSettings? settings])
    : _settings = settings ?? const VisualizerSettings();

  VisualizerSettings _settings;

  @override
  Future<VisualizerSettings> loadVisualizerSettings() async => _settings;

  @override
  Future<void> saveVisualizerSettings(VisualizerSettings settings) async {
    _settings = settings;
  }
}
