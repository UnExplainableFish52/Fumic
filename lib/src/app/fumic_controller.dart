import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;

import '../models/fumic_page.dart';
import '../models/media_item.dart';
import '../models/media_kind.dart';
import '../models/playlist.dart';
import '../models/playback_speed.dart';
import '../models/visualizer_settings.dart';
import '../services/app_settings_repository.dart';
import '../services/background_image_service.dart';
import '../services/cover_art_repository.dart';
import '../services/media_kit_playback_service.dart';
import '../services/media_library_service.dart';
import '../services/media_metadata_service.dart';
import '../services/playlist_repository.dart';
import '../services/playback_service.dart';

class FumicController extends ChangeNotifier {
  FumicController({
    required this.libraryService,
    required this.playbackService,
    this.appSettingsRepository = const JsonAppSettingsRepository(),
    PlaylistRepository? playlistRepository,
    this.backgroundImageService = const FilePickerBackgroundImageService(),
    this.coverArtRepository = const JsonCoverArtRepository(),
    this.metadataService = const NoopMediaMetadataService(),
  }) : playlistRepository = playlistRepository ?? JsonPlaylistRepository() {
    _lastPlayback = playbackService.snapshot;
    if (_lastPlayback.volume > 0.001) _lastAudibleVolume = _lastPlayback.volume;
    playbackProgress = ValueNotifier(_lastPlayback);
    playbackService.addListener(_onPlaybackChanged);
  }

  factory FumicController.production() {
    return FumicController(
      libraryService: MediaLibraryService.production(),
      playbackService: MediaKitPlaybackService(),
      metadataService: const MediaKitMetadataService(),
    );
  }

  final MediaLibraryService libraryService;
  final PlaybackService playbackService;
  final AppSettingsRepository appSettingsRepository;
  final PlaylistRepository playlistRepository;
  final BackgroundImageService backgroundImageService;
  final CoverArtRepository coverArtRepository;
  final MediaMetadataService metadataService;

  FumicPage page = FumicPage.home;
  MediaKind tab = MediaKind.audio;
  bool fullPlayer = false;
  bool scanning = false;
  bool enrichingMetadata = false;
  bool settingsLoaded = false;
  String? libraryError;
  VisualizerSettings visualizerSettings = const VisualizerSettings();

  List<String> folders = const [];
  List<MediaItem> items = const [];
  List<Playlist> playlists = [Playlist.favourites()];
  String selectedPlaylistId = Playlist.favouritesId;
  String? activePlaylistId;
  int selectedIndex = 0;
  int _metadataGeneration = 0;
  bool _activatingSelected = false;
  String? _lastPlaybackItemPath;
  Map<String, String> _customCovers = {};
  Map<String, String?> _originalCovers = {};
  bool _coverBusy = false;
  bool _backgroundBusy = false;
  int _backgroundGeneration = 0;
  Future<void> _settingsWrites = Future<void>.value();
  Future<void> _backgroundCleanup = Future<void>.value();
  VisualizerSettings _savedVisualizerSettings = const VisualizerSettings();
  bool _disposed = false;
  bool _foregroundActive = true;
  double _lastAudibleVolume = 0.52;
  late PlaybackSnapshot _lastPlayback;
  late final ValueNotifier<PlaybackSnapshot> playbackProgress;

  PlaybackSnapshot get playback => playbackService.snapshot;

  void setForegroundActive(bool active) {
    if (_foregroundActive == active) return;
    _foregroundActive = active;
    if (active) {
      playbackProgress.value = playback;
      notifyListeners();
    }
  }

  List<MediaItem> visibleItems(String query) {
    final normalized = query.trim().toLowerCase();
    final tabItems = items.where((item) => item.kind == tab);
    if (normalized.isEmpty) {
      return tabItems.toList(growable: false);
    }
    return tabItems
        .where((item) {
          return item.title.toLowerCase().contains(normalized) ||
              item.artist.toLowerCase().contains(normalized) ||
              item.path.toLowerCase().contains(normalized);
        })
        .toList(growable: false);
  }

  MediaItem? selectedItem(String query) {
    final visible = visibleItems(query);
    if (visible.isEmpty) {
      return null;
    }
    return visible[selectedIndex.clamp(0, visible.length - 1)];
  }

  int itemCountFor(MediaKind kind) {
    return items.where((item) => item.kind == kind).length;
  }

  Future<void> loadLibrary() async {
    visualizerSettings = await appSettingsRepository.loadVisualizerSettings();
    _savedVisualizerSettings = visualizerSettings;
    _backgroundCleanup = backgroundImageService
        .cleanupUnusedBackgrounds(visualizerSettings.customBackgroundPath)
        .catchError((Object _) {});
    settingsLoaded = true;
    _customCovers = await coverArtRepository.load();
    playlists = await playlistRepository.loadPlaylists();
    _ensureSelectedPlaylist();
    unawaited(
      playbackService.setSoundReactiveVisualizer(
        visualizerSettings.enabled && !visualizerSettings.performanceMode,
      ),
    );
    notifyListeners();
    folders = await libraryService.loadFolders();
    await refreshLibrary();
  }

  Future<void> refreshLibrary() async {
    final generation = ++_metadataGeneration;
    scanning = true;
    enrichingMetadata = false;
    libraryError = null;
    notifyListeners();
    try {
      final scannedItems = await libraryService.scan(List.of(folders));
      if (generation != _metadataGeneration) {
        return;
      }
      _originalCovers = {
        for (final item in scannedItems)
          _pathKey(item.path): item.thumbnailPath,
      };
      items = scannedItems.map(_withCover).toList(growable: false);
      selectedIndex = 0;
      notifyListeners();
      unawaited(_enrichMetadata(generation, items));
    } on Object catch (error) {
      if (generation == _metadataGeneration) {
        libraryError = error.toString();
      }
    } finally {
      if (generation == _metadataGeneration) {
        scanning = false;
        notifyListeners();
      }
    }
  }

  Future<void> addFolder() async {
    final next = await libraryService.addFolder(folders);
    if (listEquals(next, folders)) {
      return;
    }
    folders = next;
    await refreshLibrary();
  }

  Future<void> removeFolder(String folder) async {
    folders = await libraryService.removeFolder(folders, folder);
    await refreshLibrary();
  }

  Future<void> clearFolders() async {
    _metadataGeneration++;
    folders = await libraryService.clearFolders();
    items = const [];
    scanning = false;
    libraryError = null;
    activePlaylistId = null;
    selectedIndex = 0;
    enrichingMetadata = false;
    notifyListeners();
  }

  void selectPage(FumicPage value) {
    page = value;
    fullPlayer = false;
    notifyListeners();
  }

  Playlist get selectedPlaylist {
    return playlists.firstWhere(
      (playlist) => playlist.id == selectedPlaylistId,
      orElse: () => playlists.first,
    );
  }

  List<MediaItem> resolvedPlaylistItems(String playlistId) {
    final playlist = _playlistById(playlistId);
    if (playlist == null) {
      return const [];
    }
    final libraryByPath = {for (final item in items) _pathKey(item.path): item};
    return [
      for (final entry in playlist.entries)
        if (libraryByPath[_pathKey(entry.path)] != null)
          libraryByPath[_pathKey(entry.path)]!,
    ];
  }

  bool playlistContainsPath(String playlistId, String path) {
    final playlist = _playlistById(playlistId);
    if (playlist == null) {
      return false;
    }
    final key = _pathKey(path);
    return playlist.entries.any((entry) => _pathKey(entry.path) == key);
  }

  void selectPlaylist(String id) {
    if (_playlistById(id) == null) {
      return;
    }
    selectedPlaylistId = id;
    page = FumicPage.playlists;
    fullPlayer = false;
    notifyListeners();
  }

  void movePlaylistSelection(int delta) {
    if (playlists.isEmpty) {
      return;
    }
    final currentIndex = playlists.indexWhere(
      (playlist) => playlist.id == selectedPlaylistId,
    );
    final safeIndex = currentIndex < 0 ? 0 : currentIndex;
    final nextIndex = (safeIndex + delta).clamp(0, playlists.length - 1);
    final nextId = playlists[nextIndex].id;
    if (nextId == selectedPlaylistId && page == FumicPage.playlists) {
      return;
    }
    selectedPlaylistId = nextId;
    page = FumicPage.playlists;
    fullPlayer = false;
    notifyListeners();
  }

  Future<Playlist> createPlaylist(String name) async {
    final playlist = Playlist(
      id: _newPlaylistId(),
      name: _uniquePlaylistName(name),
      entries: const [],
    );
    await _setPlaylists([...playlists, playlist], selectedId: playlist.id);
    return playlist;
  }

  Future<Playlist> createPlaylistAndAddItem(String name, MediaItem item) async {
    final playlist = Playlist(
      id: _newPlaylistId(),
      name: _uniquePlaylistName(name),
      entries: [PlaylistEntry(path: item.path)],
    );
    await _setPlaylists([...playlists, playlist], selectedId: playlist.id);
    return playlist;
  }

  Future<void> renamePlaylist(String id, String name) async {
    final playlist = _playlistById(id);
    if (playlist == null || playlist.isProtected) {
      return;
    }
    final nextName = _uniquePlaylistName(name, exceptId: id);
    await _replacePlaylist(id, playlist.copyWith(name: nextName));
  }

  Future<void> deletePlaylist(String id) async {
    final playlist = _playlistById(id);
    if (playlist == null || playlist.isProtected) {
      return;
    }
    final next = playlists.where((value) => value.id != id).toList();
    await _setPlaylists(
      next,
      selectedId: selectedPlaylistId == id
          ? Playlist.favouritesId
          : selectedPlaylistId,
    );
  }

  Future<void> addSelectedToPlaylist(String query, String playlistId) async {
    final item = selectedItem(query);
    if (item == null) {
      return;
    }
    await addItemToPlaylist(item, playlistId);
  }

  Future<void> addItemToPlaylist(MediaItem item, String playlistId) async {
    final playlist = _playlistById(playlistId);
    if (playlist == null || playlistContainsPath(playlistId, item.path)) {
      return;
    }
    await _replacePlaylist(
      playlistId,
      playlist.copyWith(
        entries: [
          ...playlist.entries,
          PlaylistEntry(path: item.path),
        ],
      ),
    );
  }

  Future<void> removePlaylistEntry(String playlistId, String path) async {
    final playlist = _playlistById(playlistId);
    if (playlist == null) {
      return;
    }
    final key = _pathKey(path);
    final nextEntries = playlist.entries
        .where((entry) => _pathKey(entry.path) != key)
        .toList(growable: false);
    await _replacePlaylist(playlistId, playlist.copyWith(entries: nextEntries));
  }

  Future<void> reorderPlaylistEntry(
    String playlistId,
    int oldIndex,
    int newIndex,
  ) async {
    final playlist = _playlistById(playlistId);
    if (playlist == null ||
        oldIndex < 0 ||
        oldIndex >= playlist.entries.length) {
      return;
    }
    final adjustedNewIndex = newIndex > oldIndex ? newIndex - 1 : newIndex;
    if (adjustedNewIndex < 0 || adjustedNewIndex >= playlist.entries.length) {
      return;
    }
    final nextEntries = List<PlaylistEntry>.from(playlist.entries);
    final entry = nextEntries.removeAt(oldIndex);
    nextEntries.insert(adjustedNewIndex, entry);
    await _replacePlaylist(playlistId, playlist.copyWith(entries: nextEntries));
  }

  Future<void> playPlaylist(String playlistId, {bool shuffle = false}) async {
    final queue = resolvedPlaylistItems(playlistId);
    if (queue.isEmpty) {
      return;
    }
    final playbackQueue = List<MediaItem>.from(queue);
    if (shuffle && playbackQueue.length > 1) {
      playbackQueue.shuffle(math.Random());
    }
    await playbackService.openQueue(playbackQueue, 0);
    activePlaylistId = playlistId;
    page = FumicPage.playlists;
    _showFullPlayerForVideo(playbackQueue.first);
    notifyListeners();
  }

  void selectTab(MediaKind value) {
    tab = value;
    page = FumicPage.home;
    fullPlayer = false;
    selectedIndex = 0;
    notifyListeners();
  }

  void selectItem(int index) {
    final visible = visibleItems('');
    selectedIndex = visible.isEmpty ? 0 : index.clamp(0, visible.length - 1);
    notifyListeners();
  }

  void selectItemByPath(String path, String query) {
    final index = _visibleIndexForPath(query, path);
    if (index < 0) {
      return;
    }
    selectedIndex = index;
    notifyListeners();
  }

  void resetSelectionForSearch(String query) {
    final visible = visibleItems(query);
    selectedIndex = visible.isEmpty
        ? 0
        : selectedIndex.clamp(0, visible.length - 1);
    if (selectedIndex != 0 && visible.isNotEmpty) {
      selectedIndex = 0;
    }
    page = FumicPage.home;
    notifyListeners();
  }

  void moveSelection(int delta, String query) {
    final visible = visibleItems(query);
    if (visible.isEmpty) {
      return;
    }
    selectedIndex = (selectedIndex + delta).clamp(0, visible.length - 1);
    page = FumicPage.home;
    notifyListeners();
  }

  Future<void> activateSelected(String query) async {
    if (_activatingSelected) {
      return;
    }
    final visible = visibleItems(query);
    if (visible.isEmpty) {
      return;
    }
    final index = selectedIndex.clamp(0, visible.length - 1);
    await _activateVisibleItem(visible, index);
  }

  Future<void> activateItemByPath(String path, String query) async {
    if (_activatingSelected) {
      return;
    }
    final visible = visibleItems(query);
    final index = _indexForPath(visible, path);
    if (index < 0) {
      return;
    }
    await _activateVisibleItem(visible, index);
  }

  Future<void> playNext(String query) async {
    final visible = visibleItems(query);
    if (playback.currentItem == null ||
        (page == FumicPage.home && !_currentItemIsInCurrentTab())) {
      await activateSelected(query);
      return;
    }
    await playbackService.playNext();
    final currentItem = playback.currentItem;
    if (currentItem != null) {
      _showFullPlayerForVideo(currentItem);
    }
    final index = visible.indexWhere((item) => item.path == currentItem?.path);
    if (index >= 0) {
      selectedIndex = index;
    }
    notifyListeners();
  }

  Future<void> playPrevious(String query) async {
    final visible = visibleItems(query);
    if (playback.currentItem == null ||
        (page == FumicPage.home && !_currentItemIsInCurrentTab())) {
      await activateSelected(query);
      return;
    }
    await playbackService.playPrevious();
    final currentItem = playback.currentItem;
    if (currentItem != null) {
      _showFullPlayerForVideo(currentItem);
    }
    final index = visible.indexWhere((item) => item.path == currentItem?.path);
    if (index >= 0) {
      selectedIndex = index;
    }
    notifyListeners();
  }

  Future<void> togglePlay(String query) async {
    if (playback.currentItem == null ||
        (page == FumicPage.home && !_currentItemIsInCurrentTab())) {
      await activateSelected(query);
      return;
    }
    await playbackService.togglePlay();
  }

  Future<void> seekRelative(Duration delta) {
    return playbackService.seekRelative(delta);
  }

  Future<void> seekToFraction(double fraction) {
    final duration = playback.duration;
    if (duration <= Duration.zero) {
      return Future<void>.value();
    }
    final target = Duration(
      milliseconds: (duration.inMilliseconds * fraction.clamp(0.0, 1.0))
          .round(),
    );
    return playbackService.seekRelative(target - playback.position);
  }

  Future<void> setVolume(double value) {
    return playbackService.setVolume(value);
  }

  Future<void> adjustSpeed(double delta) {
    final current = playback.speed;
    final next = delta > 0
        ? playbackSpeedOptions.firstWhere(
            (speed) => speed > current + 0.01,
            orElse: () => playbackSpeedOptions.last,
          )
        : playbackSpeedOptions.lastWhere(
            (speed) => speed < current - 0.01,
            orElse: () => playbackSpeedOptions.first,
          );
    return setPlaybackSpeed(next);
  }

  Future<void> setPlaybackSpeed(double value) {
    return playbackService.setSpeed(value);
  }

  Future<void> toggleLoop() {
    return playbackService.setLoop(!playback.loop);
  }

  Future<void> toggleShuffle() {
    return playbackService.setShuffle(!playback.shuffle);
  }

  Future<void> muteOrRestore() {
    if (playback.volume > 0.001) {
      _lastAudibleVolume = playback.volume;
      return setVolume(0);
    }
    return setVolume(_lastAudibleVolume);
  }

  void showFullPlayer() {
    fullPlayer = true;
    notifyListeners();
  }

  void toggleFullPlayer() {
    if (fullPlayer) {
      closeFullPlayer();
    } else {
      showFullPlayer();
    }
  }

  void closeFullPlayer() {
    fullPlayer = false;
    notifyListeners();
  }

  void toggleVisualizer() {
    toggleFullPlayer();
  }

  void _showFullPlayerForVideo(MediaItem item) {
    if (item.kind == MediaKind.video) {
      fullPlayer = true;
    }
  }

  Future<void> cycleVisualizerQuality() {
    return updateVisualizerSettings(visualizerSettings.cycleQuality());
  }

  Future<void> toggleVisualizerParticles() {
    return updateVisualizerSettings(visualizerSettings.toggleParticles());
  }

  Future<void> adjustVisualizerIntensity(int delta) {
    return updateVisualizerSettings(visualizerSettings.adjustIntensity(delta));
  }

  Future<void> updateVisualizerSettings(VisualizerSettings value) {
    if (_disposed) return Future<void>.value();
    // A newer appearance choice wins over a picker/normalization in progress.
    _backgroundGeneration++;
    visualizerSettings = value;
    unawaited(
      playbackService.setSoundReactiveVisualizer(
        value.enabled && !value.performanceMode,
      ),
    );
    notifyListeners();
    final write = _settingsWrites.then((_) async {
      try {
        await appSettingsRepository.saveVisualizerSettings(value);
      } on Object {
        if (!_disposed && identical(visualizerSettings, value)) {
          visualizerSettings = _savedVisualizerSettings;
          notifyListeners();
        }
        rethrow;
      }
      final oldPath = _savedVisualizerSettings.customBackgroundPath;
      _savedVisualizerSettings = value;
      if (oldPath != null &&
          oldPath != value.customBackgroundPath &&
          oldPath != visualizerSettings.customBackgroundPath) {
        await backgroundImageService.deleteCustomBackground(oldPath);
      }
    });
    _settingsWrites = write.catchError((Object _) {});
    return write;
  }

  Future<void> pickCustomBackground() async {
    if (_backgroundBusy || _disposed) return;
    _backgroundBusy = true;
    final generation = ++_backgroundGeneration;
    String? imported;
    try {
      // Startup cleanup must finish before a new managed file is created.
      await _backgroundCleanup;
      if (_disposed || generation != _backgroundGeneration) return;
      imported = await backgroundImageService.pickAndStoreCustomBackground();
      if (imported == null ||
          _disposed ||
          generation != _backgroundGeneration) {
        return;
      }
      await updateVisualizerSettings(
        visualizerSettings.copyWith(
          showBackgroundImage: true,
          customBackgroundPath: imported,
        ),
      );
    } finally {
      if (imported != null &&
          imported != _savedVisualizerSettings.customBackgroundPath &&
          (_disposed || imported != visualizerSettings.customBackgroundPath)) {
        await backgroundImageService.deleteCustomBackground(imported);
      }
      _backgroundBusy = false;
    }
  }

  Future<void> resetCustomBackground() async {
    if (_disposed) return;
    await updateVisualizerSettings(
      visualizerSettings.copyWith(clearCustomBackgroundPath: true),
    );
  }

  bool hasCustomCover(MediaItem item) =>
      _customCovers.containsKey(_pathKey(item.path));

  Future<void> changeCover(MediaItem item, CoverArtAction action) async {
    if (_coverBusy || item.kind != MediaKind.audio) return;
    _coverBusy = true;
    String? imported;
    var saved = false;
    try {
      final choosing =
          action == CoverArtAction.chooseSong ||
          action == CoverArtAction.chooseFolder;
      if (choosing) {
        imported = await coverArtRepository.pickAndStore();
        if (imported == null || _disposed) return;
      }
      final folderAction =
          action == CoverArtAction.chooseFolder ||
          action == CoverArtAction.restoreFolder;
      final folder = _pathKey(p.dirname(item.path));
      final affected = folderAction
          ? items.where(
              (entry) =>
                  entry.kind == MediaKind.audio &&
                  _pathKey(p.dirname(entry.path)) == folder,
            )
          : [item];
      final next = Map<String, String>.of(_customCovers);
      for (final entry in affected) {
        if (imported != null) {
          next[_pathKey(entry.path)] = imported;
        } else {
          next.remove(_pathKey(entry.path));
        }
      }
      final previousFiles = _customCovers.values.toSet();
      await coverArtRepository.save(next);
      saved = true;
      if (_disposed) return;
      _customCovers = next;
      items = items.map(_withCover).toList(growable: false);
      final current = playback.currentItem;
      if (current != null) {
        final updated = items.where(
          (entry) => _pathKey(entry.path) == _pathKey(current.path),
        );
        if (updated.isNotEmpty) {
          playbackService.updateCurrentItem(updated.first);
        }
      }
      notifyListeners();
      for (final path in previousFiles.difference(next.values.toSet())) {
        // Removing an override has already succeeded; cleanup is best effort.
        try {
          await coverArtRepository.deleteManagedCover(path);
        } on Object {
          /* Keep the active artwork. */
        }
      }
    } finally {
      if (!saved && imported != null) {
        try {
          await coverArtRepository.deleteManagedCover(imported);
        } on Object {
          /* Import can be retried. */
        }
      }
      _coverBusy = false;
    }
  }

  MediaItem _withCover(MediaItem item) {
    final key = _pathKey(item.path);
    final path = _customCovers[key] ?? _originalCovers[key];
    return item.copyWith(thumbnailPath: path, clearThumbnailPath: path == null);
  }

  @override
  void dispose() {
    _disposed = true;
    _metadataGeneration++;
    playbackService.removeListener(_onPlaybackChanged);
    playbackService.dispose();
    playbackProgress.dispose();
    super.dispose();
  }

  void _onPlaybackChanged() {
    final nextPlayback = playback;
    if (nextPlayback.volume > 0.001) _lastAudibleVolume = nextPlayback.volume;
    final previous = _lastPlayback;
    _lastPlayback = nextPlayback;
    if (_foregroundActive) playbackProgress.value = nextPlayback;
    // Position and buffer events belong to the controls, not the library.
    if (identical(previous.currentItem, nextPlayback.currentItem) &&
        previous.playing == nextPlayback.playing &&
        previous.shuffle == nextPlayback.shuffle &&
        previous.loop == nextPlayback.loop &&
        previous.volume == nextPlayback.volume &&
        previous.speed == nextPlayback.speed &&
        previous.duration == nextPlayback.duration &&
        previous.buffering == nextPlayback.buffering &&
        previous.error == nextPlayback.error) {
      return;
    }
    final currentItem = nextPlayback.currentItem;
    final currentPath = currentItem?.path;
    if (currentPath != _lastPlaybackItemPath) {
      _lastPlaybackItemPath = currentPath;
      if (currentItem != null && currentItem.kind == tab) {
        final index = _visibleIndexForPath('', currentItem.path);
        if (index >= 0) {
          selectedIndex = index;
        }
      }
    }
    if (currentItem != null) {
      final latest = items.where(
        (item) => _pathKey(item.path) == _pathKey(currentItem.path),
      );
      if (latest.isNotEmpty &&
          latest.first.thumbnailPath != currentItem.thumbnailPath) {
        playbackService.updateCurrentItem(latest.first);
      }
    }
    if (_foregroundActive) notifyListeners();
  }

  Future<void> _activateVisibleItem(List<MediaItem> visible, int index) async {
    if (_activatingSelected) {
      return;
    }
    final safeIndex = index.clamp(0, visible.length - 1);
    _activatingSelected = true;
    try {
      final item = visible[safeIndex];
      final queue = _currentTabItems();
      final queueIndex = _indexForPath(queue, item.path);
      if (queueIndex < 0) {
        return;
      }
      await playbackService.openQueue(queue, queueIndex);
      activePlaylistId = null;
      page = FumicPage.home;
      selectedIndex = safeIndex;
      _lastPlaybackItemPath = item.path;
      _showFullPlayerForVideo(item);
      notifyListeners();
    } finally {
      _activatingSelected = false;
    }
  }

  Future<void> _enrichMetadata(int generation, List<MediaItem> source) async {
    if (source.isEmpty) {
      return;
    }
    enrichingMetadata = true;
    notifyListeners();
    await metadataService.enrich(
      items: source,
      isCancelled: () => generation != _metadataGeneration,
      onMetadata: (metadata) {
        if (generation != _metadataGeneration) {
          return;
        }
        final index = items.indexWhere((item) => item.path == metadata.path);
        if (index == -1) {
          return;
        }
        final next = List<MediaItem>.from(items);
        _originalCovers[_pathKey(metadata.path)] = metadata.thumbnailPath;
        next[index] = next[index].copyWith(
          duration: metadata.duration,
          thumbnailPath:
              _customCovers[_pathKey(metadata.path)] ?? metadata.thumbnailPath,
        );
        items = next;
        if (playback.currentItem?.path == metadata.path) {
          playbackService.updateCurrentItem(next[index]);
        }
        notifyListeners();
      },
    );
    if (generation == _metadataGeneration) {
      enrichingMetadata = false;
      notifyListeners();
    }
  }

  Playlist? _playlistById(String id) {
    for (final playlist in playlists) {
      if (playlist.id == id) {
        return playlist;
      }
    }
    return null;
  }

  Future<void> _replacePlaylist(String id, Playlist value) async {
    final next = playlists
        .map((playlist) => playlist.id == id ? value : playlist)
        .toList(growable: false);
    await _setPlaylists(next);
  }

  Future<void> _setPlaylists(List<Playlist> next, {String? selectedId}) async {
    await playlistRepository.savePlaylists(next);
    playlists = await playlistRepository.loadPlaylists();
    selectedPlaylistId = selectedId ?? selectedPlaylistId;
    _ensureSelectedPlaylist();
    if (activePlaylistId != null && _playlistById(activePlaylistId!) == null) {
      activePlaylistId = null;
    }
    notifyListeners();
  }

  void _ensureSelectedPlaylist() {
    if (playlists.isEmpty) {
      playlists = [Playlist.favourites()];
    }
    if (_playlistById(selectedPlaylistId) == null) {
      selectedPlaylistId = playlists.first.id;
    }
  }

  String _newPlaylistId() {
    final existing = playlists.map((playlist) => playlist.id).toSet();
    var id = 'playlist_${DateTime.now().microsecondsSinceEpoch}';
    var suffix = 2;
    while (existing.contains(id)) {
      id = 'playlist_${DateTime.now().microsecondsSinceEpoch}_$suffix';
      suffix++;
    }
    return id;
  }

  String _uniquePlaylistName(String value, {String? exceptId}) {
    final base = value.trim().isEmpty ? 'New Playlist' : value.trim();
    final existing = playlists
        .where((playlist) => playlist.id != exceptId)
        .map((playlist) => playlist.name.toLowerCase())
        .toSet();
    if (!existing.contains(base.toLowerCase())) {
      return base;
    }
    for (var index = 2; index < 1000; index++) {
      final candidate = '$base $index';
      if (!existing.contains(candidate.toLowerCase())) {
        return candidate;
      }
    }
    return '${base}_${DateTime.now().millisecondsSinceEpoch}';
  }

  bool _currentItemIsInCurrentTab() {
    final currentItem = playback.currentItem;
    return currentItem != null &&
        _indexForPath(_currentTabItems(), currentItem.path) >= 0;
  }

  List<MediaItem> _currentTabItems() {
    return items.where((item) => item.kind == tab).toList(growable: false);
  }

  int _visibleIndexForPath(String query, String path) {
    return _indexForPath(visibleItems(query), path);
  }

  int _indexForPath(List<MediaItem> source, String path) {
    final key = _pathKey(path);
    return source.indexWhere((item) => _pathKey(item.path) == key);
  }

  String _pathKey(String path) => path.trim().toLowerCase();
}
