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
  const JsonAppSettingsRepository();

  static const _fileName = 'fumic_settings.json';

  @override
  Future<VisualizerSettings> loadVisualizerSettings() async {
    final payload = await _readPayload();
    final settings = payload['visualizerSettings'];
    if (settings is Map<String, dynamic>) {
      return VisualizerSettings.fromJson(settings);
    }
    return const VisualizerSettings();
  }

  @override
  Future<void> saveVisualizerSettings(VisualizerSettings settings) async {
    final file = await _settingsFile();
    final payload = await _readPayload();
    payload['visualizerSettings'] = settings.toJson();
    await file.parent.create(recursive: true);
    const encoder = JsonEncoder.withIndent('  ');
    await file.writeAsString(encoder.convert(payload), flush: true);
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
    final directory = await getApplicationSupportDirectory();
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
