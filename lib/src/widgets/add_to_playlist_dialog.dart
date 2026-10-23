import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/media_item.dart';
import '../models/playlist.dart';
import '../theme/fumic_theme.dart';
import 'shared.dart';

class AddToPlaylistDialog extends StatefulWidget {
  const AddToPlaylistDialog({
    super.key,
    required this.item,
    required this.playlists,
    required this.playlistContainsItem,
    required this.onAddToPlaylist,
    required this.onCreatePlaylistAndAdd,
  });

  final MediaItem item;
  final List<Playlist> playlists;
  final bool Function(String playlistId) playlistContainsItem;
  final Future<void> Function(String playlistId) onAddToPlaylist;
  final Future<void> Function(String name) onCreatePlaylistAndAdd;

  @override
  State<AddToPlaylistDialog> createState() => _AddToPlaylistDialogState();
}

class _AddToPlaylistDialogState extends State<AddToPlaylistDialog> {
  final TextEditingController _nameController = TextEditingController();
  final FocusNode _dialogFocusNode = FocusNode(
    debugLabel: 'Add to playlist dialog',
  );
  final ScrollController _playlistScrollController = ScrollController();
  bool _busy = false;
  int _selectedIndex = 0;

  @override
  void initState() {
    super.initState();
    _selectedIndex = _firstAvailableIndex();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _dialogFocusNode.requestFocus();
      }
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _dialogFocusNode.dispose();
    _playlistScrollController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant AddToPlaylistDialog oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_selectedIndex >= widget.playlists.length) {
      _selectedIndex = _firstAvailableIndex();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      focusNode: _dialogFocusNode,
      onKeyEvent: _handleKeyEvent,
      child: Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 460),
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: const Color(0xF0101828),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: FumicTheme.edge),
              boxShadow: FumicTheme.panelShadow,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.playlist_add_rounded,
                      color: FumicTheme.accent,
                    ),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Text(
                        'Add to playlist',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Close',
                      onPressed: _busy
                          ? null
                          : () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                _SelectedTrack(item: widget.item),
                const SizedBox(height: 16),
                Flexible(
                  child: ListView.separated(
                    controller: _playlistScrollController,
                    shrinkWrap: true,
                    itemCount: widget.playlists.length,
                    separatorBuilder: (context, index) =>
                        const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final playlist = widget.playlists[index];
                      final exists = widget.playlistContainsItem(playlist.id);
                      return _PlaylistChoice(
                        key: ValueKey('playlist-choice-${playlist.id}'),
                        playlist: playlist,
                        selected: index == _selectedIndex,
                        exists: exists,
                        busy: _busy,
                        onTap: exists || _busy
                            ? null
                            : () => _addToPlaylist(playlist.id),
                        onHover: () {
                          if (_selectedIndex != index) {
                            setState(() => _selectedIndex = index);
                          }
                        },
                      );
                    },
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _nameController,
                        enabled: !_busy,
                        textInputAction: TextInputAction.done,
                        onSubmitted: (_) => _createAndAdd(),
                        decoration: InputDecoration(
                          hintText: 'New playlist name',
                          prefixIcon: const Icon(Icons.add_rounded),
                          filled: true,
                          fillColor: const Color(0xFF070B11),
                          border: _border(Colors.white.withValues(alpha: 0.10)),
                          enabledBorder: _border(
                            Colors.white.withValues(alpha: 0.10),
                          ),
                          focusedBorder: _border(FumicTheme.accent, width: 2),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    FilledButton.icon(
                      onPressed: _busy ? null : _createAndAdd,
                      icon: const Icon(Icons.playlist_add_rounded),
                      label: const Text('Create'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  OutlineInputBorder _border(Color color, {double width = 1}) {
    return OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: BorderSide(color: color, width: width),
    );
  }

  void _createAndAdd() {
    _run(() async {
      await widget.onCreatePlaylistAndAdd(_nameController.text);
    });
  }

  void _addToPlaylist(String playlistId) {
    _run(() async {
      await widget.onAddToPlaylist(playlistId);
    });
  }

  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    if (_textInputFocused) {
      if (event.logicalKey == LogicalKeyboardKey.escape && !_busy) {
        Navigator.of(context).pop();
        return KeyEventResult.handled;
      }
      return KeyEventResult.ignored;
    }
    if (event.logicalKey == LogicalKeyboardKey.escape && !_busy) {
      Navigator.of(context).pop();
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
      _moveSelection(1);
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
      _moveSelection(-1);
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.enter ||
        event.logicalKey == LogicalKeyboardKey.numpadEnter) {
      _activateSelected();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  bool get _textInputFocused {
    final context = FocusManager.instance.primaryFocus?.context;
    return context != null && context.widget is EditableText;
  }

  void _moveSelection(int delta) {
    if (widget.playlists.isEmpty || _busy) {
      return;
    }
    final next = (_selectedIndex + delta) % widget.playlists.length;
    setState(() {
      _selectedIndex = next < 0 ? widget.playlists.length - 1 : next;
    });
    _scrollSelectionIntoView();
  }

  void _activateSelected() {
    if (_busy ||
        _selectedIndex < 0 ||
        _selectedIndex >= widget.playlists.length) {
      return;
    }
    final playlist = widget.playlists[_selectedIndex];
    if (widget.playlistContainsItem(playlist.id)) {
      final next = _firstAvailableIndex();
      if (next != _selectedIndex) {
        setState(() => _selectedIndex = next);
        _scrollSelectionIntoView();
      }
      return;
    }
    _addToPlaylist(playlist.id);
  }

  int _firstAvailableIndex() {
    final index = widget.playlists.indexWhere(
      (playlist) => !widget.playlistContainsItem(playlist.id),
    );
    return index == -1 ? 0 : index;
  }

  void _scrollSelectionIntoView() {
    if (!_playlistScrollController.hasClients) {
      return;
    }
    const estimatedRowExtent = 66.0;
    final target = (_selectedIndex * estimatedRowExtent).clamp(
      0.0,
      _playlistScrollController.position.maxScrollExtent,
    );
    _playlistScrollController.animateTo(
      target,
      duration: const Duration(milliseconds: 120),
      curve: Curves.easeOut,
    );
  }

  Future<void> _run(Future<void> Function() action) async {
    if (_busy) {
      return;
    }
    setState(() => _busy = true);
    try {
      await action();
      if (mounted) {
        Navigator.of(context).pop();
      }
    } on Object {
      if (!mounted) {
        return;
      }
      setState(() => _busy = false);
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        const SnackBar(content: Text('Could not update playlist.')),
      );
    }
  }
}

class _SelectedTrack extends StatelessWidget {
  const _SelectedTrack({required this.item});

  final MediaItem item;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF1A2230),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Row(
        children: [
          Artwork(
            colors: item.colors,
            size: 54,
            icon: kindIcon(item),
            thumbnailPath: item.thumbnailPath,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 3),
                Text(
                  item.artist,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: FumicTheme.muted, fontSize: 13),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PlaylistChoice extends StatelessWidget {
  const _PlaylistChoice({
    super.key,
    required this.playlist,
    required this.selected,
    required this.exists,
    required this.busy,
    required this.onTap,
    required this.onHover,
  });

  final Playlist playlist;
  final bool selected;
  final bool exists;
  final bool busy;
  final VoidCallback? onTap;
  final VoidCallback onHover;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        onHover: (hovering) {
          if (hovering) {
            onHover();
          }
        },
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: selected ? const Color(0xFF123842) : const Color(0xFF1A2230),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: selected
                  ? FumicTheme.accent
                  : exists
                  ? FumicTheme.accent.withValues(alpha: 0.42)
                  : Colors.white.withValues(alpha: 0.07),
              width: selected ? 2 : 1,
            ),
          ),
          child: Row(
            children: [
              Icon(
                exists
                    ? Icons.check_circle_rounded
                    : Icons.playlist_play_rounded,
                color: exists ? FumicTheme.accent : const Color(0xFFB8C0CF),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  playlist.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
              ),
              SoftBadge(
                text: exists
                    ? 'Added'
                    : '${playlist.entries.length} ${playlist.entries.length == 1 ? 'track' : 'tracks'}',
              ),
            ],
          ),
        ),
      ),
    );
  }
}
