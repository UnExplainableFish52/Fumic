import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:fumic/src/models/visualizer_settings.dart';
import 'package:fumic/src/services/app_settings_repository.dart';

void main() {
  test(
    'rapid opacity saves keep the final slider values in readable JSON',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'fumic_opacity_test_',
      );
      addTearDown(() => directory.delete(recursive: true));
      final repository = JsonAppSettingsRepository(supportDirectory: directory);
      await Future.wait([
        for (var i = 0; i <= 30; i++)
          repository.saveVisualizerSettings(
            VisualizerSettings(
              cardOpacity: i / 30,
              backgroundOpacity: 1 - i / 30,
            ),
          ),
      ]);
      final restored = await repository.loadVisualizerSettings();
      expect(restored.effectiveCardOpacity, 1);
      expect(restored.effectiveBackgroundOpacity, 0);
    },
  );
}
