import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/fumic_page.dart';
import '../models/media_item.dart';
import '../models/media_kind.dart';
import '../models/visualizer_settings.dart';
import '../theme/fumic_theme.dart';
import '../widgets/add_to_playlist_dialog.dart';
import '../widgets/app_frame.dart';
import '../widgets/visualizer_view.dart';
import '../widgets/wallpaper_image.dart';
import 'fumic_controller.dart';
import 'fumic_shortcuts.dart';

class FumicApp extends StatefulWidget {
  const FumicApp({super.key, this.controller});

  final FumicController? controller;

  @override
  State<FumicApp> createState() => _FumicAppState();
}

class _FumicAppState extends State<FumicApp> with WidgetsBindingObserver {
  static const MethodChannel _windowChannel = MethodChannel('fumic/window');

  late final FumicController _controller;
  late final bool _ownsController;
  final Stopwatch _sessionStopwatch = Stopwatch()..start();
  final FocusNode _appFocusNode = FocusNode(debugLabel: 'Fumic app focus');
  late final FocusNode _searchFocusNode;
  final TextEditingController _searchController = TextEditingController();
  final ValueNotifier<int> _playerActivity = ValueNotifier(0);
  int _homeScrollToTopRequest = 0;
  int _playlistCreateShortcutRequest = 0;
  int _playlistRenameShortcutRequest = 0;
  int _playlistDeleteShortcutRequest = 0;
  bool _playlistTextInputFocused = false;
  bool _fullscreen = true;
  bool? _lastStartFullscreenSetting;
  bool _foregroundActive = true;

  String get _query => _searchController.text;

  bool get _textInputFocused {
    if (_searchFocusNode.hasFocus) {
      return true;
    }
    final context = FocusManager.instance.primaryFocus?.context;
    return context != null && context.widget is EditableText;
  }

  @override
  void initState() {
    super.initState();
    _ownsController = widget.controller == null;
    _controller = widget.controller ?? FumicController.production();
    final lifecycle = WidgetsBinding.instance.lifecycleState;
    _foregroundActive =
        lifecycle == null || lifecycle == AppLifecycleState.resumed;
    _controller.setForegroundActive(_foregroundActive);
    _searchFocusNode = FocusNode(
      debugLabel: 'Fumic search',
      onKeyEvent: _handleSearchKeyEvent,
    );
    _controller.addListener(_onControllerChanged);
    _searchController.addListener(_onSearchChanged);
    _searchFocusNode.addListener(_onSearchFocusChanged);
    FocusManager.instance.addListener(_onPrimaryFocusChanged);
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _controller.loadLibrary();
      _returnFocus();
    });
  }

  @override
  void dispose() {
    _controller.removeListener(_onControllerChanged);
    if (_ownsController) {
      _controller.dispose();
    }
    _searchFocusNode.removeListener(_onSearchFocusChanged);
    FocusManager.instance.removeListener(_onPrimaryFocusChanged);
    WidgetsBinding.instance.removeObserver(this);
    _appFocusNode.dispose();
    _searchFocusNode.dispose();
    _searchController.dispose();
    _playerActivity.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Fumic - Magical Media Player',
      debugShowCheckedModeBanner: false,
      theme: FumicTheme.dark(
        cardOpacity: _controller.visualizerSettings.effectiveCardOpacity,
      ),
      home: TickerMode(
        enabled: _foregroundActive,
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, _) {
            final visibleItems = _controller.visibleItems(_query);
            final selectedItem = _controller.selectedItem(_query);
            final playback = _controller.playback;
            final fullPlayerItem = _fullPlayerItem(
              playback.currentItem,
              selectedItem,
            );

            return Shortcuts(
              shortcuts: fumicShortcuts(
                page: _controller.page,
                textInputFocused:
                    _textInputFocused ||
                    (_controller.page == FumicPage.playlists &&
                        _playlistTextInputFocused),
                searchFocused: _searchFocusNode.hasFocus,
                visualizerOpen: _controller.fullPlayer,
              ),
              child: Actions(
                actions: _actions(context),
                child: Listener(
                  behavior: HitTestBehavior.translucent,
                  onPointerDown: (_) => _returnFocusAfterPointer(context),
                  child: Focus(
                    autofocus: true,
                    focusNode: _appFocusNode,
                    onKeyEvent: (node, event) {
                      if (_controller.fullPlayer &&
                          (event is KeyDownEvent || event is KeyRepeatEvent)) {
                        _playerActivity.value++;
                      }
                      return KeyEventResult.ignored;
                    },
                    child: Scaffold(
                      body: Stack(
                        children: [
                          if (!_controller.fullPlayer)
                            RepaintBoundary(
                              child: _Atmosphere(
                                settings: _controller.visualizerSettings,
                              ),
                            ),
                          SafeArea(
                            bottom: false,
                            child: AnimatedSwitcher(
                              duration: const Duration(milliseconds: 220),
                              child: _controller.fullPlayer
                                  ? VisualizerView(
                                      key: const ValueKey('visualizer'),
                                      item: fullPlayerItem,
                                      playback: playback,
                                      playbackProgress:
                                          _controller.playbackProgress,
                                      videoController: _controller
                                          .playbackService
                                          .videoController,
                                      settings: _controller.visualizerSettings,
                                      onBackToLibrary: _closeVisualizer,
                                      activity: _playerActivity,
                                      onPlayPause: _togglePlay,
                                      onNext: () =>
                                          _controller.playNext(_query),
                                      onPrevious: () =>
                                          _controller.playPrevious(_query),
                                      onLoop: _controller.toggleLoop,
                                      onShuffle: _controller.toggleShuffle,
                                      onMute: _controller.muteOrRestore,
                                      onSpeedChanged:
                                          _controller.setPlaybackSpeed,
                                      onSeekFraction:
                                          _controller.seekToFraction,
                                    )
                                  : AppFrame(
                                      key: const ValueKey('home'),
                                      page: _controller.page,
                                      tab: _controller.tab,
                                      visibleItems: visibleItems,
                                      libraryItems: _controller.items,
                                      selectedItem: selectedItem,
                                      playback: playback,
                                      playbackProgress:
                                          _controller.playbackProgress,
                                      playlists: _controller.playlists,
                                      selectedPlaylistId:
                                          _controller.selectedPlaylistId,
                                      activePlaylistId:
                                          _controller.activePlaylistId,
                                      folders: _controller.folders,
                                      scanning: _controller.scanning,
                                      enrichingMetadata:
                                          _controller.enrichingMetadata,
                                      libraryError: _controller.libraryError,
                                      audioCount: _controller.itemCountFor(
                                        MediaKind.audio,
                                      ),
                                      videoCount: _controller.itemCountFor(
                                        MediaKind.video,
                                      ),
                                      visualizerSettings:
                                          _controller.visualizerSettings,
                                      sessionStopwatch: _sessionStopwatch,
                                      homeScrollToTopRequest:
                                          _homeScrollToTopRequest,
                                      playlistCreateShortcutRequest:
                                          _playlistCreateShortcutRequest,
                                      playlistRenameShortcutRequest:
                                          _playlistRenameShortcutRequest,
                                      playlistDeleteShortcutRequest:
                                          _playlistDeleteShortcutRequest,
                                      searchController: _searchController,
                                      searchFocusNode: _searchFocusNode,
                                      onPageSelected: _selectPage,
                                      onTabSelected: _selectTab,
                                      hasCustomCover:
                                          _controller.hasCustomCover,
                                      onCoverAction: (item, action) async {
                                        try {
                                          await _controller.changeCover(
                                            item,
                                            action,
                                          );
                                        } on Object catch (error) {
                                          if (!context.mounted) return;
                                          ScaffoldMessenger.of(
                                            context,
                                          ).showSnackBar(
                                            SnackBar(
                                              content: Text(
                                                error is FormatException
                                                    ? error.message.toString()
                                                    : 'Could not update cover artwork. Please try another image.',
                                              ),
                                            ),
                                          );
                                        }
                                      },
                                      onItemSelected: (item) {
                                        _controller.selectItemByPath(
                                          item.path,
                                          _query,
                                        );
                                      },
                                      onItemActivated: (item) {
                                        _controller.activateItemByPath(
                                          item.path,
                                          _query,
                                        );
                                      },
                                      onPlaylistSelected:
                                          _controller.selectPlaylist,
                                      onPlaylistEditorClosed:
                                          _returnFocusAfterPlaylistEditor,
                                      onPlaylistEditorFocusChanged:
                                          _onPlaylistEditorFocusChanged,
                                      onCreatePlaylist: (name) async {
                                        await _controller.createPlaylist(name);
                                      },
                                      onRenamePlaylist:
                                          _controller.renamePlaylist,
                                      onDeletePlaylist:
                                          _controller.deletePlaylist,
                                      onPlayPlaylist: (id) =>
                                          _controller.playPlaylist(id),
                                      onShufflePlaylist: (id) => _controller
                                          .playPlaylist(id, shuffle: true),
                                      onAddItemToPlaylist: (id, item) {
                                        return _controller.addItemToPlaylist(
                                          item,
                                          id,
                                        );
                                      },
                                      onRemovePlaylistEntry:
                                          _controller.removePlaylistEntry,
                                      onReorderPlaylistEntry:
                                          _controller.reorderPlaylistEntry,
                                      onPlayPause: _togglePlay,
                                      onNext: () =>
                                          _controller.playNext(_query),
                                      onPrevious: () =>
                                          _controller.playPrevious(_query),
                                      onLoop: _controller.toggleLoop,
                                      onShuffle: _controller.toggleShuffle,
                                      onVolumeChanged: _controller.setVolume,
                                      onMute: _controller.muteOrRestore,
                                      onSpeedChanged:
                                          _controller.setPlaybackSpeed,
                                      onSeekFraction:
                                          _controller.seekToFraction,
                                      onFullPlayer: _showFullPlayer,
                                      onPickFolder: _controller.addFolder,
                                      onRefreshLibrary: () {
                                        _controller.refreshLibrary();
                                      },
                                      onRemoveFolder: _controller.removeFolder,
                                      onClearFolders: _controller.clearFolders,
                                      onVisualizerSettingsChanged: (value) {
                                        unawaited(
                                          _changeAppearance(
                                            () => _controller
                                                .updateVisualizerSettings(
                                                  value,
                                                ),
                                          ),
                                        );
                                      },
                                      onPickCustomBackground: () {
                                        unawaited(
                                          _changeAppearance(
                                            _controller.pickCustomBackground,
                                          ),
                                        );
                                        _returnFocus();
                                      },
                                      onResetCustomBackground: () {
                                        unawaited(
                                          _changeAppearance(
                                            _controller.resetCustomBackground,
                                          ),
                                        );
                                        _returnFocus();
                                      },
                                    ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Map<Type, Action<Intent>> _actions(BuildContext appContext) {
    return <Type, Action<Intent>>{
      TogglePlayIntent: CallbackAction<TogglePlayIntent>(
        onInvoke: (_) {
          _togglePlay();
          return null;
        },
      ),
      ActivateSelectedIntent: CallbackAction<ActivateSelectedIntent>(
        onInvoke: (_) {
          unawaited(_activateSelectedFromKeyboard());
          return null;
        },
      ),
      MoveSelectionIntent: CallbackAction<MoveSelectionIntent>(
        onInvoke: (intent) {
          _controller.moveSelection(intent.delta, _query);
          return null;
        },
      ),
      MovePlaylistSelectionIntent: CallbackAction<MovePlaylistSelectionIntent>(
        onInvoke: (intent) {
          _controller.movePlaylistSelection(intent.delta);
          _returnFocus();
          return null;
        },
      ),
      SeekIntent: CallbackAction<SeekIntent>(
        onInvoke: (intent) {
          _controller.seekRelative(Duration(seconds: intent.seconds));
          return null;
        },
      ),
      PercentageSeekIntent: CallbackAction<PercentageSeekIntent>(
        onInvoke: (intent) {
          _controller.seekToFraction(intent.fraction);
          return null;
        },
      ),
      PreviousIntent: CallbackAction<PreviousIntent>(
        onInvoke: (_) {
          _controller.playPrevious(_query);
          return null;
        },
      ),
      NextIntent: CallbackAction<NextIntent>(
        onInvoke: (_) {
          _controller.playNext(_query);
          return null;
        },
      ),
      VolumeIntent: CallbackAction<VolumeIntent>(
        onInvoke: (intent) {
          _controller.setVolume(_controller.playback.volume + intent.delta);
          return null;
        },
      ),
      FocusSearchIntent: CallbackAction<FocusSearchIntent>(
        onInvoke: (_) {
          _focusSearch();
          return null;
        },
      ),
      RefreshLibraryIntent: CallbackAction<RefreshLibraryIntent>(
        onInvoke: (_) {
          _controller.refreshLibrary();
          _returnFocus();
          return null;
        },
      ),
      AddSelectedToPlaylistIntent: CallbackAction<AddSelectedToPlaylistIntent>(
        onInvoke: (_) {
          _showAddToPlaylistDialog(appContext);
          return null;
        },
      ),
      StartCreatePlaylistIntent: CallbackAction<StartCreatePlaylistIntent>(
        onInvoke: (_) {
          _requestPlaylistCreate();
          return null;
        },
      ),
      RenameSelectedPlaylistIntent:
          CallbackAction<RenameSelectedPlaylistIntent>(
            onInvoke: (_) {
              _requestPlaylistRename();
              return null;
            },
          ),
      DeleteSelectedPlaylistIntent:
          CallbackAction<DeleteSelectedPlaylistIntent>(
            onInvoke: (_) {
              _requestPlaylistDelete();
              return null;
            },
          ),
      ActivateSelectedPlaylistIntent:
          CallbackAction<ActivateSelectedPlaylistIntent>(
            onInvoke: (_) {
              unawaited(_activateSelectedPlaylistFromKeyboard());
              return null;
            },
          ),
      QuitIntent: CallbackAction<QuitIntent>(
        onInvoke: (_) {
          _quitApp();
          return null;
        },
      ),
      PageIntent: CallbackAction<PageIntent>(
        onInvoke: (intent) {
          _selectPage(intent.page);
          return null;
        },
      ),
      TabIntent: CallbackAction<TabIntent>(
        onInvoke: (intent) {
          _selectTab(intent.kind);
          return null;
        },
      ),
      ToggleFullPlayerIntent: CallbackAction<ToggleFullPlayerIntent>(
        onInvoke: (_) {
          _toggleVisualizer();
          return null;
        },
      ),
      MuteIntent: CallbackAction<MuteIntent>(
        onInvoke: (_) {
          _controller.muteOrRestore();
          return null;
        },
      ),
      ShuffleIntent: CallbackAction<ShuffleIntent>(
        onInvoke: (_) {
          _controller.toggleShuffle();
          return null;
        },
      ),
      LoopIntent: CallbackAction<LoopIntent>(
        onInvoke: (_) {
          _controller.toggleLoop();
          return null;
        },
      ),
      PlaybackSpeedIntent: CallbackAction<PlaybackSpeedIntent>(
        onInvoke: (intent) {
          _controller.adjustSpeed(intent.delta);
          return null;
        },
      ),
      ToggleVisualizerIntent: CallbackAction<ToggleVisualizerIntent>(
        onInvoke: (_) {
          _toggleVisualizer();
          return null;
        },
      ),
      MinimizeAppIntent: CallbackAction<MinimizeAppIntent>(
        onInvoke: (_) {
          _minimizeApp();
          return null;
        },
      ),
      TogglePlayerControlsIntent: CallbackAction<TogglePlayerControlsIntent>(
        onInvoke: (_) {
          unawaited(
            _changeAppearance(
              () => _controller.updateVisualizerSettings(
                _controller.visualizerSettings.copyWith(
                  showPlayerControls:
                      !_controller.visualizerSettings.showPlayerControls,
                ),
              ),
            ),
          );
          return null;
        },
      ),
      CycleVisualizerQualityIntent:
          CallbackAction<CycleVisualizerQualityIntent>(
            onInvoke: (_) {
              unawaited(_changeAppearance(_controller.cycleVisualizerQuality));
              _returnFocus();
              return null;
            },
          ),
      ToggleVisualizerParticlesIntent:
          CallbackAction<ToggleVisualizerParticlesIntent>(
            onInvoke: (_) {
              unawaited(
                _changeAppearance(_controller.toggleVisualizerParticles),
              );
              _returnFocus();
              return null;
            },
          ),
      AdjustVisualizerIntensityIntent:
          CallbackAction<AdjustVisualizerIntensityIntent>(
            onInvoke: (intent) {
              unawaited(
                _changeAppearance(
                  () => _controller.adjustVisualizerIntensity(intent.delta),
                ),
              );
              _returnFocus();
              return null;
            },
          ),
      ToggleFullscreenIntent: CallbackAction<ToggleFullscreenIntent>(
        onInvoke: (_) {
          _toggleFullscreen();
          return null;
        },
      ),
      EscapeIntent: CallbackAction<EscapeIntent>(
        onInvoke: (_) {
          _escape();
          return null;
        },
      ),
    };
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final active = state == AppLifecycleState.resumed;
    if (_foregroundActive != active) {
      setState(() => _foregroundActive = active);
      _controller.setForegroundActive(active);
    }
    if (state == AppLifecycleState.resumed) {
      _returnFocus();
    }
  }

  void _selectPage(FumicPage page) {
    if (page != FumicPage.playlists && _playlistTextInputFocused) {
      setState(() {
        _playlistTextInputFocused = false;
      });
    }
    if (page == FumicPage.home &&
        _controller.page == FumicPage.home &&
        !_controller.fullPlayer) {
      setState(() {
        _homeScrollToTopRequest++;
      });
      _returnFocus();
      return;
    }
    _controller.selectPage(page);
    _returnFocus();
  }

  void _onPlaylistEditorFocusChanged(bool focused) {
    if (_playlistTextInputFocused == focused) {
      return;
    }
    setState(() {
      _playlistTextInputFocused = focused;
    });
  }

  void _selectTab(MediaKind kind) {
    _controller.selectTab(kind);
    _returnFocus();
  }

  void _requestPlaylistCreate() {
    if (_controller.page != FumicPage.playlists) {
      return;
    }
    setState(() {
      _playlistCreateShortcutRequest++;
    });
  }

  void _requestPlaylistRename() {
    if (_controller.page != FumicPage.playlists) {
      return;
    }
    setState(() {
      _playlistRenameShortcutRequest++;
    });
  }

  void _requestPlaylistDelete() {
    if (_controller.page != FumicPage.playlists) {
      return;
    }
    setState(() {
      _playlistDeleteShortcutRequest++;
    });
    _returnFocus();
  }

  Future<void> _activateSelectedPlaylistFromKeyboard() async {
    if (_controller.page != FumicPage.playlists) {
      return;
    }
    if (_controller.selectedPlaylistId == _controller.activePlaylistId) {
      await _controller.playbackService.togglePlay();
    } else {
      await _controller.playPlaylist(_controller.selectedPlaylistId);
    }
    _returnFocus();
  }

  void _togglePlay() {
    _controller.togglePlay(_query);
    _returnFocus();
  }

  Future<void> _changeAppearance(Future<void> Function() change) async {
    try {
      await change();
    } on Object catch (error) {
      if (!mounted) return;
      final context = _appFocusNode.context;
      if (context == null || !context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            error is FormatException
                ? error.message.toString()
                : 'Could not save appearance changes. Please try again.',
          ),
        ),
      );
    }
  }

  void _toggleVisualizer() {
    if (_controller.fullPlayer) {
      _closeVisualizer();
      return;
    }
    _showFullPlayer();
  }

  void _showFullPlayer() {
    if (!_fullscreen) {
      _fullscreen = true;
      _applyFullscreen(true);
    }
    _controller.showFullPlayer();
    _returnFocus();
  }

  void _closeVisualizer() {
    _controller.closeFullPlayer();
    _returnFocus();
  }

  Future<void> _activateSelectedFromKeyboard() async {
    if (_controller.selectedItem(_query) == null) {
      return;
    }
    await _controller.activateSelected(_query);
    _searchFocusNode.unfocus();
    _returnFocus();
  }

  void _focusSearch() {
    _controller.selectPage(FumicPage.home);
    _searchFocusNode.requestFocus();
  }

  void _showAddToPlaylistDialog(BuildContext dialogContext) {
    final item =
        _controller.playback.currentItem ?? _controller.selectedItem(_query);
    if (item == null) {
      _returnFocus();
      return;
    }
    unawaited(
      showDialog<void>(
        context: dialogContext,
        builder: (context) {
          return AddToPlaylistDialog(
            item: item,
            playlists: _controller.playlists,
            playlistContainsItem: (playlistId) {
              return _controller.playlistContainsPath(playlistId, item.path);
            },
            onAddToPlaylist: (playlistId) {
              return _controller.addItemToPlaylist(item, playlistId);
            },
            onCreatePlaylistAndAdd: (name) {
              return _controller
                  .createPlaylistAndAddItem(name, item)
                  .then((_) {});
            },
          );
        },
      ).whenComplete(_returnFocus),
    );
  }

  void _escape() {
    if (_controller.fullPlayer) {
      _closeVisualizer();
      return;
    }
    if (_searchFocusNode.hasFocus) {
      _searchFocusNode.unfocus();
      _returnFocus();
      return;
    }
  }

  void _toggleFullscreen() {
    _fullscreen = !_fullscreen;
    _applyFullscreen(_fullscreen);
    _returnFocus();
  }

  void _onControllerChanged() {
    if (mounted) {
      final desiredFullscreen = _controller.visualizerSettings.startFullscreen;
      if (_controller.settingsLoaded && _lastStartFullscreenSetting == null) {
        _lastStartFullscreenSetting = desiredFullscreen;
        _fullscreen = desiredFullscreen;
        _applyFullscreen(desiredFullscreen);
      }
      setState(() {});
    }
  }

  void _onSearchChanged() {
    _controller.resetSelectionForSearch(_query);
    setState(() {});
  }

  void _onSearchFocusChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  void _onPrimaryFocusChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  void _returnFocus() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && !_textInputFocused) {
        _appFocusNode.requestFocus();
      }
    });
  }

  void _returnFocusAfterPlaylistEditor() {
    FocusManager.instance.primaryFocus?.unfocus();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _appFocusNode.requestFocus();
      }
    });
  }

  void _returnFocusAfterPointer(BuildContext context) {
    final route = ModalRoute.of(context);
    if (route != null && !route.isCurrent) {
      return;
    }
    if (_textInputFocused) {
      return;
    }
    _returnFocus();
  }

  KeyEventResult _handleSearchKeyEvent(FocusNode node, KeyEvent event) {
    final key = event.logicalKey;
    final isNavigationEvent = event is KeyDownEvent || event is KeyRepeatEvent;
    if (!isNavigationEvent) {
      return KeyEventResult.ignored;
    }

    if (key == LogicalKeyboardKey.arrowDown) {
      _controller.moveSelection(1, _query);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowUp) {
      _controller.moveSelection(-1, _query);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.enter ||
        key == LogicalKeyboardKey.numpadEnter) {
      if (event is KeyDownEvent) {
        unawaited(_activateSelectedFromKeyboard());
      }
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.escape && event is KeyDownEvent) {
      _escape();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  void _applyFullscreen(bool fullscreen) {
    SystemChrome.setEnabledSystemUIMode(
      fullscreen ? SystemUiMode.immersiveSticky : SystemUiMode.edgeToEdge,
    );
    if (defaultTargetPlatform == TargetPlatform.windows) {
      unawaited(
        _windowChannel
            .invokeMethod<void>('setFullscreen', fullscreen)
            .catchError((Object _) {}),
      );
    }
  }

  void _minimizeApp() {
    if (defaultTargetPlatform == TargetPlatform.windows) {
      unawaited(
        _windowChannel.invokeMethod<void>('minimize').catchError((Object _) {}),
      );
    }
  }

  void _quitApp() {
    if (defaultTargetPlatform == TargetPlatform.windows) {
      unawaited(
        _windowChannel.invokeMethod<void>('close').catchError((Object _) {
          SystemNavigator.pop();
        }),
      );
      return;
    }
    SystemNavigator.pop();
  }

  MediaItem _fullPlayerItem(MediaItem? currentItem, MediaItem? selectedItem) {
    if (currentItem != null) {
      return currentItem;
    }
    if (selectedItem != null && selectedItem.kind == MediaKind.audio) {
      return selectedItem;
    }
    return _idleVisualizerItem;
  }
}

const _idleVisualizerItem = MediaItem(
  path: 'fumic://idle-visualizer',
  title: 'Fumic Visualizer',
  artist: 'Idle Display',
  kind: MediaKind.audio,
  duration: Duration.zero,
  colors: [
    Color(0xFF20E3D4),
    Color(0xFFFF4FD8),
    Color(0xFFFFD95C),
    Color(0xFF111827),
  ],
);

class _Atmosphere extends StatelessWidget {
  const _Atmosphere({required this.settings});

  final VisualizerSettings settings;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        if (settings.showBackgroundImage)
          WallpaperImage(settings: settings)
        else
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFF111622),
                  Color(0xFF142532),
                  Color(0xFF0E141D),
                ],
              ),
            ),
          ),
        ColoredBox(
          key: const ValueKey('background-dimming-overlay'),
          color: FumicTheme.background.withValues(
            alpha: settings.effectiveBackgroundOpacity,
          ),
        ),
      ],
    );
  }
}
