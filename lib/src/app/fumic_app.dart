import 'dart:async';
import 'dart:io';

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
  int _homeScrollToTopRequest = 0;
  bool _fullscreen = true;
  bool _visualizerFullscreenSession = false;
  bool? _lastStartFullscreenSetting;

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
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Fumic',
      debugShowCheckedModeBanner: false,
      theme: FumicTheme.dark(),
      home: AnimatedBuilder(
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
              textInputFocused: _textInputFocused,
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
                  child: Scaffold(
                    body: Stack(
                      children: [
                        _Atmosphere(settings: _controller.visualizerSettings),
                        SafeArea(
                          bottom: false,
                          child: AnimatedSwitcher(
                            duration: const Duration(milliseconds: 220),
                            child: _controller.fullPlayer
                                ? VisualizerView(
                                    key: const ValueKey('visualizer'),
                                    item: fullPlayerItem,
                                    playback: playback,
                                    videoController: _controller
                                        .playbackService
                                        .videoController,
                                    settings: _controller.visualizerSettings,
                                    onClose: _closeVisualizer,
                                    onPlayPause: _togglePlay,
                                    onNext: () => _controller.playNext(_query),
                                    onPrevious: () =>
                                        _controller.playPrevious(_query),
                                    onLoop: _controller.toggleLoop,
                                    onShuffle: _controller.toggleShuffle,
                                    onVolumeChanged: _controller.setVolume,
                                    onSpeedChanged:
                                        _controller.setPlaybackSpeed,
                                    onSeekFraction: _controller.seekToFraction,
                                  )
                                : AppFrame(
                                    key: const ValueKey('home'),
                                    page: _controller.page,
                                    tab: _controller.tab,
                                    visibleItems: visibleItems,
                                    libraryItems: _controller.items,
                                    selectedItem: selectedItem,
                                    playback: playback,
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
                                    searchController: _searchController,
                                    searchFocusNode: _searchFocusNode,
                                    onPageSelected: _selectPage,
                                    onTabSelected: _selectTab,
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
                                    onNext: () => _controller.playNext(_query),
                                    onPrevious: () =>
                                        _controller.playPrevious(_query),
                                    onLoop: _controller.toggleLoop,
                                    onShuffle: _controller.toggleShuffle,
                                    onVolumeChanged: _controller.setVolume,
                                    onSpeedChanged:
                                        _controller.setPlaybackSpeed,
                                    onSeekFraction: _controller.seekToFraction,
                                    onFullPlayer: _controller.showFullPlayer,
                                    onPickFolder: _controller.addFolder,
                                    onRefreshLibrary: () {
                                      _controller.refreshLibrary();
                                    },
                                    onRemoveFolder: _controller.removeFolder,
                                    onClearFolders: _controller.clearFolders,
                                    onVisualizerSettingsChanged:
                                        _controller.updateVisualizerSettings,
                                    onPickCustomBackground: () {
                                      unawaited(
                                        _controller.pickCustomBackground(),
                                      );
                                      _returnFocus();
                                    },
                                    onResetCustomBackground: () {
                                      unawaited(
                                        _controller.resetCustomBackground(),
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
      ToggleVisualizerFullscreenIntent:
          CallbackAction<ToggleVisualizerFullscreenIntent>(
            onInvoke: (_) {
              _toggleVisualizerFullscreen();
              return null;
            },
          ),
      CycleVisualizerQualityIntent:
          CallbackAction<CycleVisualizerQualityIntent>(
            onInvoke: (_) {
              _controller.cycleVisualizerQuality();
              _returnFocus();
              return null;
            },
          ),
      ToggleVisualizerParticlesIntent:
          CallbackAction<ToggleVisualizerParticlesIntent>(
            onInvoke: (_) {
              _controller.toggleVisualizerParticles();
              _returnFocus();
              return null;
            },
          ),
      AdjustVisualizerIntensityIntent:
          CallbackAction<AdjustVisualizerIntensityIntent>(
            onInvoke: (intent) {
              _controller.adjustVisualizerIntensity(intent.delta);
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
    if (state == AppLifecycleState.resumed) {
      _returnFocus();
    }
  }

  void _selectPage(FumicPage page) {
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

  void _selectTab(MediaKind kind) {
    _controller.selectTab(kind);
    _returnFocus();
  }

  void _togglePlay() {
    _controller.togglePlay(_query);
    _returnFocus();
  }

  void _toggleVisualizer() {
    if (_controller.fullPlayer) {
      _closeVisualizer();
      return;
    }
    _controller.showFullPlayer();
    _returnFocus();
  }

  void _toggleVisualizerFullscreen() {
    if (!_controller.fullPlayer) {
      _controller.showFullPlayer();
      if (!_fullscreen) {
        _fullscreen = true;
        _visualizerFullscreenSession = true;
        _applyFullscreen(true);
      }
      _returnFocus();
      return;
    }
    _fullscreen = !_fullscreen;
    _visualizerFullscreenSession = _fullscreen;
    _applyFullscreen(_fullscreen);
    _returnFocus();
  }

  void _closeVisualizer() {
    _controller.closeFullPlayer();
    _endVisualizerFullscreenSession();
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
    if (_fullscreen) {
      _toggleFullscreen();
    }
  }

  void _toggleFullscreen() {
    _fullscreen = !_fullscreen;
    _visualizerFullscreenSession = false;
    _applyFullscreen(_fullscreen);
    _returnFocus();
  }

  void _endVisualizerFullscreenSession() {
    if (_visualizerFullscreenSession && _fullscreen) {
      _fullscreen = false;
      _applyFullscreen(false);
    }
    _visualizerFullscreenSession = false;
  }

  void _onControllerChanged() {
    if (mounted) {
      final desiredFullscreen = _controller.visualizerSettings.startFullscreen;
      if (_lastStartFullscreenSetting != desiredFullscreen) {
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
    final hasCustomBackground = settings.customBackgroundPath != null;
    final preset = Image.asset(
      _presetBackgroundFor(settings),
      fit: BoxFit.cover,
      filterQuality: FilterQuality.medium,
    );
    final customPath = settings.customBackgroundPath;
    return Stack(
      fit: StackFit.expand,
      children: [
        if (settings.showBackgroundImage)
          customPath == null
              ? preset
              : Image.file(
                  File(customPath),
                  fit: BoxFit.cover,
                  filterQuality: FilterQuality.medium,
                  errorBuilder: (context, error, stackTrace) => preset,
                )
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
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                FumicTheme.background.withValues(
                  alpha: hasCustomBackground ? 0.68 : 0.58,
                ),
                const Color(
                  0xFF10151F,
                ).withValues(alpha: hasCustomBackground ? 0.80 : 0.72),
                Colors.black.withValues(
                  alpha: hasCustomBackground ? 0.86 : 0.78,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  String _presetBackgroundFor(VisualizerSettings settings) {
    final index = settings.backgroundIndex.clamp(0, 5);
    return 'icons/viz_bg${index + 1}.jpg';
  }
}
