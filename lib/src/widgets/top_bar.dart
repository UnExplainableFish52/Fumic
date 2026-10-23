import 'package:flutter/material.dart';

import '../models/fumic_page.dart';
import '../models/media_kind.dart';
import '../theme/fumic_theme.dart';

class TopBar extends StatelessWidget {
  const TopBar({
    super.key,
    required this.page,
    required this.tab,
    required this.searchController,
    required this.searchFocusNode,
    required this.onPageSelected,
    required this.onTabSelected,
  });

  final FumicPage page;
  final MediaKind tab;
  final TextEditingController searchController;
  final FocusNode searchFocusNode;
  final ValueChanged<FumicPage> onPageSelected;
  final ValueChanged<MediaKind> onTabSelected;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 1180;
        final narrow = constraints.maxWidth < 720;
        return Container(
          padding: EdgeInsets.symmetric(
            horizontal: compact ? 16 : 24,
            vertical: 14,
          ),
          decoration: FumicTheme.glassDecoration(context, elevated: true),
          child: compact ? _compactContent(narrow: narrow) : _wideContent(),
        );
      },
    );
  }

  Widget _navigation() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final entry in const {
          FumicPage.home: 'Home',
          FumicPage.playlists: 'Playlists',
          FumicPage.settings: 'Settings',
          FumicPage.info: 'Info',
        }.entries)
          Padding(
            padding: const EdgeInsets.only(right: 4),
            child: _NavButton(
              label: entry.value,
              selected: page == entry.key,
              onTap: () => onPageSelected(entry.key),
            ),
          ),
      ],
    );
  }

  Widget _compactContent({required bool narrow}) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Row(
          children: [
            const _Brand(),
            const Spacer(),
            if (narrow)
              SegmentedMediaTabs(tab: tab, onTabSelected: onTabSelected)
            else
              _navigation(),
          ],
        ),
        const SizedBox(height: 12),
        if (narrow) ...[_navigation(), const SizedBox(height: 12)],
        Row(
          children: [
            Expanded(
              child: _SearchField(
                controller: searchController,
                focusNode: searchFocusNode,
              ),
            ),
            if (!narrow) ...[
              const SizedBox(width: 16),
              SegmentedMediaTabs(tab: tab, onTabSelected: onTabSelected),
            ],
          ],
        ),
      ],
    );
  }

  Widget _wideContent() {
    return Row(
      children: [
        const _Brand(),
        const SizedBox(width: 24),
        _NavButton(
          label: 'Home',
          selected: page == FumicPage.home,
          onTap: () => onPageSelected(FumicPage.home),
        ),
        const SizedBox(width: 8),
        _NavButton(
          label: 'Playlists',
          selected: page == FumicPage.playlists,
          onTap: () => onPageSelected(FumicPage.playlists),
        ),
        const SizedBox(width: 8),
        _NavButton(
          label: 'Settings',
          selected: page == FumicPage.settings,
          onTap: () => onPageSelected(FumicPage.settings),
        ),
        const SizedBox(width: 8),
        _NavButton(
          label: 'Info',
          selected: page == FumicPage.info,
          onTap: () => onPageSelected(FumicPage.info),
        ),
        const SizedBox(width: 24),
        Expanded(
          child: Align(
            alignment: Alignment.center,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 550),
              child: _SearchField(
                controller: searchController,
                focusNode: searchFocusNode,
              ),
            ),
          ),
        ),
        const SizedBox(width: 24),
        SegmentedMediaTabs(tab: tab, onTabSelected: onTabSelected),
      ],
    );
  }
}

class _Brand extends StatelessWidget {
  const _Brand();

  @override
  Widget build(BuildContext context) {
    return SelectionContainer.disabled(
      child: Semantics(
        image: true,
        label: 'Fumic',
        excludeSemantics: true,
        child: SizedBox(
          width: 156,
          height: 48,
          child: Row(
            children: [
              Image.asset(
                'icons/fumic_logo_trans.png',
                width: 42,
                height: 42,
                fit: BoxFit.contain,
                filterQuality: FilterQuality.high,
                excludeFromSemantics: true,
                gaplessPlayback: true,
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Fumic',
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.6,
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

class _SearchField extends StatelessWidget {
  const _SearchField({required this.controller, required this.focusNode});

  final TextEditingController controller;
  final FocusNode focusNode;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      focusNode: focusNode,
      textInputAction: TextInputAction.search,
      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
      decoration: InputDecoration(
        hintText: 'Search media (Ctrl + K)',
        prefixIcon: const Icon(Icons.search_rounded),
        suffixIcon: controller.text.isEmpty
            ? null
            : IconButton(
                tooltip: 'Clear search',
                icon: const Icon(Icons.close_rounded),
                onPressed: controller.clear,
              ),
        filled: true,
        fillColor: FumicTheme.inset,
        contentPadding: const EdgeInsets.symmetric(vertical: 14),
        border: _border(Colors.white.withValues(alpha: 0.10)),
        enabledBorder: _border(Colors.white.withValues(alpha: 0.10)),
        focusedBorder: _border(FumicTheme.accent, width: 2),
      ),
    );
  }

  OutlineInputBorder _border(Color color, {double width = 1}) {
    return OutlineInputBorder(
      borderRadius: BorderRadius.circular(28),
      borderSide: BorderSide(color: color, width: width),
    );
  }
}

class _NavButton extends StatelessWidget {
  const _NavButton({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 48,
      child: TextButton(
        onPressed: onTap,
        style: ButtonStyle(
          backgroundColor: WidgetStateProperty.resolveWith((states) {
            if (selected) {
              return FumicTheme.accent.withValues(alpha: 0.10);
            }
            if (states.contains(WidgetState.hovered) ||
                states.contains(WidgetState.focused)) {
              return Colors.white.withValues(alpha: 0.045);
            }
            return const Color(0x80101828);
          }),
          foregroundColor: WidgetStateProperty.resolveWith((states) {
            if (selected) {
              return FumicTheme.accent;
            }
            if (states.contains(WidgetState.hovered) ||
                states.contains(WidgetState.focused)) {
              return const Color(0xFFE5F8F6);
            }
            return const Color(0xFFC7CED8);
          }),
          overlayColor: WidgetStateProperty.all(
            FumicTheme.accent.withValues(alpha: 0.06),
          ),
          padding: WidgetStateProperty.all(
            const EdgeInsets.symmetric(horizontal: 16),
          ),
          shape: WidgetStateProperty.resolveWith((states) {
            final borderColor = selected
                ? FumicTheme.accent.withValues(alpha: 0.22)
                : states.contains(WidgetState.hovered) ||
                      states.contains(WidgetState.focused)
                ? FumicTheme.accent.withValues(alpha: 0.24)
                : Colors.transparent;
            return RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
              side: BorderSide(color: borderColor, width: selected ? 1.2 : 1),
            );
          }),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

class SegmentedMediaTabs extends StatelessWidget {
  const SegmentedMediaTabs({
    super.key,
    required this.tab,
    required this.onTabSelected,
  });

  final MediaKind tab;
  final ValueChanged<MediaKind> onTabSelected;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: FumicTheme.inset,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: FumicTheme.edge),
      ),
      child: Row(
        children: [
          _SegmentButton(
            label: 'Audio',
            selected: tab == MediaKind.audio,
            onTap: () => onTabSelected(MediaKind.audio),
          ),
          _SegmentButton(
            label: 'Video',
            selected: tab == MediaKind.video,
            onTap: () => onTabSelected(MediaKind.video),
          ),
        ],
      ),
    );
  }
}

class _SegmentButton extends StatelessWidget {
  const _SegmentButton({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 80,
      height: 40,
      child: TextButton(
        onPressed: onTap,
        style: TextButton.styleFrom(
          foregroundColor: selected ? Colors.white : Colors.white70,
          backgroundColor: selected
              ? FumicTheme.accent.withValues(alpha: 0.12)
              : Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(9),
            side: selected
                ? BorderSide(color: FumicTheme.accent.withValues(alpha: 0.3))
                : BorderSide.none,
          ),
        ),
        child: Text(
          label,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }
}
