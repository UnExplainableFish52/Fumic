import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/fumic_page.dart';
import '../models/media_kind.dart';

Map<ShortcutActivator, Intent> fumicShortcuts({
  FumicPage page = FumicPage.home,
  bool textInputFocused = false,
  bool searchFocused = false,
  bool visualizerOpen = false,
}) {
  if (searchFocused) {
    return <ShortcutActivator, Intent>{
      const SingleActivator(LogicalKeyboardKey.f11, includeRepeats: false):
          const ToggleFullscreenIntent(),
      const SingleActivator(LogicalKeyboardKey.keyK, control: true):
          const FocusSearchIntent(),
      const SingleActivator(LogicalKeyboardKey.keyB, control: true):
          const AddSelectedToPlaylistIntent(),
      const SingleActivator(
        LogicalKeyboardKey.keyB,
        control: true,
        shift: true,
      ): const AddSelectedToPlaylistIntent(),
      const SingleActivator(LogicalKeyboardKey.keyH, control: true):
          const PageIntent(FumicPage.home),
      const SingleActivator(LogicalKeyboardKey.keyP, control: true):
          const PageIntent(FumicPage.playlists),
      const SingleActivator(LogicalKeyboardKey.enter, control: true):
          const ActivateSelectedIntent(),
      const SingleActivator(LogicalKeyboardKey.numpadEnter, control: true):
          const ActivateSelectedIntent(),
      const SingleActivator(LogicalKeyboardKey.enter):
          const ActivateSelectedIntent(),
      const SingleActivator(LogicalKeyboardKey.numpadEnter):
          const ActivateSelectedIntent(),
      const SingleActivator(LogicalKeyboardKey.arrowDown):
          const MoveSelectionIntent(1),
      const SingleActivator(LogicalKeyboardKey.arrowUp):
          const MoveSelectionIntent(-1),
      const SingleActivator(LogicalKeyboardKey.escape): const EscapeIntent(),
    };
  }

  if (textInputFocused) {
    return <ShortcutActivator, Intent>{
      const SingleActivator(LogicalKeyboardKey.f11, includeRepeats: false):
          const ToggleFullscreenIntent(),
    };
  }

  final shortcuts = <ShortcutActivator, Intent>{
    const SingleActivator(LogicalKeyboardKey.f11, includeRepeats: false):
        const ToggleFullscreenIntent(),
    const SingleActivator(LogicalKeyboardKey.keyE, includeRepeats: false):
        const ToggleFullPlayerIntent(),
    const SingleActivator(LogicalKeyboardKey.keyI, includeRepeats: false):
        const MinimizeAppIntent(),
    const SingleActivator(LogicalKeyboardKey.keyB, includeRepeats: false):
        const TogglePlayerControlsIntent(),
    const SingleActivator(LogicalKeyboardKey.space): const TogglePlayIntent(),
    const SingleActivator(LogicalKeyboardKey.keyJ): const SeekIntent(-5),
    const SingleActivator(LogicalKeyboardKey.keyK, includeRepeats: false):
        const TogglePlayIntent(),
    const SingleActivator(LogicalKeyboardKey.keyL): const SeekIntent(5),
    const SingleActivator(LogicalKeyboardKey.digit0):
        const PercentageSeekIntent(0),
    const SingleActivator(LogicalKeyboardKey.digit1):
        const PercentageSeekIntent(0.1),
    const SingleActivator(LogicalKeyboardKey.digit2):
        const PercentageSeekIntent(0.2),
    const SingleActivator(LogicalKeyboardKey.digit3):
        const PercentageSeekIntent(0.3),
    const SingleActivator(LogicalKeyboardKey.digit4):
        const PercentageSeekIntent(0.4),
    const SingleActivator(LogicalKeyboardKey.digit5):
        const PercentageSeekIntent(0.5),
    const SingleActivator(LogicalKeyboardKey.digit6):
        const PercentageSeekIntent(0.6),
    const SingleActivator(LogicalKeyboardKey.digit7):
        const PercentageSeekIntent(0.7),
    const SingleActivator(LogicalKeyboardKey.digit8):
        const PercentageSeekIntent(0.8),
    const SingleActivator(LogicalKeyboardKey.digit9):
        const PercentageSeekIntent(0.9),
    const SingleActivator(LogicalKeyboardKey.numpad0):
        const PercentageSeekIntent(0),
    const SingleActivator(LogicalKeyboardKey.numpad1):
        const PercentageSeekIntent(0.1),
    const SingleActivator(LogicalKeyboardKey.numpad2):
        const PercentageSeekIntent(0.2),
    const SingleActivator(LogicalKeyboardKey.numpad3):
        const PercentageSeekIntent(0.3),
    const SingleActivator(LogicalKeyboardKey.numpad4):
        const PercentageSeekIntent(0.4),
    const SingleActivator(LogicalKeyboardKey.numpad5):
        const PercentageSeekIntent(0.5),
    const SingleActivator(LogicalKeyboardKey.numpad6):
        const PercentageSeekIntent(0.6),
    const SingleActivator(LogicalKeyboardKey.numpad7):
        const PercentageSeekIntent(0.7),
    const SingleActivator(LogicalKeyboardKey.numpad8):
        const PercentageSeekIntent(0.8),
    const SingleActivator(LogicalKeyboardKey.numpad9):
        const PercentageSeekIntent(0.9),
    const SingleActivator(LogicalKeyboardKey.arrowRight): const SeekIntent(5),
    const SingleActivator(LogicalKeyboardKey.arrowLeft): const SeekIntent(-5),
    const SingleActivator(LogicalKeyboardKey.arrowRight, shift: true):
        const SeekIntent(10),
    const SingleActivator(LogicalKeyboardKey.arrowLeft, shift: true):
        const SeekIntent(-10),
    const SingleActivator(LogicalKeyboardKey.arrowRight, control: true):
        const NextIntent(),
    const SingleActivator(LogicalKeyboardKey.arrowLeft, control: true):
        const PreviousIntent(),
    const SingleActivator(LogicalKeyboardKey.arrowUp, control: true):
        const VolumeIntent(0.05),
    const SingleActivator(LogicalKeyboardKey.arrowDown, control: true):
        const VolumeIntent(-0.05),
    const SingleActivator(LogicalKeyboardKey.keyK, control: true):
        const FocusSearchIntent(),
    const SingleActivator(LogicalKeyboardKey.keyR, control: true):
        const RefreshLibraryIntent(),
    const SingleActivator(LogicalKeyboardKey.keyB, control: true):
        const AddSelectedToPlaylistIntent(),
    const SingleActivator(LogicalKeyboardKey.keyB, control: true, shift: true):
        const AddSelectedToPlaylistIntent(),
    const SingleActivator(LogicalKeyboardKey.keyW, control: true):
        const QuitIntent(),
    const SingleActivator(LogicalKeyboardKey.keyH, control: true):
        const PageIntent(FumicPage.home),
    const SingleActivator(LogicalKeyboardKey.keyP, control: true):
        const PageIntent(FumicPage.playlists),
    const SingleActivator(LogicalKeyboardKey.keyS, control: true):
        const PageIntent(FumicPage.settings),
    const SingleActivator(LogicalKeyboardKey.keyI, control: true):
        const PageIntent(FumicPage.info),
    const SingleActivator(LogicalKeyboardKey.keyA, control: true):
        const TabIntent(MediaKind.audio),
    const SingleActivator(LogicalKeyboardKey.keyV, control: true):
        const TabIntent(MediaKind.video),
    const SingleActivator(
      LogicalKeyboardKey.keyF,
      control: true,
      includeRepeats: false,
    ): const ToggleFullPlayerIntent(),
    const SingleActivator(LogicalKeyboardKey.keyF, shift: true):
        const ToggleFullscreenIntent(),
    const SingleActivator(
      LogicalKeyboardKey.keyE,
      control: true,
      includeRepeats: false,
    ): const ToggleVisualizerIntent(),
    const SingleActivator(LogicalKeyboardKey.keyV):
        const ToggleVisualizerIntent(),
    const SingleActivator(LogicalKeyboardKey.keyF, includeRepeats: false):
        const ToggleFullPlayerIntent(),
    const SingleActivator(LogicalKeyboardKey.keyG):
        const CycleVisualizerQualityIntent(),
    const SingleActivator(LogicalKeyboardKey.keyP):
        const ToggleVisualizerParticlesIntent(),
    const SingleActivator(LogicalKeyboardKey.keyM, control: true):
        const MuteIntent(),
    const SingleActivator(LogicalKeyboardKey.keyS, shift: true):
        const ShuffleIntent(),
    const SingleActivator(LogicalKeyboardKey.keyL, shift: true):
        const LoopIntent(),
    const SingleActivator(LogicalKeyboardKey.comma, shift: true):
        const PlaybackSpeedIntent(-0.1),
    const SingleActivator(LogicalKeyboardKey.period, shift: true):
        const PlaybackSpeedIntent(0.1),
    const SingleActivator(LogicalKeyboardKey.escape): const EscapeIntent(),
  };

  if (visualizerOpen) {
    shortcuts.remove(
      const SingleActivator(LogicalKeyboardKey.keyB, control: true),
    );
    shortcuts.addAll({
      const SingleActivator(
        LogicalKeyboardKey.keyB,
        control: true,
        includeRepeats: false,
      ): const TogglePlayerControlsIntent(),
      const SingleActivator(LogicalKeyboardKey.arrowDown):
          const AdjustVisualizerIntensityIntent(-1),
      const SingleActivator(LogicalKeyboardKey.arrowUp):
          const AdjustVisualizerIntensityIntent(1),
    });
    return shortcuts;
  }

  if (page == FumicPage.playlists) {
    shortcuts.addAll({
      const SingleActivator(LogicalKeyboardKey.enter):
          const ActivateSelectedPlaylistIntent(),
      const SingleActivator(LogicalKeyboardKey.numpadEnter):
          const ActivateSelectedPlaylistIntent(),
      const SingleActivator(LogicalKeyboardKey.enter, control: true):
          const ActivateSelectedPlaylistIntent(),
      const SingleActivator(LogicalKeyboardKey.numpadEnter, control: true):
          const ActivateSelectedPlaylistIntent(),
      const SingleActivator(LogicalKeyboardKey.arrowDown):
          const MovePlaylistSelectionIntent(1),
      const SingleActivator(LogicalKeyboardKey.arrowUp):
          const MovePlaylistSelectionIntent(-1),
      const SingleActivator(LogicalKeyboardKey.keyN, control: true):
          const StartCreatePlaylistIntent(),
      const SingleActivator(LogicalKeyboardKey.f2):
          const RenameSelectedPlaylistIntent(),
      const SingleActivator(LogicalKeyboardKey.delete):
          const DeleteSelectedPlaylistIntent(),
    });
    return shortcuts;
  }

  if (page == FumicPage.home) {
    shortcuts.addAll({
      const SingleActivator(LogicalKeyboardKey.enter, control: true):
          const ActivateSelectedIntent(),
      const SingleActivator(LogicalKeyboardKey.numpadEnter, control: true):
          const ActivateSelectedIntent(),
      const SingleActivator(LogicalKeyboardKey.arrowDown):
          const MoveSelectionIntent(1),
      const SingleActivator(LogicalKeyboardKey.arrowUp):
          const MoveSelectionIntent(-1),
    });
  }

  return shortcuts;
}

class FumicShortcutEntry {
  const FumicShortcutEntry({
    required this.keys,
    required this.action,
    required this.section,
  });

  final String keys;
  final String action;
  final String section;
}

const fumicShortcutCatalog = [
  FumicShortcutEntry(
    keys: 'I',
    action: 'Minimize Fumic to the taskbar',
    section: 'Interface',
  ),
  FumicShortcutEntry(
    keys: 'B / Ctrl + B in full player',
    action: 'Show / hide full-player controls (also in Settings > Playback)',
    section: 'Interface',
  ),
  FumicShortcutEntry(
    keys: 'J / K / L',
    action: 'Back 5 seconds / Play or Pause / Forward 5 seconds',
    section: 'Playback',
  ),
  FumicShortcutEntry(
    keys: 'Space',
    action: 'Play / Pause',
    section: 'Playback',
  ),
  FumicShortcutEntry(
    keys: '0-9',
    action: 'Seek to 0%-90%',
    section: 'Playback',
  ),
  FumicShortcutEntry(
    keys: 'Enter / Ctrl + Enter',
    action: 'Play Selected Track',
    section: 'Playback',
  ),
  FumicShortcutEntry(
    keys: 'Left / Right',
    action: 'Seek 5 seconds Back / Forward',
    section: 'Playback',
  ),
  FumicShortcutEntry(
    keys: 'Shift + Left / Right',
    action: 'Seek 10 seconds Back / Forward',
    section: 'Playback',
  ),
  FumicShortcutEntry(
    keys: 'Ctrl + Left / Right',
    action: 'Previous / Next Track',
    section: 'Playback',
  ),
  FumicShortcutEntry(
    keys: 'Ctrl + Up / Down',
    action: 'Volume Up / Down',
    section: 'Audio',
  ),
  FumicShortcutEntry(
    keys: 'Ctrl + M',
    action: 'Mute / Unmute',
    section: 'Audio',
  ),
  FumicShortcutEntry(
    keys: 'Shift + S',
    action: 'Toggle Shuffle',
    section: 'Playback',
  ),
  FumicShortcutEntry(
    keys: 'Shift + L',
    action: 'Toggle Loop',
    section: 'Playback',
  ),
  FumicShortcutEntry(
    keys: 'Shift + < / >',
    action: 'Playback Speed Down / Up',
    section: 'Playback',
  ),
  FumicShortcutEntry(
    keys: 'Up / Down',
    action: 'Move selected media item',
    section: 'Navigation',
  ),
  FumicShortcutEntry(
    keys: 'Ctrl + K',
    action: 'Focus Search',
    section: 'Navigation',
  ),
  FumicShortcutEntry(
    keys: 'Escape',
    action: 'Unfocus Search / Exit Player',
    section: 'Navigation',
  ),
  FumicShortcutEntry(
    keys: 'Ctrl + H',
    action: 'Go to Home',
    section: 'Interface',
  ),
  FumicShortcutEntry(
    keys: 'Ctrl + P',
    action: 'Go to Playlists',
    section: 'Interface',
  ),
  FumicShortcutEntry(
    keys: 'Ctrl + S',
    action: 'Go to Settings',
    section: 'Interface',
  ),
  FumicShortcutEntry(
    keys: 'Ctrl + I',
    action: 'Go to Info',
    section: 'Interface',
  ),
  FumicShortcutEntry(
    keys: 'Ctrl + A',
    action: 'Switch to Audio Tab',
    section: 'Audio',
  ),
  FumicShortcutEntry(
    keys: 'Ctrl + V',
    action: 'Switch to Video Tab',
    section: 'Video',
  ),
  FumicShortcutEntry(
    keys: 'Ctrl + F',
    action: 'Toggle video / visualizer player and library',
    section: 'Interface',
  ),
  FumicShortcutEntry(
    keys: 'Ctrl + R',
    action: 'Refresh Current Library',
    section: 'Library',
  ),
  FumicShortcutEntry(
    keys: 'Ctrl + B in library / Ctrl + Shift + B anywhere',
    action: 'Add selected item to playlist',
    section: 'Library',
  ),
  FumicShortcutEntry(
    keys: 'Ctrl + N in Playlists',
    action: 'Create playlist',
    section: 'Playlists',
  ),
  FumicShortcutEntry(
    keys: 'F2 in Playlists',
    action: 'Rename selected playlist',
    section: 'Playlists',
  ),
  FumicShortcutEntry(
    keys: 'Delete in Playlists',
    action: 'Confirm delete selected playlist',
    section: 'Playlists',
  ),
  FumicShortcutEntry(
    keys: 'Enter in Playlists',
    action: 'Play selected playlist',
    section: 'Playlists',
  ),
  FumicShortcutEntry(
    keys: 'Up / Down in Playlists',
    action: 'Move selected playlist',
    section: 'Playlists',
  ),
  FumicShortcutEntry(
    keys: 'Ctrl + W',
    action: 'Quit App',
    section: 'Interface',
  ),
  FumicShortcutEntry(
    keys: 'Ctrl + E',
    action: 'Toggle video / visualizer player and library',
    section: 'Interface',
  ),
  FumicShortcutEntry(
    keys: 'V',
    action: 'Toggle Visualizer',
    section: 'Interface',
  ),
  FumicShortcutEntry(
    keys: 'F / E',
    action: 'Toggle video / visualizer player and library',
    section: 'Interface',
  ),
  FumicShortcutEntry(
    keys: 'G',
    action: 'Cycle Visualizer Quality',
    section: 'Interface',
  ),
  FumicShortcutEntry(
    keys: 'P',
    action: 'Toggle Visualizer Particles',
    section: 'Interface',
  ),
  FumicShortcutEntry(
    keys: 'Up / Down in Visualizer',
    action: 'Visualizer Intensity Up / Down',
    section: 'Interface',
  ),
  FumicShortcutEntry(
    keys: 'F11 / Shift + F',
    action: 'Toggle window fullscreen',
    section: 'Interface',
  ),
];

class TogglePlayIntent extends Intent {
  const TogglePlayIntent();
}

class ActivateSelectedIntent extends Intent {
  const ActivateSelectedIntent();
}

class MoveSelectionIntent extends Intent {
  const MoveSelectionIntent(this.delta);

  final int delta;
}

class MovePlaylistSelectionIntent extends Intent {
  const MovePlaylistSelectionIntent(this.delta);

  final int delta;
}

class SeekIntent extends Intent {
  const SeekIntent(this.seconds);

  final int seconds;
}

class PercentageSeekIntent extends Intent {
  const PercentageSeekIntent(this.fraction);

  final double fraction;
}

class PreviousIntent extends Intent {
  const PreviousIntent();
}

class NextIntent extends Intent {
  const NextIntent();
}

class VolumeIntent extends Intent {
  const VolumeIntent(this.delta);

  final double delta;
}

class FocusSearchIntent extends Intent {
  const FocusSearchIntent();
}

class RefreshLibraryIntent extends Intent {
  const RefreshLibraryIntent();
}

class AddSelectedToPlaylistIntent extends Intent {
  const AddSelectedToPlaylistIntent();
}

class StartCreatePlaylistIntent extends Intent {
  const StartCreatePlaylistIntent();
}

class RenameSelectedPlaylistIntent extends Intent {
  const RenameSelectedPlaylistIntent();
}

class DeleteSelectedPlaylistIntent extends Intent {
  const DeleteSelectedPlaylistIntent();
}

class ActivateSelectedPlaylistIntent extends Intent {
  const ActivateSelectedPlaylistIntent();
}

class QuitIntent extends Intent {
  const QuitIntent();
}

class PageIntent extends Intent {
  const PageIntent(this.page);

  final FumicPage page;
}

class TabIntent extends Intent {
  const TabIntent(this.kind);

  final MediaKind kind;
}

class ToggleFullPlayerIntent extends Intent {
  const ToggleFullPlayerIntent();
}

class MuteIntent extends Intent {
  const MuteIntent();
}

class ShuffleIntent extends Intent {
  const ShuffleIntent();
}

class LoopIntent extends Intent {
  const LoopIntent();
}

class PlaybackSpeedIntent extends Intent {
  const PlaybackSpeedIntent(this.delta);

  final double delta;
}

class ToggleVisualizerIntent extends Intent {
  const ToggleVisualizerIntent();
}

class MinimizeAppIntent extends Intent {
  const MinimizeAppIntent();
}

class TogglePlayerControlsIntent extends Intent {
  const TogglePlayerControlsIntent();
}

class CycleVisualizerQualityIntent extends Intent {
  const CycleVisualizerQualityIntent();
}

class ToggleVisualizerParticlesIntent extends Intent {
  const ToggleVisualizerParticlesIntent();
}

class AdjustVisualizerIntensityIntent extends Intent {
  const AdjustVisualizerIntensityIntent(this.delta);

  final int delta;
}

class ToggleFullscreenIntent extends Intent {
  const ToggleFullscreenIntent();
}

class EscapeIntent extends Intent {
  const EscapeIntent();
}
