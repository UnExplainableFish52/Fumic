import 'package:flutter_test/flutter_test.dart';
import 'package:fumic/features/visualizer/fake_spectrum_generator.dart';
import 'package:fumic/src/models/visualizer_settings.dart';

void main() {
  test(
    'full-player control visibility and delay persist with safe defaults',
    () {
      const defaults = VisualizerSettings();
      expect(defaults.showPlayerControls, isTrue);
      expect(defaults.effectivePlayerControlsHideDelaySeconds, 5);
      final restored = VisualizerSettings.fromJson(
        defaults
            .copyWith(
              showPlayerControls: false,
              playerControlsHideDelaySeconds: 10,
            )
            .toJson(),
      );
      expect(restored.showPlayerControls, isFalse);
      expect(restored.effectivePlayerControlsHideDelaySeconds, 10);
      expect(VisualizerSettings.fromJson({}).showPlayerControls, isTrue);
      expect(
        VisualizerSettings.fromJson({}).effectivePlayerControlsHideDelaySeconds,
        5,
      );
      expect(
        defaults
            .copyWith(playerControlsHideDelaySeconds: -1)
            .effectivePlayerControlsHideDelaySeconds,
        0,
      );
      expect(
        defaults
            .copyWith(playerControlsHideDelaySeconds: 200)
            .effectivePlayerControlsHideDelaySeconds,
        60,
      );
    },
  );

  test('visualizer defaults match release settings', () {
    const settings = VisualizerSettings();

    expect(settings.enabled, isTrue);
    expect(settings.effectiveFps, 30);
    expect(settings.effectiveWaveformBars, 128);
    expect(settings.effectiveParticleCount, 0);
    expect(settings.glowStrength, VisualizerGlowStrength.off);
    expect(settings.backgroundIndex, 0);
    expect(settings.showBackgroundImage, isTrue);
    expect(settings.customBackgroundPath, isNull);
  });

  test('legacy persisted visualizer settings migrate to current defaults', () {
    final settings = VisualizerSettings.fromJson({
      'enabled': false,
      'backgroundIndex': 0,
      'waveformBars': 96,
      'particleCount': 90,
      'glowStrength': 'medium',
    });

    expect(settings.enabled, isTrue);
    expect(settings.backgroundIndex, 0);
    expect(settings.effectiveWaveformBars, 128);
    expect(settings.effectiveParticleCount, 0);
    expect(settings.glowStrength, VisualizerGlowStrength.off);
  });

  test(
    'wallpaper reorder preserves existing selections and replaces removed Anime Sky',
    () {
      const expectedIds = [
        'tanjiro',
        'magical-night',
        'fullmoon-shrine',
        'swordmaster',
        'night-girl',
        'fumic',
        'sakura-night',
        'samurai-night',
        'matrix-rain',
      ];
      for (var oldIndex = 0; oldIndex < expectedIds.length; oldIndex++) {
        final restored = VisualizerSettings.fromJson({
          'visualizerDefaultsVersion': VisualizerSettings.defaultsVersion,
          'backgroundIndex': oldIndex,
          'customBackgroundPath': 'custom.jpg',
        });
        expect(restored.background.id, expectedIds[oldIndex]);
        expect(restored.customBackgroundPath, 'custom.jpg');
      }
    },
  );

  test('stable wallpaper identity takes precedence over an outdated index', () {
    final restored = VisualizerSettings.fromJson({
      ...const VisualizerSettings(backgroundIndex: 1).toJson(),
      'backgroundIndex': 0,
    });
    expect(restored.background.id, 'tanjiro');
    expect(const VisualizerSettings().background.id, 'fumic');
    expect(
      VisualizerBackground.presets
          .map((background) => background.id)
          .toSet()
          .length,
      VisualizerBackground.presets.length,
    );
  });

  test('custom background path roundtrips and can be cleared', () {
    final settings = VisualizerSettings.fromJson({
      'showBackgroundImage': true,
      'backgroundIndex': 2,
      'customBackgroundPath': 'C:\\Fumic\\backgrounds\\custom_background.jpg',
      'visualizerDefaultsVersion': VisualizerSettings.defaultsVersion,
    });

    expect(
      settings.customBackgroundPath,
      'C:\\Fumic\\backgrounds\\custom_background.jpg',
    );
    expect(
      VisualizerSettings.fromJson(settings.toJson()).customBackgroundPath,
      'C:\\Fumic\\backgrounds\\custom_background.jpg',
    );
    expect(
      settings.copyWith(clearCustomBackgroundPath: true).customBackgroundPath,
      isNull,
    );
  });

  test('new wallpaper selections survive saved preferences', () {
    for (final name in ['Sakura Night', 'Samurai Night', 'Matrix Rain']) {
      final index = VisualizerBackground.presets.indexWhere(
        (background) => background.name == name,
      );
      final settings = const VisualizerSettings().copyWith(
        backgroundIndex: index,
      );
      final restored = VisualizerSettings.fromJson(settings.toJson());
      expect(restored.background.name, name);
      expect(restored.backgroundIndex, index);
    }
  });

  test(
    'appearance opacity survives preferences and handles invalid values',
    () {
      final settings = const VisualizerSettings().copyWith(
        cardOpacity: 0.23,
        backgroundOpacity: 0.67,
      );
      final restored = VisualizerSettings.fromJson(settings.toJson());
      expect(restored.effectiveCardOpacity, 0.23);
      expect(restored.effectiveBackgroundOpacity, 0.67);
      expect(
        settings
            .copyWith(cardOpacity: -1, backgroundOpacity: 2)
            .effectiveCardOpacity,
        0,
      );
      expect(
        settings
            .copyWith(cardOpacity: -1, backgroundOpacity: 2)
            .effectiveBackgroundOpacity,
        1,
      );
      expect(
        const VisualizerSettings(cardOpacity: double.nan).effectiveCardOpacity,
        0.35,
      );
    },
  );

  test('fake spectrum decays toward silence when playback stops', () {
    final generator = FakeSpectrumGenerator(42);
    const settings = VisualizerSettings();

    var frame = generator.nextFrame(
      elapsed: const Duration(milliseconds: 120),
      settings: settings,
      playing: true,
      volume: 0.8,
    );
    frame = generator.nextFrame(
      elapsed: const Duration(milliseconds: 240),
      settings: settings,
      playing: true,
      volume: 0.8,
    );
    final activeEnergy = frame.energy;

    for (var step = 0; step < 28; step++) {
      frame = generator.nextFrame(
        elapsed: Duration(milliseconds: 360 + step * 120),
        settings: settings,
        playing: false,
        volume: 0.8,
      );
    }

    expect(activeEnergy, greaterThan(0));
    expect(frame.energy, lessThan(activeEnergy * 0.05));
    expect(frame.values.reduce((a, b) => a > b ? a : b), lessThan(0.01));
  });
}
