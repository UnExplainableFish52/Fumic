import 'dart:io';

import 'package:flutter/material.dart';

import '../models/visualizer_settings.dart';
import '../theme/fumic_theme.dart';
import 'shared.dart';

class SettingsPage extends StatelessWidget {
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

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(28, 30, 28, 150),
      children: [
        _SettingsHeader(
          audioCount: audioCount,
          videoCount: videoCount,
          scanning: scanning,
        ),
        const SizedBox(height: 22),
        LayoutBuilder(
          builder: (context, constraints) {
            final wide = constraints.maxWidth >= 1180;
            final library = _LibrarySection(
              folders: folders,
              scanning: scanning,
              libraryError: libraryError,
              audioCount: audioCount,
              videoCount: videoCount,
              onPickFolder: onPickFolder,
              onRefreshLibrary: onRefreshLibrary,
              onRemoveFolder: onRemoveFolder,
              onClearFolders: onClearFolders,
            );
            final visualizer = _VisualizerSection(
              settings: visualizerSettings,
              onChanged: onVisualizerSettingsChanged,
              onPickCustomBackground: onPickCustomBackground,
              onResetCustomBackground: onResetCustomBackground,
            );
            if (!wide) {
              return Column(
                children: [library, const SizedBox(height: 16), visualizer],
              );
            }
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(flex: 7, child: library),
                const SizedBox(width: 16),
                Expanded(flex: 5, child: visualizer),
              ],
            );
          },
        ),
        const SizedBox(height: 18),
        const _EssentialsSection(),
        const SizedBox(height: 18),
        const _AdvancedSection(),
      ],
    );
  }
}

class _SettingsHeader extends StatelessWidget {
  const _SettingsHeader({
    required this.audioCount,
    required this.videoCount,
    required this.scanning,
  });

  final int audioCount;
  final int videoCount;
  final bool scanning;

  @override
  Widget build(BuildContext context) {
    return _Panel(
      padding: const EdgeInsets.all(28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Settings',
            style: TextStyle(fontSize: 32, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 8),
          const Text(
            'Tune the player without adding noise. These controls affect the live app and are saved locally.',
            style: TextStyle(color: FumicTheme.muted, fontSize: 15),
          ),
          const SizedBox(height: 18),
          Wrap(
            spacing: 12,
            runSpacing: 10,
            children: [
              SoftBadge(text: '$audioCount audio'),
              SoftBadge(text: '$videoCount video'),
              SoftBadge(text: scanning ? 'Scanning' : 'Ready'),
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
          '$audioCount audio files and $videoCount videos indexed recursively.',
      actions: [
        FilledButton.icon(
          onPressed: onPickFolder,
          icon: const Icon(Icons.add_rounded),
          label: const Text('Add folder'),
        ),
        OutlinedButton.icon(
          onPressed: scanning ? null : onRefreshLibrary,
          icon: const Icon(Icons.refresh_rounded),
          label: const Text('Rescan'),
        ),
        if (folders.isNotEmpty)
          OutlinedButton.icon(
            onPressed: onClearFolders,
            icon: const Icon(Icons.clear_all_rounded),
            label: const Text('Clear'),
          ),
      ],
      children: [
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
            return _FolderRow(folder: folder, onRemove: onRemoveFolder);
          }),
      ],
    );
  }
}

class _VisualizerSection extends StatelessWidget {
  const _VisualizerSection({
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
  Widget build(BuildContext context) {
    return _SettingsGroup(
      icon: Icons.graphic_eq_rounded,
      title: 'Visualizer',
      subtitle:
          'Tune the fake spectrum canvas for motion, detail, and GPU load.',
      children: [
        _SwitchTile(
          icon: Icons.auto_awesome_motion_rounded,
          title: 'Enable visualizer effects',
          subtitle: 'Emergency switch for all animated visualizer effects.',
          value: settings.enabled,
          onChanged: (value) => onChanged(settings.copyWith(enabled: value)),
        ),
        _SegmentedSettingTile<int>(
          icon: Icons.speed_rounded,
          title: 'Visualizer FPS',
          subtitle:
              '30 is the default. Use 60 only when the desktop can spare it.',
          selected: settings.effectiveFps,
          segments: const [
            ButtonSegment(value: 30, label: Text('30')),
            ButtonSegment(value: 60, label: Text('60')),
          ],
          onChanged: (value) => onChanged(settings.copyWith(fps: value)),
        ),
        _SegmentedSettingTile<int>(
          icon: Icons.graphic_eq_rounded,
          title: 'Waveform detail',
          subtitle: 'Low 64 / Medium 96 / High 128 circular bars.',
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
          icon: Icons.blur_on_rounded,
          title: 'Particle count',
          subtitle: 'Off 0 / Low 40 / Medium 90 / High 150 particles.',
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
          icon: Icons.bolt_rounded,
          title: 'Visualizer intensity',
          subtitle:
              'Raises or softens fake bass, bar length, and pulse motion.',
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
        _SwitchTile(
          icon: Icons.image_rounded,
          title: 'Background image',
          subtitle: 'Show the visualizer background artwork.',
          value: settings.showBackgroundImage,
          onChanged: (value) =>
              onChanged(settings.copyWith(showBackgroundImage: value)),
        ),
        _BackgroundSelector(
          settings: settings,
          onChanged: onChanged,
          onPickCustomBackground: onPickCustomBackground,
          onResetCustomBackground: onResetCustomBackground,
        ),
        _SwitchTile(
          icon: Icons.motion_photos_on_rounded,
          title: 'Background motion',
          subtitle:
              'Animate subtle waves and rotating accents behind the ring.',
          value: settings.backgroundMotion,
          onChanged: (value) =>
              onChanged(settings.copyWith(backgroundMotion: value)),
        ),
        _SwitchTile(
          icon: Icons.radio_button_checked_rounded,
          title: 'Logo pulse',
          subtitle: 'Scale the center artwork gently with simulated bass.',
          value: settings.logoPulse,
          onChanged: (value) => onChanged(settings.copyWith(logoPulse: value)),
        ),
        _SwitchTile(
          icon: Icons.album_rounded,
          title: 'Center artwork',
          subtitle: 'Show the current track cover inside the visualizer.',
          value: settings.showArtwork,
          onChanged: (value) =>
              onChanged(settings.copyWith(showArtwork: value)),
        ),
        _SwitchTile(
          icon: Icons.fullscreen_rounded,
          title: 'Start fullscreen',
          subtitle: 'Launch into an immersive full-window player shell.',
          value: settings.startFullscreen,
          onChanged: (value) =>
              onChanged(settings.copyWith(startFullscreen: value)),
        ),
      ],
    );
  }
}

class _EssentialsSection extends StatelessWidget {
  const _EssentialsSection();

  @override
  Widget build(BuildContext context) {
    return const _SettingsGroup(
      icon: Icons.tune_rounded,
      title: 'Core Preferences',
      subtitle: 'Current runtime defaults are lightweight and local-first.',
      children: [
        _SettingTile(
          icon: Icons.palette_rounded,
          title: 'Appearance',
          value: 'Dark, compact, high contrast',
        ),
        _SettingTile(
          icon: Icons.play_circle_rounded,
          title: 'Playback',
          value: 'Keyboard-first queue controls',
        ),
        _SettingTile(
          icon: Icons.memory_rounded,
          title: 'Performance',
          value: 'Async scanning with cached metadata',
        ),
      ],
    );
  }
}

class _AdvancedSection extends StatelessWidget {
  const _AdvancedSection();

  @override
  Widget build(BuildContext context) {
    return const _SettingsGroup(
      icon: Icons.admin_panel_settings_rounded,
      title: 'Advanced',
      subtitle: 'Technical defaults chosen for offline desktop playback.',
      children: [
        _SettingTile(
          icon: Icons.image_rounded,
          title: 'Artwork cache',
          value: 'Embedded covers and generated fallbacks',
        ),
        _SettingTile(
          icon: Icons.storage_rounded,
          title: 'Metadata cache',
          value: 'Duration and thumbnail cache per file signature',
        ),
        _SettingTile(
          icon: Icons.info_rounded,
          title: 'Shortcuts',
          value: 'View the searchable list on the Info page',
        ),
      ],
    );
  }
}

class _SettingsGroup extends StatelessWidget {
  const _SettingsGroup({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.children,
    this.actions = const [],
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final List<Widget> children;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    return _Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 14,
            runSpacing: 12,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              _SectionIcon(icon),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 620),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        color: FumicTheme.muted,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
              if (actions.isNotEmpty) Wrap(spacing: 10, children: actions),
            ],
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
  final ValueChanged<String> onRemove;

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
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
          IconButton(
            tooltip: 'Remove folder',
            onPressed: () => onRemove(folder),
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
  final ValueChanged<bool> onChanged;

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
                    fontWeight: FontWeight.w900,
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
  });

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
            segments: segments,
            selected: {selected},
            showSelectedIcon: false,
            onSelectionChanged: (selection) => onChanged(selection.single),
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
                        fontWeight: FontWeight.w900,
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
                Align(alignment: Alignment.centerRight, child: picker),
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
    required this.onPickCustomBackground,
    required this.onResetCustomBackground,
  });

  final VisualizerSettings settings;
  final ValueChanged<VisualizerSettings> onChanged;
  final VoidCallback onPickCustomBackground;
  final VoidCallback onResetCustomBackground;

  @override
  Widget build(BuildContext context) {
    return _HoverSurface(
      margin: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.wallpaper_rounded, color: FumicTheme.accent),
              SizedBox(width: 12),
              Text(
                'Visualizer background',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              for (var index = 0; index < 6; index++)
                _BackgroundChoice(
                  index: index,
                  selected:
                      settings.customBackgroundPath == null &&
                      settings.backgroundIndex == index,
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
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              OutlinedButton.icon(
                onPressed: onPickCustomBackground,
                icon: const Icon(Icons.upload_file_rounded),
                label: Text(
                  settings.customBackgroundPath == null
                      ? 'Choose image'
                      : 'Change image',
                ),
              ),
              if (settings.customBackgroundPath != null)
                OutlinedButton.icon(
                  onPressed: onResetCustomBackground,
                  icon: const Icon(Icons.restart_alt_rounded),
                  label: const Text('Use presets'),
                ),
            ],
          ),
        ],
      ),
    );
  }
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
    return Tooltip(
      message: 'Background ${index + 1}',
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          width: 92,
          height: 54,
          padding: const EdgeInsets.all(3),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(9),
            border: Border.all(
              color: selected
                  ? FumicTheme.accent
                  : Colors.white.withValues(alpha: 0.12),
              width: selected ? 2 : 1,
            ),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: Image.asset(
              'icons/viz_bg${index + 1}.jpg',
              fit: BoxFit.cover,
              filterQuality: FilterQuality.low,
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
    final file = File(path);
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
          child: file.existsSync()
              ? Image.file(
                  file,
                  fit: BoxFit.cover,
                  filterQuality: FilterQuality.low,
                  errorBuilder: (context, error, stackTrace) {
                    return const _MissingCustomBackgroundPreview();
                  },
                )
              : const _MissingCustomBackgroundPreview(),
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

class _SettingTile extends StatelessWidget {
  const _SettingTile({
    required this.icon,
    required this.title,
    required this.value,
  });

  final IconData icon;
  final String title;
  final String value;

  @override
  Widget build(BuildContext context) {
    return _HoverSurface(
      margin: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Icon(icon, color: FumicTheme.accent),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              title,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900),
            ),
          ),
          const SizedBox(width: 14),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: FumicTheme.muted,
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
            ),
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
        borderRadius: BorderRadius.circular(8),
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
              style: const TextStyle(fontWeight: FontWeight.w800),
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
          color: _hovered ? const Color(0xFF26303C) : const Color(0xFF1A2230),
          borderRadius: BorderRadius.circular(8),
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
  const _Panel({required this.child, this.padding = const EdgeInsets.all(20)});

  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF242C38), Color(0xFF1A2230)],
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.16),
            blurRadius: 24,
            offset: const Offset(0, 14),
          ),
        ],
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
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: FumicTheme.accent.withValues(alpha: 0.45)),
      ),
      child: Icon(icon, color: FumicTheme.accent),
    );
  }
}
