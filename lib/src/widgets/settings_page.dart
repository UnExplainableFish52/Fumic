import 'package:flutter/material.dart';

import '../models/visualizer_settings.dart';
import '../theme/fumic_theme.dart';
import '../services/playback_service.dart';
import 'shared.dart';
import 'wallpaper_image.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({
    super.key,
    required this.folders,
    required this.scanning,
    required this.libraryError,
    required this.audioCount,
    required this.videoCount,
    required this.visualizerSettings,
    required this.onPickFolder,
    required this.onRefreshLibrary,
    required this.onRemoveFolder,
    required this.onClearFolders,
    required this.onVisualizerSettingsChanged,
    required this.onPickCustomBackground,
    required this.onResetCustomBackground,
    required this.playback,
    required this.onVolumeChanged,
    required this.onSpeedChanged,
    required this.onLoop,
    required this.onShuffle,
  });

  final List<String> folders;
  final bool scanning;
  final String? libraryError;
  final int audioCount;
  final int videoCount;
  final VisualizerSettings visualizerSettings;
  final VoidCallback onPickFolder;
  final VoidCallback onRefreshLibrary;
  final ValueChanged<String> onRemoveFolder;
  final VoidCallback onClearFolders;
  final ValueChanged<VisualizerSettings> onVisualizerSettingsChanged;
  final VoidCallback onPickCustomBackground;
  final VoidCallback onResetCustomBackground;

  final PlaybackSnapshot playback;
  final ValueChanged<double> onVolumeChanged;
  final ValueChanged<double> onSpeedChanged;
  final VoidCallback onLoop;
  final VoidCallback onShuffle;

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  int _section = 0;
  final _scrollController = ScrollController();
  static const _sections = [
    (Icons.folder_open_rounded, 'Library'),
    (Icons.palette_outlined, 'Appearance'),
    (Icons.graphic_eq_rounded, 'Visualizer'),
    (Icons.tune_rounded, 'Playback'),
  ];

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final content = switch (_section) {
      0 => _LibrarySection(
        folders: widget.folders,
        scanning: widget.scanning,
        libraryError: widget.libraryError,
        audioCount: widget.audioCount,
        videoCount: widget.videoCount,
        onPickFolder: widget.onPickFolder,
        onRefreshLibrary: widget.onRefreshLibrary,
        onRemoveFolder: widget.onRemoveFolder,
        onClearFolders: widget.onClearFolders,
      ),
      1 => _AppearanceSection(
        settings: widget.visualizerSettings,
        onChanged: widget.onVisualizerSettingsChanged,
        onPickCustomBackground: widget.onPickCustomBackground,
        onResetCustomBackground: widget.onResetCustomBackground,
      ),
      2 => _VisualizerSection(
        settings: widget.visualizerSettings,
        onChanged: widget.onVisualizerSettingsChanged,
      ),
      _ => _PlaybackSection(
        playback: widget.playback,
        settings: widget.visualizerSettings,
        onChanged: widget.onVisualizerSettingsChanged,
        onVolumeChanged: widget.onVolumeChanged,
        onSpeedChanged: widget.onSpeedChanged,
        onLoop: widget.onLoop,
        onShuffle: widget.onShuffle,
      ),
    };
    return Scrollbar(
      controller: _scrollController,
      child: ListView(
        controller: _scrollController,
        padding: const EdgeInsets.fromLTRB(28, 30, 28, 36),
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'MAKE IT YOURS',
                      style: TextStyle(
                        color: FumicTheme.accent,
                        fontSize: 11,
                        letterSpacing: 2,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Settings',
                      style: TextStyle(
                        fontSize: 34,
                        letterSpacing: -1,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Your library. Your atmosphere. Your way to listen.',
                      style: TextStyle(color: FumicTheme.muted, height: 1.5),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              const SoftBadge(text: 'Stored on this device'),
            ],
          ),
          const SizedBox(height: 26),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (var i = 0; i < _sections.length; i++)
                ChoiceChip(
                  avatar: Icon(
                    _sections[i].$1,
                    size: 18,
                    color: _section == i ? FumicTheme.accent : FumicTheme.muted,
                  ),
                  label: Text(_sections[i].$2),
                  selected: _section == i,
                  showCheckmark: false,
                  selectedColor: FumicTheme.accent.withValues(alpha: 0.12),
                  backgroundColor: FumicTheme.inset,
                  labelStyle: TextStyle(
                    color: _section == i ? FumicTheme.accent : FumicTheme.muted,
                  ),
                  side: BorderSide(
                    color: _section == i
                        ? FumicTheme.accent.withValues(alpha: 0.35)
                        : FumicTheme.edge,
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  onSelected: (_) => setState(() => _section = i),
                ),
            ],
          ),
          const SizedBox(height: 22),
          content,
          const SizedBox(height: 18),
          const Row(
            children: [
              Icon(
                Icons.check_circle_outline_rounded,
                size: 15,
                color: FumicTheme.accent,
              ),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Changes apply immediately. Appearance and visualizer preferences are saved automatically.',
                  style: TextStyle(color: FumicTheme.muted, fontSize: 12),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _LibrarySection extends StatelessWidget {
  const _LibrarySection({
    required this.folders,
    required this.scanning,
    required this.libraryError,
    required this.audioCount,
    required this.videoCount,
    required this.onPickFolder,
    required this.onRefreshLibrary,
    required this.onRemoveFolder,
    required this.onClearFolders,
  });

  final List<String> folders;
  final bool scanning;
  final String? libraryError;
  final int audioCount;
  final int videoCount;
  final VoidCallback onPickFolder;
  final VoidCallback onRefreshLibrary;
  final ValueChanged<String> onRemoveFolder;
  final VoidCallback onClearFolders;

  @override
  Widget build(BuildContext context) {
    return _SettingsGroup(
      icon: Icons.folder_open_rounded,
      title: 'Library & Scanning',
      subtitle:
          '$audioCount audio files and $videoCount videos · Subfolders included.',
      actions: [
        FilledButton.icon(
          onPressed: scanning ? null : onPickFolder,
          icon: const Icon(Icons.add_rounded),
          label: const Text('Add folder'),
        ),
        OutlinedButton.icon(
          onPressed: scanning || folders.isEmpty ? null : onRefreshLibrary,
          icon: const Icon(Icons.refresh_rounded),
          label: const Text('Rescan'),
        ),
        if (folders.isNotEmpty)
          OutlinedButton.icon(
            onPressed: scanning
                ? null
                : () async {
                    final confirmed = await showDialog<bool>(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: const Text('Remove all library folders?'),
                        content: const Text(
                          'This clears the library list. Your files and saved playlists stay on your device.',
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context, false),
                            child: const Text('Cancel'),
                          ),
                          FilledButton(
                            onPressed: () => Navigator.pop(context, true),
                            child: const Text('Remove all'),
                          ),
                        ],
                      ),
                    );
                    if (confirmed == true) onClearFolders();
                  },
            icon: const Icon(Icons.clear_all_rounded),
            label: const Text('Remove all'),
          ),
      ],
      children: [
        if (scanning) ...[
          const LinearProgressIndicator(minHeight: 2),
          const SizedBox(height: 16),
          const Text(
            'Finding your music and videos…',
            style: TextStyle(color: FumicTheme.muted),
          ),
          const SizedBox(height: 16),
        ],
        if (libraryError != null)
          _StatusStrip(
            icon: Icons.warning_rounded,
            text: 'Library scan failed: $libraryError',
            warning: true,
          ),
        if (folders.isEmpty)
          const _StatusStrip(
            icon: Icons.info_rounded,
            text:
                'Add a folder to scan MP3, FLAC, M4A, OGG, OPUS, WAV, MP4, MKV, MOV, and WEBM files.',
          )
        else
          ...folders.map((folder) {
            return _FolderRow(
              folder: folder,
              onRemove: scanning ? null : onRemoveFolder,
            );
          }),
      ],
    );
  }
}

class _VisualizerSection extends StatelessWidget {
  const _VisualizerSection({required this.settings, required this.onChanged});

  final VisualizerSettings settings;
  final ValueChanged<VisualizerSettings> onChanged;

  @override
  Widget build(BuildContext context) {
    return _SettingsGroup(
      icon: Icons.graphic_eq_rounded,
      title: 'Visualizer',
      subtitle:
          'Set the mood with an animated spectrum while your music plays.',
      actions: [_QualityPresets(settings: settings, onChanged: onChanged)],
      children: [
        _SwitchTile(
          icon: Icons.auto_awesome_motion_rounded,
          title: 'Enable visualizer effects',
          subtitle:
              'Turn off to show only the wallpaper while music plays. Hide player controls for a clear view.',
          value: settings.enabled,
          onChanged: (value) => onChanged(settings.copyWith(enabled: value)),
        ),
        _SegmentedSettingTile<int>(
          enabled: settings.enabled,
          icon: Icons.speed_rounded,
          title: 'Visualizer FPS',
          subtitle: '30 FPS uses less power. 60 FPS gives smoother motion.',
          selected: settings.effectiveFps,
          segments: const [
            ButtonSegment(value: 30, label: Text('30')),
            ButtonSegment(value: 60, label: Text('60')),
          ],
          onChanged: (value) => onChanged(settings.copyWith(fps: value)),
        ),
        _SegmentedSettingTile<int>(
          enabled: settings.enabled,
          icon: Icons.graphic_eq_rounded,
          title: 'Waveform detail',
          subtitle: 'Choose how much detail appears around the spectrum ring.',
          selected: settings.effectiveWaveformBars,
          segments: const [
            ButtonSegment(value: 64, label: Text('Low')),
            ButtonSegment(value: 96, label: Text('Medium')),
            ButtonSegment(value: 128, label: Text('High')),
          ],
          onChanged: (value) =>
              onChanged(settings.copyWith(waveformBars: value)),
        ),
        _SegmentedSettingTile<int>(
          enabled: settings.enabled,
          icon: Icons.blur_on_rounded,
          title: 'Particle count',
          subtitle:
              'Add floating particles, or turn them off for a calmer view.',
          selected: settings.effectiveParticleCount,
          segments: const [
            ButtonSegment(value: 0, label: Text('Off')),
            ButtonSegment(value: 40, label: Text('Low')),
            ButtonSegment(value: 90, label: Text('Medium')),
            ButtonSegment(value: 150, label: Text('High')),
          ],
          onChanged: (value) =>
              onChanged(settings.copyWith(particleCount: value)),
        ),
        _SegmentedSettingTile<VisualizerGlowStrength>(
          enabled: settings.enabled,
          icon: Icons.light_mode_rounded,
          title: 'Glow strength',
          subtitle: 'Controls neon bloom, beat bursts, and halo softness.',
          selected: settings.glowStrength,
          segments: const [
            ButtonSegment(
              value: VisualizerGlowStrength.off,
              label: Text('Off'),
            ),
            ButtonSegment(
              value: VisualizerGlowStrength.low,
              label: Text('Low'),
            ),
            ButtonSegment(
              value: VisualizerGlowStrength.medium,
              label: Text('Medium'),
            ),
            ButtonSegment(
              value: VisualizerGlowStrength.high,
              label: Text('High'),
            ),
          ],
          onChanged: (value) =>
              onChanged(settings.copyWith(glowStrength: value)),
        ),
        _SegmentedSettingTile<VisualizerIntensity>(
          enabled: settings.enabled,
          icon: Icons.bolt_rounded,
          title: 'Visualizer intensity',
          subtitle: 'Adjust the energy of the simulated spectrum animation.',
          selected: settings.intensity,
          segments: const [
            ButtonSegment(value: VisualizerIntensity.low, label: Text('Low')),
            ButtonSegment(
              value: VisualizerIntensity.medium,
              label: Text('Medium'),
            ),
            ButtonSegment(value: VisualizerIntensity.high, label: Text('High')),
          ],
          onChanged: (value) => onChanged(settings.copyWith(intensity: value)),
        ),
      ],
    );
  }
}

class _QualityPresets extends StatelessWidget {
  const _QualityPresets({required this.settings, required this.onChanged});
  final VisualizerSettings settings;
  final ValueChanged<VisualizerSettings> onChanged;

  @override
  Widget build(BuildContext context) => Wrap(
    alignment: WrapAlignment.end,
    spacing: 10,
    runSpacing: 10,
    children: [
      for (final quality in VisualizerQuality.values)
        OutlinedButton.icon(
          onPressed: settings.enabled
              ? () => onChanged(settings.applyQuality(quality))
              : null,
          icon: Icon(switch (quality) {
            VisualizerQuality.low => Icons.eco_outlined,
            VisualizerQuality.medium => Icons.balance_rounded,
            VisualizerQuality.high => Icons.auto_awesome_rounded,
          }, size: 18),
          label: Text(switch (quality) {
            VisualizerQuality.low => 'Lightweight',
            VisualizerQuality.medium => 'Balanced',
            VisualizerQuality.high => 'Immersive',
          }),
        ),
    ],
  );
}

class _AppearanceSection extends StatelessWidget {
  const _AppearanceSection({
    required this.settings,
    required this.onChanged,
    required this.onPickCustomBackground,
    required this.onResetCustomBackground,
  });
  final VisualizerSettings settings;
  final ValueChanged<VisualizerSettings> onChanged;
  final VoidCallback onPickCustomBackground;
  final VoidCallback onResetCustomBackground;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      LayoutBuilder(
        builder: (context, constraints) {
          final preview = _Panel(child: _AppearancePreview(settings: settings));
          final transparency = _Panel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const _AppearanceHeading(
                  icon: Icons.opacity_rounded,
                  title: 'Transparency',
                  subtitle: 'Find your balance between artwork and focus.',
                ),
                const SizedBox(height: 20),
                _OpacityControl(
                  sliderKey: const ValueKey('card-opacity-slider'),
                  title: 'Card opacity',
                  description: 'Applies to every card, including idle songs.',
                  value: settings.effectiveCardOpacity,
                  startLabel: 'Clear',
                  endLabel: 'Solid',
                  onChanged: (value) =>
                      onChanged(settings.copyWith(cardOpacity: value)),
                ),
                const SizedBox(height: 18),
                _OpacityControl(
                  sliderKey: const ValueKey('background-opacity-slider'),
                  title: 'Background opacity',
                  description:
                      'Dark overlay behind the cards. Lower reveals more wallpaper.',
                  value: settings.effectiveBackgroundOpacity,
                  startLabel: 'Vivid artwork',
                  endLabel: 'Dark backdrop',
                  onChanged: (value) =>
                      onChanged(settings.copyWith(backgroundOpacity: value)),
                ),
                const SizedBox(height: 10),
                TextButton.icon(
                  onPressed: () => onChanged(
                    settings.copyWith(
                      cardOpacity: 0.35,
                      backgroundOpacity: 0.42,
                    ),
                  ),
                  icon: const Icon(Icons.restart_alt_rounded, size: 17),
                  label: const Text('Reset transparency'),
                ),
              ],
            ),
          );
          if (constraints.maxWidth < 900) {
            return Column(
              children: [preview, const SizedBox(height: 16), transparency],
            );
          }
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(flex: 7, child: preview),
              const SizedBox(width: 16),
              Expanded(flex: 5, child: transparency),
            ],
          );
        },
      ),
      const SizedBox(height: 16),
      _Panel(
        child: _BackgroundSelector(
          settings: settings,
          onChanged: (value) =>
              onChanged(value.copyWith(showBackgroundImage: true)),
          onVisibilityChanged: (value) =>
              onChanged(settings.copyWith(showBackgroundImage: value)),
          onPickCustomBackground: onPickCustomBackground,
          onResetCustomBackground: onResetCustomBackground,
        ),
      ),
      const SizedBox(height: 16),
      _SettingsGroup(
        title: 'Visualizer Screen Options',
        subtitle: 'Choose what to show in Visualizer Mode',
        children: [
          _SwitchTile(
            icon: Icons.motion_photos_on_rounded,
            title: 'Background motion',
            subtitle: 'Slow-moving accents in the fullscreen visualizer.',
            value: settings.backgroundMotion,
            onChanged: settings.enabled
                ? (value) =>
                      onChanged(settings.copyWith(backgroundMotion: value))
                : null,
          ),
          _SwitchTile(
            icon: Icons.album_outlined,
            title: 'Center artwork',
            subtitle:
                'Show the cover or logo in the center. Turning this off leaves the center clear.',
            value: settings.showArtwork,
            onChanged: (value) =>
                onChanged(settings.copyWith(showArtwork: value)),
          ),
          _SwitchTile(
            icon: Icons.radio_button_checked_rounded,
            title: 'Logo pulse',
            subtitle: 'Let the center artwork move with the animation.',
            value: settings.logoPulse,
            onChanged: settings.enabled && settings.showArtwork
                ? (value) => onChanged(settings.copyWith(logoPulse: value))
                : null,
          ),
        ],
      ),
    ],
  );
}

class _AppearanceHeading extends StatelessWidget {
  const _AppearanceHeading({
    required this.icon,
    required this.title,
    required this.subtitle,
  });
  final IconData icon;
  final String title;
  final String subtitle;
  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Icon(icon, color: FumicTheme.accent, size: 22),
      const SizedBox(width: 12),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 5),
            Text(
              subtitle,
              style: const TextStyle(
                color: FumicTheme.muted,
                fontSize: 13,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    ],
  );
}

class _OpacityControl extends StatelessWidget {
  const _OpacityControl({
    required this.sliderKey,
    required this.title,
    required this.description,
    required this.value,
    required this.startLabel,
    required this.endLabel,
    required this.onChanged,
  });
  final Key sliderKey;
  final String title;
  final String description;
  final double value;
  final String startLabel;
  final String endLabel;
  final ValueChanged<double> onChanged;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          Text(
            '${(value * 100).round()}%',
            style: const TextStyle(
              color: FumicTheme.accent,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
      const SizedBox(height: 6),
      Text(
        description,
        style: const TextStyle(
          color: FumicTheme.muted,
          fontSize: 12,
          height: 1.4,
        ),
      ),
      Semantics(
        label: title,
        child: Slider(
          key: sliderKey,
          value: value,
          divisions: 100,
          label: '${(value * 100).round()}%',
          semanticFormatterCallback: (value) =>
              '${(value * 100).round()} percent',
          onChanged: onChanged,
        ),
      ),
      Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            startLabel,
            style: const TextStyle(color: FumicTheme.muted, fontSize: 11),
          ),
          Text(
            endLabel,
            style: const TextStyle(color: FumicTheme.muted, fontSize: 11),
          ),
        ],
      ),
    ],
  );
}

class _AppearancePreview extends StatelessWidget {
  const _AppearancePreview({required this.settings});
  final VisualizerSettings settings;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const _AppearanceHeading(
        icon: Icons.visibility_outlined,
        title: 'Live preview',
        subtitle: 'The same card styling you will see throughout Fumic.',
      ),
      const SizedBox(height: 18),
      ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: SizedBox(
          key: const ValueKey('appearance-live-preview'),
          height: 280,
          width: double.infinity,
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (settings.showBackgroundImage)
                WallpaperImage(settings: settings, cacheWidth: 1200)
              else
                const ColoredBox(color: FumicTheme.background),
              ColoredBox(
                color: FumicTheme.background.withValues(
                  alpha: settings.effectiveBackgroundOpacity,
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SoftBadge(
                      text: !settings.showBackgroundImage
                          ? 'Wallpaper hidden'
                          : settings.customBackgroundPath != null
                          ? 'Custom wallpaper'
                          : settings.background.name,
                    ),
                    const Spacer(),
                    _PreviewCard(
                      opacity: settings.effectiveCardOpacity,
                      playing: true,
                    ),
                    const SizedBox(height: 10),
                    _PreviewCard(
                      opacity: settings.effectiveCardOpacity,
                      playing: false,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    ],
  );
}

class _PreviewCard extends StatelessWidget {
  const _PreviewCard({required this.opacity, required this.playing});
  final double opacity;
  final bool playing;
  @override
  Widget build(BuildContext context) => Container(
    height: 64,
    padding: const EdgeInsets.symmetric(horizontal: 14),
    decoration: BoxDecoration(
      color: const Color(0xFF101828).withValues(alpha: opacity),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(
        color: playing ? FumicTheme.accent : FumicTheme.edge,
        width: playing ? 1.5 : 1,
      ),
    ),
    child: Row(
      children: [
        Icon(
          playing ? Icons.graphic_eq_rounded : Icons.music_note_rounded,
          color: playing ? FumicTheme.accent : FumicTheme.muted,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            playing ? 'Playing card' : 'Library card',
            style: TextStyle(
              color: playing ? FumicTheme.accent : FumicTheme.text,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        if (playing)
          const Icon(
            Icons.equalizer_rounded,
            size: 18,
            color: FumicTheme.accent,
          ),
      ],
    ),
  );
}

class _PlaybackSection extends StatelessWidget {
  const _PlaybackSection({
    required this.playback,
    required this.settings,
    required this.onChanged,
    required this.onVolumeChanged,
    required this.onSpeedChanged,
    required this.onLoop,
    required this.onShuffle,
  });
  final PlaybackSnapshot playback;
  final VisualizerSettings settings;
  final ValueChanged<VisualizerSettings> onChanged;
  final ValueChanged<double> onVolumeChanged;
  final ValueChanged<double> onSpeedChanged;
  final VoidCallback onLoop;
  final VoidCallback onShuffle;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      _SettingsGroup(
        icon: Icons.tune_rounded,
        title: 'Listening preferences',
        subtitle:
            'Adjust the current session. Start fullscreen is saved for your next launch.',
        children: [
          _HoverSurface(
            margin: const EdgeInsets.only(bottom: 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.volume_up_outlined,
                      color: FumicTheme.accent,
                    ),
                    const SizedBox(width: 12),
                    const Expanded(child: Text('Volume')),
                    Text(
                      '${(playback.volume * 100).round()}%',
                      style: const TextStyle(color: FumicTheme.accent),
                    ),
                  ],
                ),
                Slider(
                  value: playback.volume.clamp(0, 1),
                  semanticFormatterCallback: (value) =>
                      'Volume ${(value * 100).round()} percent',
                  onChanged: onVolumeChanged,
                ),
              ],
            ),
          ),
          _HoverSurface(
            margin: const EdgeInsets.only(bottom: 10),
            child: Row(
              children: [
                const Icon(Icons.speed_rounded, color: FumicTheme.accent),
                const SizedBox(width: 12),
                const Expanded(child: Text('Playback speed')),
                PlaybackSpeedControl(
                  speed: playback.speed,
                  onChanged: onSpeedChanged,
                ),
              ],
            ),
          ),
          _SwitchTile(
            icon: Icons.shuffle_rounded,
            title: 'Shuffle',
            subtitle: 'Mix up the order of your current queue.',
            value: playback.shuffle,
            onChanged: (_) => onShuffle(),
          ),
          _SwitchTile(
            icon: Icons.repeat_rounded,
            title: 'Loop',
            subtitle: 'Repeat the current track.',
            value: playback.loop,
            onChanged: (_) => onLoop(),
          ),
          _SwitchTile(
            icon: Icons.fullscreen_rounded,
            title: 'Start fullscreen',
            subtitle: 'Open Fumic in fullscreen when you launch it.',
            value: settings.startFullscreen,
            onChanged: (value) =>
                onChanged(settings.copyWith(startFullscreen: value)),
          ),
          const _StatusStrip(
            icon: Icons.mouse_outlined,
            text:
                'Click a track to select it. Double-click or press Ctrl + Enter to play. Space pauses or resumes playback.',
          ),
        ],
      ),
      const SizedBox(height: 16),
      _PlayerControlsPreferences(settings: settings, onChanged: onChanged),
    ],
  );
}

class _PlayerControlsPreferences extends StatelessWidget {
  const _PlayerControlsPreferences({
    required this.settings,
    required this.onChanged,
  });
  final VisualizerSettings settings;
  final ValueChanged<VisualizerSettings> onChanged;

  @override
  Widget build(BuildContext context) {
    final delay = settings.effectivePlayerControlsHideDelaySeconds;
    final delays = {0, 3, 5, 10, 15, 30, 60, delay}.toList()..sort();
    return _SettingsGroup(
      icon: Icons.video_settings_rounded,
      title: 'Full player controls',
      subtitle:
          'Applies to videos and the visualizer. The Home player bar always stays visible.',
      children: [
        _SwitchTile(
          icon: Icons.visibility_outlined,
          title: 'Show full player controls',
          subtitle:
              'B toggles this setting; Ctrl+B also works in the full player. Restore hidden controls here anytime.',
          value: settings.showPlayerControls,
          onChanged: (value) =>
              onChanged(settings.copyWith(showPlayerControls: value)),
        ),
        _HoverSurface(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Hide after inactivity'),
              const SizedBox(height: 8),
              DropdownButtonFormField<int>(
                key: ValueKey('player-controls-delay-$delay'),
                initialValue: delay,
                decoration: const InputDecoration(labelText: 'Auto-hide delay'),
                items: [
                  for (final seconds in delays)
                    DropdownMenuItem(
                      value: seconds,
                      child: Text(
                        seconds == 0
                            ? 'Never hide automatically'
                            : '$seconds seconds',
                      ),
                    ),
                ],
                onChanged: settings.showPlayerControls
                    ? (value) {
                        if (value != null) {
                          onChanged(
                            settings.copyWith(
                              playerControlsHideDelaySeconds: value,
                            ),
                          );
                        }
                      }
                    : null,
              ),
              const SizedBox(height: 8),
              const Text(
                'Move the pointer, touch the player, or use a playback shortcut to show controls again.',
                style: TextStyle(color: FumicTheme.muted, fontSize: 12),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _SettingsGroup extends StatelessWidget {
  const _SettingsGroup({
    this.icon,
    required this.title,
    required this.subtitle,
    required this.children,
    this.actions = const [],
  });

  final IconData? icon;
  final String title;
  final String subtitle;
  final List<Widget> children;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final heading = Row(
      children: [
        if (icon != null) ...[_SectionIcon(icon!), const SizedBox(width: 14)],
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: const TextStyle(color: FumicTheme.muted, fontSize: 14),
              ),
            ],
          ),
        ),
      ],
    );
    return _Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              if (actions.isEmpty) return heading;
              final buttons = Wrap(
                alignment: WrapAlignment.end,
                spacing: 10,
                runSpacing: 10,
                children: actions,
              );
              if (constraints.maxWidth >= 900) {
                return Row(
                  children: [
                    Expanded(child: heading),
                    const SizedBox(width: 16),
                    buttons,
                  ],
                );
              }
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  heading,
                  const SizedBox(height: 12),
                  Align(alignment: Alignment.centerRight, child: buttons),
                ],
              );
            },
          ),
          const SizedBox(height: 18),
          ...children,
        ],
      ),
    );
  }
}

class _FolderRow extends StatelessWidget {
  const _FolderRow({required this.folder, required this.onRemove});

  final String folder;
  final ValueChanged<String>? onRemove;

  @override
  Widget build(BuildContext context) {
    return _HoverSurface(
      margin: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          const Icon(Icons.folder_rounded, color: Color(0xFFFFC247)),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              folder,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          IconButton(
            tooltip: 'Remove folder',
            onPressed: onRemove == null ? null : () => onRemove!(folder),
            icon: const Icon(Icons.close_rounded),
          ),
        ],
      ),
    );
  }
}

class _SwitchTile extends StatelessWidget {
  const _SwitchTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    return _HoverSurface(
      margin: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Icon(icon, color: FumicTheme.accent),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  style: const TextStyle(color: FumicTheme.muted, fontSize: 13),
                ),
              ],
            ),
          ),
          Switch(value: value, onChanged: onChanged),
        ],
      ),
    );
  }
}

class _SegmentedSettingTile<T extends Object> extends StatelessWidget {
  const _SegmentedSettingTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.segments,
    required this.onChanged,
    this.enabled = true,
  });

  final bool enabled;
  final IconData icon;
  final String title;
  final String subtitle;
  final T selected;
  final List<ButtonSegment<T>> segments;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    return _HoverSurface(
      margin: const EdgeInsets.only(bottom: 10),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final picker = SegmentedButton<T>(
            style: const ButtonStyle(visualDensity: VisualDensity.compact),
            segments: segments,
            selected: {selected},
            showSelectedIcon: false,
            onSelectionChanged: enabled
                ? (selection) => onChanged(selection.single)
                : null,
          );
          final copy = Row(
            children: [
              Icon(icon, color: FumicTheme.accent),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        color: FumicTheme.muted,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );

          if (constraints.maxWidth < 720) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                copy,
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerRight,
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: picker,
                  ),
                ),
              ],
            );
          }
          return Row(
            children: [
              Expanded(child: copy),
              picker,
            ],
          );
        },
      ),
    );
  }
}

class _BackgroundSelector extends StatelessWidget {
  const _BackgroundSelector({
    required this.settings,
    required this.onChanged,
    required this.onVisibilityChanged,
    required this.onPickCustomBackground,
    required this.onResetCustomBackground,
  });
  final VisualizerSettings settings;
  final ValueChanged<VisualizerSettings> onChanged;
  final ValueChanged<bool> onVisibilityChanged;
  final VoidCallback onPickCustomBackground;
  final VoidCallback onResetCustomBackground;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(
        children: [
          const Expanded(
            child: _AppearanceHeading(
              icon: Icons.wallpaper_rounded,
              title: 'Wallpaper',
              subtitle: 'Pick a scene or bring a favorite image of your own.',
            ),
          ),
          const SizedBox(width: 12),
          Semantics(
            label: 'Show wallpaper',
            child: Switch(
              value: settings.showBackgroundImage,
              onChanged: onVisibilityChanged,
            ),
          ),
        ],
      ),
      const SizedBox(height: 22),
      Wrap(
        spacing: 12,
        runSpacing: 16,
        children: [
          for (
            var index = 0;
            index < VisualizerBackground.presets.length;
            index++
          )
            _BackgroundChoice(
              index: index,
              selected:
                  settings.customBackgroundPath == null &&
                  settings.effectiveBackgroundIndex == index,
              onTap: () => onChanged(
                settings.copyWith(
                  backgroundIndex: index,
                  clearCustomBackgroundPath: true,
                ),
              ),
            ),
          if (settings.customBackgroundPath != null)
            _CustomBackgroundChoice(path: settings.customBackgroundPath!),
        ],
      ),
      const SizedBox(height: 22),
      Wrap(
        spacing: 10,
        runSpacing: 10,
        children: [
          OutlinedButton.icon(
            onPressed: onPickCustomBackground,
            icon: const Icon(Icons.add_photo_alternate_outlined),
            label: Text(
              settings.customBackgroundPath == null
                  ? 'Choose image'
                  : 'Change image',
            ),
          ),
          if (settings.customBackgroundPath != null)
            TextButton.icon(
              onPressed: onResetCustomBackground,
              icon: const Icon(Icons.restart_alt_rounded),
              label: const Text('Use presets'),
            ),
        ],
      ),
    ],
  );
}

class _BackgroundChoice extends StatelessWidget {
  const _BackgroundChoice({
    required this.index,
    required this.selected,
    required this.onTap,
  });
  final int index;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final background = VisualizerBackground.presets[index];
    return Semantics(
      selected: selected,
      button: true,
      child: Tooltip(
        message: background.name,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: SizedBox(
            width: 144,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 140),
                  width: 144,
                  height: 86,
                  padding: const EdgeInsets.all(3),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: selected
                          ? FumicTheme.accent
                          : Colors.white.withValues(alpha: 0.12),
                      width: selected ? 2 : 1,
                    ),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(7),
                    child: Image.asset(
                      background.asset,
                      fit: BoxFit.cover,
                      cacheWidth: 432,
                      filterQuality: FilterQuality.low,
                      errorBuilder: (context, error, stackTrace) =>
                          const ColoredBox(
                            color: FumicTheme.background,
                            child: Icon(Icons.broken_image_outlined),
                          ),
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  background.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    color: selected ? FumicTheme.accent : FumicTheme.muted,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CustomBackgroundChoice extends StatelessWidget {
  const _CustomBackgroundChoice({required this.path});

  final String path;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: 'Custom background',
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        width: 92,
        height: 54,
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(9),
          border: Border.all(color: FumicTheme.accent, width: 2),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: WallpaperImage(
            settings: VisualizerSettings(customBackgroundPath: path),
            cacheWidth: 276,
            errorPlaceholder: const _MissingCustomBackgroundPreview(),
          ),
        ),
      ),
    );
  }
}

class _MissingCustomBackgroundPreview extends StatelessWidget {
  const _MissingCustomBackgroundPreview();

  @override
  Widget build(BuildContext context) {
    return const ColoredBox(
      color: Color(0xFF202A35),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.broken_image_rounded, size: 18),
          SizedBox(height: 2),
          Text(
            'Missing',
            style: TextStyle(fontSize: 10, color: FumicTheme.muted),
          ),
        ],
      ),
    );
  }
}

class _StatusStrip extends StatelessWidget {
  const _StatusStrip({
    required this.icon,
    required this.text,
    this.warning = false,
  });

  final IconData icon;
  final String text;
  final bool warning;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: warning ? const Color(0xFF3C252A) : const Color(0xFF182431),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: warning
              ? const Color(0xFFD96C7A)
              : Colors.white.withValues(alpha: 0.08),
        ),
      ),
      child: Row(
        children: [
          Icon(
            icon,
            color: warning ? const Color(0xFFFF9AA8) : FumicTheme.accent,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}

class _HoverSurface extends StatefulWidget {
  const _HoverSurface({required this.child, this.margin});

  final Widget child;
  final EdgeInsetsGeometry? margin;

  @override
  State<_HoverSurface> createState() => _HoverSurfaceState();
}

class _HoverSurfaceState extends State<_HoverSurface> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        curve: Curves.easeOut,
        margin: widget.margin,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        decoration: BoxDecoration(
          color: _hovered ? const Color(0x99101828) : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: _hovered
                ? FumicTheme.accent.withValues(alpha: 0.32)
                : Colors.white.withValues(alpha: 0.07),
          ),
        ),
        child: widget.child,
      ),
    );
  }
}

class _Panel extends StatelessWidget {
  const _Panel({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: FumicTheme.cardFill(context),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: FumicTheme.edge),
      ),
      child: child,
    );
  }
}

class _SectionIcon extends StatelessWidget {
  const _SectionIcon(this.icon);

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 42,
      height: 42,
      decoration: BoxDecoration(
        color: const Color(0xFF132E35),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: FumicTheme.accent.withValues(alpha: 0.45)),
      ),
      child: Icon(icon, color: FumicTheme.accent),
    );
  }
}
