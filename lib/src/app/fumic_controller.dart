import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import '../models/fumic_page.dart';
import '../models/media_item.dart';
import '../models/media_kind.dart';
import '../models/playlist.dart';
import '../models/playback_speed.dart';
import '../models/visualizer_settings.dart';
import '../services/app_settings_repository.dart';
import '../services/background_image_service.dart';
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
    this.metadataService = const NoopMediaMetadataService(),
  }) : playlistRepository = playlistRepository ?? JsonPlaylistRepository() {
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
  final MediaMetadataService metadataService;

  FumicPage page = FumicPage.home;
  MediaKind tab = MediaKind.audio;
  bool fullPlayer = false;
  bool scanning = false;
  bool enrichingMetadata = false;
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

  PlaybackSnapshot get playback => playbackService.snapshot;

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
      items = await libraryService.scan(folders);
      selectedIndex = 0;
      notifyListeners();
      unawaited(_enrichMetadata(generation, items));
    } on Object catch (error) {
      libraryError = error.toString();
    } finally {
      scanning = false;
      notifyListeners();
    }
  }

  Future<void> addFolder() async {
    folders = await libraryService.addFolder(folders);
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
    if (visible.isEmpty) {
      return;
    }
    if (playback.currentItem == null ||
        (page == FumicPage.home && !_currentItemIsVisible(visible))) {
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
    if (visible.isEmpty) {
      return;
    }
    if (playback.currentItem == null ||
        (page == FumicPage.home && !_currentItemIsVisible(visible))) {
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
    final visible = visibleItems(query);
    if (playback.currentItem == null ||
        (page == FumicPage.home &&
            visible.isNotEmpty &&
            !_currentItemIsVisible(visible))) {
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
    return setVolume(playback.volume == 0 ? 0.52 : 0);
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

  void cycleVisualizerQuality() {
    updateVisualizerSettings(visualizerSettings.cycleQuality());
  }

  void toggleVisualizerParticles() {
    updateVisualizerSettings(visualizerSettings.toggleParticles());
  }

  void adjustVisualizerIntensity(int delta) {
    updateVisualizerSettings(visualizerSettings.adjustIntensity(delta));
  }

  void updateVisualizerSettings(VisualizerSettings value) {
    visualizerSettings = value;
    unawaited(appSettingsRepository.saveVisualizerSettings(value));
    unawaited(
      playbackService.setSoundReactiveVisualizer(
        value.enabled && !value.performanceMode,
      ),
    );
    notifyListeners();
  }

  Future<void> pickCustomBackground() async {
    final path = await backgroundImageService.pickAndStoreCustomBackground();
    if (path == null) {
      return;
    }
    visualizerSettings = visualizerSettings.copyWith(
      showBackgroundImage: true,
      customBackgroundPath: path,
    );
    await appSettingsRepository.saveVisualizerSettings(visualizerSettings);
    notifyListeners();
  }

  Future<void> resetCustomBackground() async {
    final previousPath = visualizerSettings.customBackgroundPath;
    if (previousPath == null) {
      return;
    }
    visualizerSettings = visualizerSettings.copyWith(
      clearCustomBackgroundPath: true,
    );
    await appSettingsRepository.saveVisualizerSettings(visualizerSettings);
    await backgroundImageService.deleteCustomBackground(previousPath);
    notifyListeners();
  }

  @override
  void dispose() {
    _metadataGeneration++;
    playbackService.removeListener(_onPlaybackChanged);
    playbackService.dispose();
    super.dispose();
  }

  void _onPlaybackChanged() {
    final currentItem = playback.currentItem;
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
    notifyListeners();
  }

  Future<void> _activateVisibleItem(List<MediaItem> visible, int index) async {
    if (_activatingSelected) {
      return;
    }
    final safeIndex = index.clamp(0, visible.length - 1);
    _activatingSelected = true;
    try {
      final item = visible[safeIndex];
      await playbackService.openQueue(visible, safeIndex);
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
        next[index] = next[index].copyWith(
          duration: metadata.duration,
          thumbnailPath: metadata.thumbnailPath,
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

  bool _currentItemIsVisible(List<MediaItem> visible) {
    final currentItem = playback.currentItem;
    return currentItem != null && _indexForPath(visible, currentItem.path) >= 0;
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
