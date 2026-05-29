import 'visualizer_quality.dart';

class VisualizerSettings {
  const VisualizerSettings({
    this.enabled = true,
    this.performanceMode = false,
    this.showBackgroundImage = true,
    this.backgroundIndex = 4,
    this.customBackgroundPath,
    bool? particles,
    this.showArtwork = true,
    this.startFullscreen = true,
    this.fps = 30,
    this.waveformBars = 128,
    int? particleCount,
    this.glowStrength = VisualizerGlowStrength.off,
    this.intensity = VisualizerIntensity.medium,
    this.backgroundMotion = true,
    this.logoPulse = true,
    this.quality = VisualizerQuality.medium,
  }) : particleCount = particleCount ?? (particles == true ? 90 : 0);

  static const defaultsVersion = 2;

  static const allowedFps = [30, 60];
  static const allowedWaveformBars = [64, 96, 128];
  static const allowedParticleCounts = [0, 40, 90, 150];

  final bool enabled;

  /// Kept for older persisted settings and tests. The new visualizer is fake
  /// spectrum-first, so this no longer switches to real audio analysis.
  final bool performanceMode;
  final bool showBackgroundImage;
  final int backgroundIndex;
  final String? customBackgroundPath;
  final bool showArtwork;
  final bool startFullscreen;
  final int fps;
  final int waveformBars;
  final int particleCount;
  final VisualizerGlowStrength glowStrength;
  final VisualizerIntensity intensity;
  final bool backgroundMotion;
  final bool logoPulse;
  final VisualizerQuality quality;

  bool get particles => effectiveParticleCount > 0;
  int get effectiveFps => _closestAllowed(fps, allowedFps);
  int get effectiveWaveformBars =>
      _closestAllowed(waveformBars, allowedWaveformBars);
  int get effectiveParticleCount =>
      _closestAllowed(particleCount, allowedParticleCounts);

  Duration get frameInterval =>
      Duration(microseconds: (1000000 / effectiveFps).round());

  VisualizerSettings copyWith({
    bool? enabled,
    bool? performanceMode,
    bool? showBackgroundImage,
    int? backgroundIndex,
    String? customBackgroundPath,
    bool clearCustomBackgroundPath = false,
    bool? particles,
    bool? showArtwork,
    bool? startFullscreen,
    int? fps,
    int? waveformBars,
    int? particleCount,
    VisualizerGlowStrength? glowStrength,
    VisualizerIntensity? intensity,
    bool? backgroundMotion,
    bool? logoPulse,
    VisualizerQuality? quality,
  }) {
    final nextParticleCount =
        particleCount ??
        (particles == null
            ? this.particleCount
            : particles
            ? 90
            : 0);
    return VisualizerSettings(
      enabled: enabled ?? this.enabled,
      performanceMode: performanceMode ?? this.performanceMode,
      showBackgroundImage: showBackgroundImage ?? this.showBackgroundImage,
      backgroundIndex: (backgroundIndex ?? this.backgroundIndex).clamp(0, 5),
      customBackgroundPath: clearCustomBackgroundPath
          ? null
          : customBackgroundPath ?? this.customBackgroundPath,
      showArtwork: showArtwork ?? this.showArtwork,
      startFullscreen: startFullscreen ?? this.startFullscreen,
      fps: _closestAllowed(fps ?? this.fps, allowedFps),
      waveformBars: _closestAllowed(
        waveformBars ?? this.waveformBars,
        allowedWaveformBars,
      ),
      particleCount: _closestAllowed(nextParticleCount, allowedParticleCounts),
      glowStrength: glowStrength ?? this.glowStrength,
      intensity: intensity ?? this.intensity,
      backgroundMotion: backgroundMotion ?? this.backgroundMotion,
      logoPulse: logoPulse ?? this.logoPulse,
      quality: quality ?? this.quality,
    );
  }

  VisualizerSettings applyQuality(VisualizerQuality value) {
    return copyWith(
      quality: value,
      fps: value.fps,
      waveformBars: value.waveformBars,
      particleCount: value.particleCount,
      glowStrength: value.glowStrength,
      intensity: value.intensity,
    );
  }

  VisualizerSettings cycleQuality() => applyQuality(quality.next);

  VisualizerSettings toggleParticles() {
    return copyWith(particleCount: particles ? 0 : 90);
  }

  VisualizerSettings adjustIntensity(int delta) {
    return copyWith(intensity: intensity.step(delta));
  }

  factory VisualizerSettings.fromJson(Map<String, dynamic> json) {
    final shouldApplyCurrentDefaults =
        json['visualizerDefaultsVersion'] != defaultsVersion;
    final legacyParticles = json['particles'] as bool?;
    final rawParticleCount = (json['particleCount'] as num?)?.toInt();
    return VisualizerSettings(
      enabled: shouldApplyCurrentDefaults
          ? true
          : json['enabled'] as bool? ?? true,
      performanceMode: json['performanceMode'] as bool? ?? false,
      showBackgroundImage: shouldApplyCurrentDefaults
          ? true
          : json['showBackgroundImage'] as bool? ?? true,
      backgroundIndex:
          (shouldApplyCurrentDefaults
                  ? 4
                  : (json['backgroundIndex'] as num?)?.toInt() ?? 4)
              .clamp(0, 5),
      customBackgroundPath: _stringOrNull(json['customBackgroundPath']),
      particles: legacyParticles,
      showArtwork: json['showArtwork'] as bool? ?? true,
      startFullscreen: json['startFullscreen'] as bool? ?? true,
      fps: _closestAllowed((json['fps'] as num?)?.toInt() ?? 30, allowedFps),
      waveformBars: _closestAllowed(
        shouldApplyCurrentDefaults
            ? 128
            : (json['waveformBars'] as num?)?.toInt() ?? 128,
        allowedWaveformBars,
      ),
      particleCount: _closestAllowed(
        shouldApplyCurrentDefaults
            ? 0
            : rawParticleCount ?? (legacyParticles == true ? 90 : 0),
        allowedParticleCounts,
      ),
      glowStrength: shouldApplyCurrentDefaults
          ? VisualizerGlowStrength.off
          : VisualizerGlowStrength.fromJson(json['glowStrength']),
      intensity: VisualizerIntensity.fromJson(json['intensity']),
      backgroundMotion: json['backgroundMotion'] as bool? ?? true,
      logoPulse: json['logoPulse'] as bool? ?? true,
      quality: VisualizerQuality.fromJson(json['quality']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'enabled': enabled,
      'performanceMode': performanceMode,
      'showBackgroundImage': showBackgroundImage,
      'backgroundIndex': backgroundIndex.clamp(0, 5),
      'customBackgroundPath': customBackgroundPath,
      'particles': particles,
      'showArtwork': showArtwork,
      'startFullscreen': startFullscreen,
      'fps': effectiveFps,
      'waveformBars': effectiveWaveformBars,
      'particleCount': effectiveParticleCount,
      'glowStrength': glowStrength.name,
      'intensity': intensity.name,
      'backgroundMotion': backgroundMotion,
      'logoPulse': logoPulse,
      'quality': quality.name,
      'visualizerDefaultsVersion': defaultsVersion,
    };
  }

  static int _closestAllowed(int value, List<int> allowed) {
    return allowed.reduce((best, option) {
      final bestDistance = (best - value).abs();
      final optionDistance = (option - value).abs();
      return optionDistance < bestDistance ? option : best;
    });
  }

  static String? _stringOrNull(Object? value) {
    if (value is! String) {
      return null;
    }
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }
}
