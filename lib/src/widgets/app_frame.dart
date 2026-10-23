import 'package:flutter/material.dart';

import '../models/fumic_page.dart';
import '../models/media_item.dart';
import '../models/media_kind.dart';
import '../models/playlist.dart';
import '../models/visualizer_settings.dart';
import '../services/playback_service.dart';
import '../services/cover_art_repository.dart';
import '../theme/fumic_theme.dart';
import 'home_library.dart';
import 'info_page.dart';
import 'player_bar.dart';
import 'playlists_page.dart';
import 'settings_page.dart';
import 'top_bar.dart';

class AppFrame extends StatelessWidget {
  const AppFrame({
    super.key,
    required this.page,
    required this.tab,
    required this.visibleItems,
    required this.libraryItems,
    required this.selectedItem,
    required this.playback,
    required this.playbackProgress,
    required this.playlists,
    required this.selectedPlaylistId,
    required this.activePlaylistId,
    required this.folders,
    required this.scanning,
    required this.enrichingMetadata,
    required this.libraryError,
    required this.audioCount,
    required this.videoCount,
    required this.visualizerSettings,
    required this.sessionStopwatch,
    required this.homeScrollToTopRequest,
    required this.playlistCreateShortcutRequest,
    required this.playlistRenameShortcutRequest,
    required this.playlistDeleteShortcutRequest,
    required this.searchController,
    required this.searchFocusNode,
    required this.onPageSelected,
    required this.onTabSelected,
    required this.onItemSelected,
    required this.onItemActivated,
    required this.onCoverAction,
    required this.hasCustomCover,
    required this.onPlaylistSelected,
    required this.onPlaylistEditorClosed,
    required this.onPlaylistEditorFocusChanged,
    required this.onCreatePlaylist,
    required this.onRenamePlaylist,
    required this.onDeletePlaylist,
    required this.onPlayPlaylist,
    required this.onShufflePlaylist,
    required this.onAddItemToPlaylist,
    required this.onRemovePlaylistEntry,
    required this.onReorderPlaylistEntry,
    required this.onPlayPause,
    required this.onNext,
    required this.onPrevious,
    required this.onLoop,
    required this.onShuffle,
    required this.onVolumeChanged,
    required this.onMute,
    required this.onSpeedChanged,
    required this.onSeekFraction,
    required this.onFullPlayer,
    required this.onPickFolder,
    required this.onRefreshLibrary,
    required this.onRemoveFolder,
    required this.onClearFolders,
    required this.onVisualizerSettingsChanged,
    required this.onPickCustomBackground,
    required this.onResetCustomBackground,
  });

  final FumicPage page;
  final MediaKind tab;
  final List<MediaItem> visibleItems;
  final List<MediaItem> libraryItems;
  final MediaItem? selectedItem;
  final PlaybackSnapshot playback;
  final ValueNotifier<PlaybackSnapshot> playbackProgress;
  final List<Playlist> playlists;
  final String selectedPlaylistId;
  final String? activePlaylistId;
  final List<String> folders;
  final bool scanning;
  final bool enrichingMetadata;
  final String? libraryError;
  final int audioCount;
  final int videoCount;
  final VisualizerSettings visualizerSettings;
  final Stopwatch sessionStopwatch;
  final int homeScrollToTopRequest;
  final int playlistCreateShortcutRequest;
  final int playlistRenameShortcutRequest;
  final int playlistDeleteShortcutRequest;
  final TextEditingController searchController;
  final FocusNode searchFocusNode;
  final ValueChanged<FumicPage> onPageSelected;
  final ValueChanged<MediaKind> onTabSelected;
  final ValueChanged<MediaItem> onItemSelected;
  final ValueChanged<MediaItem> onItemActivated;
  final Future<void> Function(MediaItem, CoverArtAction) onCoverAction;
  final bool Function(MediaItem) hasCustomCover;
  final ValueChanged<String> onPlaylistSelected;
  final VoidCallback onPlaylistEditorClosed;
  final ValueChanged<bool> onPlaylistEditorFocusChanged;
  final Future<void> Function(String name) onCreatePlaylist;
  final Future<void> Function(String id, String name) onRenamePlaylist;
  final Future<void> Function(String id) onDeletePlaylist;
  final Future<void> Function(String id) onPlayPlaylist;
  final Future<void> Function(String id) onShufflePlaylist;
  final Future<void> Function(String id, MediaItem item) onAddItemToPlaylist;
  final Future<void> Function(String id, String path) onRemovePlaylistEntry;
  final Future<void> Function(String id, int oldIndex, int newIndex)
  onReorderPlaylistEntry;
  final VoidCallback onPlayPause;
  final VoidCallback onNext;
  final VoidCallback onPrevious;
  final VoidCallback onLoop;
  final VoidCallback onShuffle;
  final ValueChanged<double> onVolumeChanged;
  final VoidCallback onMute;
  final ValueChanged<double> onSpeedChanged;
  final ValueChanged<double> onSeekFraction;
  final VoidCallback onFullPlayer;
  final VoidCallback onPickFolder;
  final VoidCallback onRefreshLibrary;
  final ValueChanged<String> onRemoveFolder;
  final VoidCallback onClearFolders;
  final ValueChanged<VisualizerSettings> onVisualizerSettingsChanged;
  final VoidCallback onPickCustomBackground;
  final VoidCallback onResetCustomBackground;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(18, 14, 18, 0),
          child: TopBar(
            page: page,
            tab: tab,
            searchController: searchController,
            searchFocusNode: searchFocusNode,
            onPageSelected: onPageSelected,
            onTabSelected: onTabSelected,
          ),
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 14, 18, 0),
            child: _ContentPanel(
              child: switch (page) {
                FumicPage.home => HomeLibrary(
                  tab: tab,
                  selectedItemPath: selectedItem?.path,
                  currentItemPath: playback.currentItem?.path,
                  playing: playback.playing,
                  query: searchController.text,
                  libraryError: libraryError,
                  items: visibleItems,
                  scanning: scanning,
                  enrichingMetadata: enrichingMetadata,
                  hasFolders: folders.isNotEmpty,
                  audioCount: audioCount,
                  videoCount: videoCount,
                  sessionStopwatch: sessionStopwatch,
                  scrollToTopRequest: homeScrollToTopRequest,
                  onPickFolder: onPickFolder,
                  onRefreshLibrary: onRefreshLibrary,
                  onClearSearch: searchController.clear,
                  onTabSelected: onTabSelected,
                  onItemSelected: onItemSelected,
                  onItemActivated: onItemActivated,
                  onCoverAction: onCoverAction,
                  hasCustomCover: hasCustomCover,
                ),
                FumicPage.playlists => PlaylistsPage(
                  playlists: playlists,
                  selectedPlaylistId: selectedPlaylistId,
                  activePlaylistId: activePlaylistId,
                  currentItemPath: playback.currentItem?.path,
                  playbackPlaying: playback.playing,
                  createShortcutRequest: playlistCreateShortcutRequest,
                  renameShortcutRequest: playlistRenameShortcutRequest,
                  deleteShortcutRequest: playlistDeleteShortcutRequest,
                  libraryItems: libraryItems,
                  addCandidate: playback.currentItem ?? selectedItem,
                  scanning: scanning,
                  onPlaylistSelected: onPlaylistSelected,
                  onEditorClosed: onPlaylistEditorClosed,
                  onEditorFocusChanged: onPlaylistEditorFocusChanged,
                  onCreatePlaylist: onCreatePlaylist,
                  onRenamePlaylist: onRenamePlaylist,
                  onDeletePlaylist: onDeletePlaylist,
                  onPlayPlaylist: onPlayPlaylist,
                  onShufflePlaylist: onShufflePlaylist,
                  onToggleActivePlaylist: onPlayPause,
                  onAddItem: onAddItemToPlaylist,
                  onRemoveEntry: onRemovePlaylistEntry,
                  onReorderEntry: onReorderPlaylistEntry,
                ),
                FumicPage.settings => SettingsPage(
                  playback: playback,
                  onVolumeChanged: onVolumeChanged,
                  onSpeedChanged: onSpeedChanged,
                  onLoop: onLoop,
                  onShuffle: onShuffle,
                  folders: folders,
                  scanning: scanning,
                  libraryError: libraryError,
                  audioCount: audioCount,
                  videoCount: videoCount,
                  visualizerSettings: visualizerSettings,
                  onPickFolder: onPickFolder,
                  onRefreshLibrary: onRefreshLibrary,
                  onRemoveFolder: onRemoveFolder,
                  onClearFolders: onClearFolders,
                  onVisualizerSettingsChanged: onVisualizerSettingsChanged,
                  onPickCustomBackground: onPickCustomBackground,
                  onResetCustomBackground: onResetCustomBackground,
                ),
                FumicPage.info => const InfoPage(),
              },
            ),
          ),
        ),
        ValueListenableBuilder<PlaybackSnapshot>(
          valueListenable: playbackProgress,
          builder: (context, progress, _) => RepaintBoundary(
            child: PlayerBar(
              item: playback.currentItem ?? selectedItem,
              playback: progress,
              onPlayPause: onPlayPause,
              onNext: onNext,
              onPrevious: onPrevious,
              onLoop: onLoop,
              onShuffle: onShuffle,
              onMute: onMute,
              onSpeedChanged: onSpeedChanged,
              onSeekFraction: onSeekFraction,
              onFullPlayer: onFullPlayer,
            ),
          ),
        ),
      ],
    );
  }
}

class _ContentPanel extends StatelessWidget {
  const _ContentPanel({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: FumicTheme.glassDecoration(
        context,
        filled: false,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
      ),
      clipBehavior: Clip.antiAlias,
      child: child,
    );
  }
}
