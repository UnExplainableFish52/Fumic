import 'visualizer_quality.dart';
import 'visualizer_background.dart';

class VisualizerSettings {
  const VisualizerSettings({
    this.enabled = true,
    this.performanceMode = false,
    this.showBackgroundImage = true,
    this.backgroundIndex = 0,
    this.customBackgroundPath,
    this.cardOpacity = 0.35,
    this.backgroundOpacity = 0.42,
    bool? particles,
    this.showArtwork = true,
    this.startFullscreen = true,
    this.showPlayerControls = true,
    this.playerControlsHideDelaySeconds = 5,
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
  final double cardOpacity;
  final double backgroundOpacity;
  final bool showArtwork;
  final bool startFullscreen;
  final bool showPlayerControls;
  final int playerControlsHideDelaySeconds;
  int get effectivePlayerControlsHideDelaySeconds =>
      playerControlsHideDelaySeconds.clamp(0, 60);
  final int fps;
  final int waveformBars;
  final int particleCount;
  final VisualizerGlowStrength glowStrength;
  final VisualizerIntensity intensity;
  final bool backgroundMotion;
  final bool logoPulse;
  final VisualizerQuality quality;

  bool get particles => effectiveParticleCount > 0;
  double get effectiveCardOpacity => _opacity(cardOpacity, 0.35);
  double get effectiveBackgroundOpacity => _opacity(backgroundOpacity, 0.42);
  int get effectiveBackgroundIndex =>
      backgroundIndex.clamp(0, VisualizerBackground.presets.length - 1);
  VisualizerBackground get background =>
      VisualizerBackground.presets[effectiveBackgroundIndex];
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
    double? cardOpacity,
    double? backgroundOpacity,
    bool? particles,
    bool? showArtwork,
    bool? startFullscreen,
    bool? showPlayerControls,
    int? playerControlsHideDelaySeconds,
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
      backgroundIndex: (backgroundIndex ?? this.backgroundIndex).clamp(
        0,
        VisualizerBackground.presets.length - 1,
      ),
      customBackgroundPath: clearCustomBackgroundPath
          ? null
          : customBackgroundPath ?? this.customBackgroundPath,
      cardOpacity: _opacity(cardOpacity ?? this.cardOpacity, 0.35),
      backgroundOpacity: _opacity(
        backgroundOpacity ?? this.backgroundOpacity,
        0.42,
      ),
      showArtwork: showArtwork ?? this.showArtwork,
      startFullscreen: startFullscreen ?? this.startFullscreen,
      showPlayerControls: showPlayerControls ?? this.showPlayerControls,
      playerControlsHideDelaySeconds:
          playerControlsHideDelaySeconds ?? this.playerControlsHideDelaySeconds,
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
      backgroundIndex: _backgroundIndexFromJson(
        json,
        shouldApplyCurrentDefaults,
      ),
      customBackgroundPath: _stringOrNull(json['customBackgroundPath']),
      cardOpacity: _opacity(
        (json['cardOpacity'] as num?)?.toDouble() ?? 0.35,
        0.35,
      ),
      backgroundOpacity: _opacity(
        (json['backgroundOpacity'] as num?)?.toDouble() ?? 0.42,
        0.42,
      ),
      particles: legacyParticles,
      showArtwork: json['showArtwork'] as bool? ?? true,
      startFullscreen: json['startFullscreen'] as bool? ?? true,
      showPlayerControls: json['showPlayerControls'] as bool? ?? true,
      playerControlsHideDelaySeconds:
          (json['playerControlsHideDelaySeconds'] as num?)?.toInt() ?? 5,
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
      'backgroundIndex': effectiveBackgroundIndex,
      'backgroundId': background.id,
      'backgroundCatalogVersion': VisualizerBackground.catalogVersion,
      'customBackgroundPath': customBackgroundPath,
      'cardOpacity': effectiveCardOpacity,
      'backgroundOpacity': effectiveBackgroundOpacity,
      'particles': particles,
      'showArtwork': showArtwork,
      'startFullscreen': startFullscreen,
      'showPlayerControls': showPlayerControls,
      'playerControlsHideDelaySeconds': effectivePlayerControlsHideDelaySeconds,
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

  static int _backgroundIndexFromJson(
    Map<String, dynamic> json,
    bool applyDefaults,
  ) {
    final id = json['backgroundId'];
    if (id is String) {
      final index = VisualizerBackground.presets.indexWhere(
        (background) => background.id == id,
      );
      return index < 0 ? 0 : index;
    }
    if (applyDefaults) return 0;
    final index = (json['backgroundIndex'] as num?)?.toInt();
    if (index == null) return 0;
    if (json['backgroundCatalogVersion'] !=
        VisualizerBackground.catalogVersion) {
      return VisualizerBackground.migrateLegacyIndex(index);
    }
    return index.clamp(0, VisualizerBackground.presets.length - 1);
  }

  static int _closestAllowed(int value, List<int> allowed) {
    return allowed.reduce((best, option) {
      final bestDistance = (best - value).abs();
      final optionDistance = (option - value).abs();
      return optionDistance < bestDistance ? option : best;
    });
  }

  static double _opacity(double value, double fallback) =>
      value.isFinite ? value.clamp(0.0, 1.0) : fallback;

  static String? _stringOrNull(Object? value) {
    if (value is! String) {
      return null;
    }
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }
}
