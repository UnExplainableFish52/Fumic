import 'dart:async';

import 'package:flutter/material.dart';

import '../models/media_item.dart';
import '../models/media_kind.dart';
import '../theme/fumic_theme.dart';
import '../services/cover_art_repository.dart';
import 'shared.dart';

class HomeLibrary extends StatefulWidget {
  const HomeLibrary({
    super.key,
    required this.tab,
    required this.selectedItemPath,
    required this.currentItemPath,
    required this.playing,
    required this.query,
    required this.libraryError,
    required this.items,
    required this.scanning,
    required this.enrichingMetadata,
    required this.hasFolders,
    required this.audioCount,
    required this.videoCount,
    required this.sessionStopwatch,
    required this.scrollToTopRequest,
    required this.onPickFolder,
    required this.onRefreshLibrary,
    required this.onClearSearch,
    required this.onTabSelected,
    required this.onItemSelected,
    required this.onItemActivated,
    required this.onCoverAction,
    required this.hasCustomCover,
  });

  final MediaKind tab;
  final String? selectedItemPath;
  final String? currentItemPath;
  final bool playing;
  final String query;
  final String? libraryError;
  final List<MediaItem> items;
  final bool scanning;
  final bool enrichingMetadata;
  final bool hasFolders;
  final int audioCount;
  final int videoCount;
  final Stopwatch sessionStopwatch;
  final int scrollToTopRequest;
  final VoidCallback onPickFolder;
  final VoidCallback onRefreshLibrary;
  final VoidCallback onClearSearch;
  final ValueChanged<MediaKind> onTabSelected;
  final ValueChanged<MediaItem> onItemSelected;
  final ValueChanged<MediaItem> onItemActivated;
  final Future<void> Function(MediaItem, CoverArtAction) onCoverAction;
  final bool Function(MediaItem) hasCustomCover;

  @override
  State<HomeLibrary> createState() => _HomeLibraryState();
}

class _HomeLibraryState extends State<HomeLibrary> {
  final GlobalKey _selectedTileKey = GlobalKey();
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scheduleSelectedItemIntoView();
  }

  @override
  void didUpdateWidget(HomeLibrary oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.scrollToTopRequest != widget.scrollToTopRequest ||
        oldWidget.query != widget.query) {
      _scrollToTop();
      return;
    }
    if (oldWidget.items.isNotEmpty &&
        (oldWidget.selectedItemPath != widget.selectedItemPath ||
            !_sameItemPaths(oldWidget.items, widget.items))) {
      _scheduleSelectedItemIntoView();
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final groups = _groupedItems(widget.items);
    final slivers = <Widget>[
      SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 22, 24, 8),
          child: _LibrarySummary(
            tab: widget.tab,
            itemCount: widget.items.length,
            audioCount: widget.audioCount,
            videoCount: widget.videoCount,
            sessionStopwatch: widget.sessionStopwatch,
            enrichingMetadata: widget.enrichingMetadata,
            scanning: widget.scanning,
            query: widget.query,
            onPickFolder: widget.onPickFolder,
            onRefreshLibrary: widget.onRefreshLibrary,
          ),
        ),
      ),
      if (widget.libraryError != null)
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 12, 24, 8),
            child: Semantics(
              liveRegion: true,
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF362A21),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.folder_off_outlined,
                      color: Color(0xFFFFCC80),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text(
                        'Some folders could not be read. Check that your library folders are available, then refresh.',
                      ),
                    ),
                    TextButton(
                      onPressed: widget.onRefreshLibrary,
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      if (widget.scanning)
        const SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            child: LinearProgressIndicator(minHeight: 2),
          ),
        ),
      if (widget.items.isEmpty)
        SliverToBoxAdapter(
          child: _EmptyLibrary(
            hasFolders: widget.hasFolders,
            searching: widget.query.trim().isNotEmpty,
            scanning: widget.scanning,
            tab: widget.tab,
            otherTabCount: widget.tab == MediaKind.audio
                ? widget.videoCount
                : widget.audioCount,
            onClearSearch: widget.onClearSearch,
            onSwitchTab: () => widget.onTabSelected(
              widget.tab == MediaKind.audio ? MediaKind.video : MediaKind.audio,
            ),
          ),
        ),
    ];

    for (final group in groups.entries) {
      final count = group.value.length;
      slivers.add(SliverToBoxAdapter(child: _GroupHeading(label: group.key)));
      slivers.add(
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 14),
          sliver: SliverGrid.builder(
            itemCount: count,
            gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: widget.tab == MediaKind.audio ? 560 : 470,
              mainAxisExtent: widget.tab == MediaKind.audio ? 104 : 134,
              mainAxisSpacing: 14,
              crossAxisSpacing: 14,
            ),
            itemBuilder: (context, localIndex) {
              final item = group.value[localIndex];
              final selected = item.path == widget.selectedItemPath;
              return _MediaTile(
                key: selected ? _selectedTileKey : ValueKey(item.path),
                item: item,
                hasCustomCover: widget.hasCustomCover(item),
                onCoverAction: (action) => widget.onCoverAction(item, action),
                selected: selected,
                current: item.path == widget.currentItemPath,
                playing: widget.playing,
                onTap: () => widget.onItemSelected(item),
                onDoubleTap: () => widget.onItemActivated(item),
              );
            },
          ),
        ),
      );
    }

    if (widget.items.isNotEmpty) {
      slivers.add(const SliverToBoxAdapter(child: SizedBox(height: 28)));
    }
    return Scrollbar(
      controller: _scrollController,
      child: CustomScrollView(controller: _scrollController, slivers: slivers),
    );
  }

  void _scrollToTop() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scrollController.hasClients) {
        return;
      }
      _scrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
      );
    });
  }

  void _scheduleSelectedItemIntoView() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      final context = _selectedTileKey.currentContext;
      if (context == null) {
        return;
      }
      Scrollable.ensureVisible(
        context,
        duration: const Duration(milliseconds: 140),
        curve: Curves.easeOut,
        alignment: 0.35,
      );
    });
  }

  Map<String, List<MediaItem>> _groupedItems(List<MediaItem> source) {
    final groups = <String, List<MediaItem>>{};
    for (final item in source) {
      final trimmedTitle = item.title.trim();
      final first = trimmedTitle.isEmpty
          ? '#'
          : trimmedTitle.substring(0, 1).toUpperCase();
      final key = RegExp('[A-Z]').hasMatch(first) ? first : '#';
      groups.putIfAbsent(key, () => <MediaItem>[]).add(item);
    }
    return groups;
  }

  bool _sameItemPaths(List<MediaItem> a, List<MediaItem> b) {
    if (identical(a, b)) {
      return true;
    }
    if (a.length != b.length) {
      return false;
    }
    for (var index = 0; index < a.length; index++) {
      if (a[index].path != b[index].path) {
        return false;
      }
    }
    return true;
  }
}

class _LibrarySummary extends StatelessWidget {
  const _LibrarySummary({
    required this.tab,
    required this.itemCount,
    required this.audioCount,
    required this.videoCount,
    required this.sessionStopwatch,
    required this.enrichingMetadata,
    required this.scanning,
    required this.query,
    required this.onPickFolder,
    required this.onRefreshLibrary,
  });

  final MediaKind tab;
  final int itemCount;
  final int audioCount;
  final int videoCount;
  final Stopwatch sessionStopwatch;
  final bool enrichingMetadata;
  final bool scanning;
  final String query;
  final VoidCallback onPickFolder;
  final VoidCallback onRefreshLibrary;

  @override
  Widget build(BuildContext context) {
    final label = tab == MediaKind.audio ? 'Audio library' : 'Video library';
    final total = tab == MediaKind.audio ? audioCount : videoCount;
    final noun = tab == MediaKind.audio ? 'tracks' : 'videos';
    final heading = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 6),
        Text(
          scanning
              ? 'Looking for your music and videos…'
              : query.trim().isNotEmpty
              ? '$itemCount results in $total $noun'
              : '$total $noun · Your files, always local',
          style: const TextStyle(color: FumicTheme.muted, fontSize: 14),
        ),
      ],
    );
    final actions = Wrap(
      spacing: 8,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        if (enrichingMetadata) const SoftBadge(text: 'Loading details'),
        OutlinedButton.icon(
          onPressed: scanning ? null : onRefreshLibrary,
          icon: const Icon(Icons.refresh_rounded, size: 18),
          label: const Text('Refresh'),
        ),
        FilledButton.icon(
          onPressed: scanning ? null : onPickFolder,
          icon: const Icon(Icons.create_new_folder_outlined, size: 18),
          label: const Text('Add folder'),
        ),
      ],
    );
    return LayoutBuilder(
      builder: (context, constraints) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (constraints.maxWidth >= 760)
              Row(
                children: [
                  Expanded(child: heading),
                  if (constraints.maxWidth >= 1180) ...[
                    _SessionTimerBadge(stopwatch: sessionStopwatch),
                    const SizedBox(width: 16),
                  ],
                  const SizedBox(width: 16),
                  actions,
                ],
              )
            else ...[
              heading,
              const SizedBox(height: 16),
              actions,
            ],
          ],
        );
      },
    );
  }
}

class _SessionTimerBadge extends StatefulWidget {
  const _SessionTimerBadge({required this.stopwatch});

  final Stopwatch stopwatch;

  @override
  State<_SessionTimerBadge> createState() => _SessionTimerBadgeState();
}

class _SessionTimerBadgeState extends State<_SessionTimerBadge> {
  Timer? _timer;
  Duration _elapsed = Duration.zero;

  @override
  void initState() {
    super.initState();
    _elapsed = widget.stopwatch.elapsed;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _timer?.cancel();
    _timer = null;
    _elapsed = widget.stopwatch.elapsed;
    if (!TickerMode.valuesOf(context).enabled) return;
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _elapsed = widget.stopwatch.elapsed;
      });
    });
  }

  @override
  void didUpdateWidget(covariant _SessionTimerBadge oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.stopwatch != widget.stopwatch) {
      _elapsed = widget.stopwatch.elapsed;
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Session time ${_formatSemanticDuration(_elapsed)}',
      child: Container(
        height: 42,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: const Color(0xFF112832).withValues(alpha: 0.86),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: FumicTheme.accent.withValues(alpha: 0.42)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.timer_rounded, size: 17, color: FumicTheme.accent),
            const SizedBox(width: 8),
            Text(
              'Session: ${_formatSessionDuration(_elapsed)}',
              style: const TextStyle(
                color: Color(0xFFDDE8ED),
                fontSize: 13,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatSessionDuration(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    if (hours > 0) {
      return '${hours}h ${minutes}m';
    }
    final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '${minutes}m ${seconds}s';
  }

  String _formatSemanticDuration(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);
    if (hours > 0) {
      return '$hours hours and $minutes minutes';
    }
    return '$minutes minutes and $seconds seconds';
  }
}

class _GroupHeading extends StatelessWidget {
  const _GroupHeading({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(26, 22, 26, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 13,
              height: 1,
              fontWeight: FontWeight.w600,
              color: Color(0xFFD6DAE2),
            ),
          ),
        ],
      ),
    );
  }
}

class _MediaTile extends StatefulWidget {
  const _MediaTile({
    super.key,
    required this.item,
    required this.selected,
    required this.current,
    required this.playing,
    required this.onTap,
    required this.onDoubleTap,
    required this.onCoverAction,
    required this.hasCustomCover,
  });
  final MediaItem item;
  final bool selected;
  final bool current;
  final bool playing;
  final VoidCallback onTap;
  final VoidCallback onDoubleTap;
  final Future<void> Function(CoverArtAction) onCoverAction;
  final bool hasCustomCover;

  @override
  State<_MediaTile> createState() => _MediaTileState();
}

class _MediaTileState extends State<_MediaTile> {
  bool _hovered = false;
  bool _focused = false;

  Future<void> _showCoverMenu(Offset position) async {
    final overlay =
        Overlay.of(context).context.findRenderObject()! as RenderBox;
    final local = overlay.globalToLocal(position);
    final action = await showMenu<CoverArtAction>(
      context: context,
      position: RelativeRect.fromRect(
        local & Size.zero,
        Offset.zero & overlay.size,
      ),
      items: [
        const PopupMenuItem(
          value: CoverArtAction.chooseSong,
          child: Text('Choose song cover'),
        ),
        const PopupMenuItem(
          value: CoverArtAction.chooseFolder,
          child: Text('Choose cover for this folder'),
        ),
        if (widget.hasCustomCover) ...[
          const PopupMenuDivider(),
          const PopupMenuItem(
            value: CoverArtAction.restoreSong,
            child: Text('Restore original song cover'),
          ),
          const PopupMenuItem(
            value: CoverArtAction.restoreFolder,
            child: Text('Restore covers in this folder'),
          ),
        ],
      ],
    );
    if (action != null && mounted) await widget.onCoverAction(action);
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final baseFill = FumicTheme.cardFill(context, hovered: _hovered);
    final emphasized = widget.selected || _focused;
    final radius = BorderRadius.circular(16);
    return Semantics(
      button: true,
      selected: widget.selected,
      onTap: widget.onDoubleTap,
      hint: 'Double-click to play. Ctrl + Enter plays the selected track.',
      label:
          '${item.title}, ${item.artist}${widget.current
              ? widget.playing
                    ? ", now playing"
                    : ", paused"
              : ""}',
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          decoration: BoxDecoration(
            color: widget.selected
                ? const Color(
                    0xFF293250,
                  ).withValues(alpha: baseFill.a.clamp(0.86, 1.0))
                : _focused
                ? Color.alphaBlend(
                    FumicTheme.brand.withValues(alpha: 0.12),
                    baseFill,
                  )
                : baseFill,
            borderRadius: radius,
            border: Border.all(
              color: emphasized
                  ? FumicTheme.brand
                  : widget.current
                  ? FumicTheme.accent
                  : Colors.white.withValues(alpha: _hovered ? 0.18 : 0.08),
              // A constant width keeps the content still as selection moves.
              width: 2,
            ),
          ),
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (emphasized)
                Positioned(
                  left: 5,
                  top: 18,
                  bottom: 18,
                  child: Container(
                    width: 4,
                    decoration: BoxDecoration(
                      color: FumicTheme.brand,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
              Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: widget.onTap,
                  onDoubleTap: widget.onDoubleTap,
                  onSecondaryTapDown: item.kind == MediaKind.audio
                      ? (details) => _showCoverMenu(details.globalPosition)
                      : null,
                  onFocusChange: (value) => setState(() => _focused = value),
                  borderRadius: radius,
                  hoverColor: Colors.transparent,
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Row(
                      children: [
                        Artwork(
                          colors: item.colors,
                          size: item.kind == MediaKind.audio ? 62 : 76,
                          icon: kindIcon(item),
                          thumbnailPath: item.thumbnailPath,
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                item.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                  color: widget.current
                                      ? FumicTheme.accent
                                      : FumicTheme.text,
                                ),
                              ),
                              const SizedBox(height: 5),
                              Text(
                                item.artist,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: FumicTheme.muted,
                                  fontSize: 13,
                                ),
                              ),
                              if (item.kind == MediaKind.video) ...[
                                const SizedBox(height: 5),
                                Text(
                                  item.durationLabel,
                                  style: const TextStyle(
                                    color: FumicTheme.muted,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        if (widget.current)
                          Icon(
                            widget.playing
                                ? Icons.graphic_eq_rounded
                                : Icons.pause_rounded,
                            color: FumicTheme.accent,
                            size: 20,
                          )
                        else if (item.kind == MediaKind.audio)
                          Text(
                            item.durationLabel,
                            style: const TextStyle(
                              color: FumicTheme.muted,
                              fontSize: 12,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyLibrary extends StatelessWidget {
  const _EmptyLibrary({
    required this.hasFolders,
    required this.searching,
    required this.scanning,
    required this.tab,
    required this.otherTabCount,
    required this.onClearSearch,
    required this.onSwitchTab,
  });

  final bool hasFolders;
  final bool searching;
  final bool scanning;
  final MediaKind tab;
  final int otherTabCount;
  final VoidCallback onClearSearch;
  final VoidCallback onSwitchTab;

  @override
  Widget build(BuildContext context) {
    final title = scanning
        ? 'Scanning your library'
        : searching
        ? 'No matching media'
        : !hasFolders
        ? 'Your library starts here'
        : tab == MediaKind.audio
        ? 'No audio here yet'
        : 'No videos here yet';
    final subtitle = scanning
        ? 'Your files stay on this device.'
        : searching
        ? 'Try another title or artist, or clear your search to see everything in this tab.'
        : !hasFolders
        ? 'Add a folder with music or videos. Fumic finds supported files in its subfolders, too.'
        : 'Add another folder to find more media. You can manage your folders in Settings.';
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 460),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(22),
                decoration: BoxDecoration(
                  color: FumicTheme.accent.withValues(alpha: 0.07),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: FumicTheme.accent.withValues(alpha: 0.15),
                  ),
                ),
                child: Icon(
                  searching
                      ? Icons.search_off_rounded
                      : Icons.library_music_outlined,
                  size: 42,
                  color: FumicTheme.accent,
                ),
              ),
              const SizedBox(height: 18),
              Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                subtitle,
                textAlign: TextAlign.center,
                style: const TextStyle(color: FumicTheme.muted, height: 1.6),
              ),
              if (!scanning) ...[
                const SizedBox(height: 22),
                if (searching)
                  FilledButton.icon(
                    onPressed: onClearSearch,
                    icon: const Icon(Icons.close_rounded),
                    label: const Text('Clear search'),
                  )
                else if (otherTabCount > 0)
                  OutlinedButton.icon(
                    onPressed: onSwitchTab,
                    icon: const Icon(Icons.swap_horiz_rounded),
                    label: Text(
                      tab == MediaKind.audio ? 'Browse videos' : 'Browse audio',
                    ),
                  ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
