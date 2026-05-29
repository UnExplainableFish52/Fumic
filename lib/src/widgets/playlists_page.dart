import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;

import '../models/media_item.dart';
import '../models/playlist.dart';
import '../theme/fumic_theme.dart';
import 'shared.dart';

class PlaylistsPage extends StatefulWidget {
  const PlaylistsPage({
    super.key,
    required this.playlists,
    required this.selectedPlaylistId,
    required this.activePlaylistId,
    required this.currentItemPath,
    required this.playbackPlaying,
    required this.libraryItems,
    required this.addCandidate,
    required this.scanning,
    required this.onPlaylistSelected,
    required this.onCreatePlaylist,
    required this.onRenamePlaylist,
    required this.onDeletePlaylist,
    required this.onPlayPlaylist,
    required this.onShufflePlaylist,
    required this.onToggleActivePlaylist,
    required this.onAddItem,
    required this.onRemoveEntry,
    required this.onReorderEntry,
  });

  final List<Playlist> playlists;
  final String selectedPlaylistId;
  final String? activePlaylistId;
  final String? currentItemPath;
  final bool playbackPlaying;
  final List<MediaItem> libraryItems;
  final MediaItem? addCandidate;
  final bool scanning;
  final ValueChanged<String> onPlaylistSelected;
  final Future<void> Function(String name) onCreatePlaylist;
  final Future<void> Function(String id, String name) onRenamePlaylist;
  final Future<void> Function(String id) onDeletePlaylist;
  final Future<void> Function(String id) onPlayPlaylist;
  final Future<void> Function(String id) onShufflePlaylist;
  final VoidCallback onToggleActivePlaylist;
  final Future<void> Function(String id, MediaItem item) onAddItem;
  final Future<void> Function(String id, String path) onRemoveEntry;
  final Future<void> Function(String id, int oldIndex, int newIndex)
  onReorderEntry;

  @override
  State<PlaylistsPage> createState() => _PlaylistsPageState();
}

class _PlaylistsPageState extends State<PlaylistsPage> {
  late final TextEditingController _createController;
  late final TextEditingController _renameController;
  late final FocusNode _createFocusNode;
  late final FocusNode _renameFocusNode;

  bool _creating = false;
  bool _createBusy = false;
  String? _renamingPlaylistId;
  bool _renameBusy = false;
  String? _deleteConfirmPlaylistId;
  bool _deleteBusy = false;

  @override
  void initState() {
    super.initState();
    _createController = TextEditingController();
    _renameController = TextEditingController();
    _createFocusNode = FocusNode(
      debugLabel: 'Create playlist name',
      onKeyEvent: _handleCreateKeyEvent,
    );
    _renameFocusNode = FocusNode(
      debugLabel: 'Rename playlist name',
      onKeyEvent: _handleRenameKeyEvent,
    );
  }

  @override
  void didUpdateWidget(covariant PlaylistsPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    final ids = widget.playlists.map((playlist) => playlist.id).toSet();
    if (_renamingPlaylistId != null && !ids.contains(_renamingPlaylistId)) {
      _renamingPlaylistId = null;
      _renameBusy = false;
    }
    if (_deleteConfirmPlaylistId != null &&
        !ids.contains(_deleteConfirmPlaylistId)) {
      _deleteConfirmPlaylistId = null;
      _deleteBusy = false;
    }
  }

  @override
  void dispose() {
    _createController.dispose();
    _renameController.dispose();
    _createFocusNode.dispose();
    _renameFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final safePlaylists = widget.playlists.isEmpty
        ? [Playlist.favourites()]
        : widget.playlists;
    final selected = safePlaylists.firstWhere(
      (playlist) => playlist.id == widget.selectedPlaylistId,
      orElse: () => safePlaylists.first,
    );
    final libraryByPath = {
      for (final item in widget.libraryItems) _pathKey(item.path): item,
    };
    final selectedActive = selected.id == widget.activePlaylistId;
    final resolvedCount = _resolvedCount(selected, libraryByPath);

    return ClipRect(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 900;
          final rail = _PlaylistRail(
            playlists: safePlaylists,
            selectedPlaylistId: selected.id,
            activePlaylistId: widget.activePlaylistId,
            creating: _creating,
            createBusy: _createBusy,
            createController: _createController,
            createFocusNode: _createFocusNode,
            onSelected: _selectPlaylist,
            onCreateStart: _startCreate,
            onCreateSubmit: _submitCreate,
            onCreateCancel: _cancelCreate,
          );
          final detail = _PlaylistDetail(
            playlist: selected,
            libraryByPath: libraryByPath,
            addCandidate: widget.addCandidate,
            scanning: widget.scanning,
            active: selectedActive,
            currentItemPath: widget.currentItemPath,
            playbackPlaying: widget.playbackPlaying,
            renaming: _renamingPlaylistId == selected.id,
            renameBusy: _renameBusy,
            renameController: _renameController,
            renameFocusNode: _renameFocusNode,
            deleteConfirming: _deleteConfirmPlaylistId == selected.id,
            deleteBusy: _deleteBusy,
            onCreate: _startCreate,
            onRename: selected.isProtected
                ? null
                : () => _startRename(selected),
            onRenameSubmit: () => _submitRename(selected),
            onRenameCancel: _cancelRename,
            onDelete: selected.isProtected
                ? null
                : () => _startDelete(selected),
            onDeleteConfirm: () => _confirmDelete(selected),
            onDeleteCancel: _cancelDelete,
            onPlay: selectedActive
                ? widget.onToggleActivePlaylist
                : resolvedCount == 0
                ? null
                : () => widget.onPlayPlaylist(selected.id),
            onShuffle: resolvedCount < 2
                ? null
                : () => widget.onShufflePlaylist(selected.id),
            onAddItem: (item) => widget.onAddItem(selected.id, item),
            onRemoveEntry: (path) => widget.onRemoveEntry(selected.id, path),
            onReorderEntry: (oldIndex, newIndex) =>
                widget.onReorderEntry(selected.id, oldIndex, newIndex),
          );

          if (compact) {
            final railHeight = constraints.maxHeight < 620 ? 178.0 : 220.0;
            return Column(
              children: [
                SizedBox(height: railHeight, child: rail),
                Divider(height: 1, color: Colors.white.withValues(alpha: 0.08)),
                Expanded(child: detail),
              ],
            );
          }
          return Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(width: 292, child: rail),
              VerticalDivider(
                width: 1,
                color: Colors.white.withValues(alpha: 0.08),
              ),
              Expanded(child: detail),
            ],
          );
        },
      ),
    );
  }

  int _resolvedCount(Playlist playlist, Map<String, MediaItem> libraryByPath) {
    return playlist.entries
        .where((entry) => libraryByPath.containsKey(_pathKey(entry.path)))
        .length;
  }

  void _selectPlaylist(String id) {
    _cancelCreate();
    _cancelRename();
    _cancelDelete();
    widget.onPlaylistSelected(id);
  }

  void _startCreate() {
    setState(() {
      _creating = true;
      _createBusy = false;
      _deleteConfirmPlaylistId = null;
      _renamingPlaylistId = null;
      _createController.clear();
    });
    _focusAfterFrame(_createFocusNode);
  }

  Future<void> _submitCreate() async {
    if (_createBusy) {
      return;
    }
    setState(() => _createBusy = true);
    final saved = await _runPlaylistMutation(
      context,
      () => widget.onCreatePlaylist(_createController.text),
    );
    if (!mounted) {
      return;
    }
    setState(() {
      _createBusy = false;
      if (saved) {
        _creating = false;
        _createController.clear();
      }
    });
  }

  void _cancelCreate() {
    if (!_creating && !_createBusy) {
      return;
    }
    setState(() {
      _creating = false;
      _createBusy = false;
      _createController.clear();
    });
  }

  void _startRename(Playlist playlist) {
    setState(() {
      _renamingPlaylistId = playlist.id;
      _renameBusy = false;
      _deleteConfirmPlaylistId = null;
      _creating = false;
      _renameController.text = playlist.name;
      _renameController.selection = TextSelection(
        baseOffset: 0,
        extentOffset: playlist.name.length,
      );
    });
    _focusAfterFrame(_renameFocusNode);
  }

  Future<void> _submitRename(Playlist playlist) async {
    if (_renameBusy || _renamingPlaylistId != playlist.id) {
      return;
    }
    setState(() => _renameBusy = true);
    final saved = await _runPlaylistMutation(
      context,
      () => widget.onRenamePlaylist(playlist.id, _renameController.text),
    );
    if (!mounted) {
      return;
    }
    setState(() {
      _renameBusy = false;
      if (saved) {
        _renamingPlaylistId = null;
        _renameController.clear();
      }
    });
  }

  void _cancelRename() {
    if (_renamingPlaylistId == null && !_renameBusy) {
      return;
    }
    setState(() {
      _renamingPlaylistId = null;
      _renameBusy = false;
      _renameController.clear();
    });
  }

  void _startDelete(Playlist playlist) {
    setState(() {
      _deleteConfirmPlaylistId = playlist.id;
      _deleteBusy = false;
      _renamingPlaylistId = null;
      _creating = false;
    });
  }

  Future<void> _confirmDelete(Playlist playlist) async {
    if (_deleteBusy || _deleteConfirmPlaylistId != playlist.id) {
      return;
    }
    setState(() => _deleteBusy = true);
    final deleted = await _runPlaylistMutation(
      context,
      () => widget.onDeletePlaylist(playlist.id),
    );
    if (!mounted) {
      return;
    }
    setState(() {
      _deleteBusy = false;
      if (deleted) {
        _deleteConfirmPlaylistId = null;
      }
    });
  }

  void _cancelDelete() {
    if (_deleteConfirmPlaylistId == null && !_deleteBusy) {
      return;
    }
    setState(() {
      _deleteConfirmPlaylistId = null;
      _deleteBusy = false;
    });
  }

  KeyEventResult _handleCreateKeyEvent(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) {
      return KeyEventResult.ignored;
    }
    if (event.logicalKey == LogicalKeyboardKey.escape) {
      _cancelCreate();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  KeyEventResult _handleRenameKeyEvent(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) {
      return KeyEventResult.ignored;
    }
    if (event.logicalKey == LogicalKeyboardKey.escape) {
      _cancelRename();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  void _focusAfterFrame(FocusNode node) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        node.requestFocus();
      }
    });
  }

  Future<bool> _runPlaylistMutation(
    BuildContext context,
    Future<void> Function() action,
  ) async {
    try {
      await action();
      return true;
    } on Object {
      if (!context.mounted) {
        return false;
      }
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        const SnackBar(content: Text('Could not update playlist.')),
      );
      return false;
    }
  }
}

class _PlaylistRail extends StatelessWidget {
  const _PlaylistRail({
    required this.playlists,
    required this.selectedPlaylistId,
    required this.activePlaylistId,
    required this.creating,
    required this.createBusy,
    required this.createController,
    required this.createFocusNode,
    required this.onSelected,
    required this.onCreateStart,
    required this.onCreateSubmit,
    required this.onCreateCancel,
  });

  final List<Playlist> playlists;
  final String selectedPlaylistId;
  final String? activePlaylistId;
  final bool creating;
  final bool createBusy;
  final TextEditingController createController;
  final FocusNode createFocusNode;
  final ValueChanged<String> onSelected;
  final VoidCallback onCreateStart;
  final VoidCallback onCreateSubmit;
  final VoidCallback onCreateCancel;

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 12),
            child: Row(
              children: [
                const Expanded(
                  child: Text(
                    'Playlists',
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
                  ),
                ),
                IconButton.filledTonal(
                  key: const ValueKey('playlist-create-button'),
                  onPressed: creating ? null : onCreateStart,
                  icon: const Icon(
                    Icons.add_rounded,
                    semanticLabel: 'Create playlist',
                  ),
                ),
              ],
            ),
          ),
        ),
        if (creating)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              child: _InlinePlaylistNameEditor(
                keyPrefix: 'playlist-create',
                controller: createController,
                focusNode: createFocusNode,
                busy: createBusy,
                hintText: 'New playlist name',
                onSubmit: onCreateSubmit,
                onCancel: onCreateCancel,
              ),
            ),
          ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 18),
          sliver: SliverList.separated(
            itemCount: playlists.length,
            separatorBuilder: (context, index) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final playlist = playlists[index];
              return _PlaylistRailTile(
                playlist: playlist,
                selected: playlist.id == selectedPlaylistId,
                active: playlist.id == activePlaylistId,
                onTap: () => onSelected(playlist.id),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _PlaylistRailTile extends StatelessWidget {
  const _PlaylistRailTile({
    required this.playlist,
    required this.selected,
    required this.active,
    required this.onTap,
  });

  final Playlist playlist;
  final bool selected;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final countLabel = playlist.entries.length == 1
        ? '1 track'
        : '${playlist.entries.length} tracks';
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: selected
                ? const Color(0xFF123842)
                : active
                ? const Color(0xFF102D35)
                : Colors.white.withValues(alpha: 0.045),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: selected || active
                  ? FumicTheme.accent.withValues(alpha: selected ? 0.72 : 0.42)
                  : Colors.white.withValues(alpha: 0.07),
            ),
          ),
          child: Row(
            children: [
              Icon(
                playlist.isFavourites
                    ? Icons.favorite_rounded
                    : Icons.queue_music_rounded,
                color: selected || active
                    ? FumicTheme.accent
                    : const Color(0xFFB8C0CF),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      playlist.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w900),
                    ),
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            countLabel,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: FumicTheme.muted,
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        if (active) const _MiniStatusBadge(text: 'Active'),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PlaylistDetail extends StatelessWidget {
  const _PlaylistDetail({
    required this.playlist,
    required this.libraryByPath,
    required this.addCandidate,
    required this.scanning,
    required this.active,
    required this.currentItemPath,
    required this.playbackPlaying,
    required this.renaming,
    required this.renameBusy,
    required this.renameController,
    required this.renameFocusNode,
    required this.deleteConfirming,
    required this.deleteBusy,
    required this.onCreate,
    required this.onRename,
    required this.onRenameSubmit,
    required this.onRenameCancel,
    required this.onDelete,
    required this.onDeleteConfirm,
    required this.onDeleteCancel,
    required this.onPlay,
    required this.onShuffle,
    required this.onAddItem,
    required this.onRemoveEntry,
    required this.onReorderEntry,
  });

  final Playlist playlist;
  final Map<String, MediaItem> libraryByPath;
  final MediaItem? addCandidate;
  final bool scanning;
  final bool active;
  final String? currentItemPath;
  final bool playbackPlaying;
  final bool renaming;
  final bool renameBusy;
  final TextEditingController renameController;
  final FocusNode renameFocusNode;
  final bool deleteConfirming;
  final bool deleteBusy;
  final VoidCallback onCreate;
  final VoidCallback? onRename;
  final VoidCallback onRenameSubmit;
  final VoidCallback onRenameCancel;
  final VoidCallback? onDelete;
  final VoidCallback onDeleteConfirm;
  final VoidCallback onDeleteCancel;
  final VoidCallback? onPlay;
  final VoidCallback? onShuffle;
  final Future<void> Function(MediaItem item) onAddItem;
  final Future<void> Function(String path) onRemoveEntry;
  final Future<void> Function(int oldIndex, int newIndex) onReorderEntry;

  @override
  Widget build(BuildContext context) {
    final resolvedCount = playlist.entries
        .where((entry) => libraryByPath.containsKey(_pathKey(entry.path)))
        .length;
    final addAction = _addActionFor(context, playlist, addCandidate);
    final currentKey = currentItemPath == null
        ? null
        : _pathKey(currentItemPath!);
    return CustomScrollView(
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(22, 18, 22, 12),
          sliver: SliverToBoxAdapter(
            child: _PlaylistToolbar(
              playlist: playlist,
              resolvedCount: resolvedCount,
              scanning: scanning,
              active: active,
              playbackPlaying: playbackPlaying,
              renaming: renaming,
              renameBusy: renameBusy,
              renameController: renameController,
              renameFocusNode: renameFocusNode,
              deleteConfirming: deleteConfirming,
              deleteBusy: deleteBusy,
              onCreate: onCreate,
              onRename: onRename,
              onRenameSubmit: onRenameSubmit,
              onRenameCancel: onRenameCancel,
              onDelete: onDelete,
              onDeleteConfirm: onDeleteConfirm,
              onDeleteCancel: onDeleteCancel,
              onPlay: onPlay,
              onShuffle: onShuffle,
              onAddSelected: addAction,
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: Divider(
            height: 1,
            color: Colors.white.withValues(alpha: 0.08),
          ),
        ),
        if (playlist.entries.isEmpty)
          SliverFillRemaining(
            hasScrollBody: false,
            child: _PlaylistEmptyState(
              playlist: playlist,
              onAddSelected: addAction,
              onCreate: onCreate,
            ),
          )
        else
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 120),
            sliver: SliverReorderableList(
              itemCount: playlist.entries.length,
              onReorder: (oldIndex, newIndex) {
                unawaited(
                  _runPlaylistMutation(
                    context,
                    () => onReorderEntry(oldIndex, newIndex),
                  ),
                );
              },
              proxyDecorator: (child, index, animation) {
                return Material(
                  color: Colors.transparent,
                  child: ScaleTransition(
                    scale: Tween<double>(
                      begin: 1,
                      end: 1.02,
                    ).animate(animation),
                    child: child,
                  ),
                );
              },
              itemBuilder: (context, index) {
                final entry = playlist.entries[index];
                final item = libraryByPath[_pathKey(entry.path)];
                return _PlaylistTrackRow(
                  key: ValueKey(entry.path),
                  index: index,
                  entry: entry,
                  item: item,
                  nowPlaying: active && currentKey == _pathKey(entry.path),
                  onRemove: () {
                    unawaited(
                      _runPlaylistMutation(
                        context,
                        () => onRemoveEntry(entry.path),
                      ),
                    );
                  },
                );
              },
            ),
          ),
      ],
    );
  }

  VoidCallback? _addActionFor(
    BuildContext context,
    Playlist playlist,
    MediaItem? candidate,
  ) {
    if (candidate == null) {
      return null;
    }
    final exists = playlist.entries.any(
      (entry) => _pathKey(entry.path) == _pathKey(candidate.path),
    );
    if (exists) {
      return null;
    }
    return () {
      unawaited(_runPlaylistMutation(context, () => onAddItem(candidate)));
    };
  }

  Future<void> _runPlaylistMutation(
    BuildContext context,
    Future<void> Function() action,
  ) async {
    try {
      await action();
    } on Object {
      if (!context.mounted) {
        return;
      }
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        const SnackBar(content: Text('Could not update playlist.')),
      );
    }
  }
}

class _PlaylistToolbar extends StatelessWidget {
  const _PlaylistToolbar({
    required this.playlist,
    required this.resolvedCount,
    required this.scanning,
    required this.active,
    required this.playbackPlaying,
    required this.renaming,
    required this.renameBusy,
    required this.renameController,
    required this.renameFocusNode,
    required this.deleteConfirming,
    required this.deleteBusy,
    required this.onCreate,
    required this.onRename,
    required this.onRenameSubmit,
    required this.onRenameCancel,
    required this.onDelete,
    required this.onDeleteConfirm,
    required this.onDeleteCancel,
    required this.onPlay,
    required this.onShuffle,
    required this.onAddSelected,
  });

  final Playlist playlist;
  final int resolvedCount;
  final bool scanning;
  final bool active;
  final bool playbackPlaying;
  final bool renaming;
  final bool renameBusy;
  final TextEditingController renameController;
  final FocusNode renameFocusNode;
  final bool deleteConfirming;
  final bool deleteBusy;
  final VoidCallback onCreate;
  final VoidCallback? onRename;
  final VoidCallback onRenameSubmit;
  final VoidCallback onRenameCancel;
  final VoidCallback? onDelete;
  final VoidCallback onDeleteConfirm;
  final VoidCallback onDeleteCancel;
  final VoidCallback? onPlay;
  final VoidCallback? onShuffle;
  final VoidCallback? onAddSelected;

  @override
  Widget build(BuildContext context) {
    final playLabel = active
        ? (playbackPlaying ? 'Playing' : 'Resume')
        : 'Play';
    final playIcon = active && playbackPlaying
        ? Icons.pause_rounded
        : Icons.play_arrow_rounded;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 12,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    playlist.isFavourites
                        ? Icons.favorite_rounded
                        : Icons.queue_music_rounded,
                    color: FumicTheme.accent,
                  ),
                  const SizedBox(width: 10),
                  Flexible(
                    child: Text(
                      playlist.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            SoftBadge(text: '${playlist.entries.length} saved'),
            SoftBadge(text: '$resolvedCount playable'),
            if (active) const SoftBadge(text: 'Active queue'),
            if (scanning) const SoftBadge(text: 'Scanning'),
          ],
        ),
        if (renaming) ...[
          const SizedBox(height: 12),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: _InlinePlaylistNameEditor(
              keyPrefix: 'playlist-rename',
              controller: renameController,
              focusNode: renameFocusNode,
              busy: renameBusy,
              hintText: 'Playlist name',
              onSubmit: onRenameSubmit,
              onCancel: onRenameCancel,
            ),
          ),
        ],
        const SizedBox(height: 12),
        Wrap(
          spacing: 10,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            FilledButton.icon(
              onPressed: onPlay,
              icon: Icon(playIcon),
              label: Text(playLabel),
            ),
            OutlinedButton.icon(
              onPressed: onAddSelected,
              icon: const Icon(Icons.playlist_add_rounded),
              label: const Text('Add Selected'),
            ),
            OutlinedButton.icon(
              onPressed: onShuffle,
              icon: const Icon(Icons.shuffle_rounded),
              label: const Text('Shuffle'),
            ),
            OutlinedButton.icon(
              onPressed: onCreate,
              icon: const Icon(Icons.add_rounded),
              label: const Text('Create'),
            ),
            if (onRename != null)
              OutlinedButton.icon(
                onPressed: renaming ? null : onRename,
                icon: const Icon(Icons.edit_rounded),
                label: const Text('Rename'),
              ),
            if (deleteConfirming) ...[
              FilledButton.icon(
                onPressed: deleteBusy ? null : onDeleteConfirm,
                icon: deleteBusy
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.delete_rounded),
                label: const Text('Confirm Delete'),
              ),
              OutlinedButton(
                onPressed: deleteBusy ? null : onDeleteCancel,
                child: const Text('Cancel'),
              ),
            ] else if (onDelete != null)
              OutlinedButton.icon(
                onPressed: onDelete,
                icon: const Icon(Icons.delete_outline_rounded),
                label: const Text('Delete'),
              ),
          ],
        ),
      ],
    );
  }
}

class _InlinePlaylistNameEditor extends StatelessWidget {
  const _InlinePlaylistNameEditor({
    required this.keyPrefix,
    required this.controller,
    required this.focusNode,
    required this.busy,
    required this.hintText,
    required this.onSubmit,
    required this.onCancel,
  });

  final String keyPrefix;
  final TextEditingController controller;
  final FocusNode focusNode;
  final bool busy;
  final String hintText;
  final VoidCallback onSubmit;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: const Color(0xFF0D141E),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              key: ValueKey('$keyPrefix-field'),
              controller: controller,
              focusNode: focusNode,
              enabled: !busy,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) {
                if (!busy) {
                  onSubmit();
                }
              },
              decoration: InputDecoration(
                isDense: true,
                hintText: hintText,
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(horizontal: 8),
              ),
            ),
          ),
          IconButton(
            key: ValueKey('$keyPrefix-save'),
            onPressed: busy ? null : onSubmit,
            icon: busy
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.check_rounded, semanticLabel: 'Save'),
          ),
          IconButton(
            key: ValueKey('$keyPrefix-cancel'),
            onPressed: busy ? null : onCancel,
            icon: const Icon(Icons.close_rounded, semanticLabel: 'Cancel'),
          ),
        ],
      ),
    );
  }
}

class _PlaylistTrackRow extends StatelessWidget {
  const _PlaylistTrackRow({
    super.key,
    required this.index,
    required this.entry,
    required this.item,
    required this.nowPlaying,
    required this.onRemove,
  });

  final int index;
  final PlaylistEntry entry;
  final MediaItem? item;
  final bool nowPlaying;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final resolved = item;
    final missing = resolved == null;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: missing ? const Color(0xFF1B222C) : const Color(0xFF1A2230),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: nowPlaying
              ? FumicTheme.accent.withValues(alpha: 0.55)
              : missing
              ? const Color(0xFF647084).withValues(alpha: 0.45)
              : Colors.white.withValues(alpha: 0.07),
        ),
      ),
      child: Row(
        children: [
          ReorderableDragStartListener(
            index: index,
            child: const Padding(
              padding: EdgeInsets.only(right: 10),
              child: Icon(
                Icons.drag_indicator_rounded,
                color: FumicTheme.muted,
              ),
            ),
          ),
          if (resolved == null)
            const _MissingArtwork()
          else
            Artwork(
              colors: resolved.colors,
              size: 56,
              icon: kindIcon(resolved),
              thumbnailPath: resolved.thumbnailPath,
            ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  resolved?.title ?? p.basename(entry.path),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  resolved?.artist ?? entry.path,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: FumicTheme.muted, fontSize: 13),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Wrap(
            spacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              if (nowPlaying) const SoftBadge(text: 'Now playing'),
              SoftBadge(text: resolved?.durationLabel ?? 'Unavailable'),
            ],
          ),
          const SizedBox(width: 8),
          IconButton(
            onPressed: onRemove,
            icon: const Icon(Icons.close_rounded, semanticLabel: 'Remove'),
          ),
        ],
      ),
    );
  }
}

class _MissingArtwork extends StatelessWidget {
  const _MissingArtwork();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 56,
      height: 56,
      decoration: BoxDecoration(
        color: const Color(0xFF202A35),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: const Icon(Icons.link_off_rounded, color: FumicTheme.muted),
    );
  }
}

class _PlaylistEmptyState extends StatelessWidget {
  const _PlaylistEmptyState({
    required this.playlist,
    required this.onAddSelected,
    required this.onCreate,
  });

  final Playlist playlist;
  final VoidCallback? onAddSelected;
  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              playlist.isFavourites
                  ? Icons.favorite_border_rounded
                  : Icons.queue_music_rounded,
              size: 62,
              color: const Color(0xFF677186),
            ),
            const SizedBox(height: 16),
            const Text(
              'No tracks yet',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 8),
            const Text(
              'Select a song or video, then add it here.',
              textAlign: TextAlign.center,
              style: TextStyle(color: FumicTheme.muted, fontSize: 15),
            ),
            const SizedBox(height: 18),
            Wrap(
              spacing: 10,
              runSpacing: 8,
              alignment: WrapAlignment.center,
              children: [
                FilledButton.icon(
                  onPressed: onAddSelected,
                  icon: const Icon(Icons.playlist_add_rounded),
                  label: const Text('Add Selected'),
                ),
                OutlinedButton.icon(
                  onPressed: onCreate,
                  icon: const Icon(Icons.add_rounded),
                  label: const Text('Create Playlist'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _MiniStatusBadge extends StatelessWidget {
  const _MiniStatusBadge({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: FumicTheme.accent.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: FumicTheme.accent.withValues(alpha: 0.28)),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: FumicTheme.accent,
          fontSize: 10,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

String _pathKey(String path) => path.trim().toLowerCase();
