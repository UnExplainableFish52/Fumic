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
        final compact = constraints.maxWidth < 980;
        return Container(
          height: compact ? 168 : 106,
          padding: EdgeInsets.symmetric(horizontal: compact ? 18 : 28),
          decoration: BoxDecoration(
            color: FumicTheme.panel,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
          ),
          child: compact ? _compactContent() : _wideContent(),
        );
      },
    );
  }

  Widget _compactContent() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Row(
          children: [
            const _Brand(),
            const Spacer(),
            SegmentedMediaTabs(tab: tab, onTabSelected: onTabSelected),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
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
            const SizedBox(width: 12),
            Expanded(
              child: _SearchField(
                controller: searchController,
                focusNode: searchFocusNode,
              ),
            ),
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

class _Brand extends StatefulWidget {
  const _Brand();

  @override
  State<_Brand> createState() => _BrandState();
}

class _BrandState extends State<_Brand> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return SelectionContainer.disabled(
      child: MouseRegion(
        cursor: SystemMouseCursors.basic,
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: Semantics(
          image: true,
          label: 'Fumic',
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 120),
            curve: Curves.easeOut,
            width: 184,
            height: 82,
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: _hovered
                    ? FumicTheme.accent.withValues(alpha: 0.72)
                    : Colors.transparent,
                width: 1.2,
              ),
            ),
            child: Center(
              child: Image.asset(
                'icons/fumic_logo_trans.png',
                width: 74,
                height: 74,
                fit: BoxFit.contain,
                filterQuality: FilterQuality.high,
                excludeFromSemantics: true,
                gaplessPlayback: true,
              ),
            ),
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
      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
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
        fillColor: const Color(0xFF070B11),
        contentPadding: const EdgeInsets.symmetric(vertical: 17),
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
              return const Color(0xFF172A33);
            }
            if (states.contains(WidgetState.hovered) ||
                states.contains(WidgetState.focused)) {
              return Colors.white.withValues(alpha: 0.045);
            }
            return Colors.transparent;
          }),
          foregroundColor: WidgetStateProperty.resolveWith((states) {
            if (selected) {
              return Colors.white;
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
            const EdgeInsets.symmetric(horizontal: 20),
          ),
          shape: WidgetStateProperty.resolveWith((states) {
            final borderColor = selected
                ? FumicTheme.accent.withValues(alpha: 0.62)
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
            fontSize: 16,
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
        color: const Color(0xFF171E2A),
        borderRadius: BorderRadius.circular(12),
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
      width: 108,
      height: 44,
      child: TextButton(
        onPressed: onTap,
        style: TextButton.styleFrom(
          foregroundColor: selected ? Colors.white : Colors.white70,
          backgroundColor: selected
              ? const Color(0xFF26313D)
              : Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(9),
            side: selected
                ? const BorderSide(color: FumicTheme.accent, width: 1.5)
                : BorderSide.none,
          ),
        ),
        child: Text(label, style: const TextStyle(fontSize: 18)),
      ),
    );
  }
}
