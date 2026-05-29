import 'dart:async';

import 'package:flutter/material.dart';

import '../models/media_item.dart';
import '../models/media_kind.dart';
import '../theme/fumic_theme.dart';
import 'shared.dart';

class HomeLibrary extends StatefulWidget {
  const HomeLibrary({
    super.key,
    required this.tab,
    required this.selectedItemPath,
    required this.items,
    required this.scanning,
    required this.enrichingMetadata,
    required this.hasFolders,
    required this.audioCount,
    required this.videoCount,
    required this.sessionStopwatch,
    required this.scrollToTopRequest,
    required this.onPickFolder,
    required this.onItemSelected,
    required this.onItemActivated,
  });

  final MediaKind tab;
  final String? selectedItemPath;
  final List<MediaItem> items;
  final bool scanning;
  final bool enrichingMetadata;
  final bool hasFolders;
  final int audioCount;
  final int videoCount;
  final Stopwatch sessionStopwatch;
  final int scrollToTopRequest;
  final VoidCallback onPickFolder;
  final ValueChanged<MediaItem> onItemSelected;
  final ValueChanged<MediaItem> onItemActivated;

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
    if (oldWidget.scrollToTopRequest != widget.scrollToTopRequest) {
      _scrollToTop();
      return;
    }
    if (oldWidget.selectedItemPath != widget.selectedItemPath ||
        !_sameItemPaths(oldWidget.items, widget.items)) {
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
    if (widget.scanning) {
      return const _LibraryStatus(
        icon: Icons.manage_search_rounded,
        title: 'Scanning media folders...',
        subtitle: 'Fumic is indexing supported audio and video files.',
      );
    }

    if (widget.items.isEmpty) {
      return _EmptyLibrary(
        hasFolders: widget.hasFolders,
        onPickFolder: widget.onPickFolder,
      );
    }

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
            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: 470,
              mainAxisExtent: 134,
              mainAxisSpacing: 14,
              crossAxisSpacing: 14,
            ),
            itemBuilder: (context, localIndex) {
              final item = group.value[localIndex];
              final selected = item.path == widget.selectedItemPath;
              return _MediaTile(
                key: selected ? _selectedTileKey : ValueKey(item.path),
                item: item,
                selected: selected,
                onTap: () => widget.onItemSelected(item),
                onDoubleTap: () => widget.onItemActivated(item),
              );
            },
          ),
        ),
      );
    }

    slivers.add(const SliverToBoxAdapter(child: SizedBox(height: 120)));
    return CustomScrollView(controller: _scrollController, slivers: slivers);
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
  });

  final MediaKind tab;
  final int itemCount;
  final int audioCount;
  final int videoCount;
  final Stopwatch sessionStopwatch;
  final bool enrichingMetadata;

  @override
  Widget build(BuildContext context) {
    final label = tab == MediaKind.audio ? 'Audio library' : 'Video library';
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Wrap(
            spacing: 12,
            runSpacing: 10,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                ),
              ),
              SoftBadge(text: '$itemCount visible'),
              SoftBadge(text: '$audioCount audio'),
              SoftBadge(text: '$videoCount video'),
              if (enrichingMetadata) const SoftBadge(text: 'Loading details'),
            ],
          ),
        ),
        const SizedBox(width: 12),
        _SessionTimerBadge(stopwatch: sessionStopwatch),
      ],
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
          boxShadow: [
            BoxShadow(
              color: FumicTheme.accent.withValues(alpha: 0.12),
              blurRadius: 18,
              offset: const Offset(0, 8),
            ),
          ],
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
      padding: const EdgeInsets.fromLTRB(24, 18, 24, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Divider(color: Colors.white.withValues(alpha: 0.08)),
          const SizedBox(height: 10),
          Text(
            label,
            style: const TextStyle(
              fontSize: 56,
              height: 1,
              fontWeight: FontWeight.w900,
              color: Color(0xFFD6DAE2),
            ),
          ),
        ],
      ),
    );
  }
}

class _MediaTile extends StatelessWidget {
  const _MediaTile({
    super.key,
    required this.item,
    required this.selected,
    required this.onTap,
    required this.onDoubleTap,
  });

  final MediaItem item;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback onDoubleTap;

  @override
  Widget build(BuildContext context) {
    final borderRadius = BorderRadius.circular(12);
    final innerRadius = BorderRadius.circular(10);
    final borderWidth = selected ? 2.4 : 1.0;

    return Semantics(
      button: true,
      selected: selected,
      label: selected
          ? '${item.title}, selected media item'
          : '${item.title}, media item',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          onDoubleTap: onDoubleTap,
          borderRadius: borderRadius,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            padding: EdgeInsets.all(borderWidth),
            decoration: BoxDecoration(
              gradient: selected
                  ? const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Color(0xFF20F3E3),
                        Color(0xFF42A5FF),
                        Color(0xFF8B6CFF),
                        Color(0xFF20F3E3),
                      ],
                    )
                  : null,
              color: selected ? null : Colors.white.withValues(alpha: 0.09),
              borderRadius: borderRadius,
              boxShadow: selected
                  ? [
                      BoxShadow(
                        color: FumicTheme.accent.withValues(alpha: 0.26),
                        blurRadius: 26,
                        offset: const Offset(0, 14),
                      ),
                    ]
                  : null,
            ),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                gradient: selected
                    ? const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [Color(0xFF123842), Color(0xFF1F2D3B)],
                      )
                    : null,
                color: selected ? null : const Color(0xFF232A35),
                borderRadius: innerRadius,
              ),
              child: Row(
                children: [
                  Artwork(
                    colors: item.colors,
                    size: 96,
                    icon: kindIcon(item),
                    thumbnailPath: item.thumbnailPath,
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Row(
                          children: [
                            if (selected)
                              Container(
                                width: 24,
                                height: 24,
                                margin: const EdgeInsets.only(right: 8),
                                decoration: const BoxDecoration(
                                  color: FumicTheme.accent,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.play_arrow_rounded,
                                  size: 18,
                                  color: Color(0xFF051014),
                                ),
                              ),
                            Expanded(
                              child: Text(
                                item.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 5),
                        Text(
                          item.artist,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Color(0xFFC7CDD7),
                            fontSize: 18,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          item.durationLabel,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: FumicTheme.muted,
                            fontSize: 17,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _EmptyLibrary extends StatelessWidget {
  const _EmptyLibrary({required this.hasFolders, required this.onPickFolder});

  final bool hasFolders;
  final VoidCallback onPickFolder;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.folder_open_rounded,
            size: 70,
            color: Color(0xFF677186),
          ),
          const SizedBox(height: 18),
          Text(
            hasFolders
                ? 'No media found in this tab.'
                : 'Choose a media folder.',
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 10),
          Text(
            hasFolders
                ? 'Supported files include MP3, FLAC, M4A, OGG, OPUS, WAV, MP4, MKV, MOV, and WEBM.'
                : 'Fumic will recursively scan audio and video files.',
            style: const TextStyle(color: FumicTheme.muted, fontSize: 16),
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: onPickFolder,
            icon: const Icon(Icons.add_rounded),
            label: const Text('Add folder'),
          ),
        ],
      ),
    );
  }
}

class _LibraryStatus extends StatelessWidget {
  const _LibraryStatus({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 70, color: FumicTheme.accent),
          const SizedBox(height: 18),
          Text(
            title,
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 10),
          Text(subtitle, style: const TextStyle(color: FumicTheme.muted)),
        ],
      ),
    );
  }
}
