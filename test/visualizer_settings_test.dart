import 'package:flutter_test/flutter_test.dart';
import 'package:fumic/features/visualizer/fake_spectrum_generator.dart';
import 'package:fumic/src/models/visualizer_settings.dart';

void main() {
  test('visualizer defaults match release settings', () {
    const settings = VisualizerSettings();

    expect(settings.enabled, isTrue);
    expect(settings.effectiveFps, 30);
    expect(settings.effectiveWaveformBars, 128);
    expect(settings.effectiveParticleCount, 0);
    expect(settings.glowStrength, VisualizerGlowStrength.off);
    expect(settings.backgroundIndex, 4);
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
    expect(settings.backgroundIndex, 4);
    expect(settings.effectiveWaveformBars, 128);
    expect(settings.effectiveParticleCount, 0);
    expect(settings.glowStrength, VisualizerGlowStrength.off);
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
