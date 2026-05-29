import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app/fumic_shortcuts.dart';
import '../theme/fumic_theme.dart';
import 'shared.dart';

class InfoPage extends StatefulWidget {
  const InfoPage({super.key});

  @override
  State<InfoPage> createState() => _InfoPageState();
}

class _InfoPageState extends State<InfoPage> {
  final TextEditingController _shortcutSearchController =
      TextEditingController();

  @override
  void dispose() {
    _shortcutSearchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(28, 30, 28, 150),
      children: [
        const _InfoHero(),
        const SizedBox(height: 26),
        const _ProjectStrip(),
        const SizedBox(height: 26),
        _ShortcutReference(controller: _shortcutSearchController),
        const SizedBox(height: 30),
        const SectionTitle('Features'),
        const SizedBox(height: 14),
        const _FeatureGrid(),
        const SizedBox(height: 30),
        const SectionTitle('FAQ'),
        const SizedBox(height: 14),
        const _FaqSection(),
      ],
    );
  }
}

class _InfoHero extends StatelessWidget {
  const _InfoHero();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 34),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF202B3D), Color(0xFF141B28), Color(0xFF102A2E)],
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.24),
            blurRadius: 34,
            offset: const Offset(0, 18),
          ),
        ],
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 760;
          final logo = Container(
            width: compact ? 96 : 132,
            height: compact ? 96 : 132,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF101722),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: FumicTheme.accent),
            ),
            child: const Image(
              image: AssetImage('icons/fumic_logo_trans.png'),
              fit: BoxFit.contain,
              filterQuality: FilterQuality.high,
            ),
          );
          final copy = const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'FUMIC',
                style: TextStyle(fontSize: 32, fontWeight: FontWeight.w900),
              ),
              SizedBox(height: 8),
              Text(
                'The Magical Media Player (FOSS)',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900),
              ),
              SizedBox(height: 14),
              Text(
                'A keyboard-first, offline-focused desktop media player built for people who want speed, control, and clean software.',
                style: TextStyle(
                  color: Color(0xFFD2D8E3),
                  fontSize: 16,
                  height: 1.45,
                ),
              ),
            ],
          );
          if (compact) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [logo, const SizedBox(height: 22), copy],
            );
          }
          return Row(
            children: [
              logo,
              const SizedBox(width: 26),
              Expanded(child: copy),
            ],
          );
        },
      ),
    );
  }
}

class _ProjectStrip extends StatelessWidget {
  const _ProjectStrip();

  @override
  Widget build(BuildContext context) {
    return const Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [
        _ProjectPill(icon: Icons.public_rounded, label: 'GPL-3.0'),
        _ProjectPill(icon: Icons.lock_rounded, label: 'Offline-first'),
        _ProjectPill(icon: Icons.keyboard_alt_rounded, label: 'Keyboard-first'),
        _ProjectPill(icon: Icons.favorite_rounded, label: 'Community-focused'),
      ],
    );
  }
}

class _ShortcutReference extends StatefulWidget {
  const _ShortcutReference({required this.controller});

  final TextEditingController controller;

  @override
  State<_ShortcutReference> createState() => _ShortcutReferenceState();
}

class _ShortcutReferenceState extends State<_ShortcutReference> {
  static const _sections = [
    'Playback',
    'Navigation',
    'Audio',
    'Video',
    'Library',
    'Interface',
  ];

  @override
  Widget build(BuildContext context) {
    final query = widget.controller.text.trim().toLowerCase();
    final entries = fumicShortcutCatalog
        .where((entry) {
          if (query.isEmpty) {
            return true;
          }
          return entry.keys.toLowerCase().contains(query) ||
              entry.action.toLowerCase().contains(query) ||
              entry.section.toLowerCase().contains(query);
        })
        .toList(growable: false);

    return _Surface(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 14,
            runSpacing: 12,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              const Text(
                'Keyboard Shortcuts',
                style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900),
              ),
              SoftBadge(text: '${entries.length} shown'),
              SizedBox(
                width: 340,
                child: TextField(
                  controller: widget.controller,
                  onChanged: (_) => setState(() {}),
                  textInputAction: TextInputAction.search,
                  decoration: InputDecoration(
                    hintText: 'Search shortcuts',
                    prefixIcon: const Icon(Icons.search_rounded),
                    suffixIcon: widget.controller.text.isEmpty
                        ? null
                        : IconButton(
                            tooltip: 'Clear shortcut search',
                            onPressed: () {
                              widget.controller.clear();
                              setState(() {});
                            },
                            icon: const Icon(Icons.close_rounded),
                          ),
                    filled: true,
                    fillColor: const Color(0xFF111821),
                    border: _fieldBorder(Colors.white.withValues(alpha: 0.10)),
                    enabledBorder: _fieldBorder(
                      Colors.white.withValues(alpha: 0.10),
                    ),
                    focusedBorder: _fieldBorder(FumicTheme.accent, width: 2),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          if (entries.isEmpty)
            const _EmptyShortcuts()
          else
            ..._sections.map((section) {
              final sectionEntries = entries
                  .where((entry) => entry.section == section)
                  .toList(growable: false);
              if (sectionEntries.isEmpty) {
                return const SizedBox.shrink();
              }
              return _ShortcutGroup(title: section, entries: sectionEntries);
            }),
        ],
      ),
    );
  }

  OutlineInputBorder _fieldBorder(Color color, {double width = 1}) {
    return OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: BorderSide(color: color, width: width),
    );
  }
}

class _ShortcutGroup extends StatelessWidget {
  const _ShortcutGroup({required this.title, required this.entries});

  final String title;
  final List<FumicShortcutEntry> entries;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 10),
          LayoutBuilder(
            builder: (context, constraints) {
              final columns = constraints.maxWidth > 1100
                  ? 3
                  : constraints.maxWidth > 720
                  ? 2
                  : 1;
              return GridView.builder(
                itemCount: entries.length,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: columns,
                  mainAxisExtent: 64,
                  mainAxisSpacing: 10,
                  crossAxisSpacing: 10,
                ),
                itemBuilder: (context, index) {
                  final entry = entries[index];
                  return _ShortcutCard(keys: entry.keys, action: entry.action);
                },
              );
            },
          ),
        ],
      ),
    );
  }
}

class _EmptyShortcuts extends StatelessWidget {
  const _EmptyShortcuts();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF182431),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: const Row(
        children: [
          Icon(Icons.search_off_rounded, color: FumicTheme.accent),
          SizedBox(width: 12),
          Text(
            'No matching shortcuts.',
            style: TextStyle(fontWeight: FontWeight.w800),
          ),
        ],
      ),
    );
  }
}

class _FeatureGrid extends StatelessWidget {
  const _FeatureGrid();

  static const features = [
    (Icons.keyboard_alt_rounded, '100% Keyboard Control'),
    (Icons.free_breakfast_rounded, 'Free & Open Source'),
    (Icons.folder_rounded, 'Broad audio and video support'),
    (Icons.lock_rounded, '100% Offline'),
    (Icons.speed_rounded, 'Fast native playback'),
    (Icons.auto_awesome_rounded, 'Minimal modern interface'),
    (Icons.tune_rounded, 'Focused media controls'),
    (Icons.bolt_rounded, 'Reliable local library'),
  ];

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth > 1300
            ? 4
            : constraints.maxWidth > 760
            ? 3
            : 1;
        return GridView.builder(
          itemCount: features.length,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            mainAxisExtent: 86,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
          ),
          itemBuilder: (context, index) {
            final feature = features[index];
            return _InfoCard(icon: feature.$1, text: feature.$2);
          },
        );
      },
    );
  }
}

class _FaqSection extends StatelessWidget {
  const _FaqSection();

  static const entries = [
    (
      'Why Fumic?',
      "Because no matter how much you look for, you won't find anything like this on the internet. A truly offline, keyboard-first, no-nonsense media player that just works.\n\nEven if you do find something close, they will be behind paywalls or loaded with bloat you never asked for.\n\nSo Fumic is a lifesaver for you all. It was built out of genuine frustration and love for clean software.",
    ),
    (
      'Why FOSS?',
      "FOSS means Free Open Source Software. It's not just a license, it's a philosophy.\n\nGrew up using lots of tools and stuff, and now when I am able to contribute to the community, it's my chance -- and so I did. Giving back feels right, and everyone deserves good tools without strings attached.",
    ),
    (
      'Who is the developer?',
      'Legally responsible developer: TheIdealDev52 aka Saksham Sharma, along with Shelly (AI Agent).\n\nA solo developer who believes software should be simple, fast, and free. Shelly helped bring the vision to life with precision and speed.',
    ),
    (
      'How to contribute?',
      'You will find this repo at github.com/UnExplainableFish52/Fumic\n\nFollow the profile to stay updated. Support by giving stars -- it genuinely helps with visibility and motivation.\n\nPull requests, bug reports, and feature suggestions are always welcome. Every bit of contribution counts.\n\nIf you want to support financially, contact at:\n\nsharma@saksham.info.np\ncontactsaksham52@gmail.com\ninfo@sakshamsharma.com.np',
    ),
    (
      'What license does Fumic use?',
      'GNU General Public License v3.0\n\nIn simple terms, this means:\n\n* Feel free to use\n* Feel free to modify\n* Feel free to share\n* Never allowed to redistribute as proprietary -- it must always stay FOSS\n\nThe whole point is to keep it open forever. No one should lock this down behind a paywall.',
    ),
    (
      'Where to give feedback?',
      "In the GitHub repo as Issues -- whether it's a bug, a suggestion, or just a thought, open an issue and it will be looked at.\n\nYou can also send feedback using the email addresses mentioned above.\n\nOr use the contact form at:\nsakshamsharma.com.np/#contact\n\nHonestly, any feedback is appreciated. It helps shape Fumic into something even better.",
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (final entry in entries)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _FaqCard(title: entry.$1, body: entry.$2),
          ),
      ],
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return _Surface(
      child: Row(
        children: [
          Icon(icon, color: const Color(0xFFFFC247), size: 26),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              text,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Color(0xFFC7CDD7),
                fontSize: 16,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FaqCard extends StatelessWidget {
  const _FaqCard({required this.title, required this.body});

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return _Surface(
      padding: EdgeInsets.zero,
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          childrenPadding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          iconColor: FumicTheme.accent,
          collapsedIconColor: const Color(0xFFB8C0CF),
          title: Text(
            title,
            style: const TextStyle(
              color: Color(0xFF8FEDE6),
              fontSize: 21,
              fontWeight: FontWeight.w800,
              height: 1.15,
            ),
          ),
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: _LinkedBodyText(body),
            ),
          ],
        ),
      ),
    );
  }
}

class _LinkedBodyText extends StatelessWidget {
  const _LinkedBodyText(this.body);

  final String body;

  @override
  Widget build(BuildContext context) {
    final lines = body.split('\n');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final line in lines)
          if (line.trim().isEmpty)
            const SizedBox(height: 10)
          else if (line.trim() == 'github.com/UnExplainableFish52/Fumic')
            const _InfoLink(
              label: 'github.com/UnExplainableFish52/Fumic',
              url: 'https://github.com/UnExplainableFish52/Fumic',
            )
          else if (line.trim() == 'sakshamsharma.com.np/#contact')
            const _InfoLink(
              label: 'sakshamsharma.com.np/#contact',
              url: 'https://sakshamsharma.com.np/#contact',
            )
          else
            Text(
              line,
              style: const TextStyle(
                color: Color(0xFFC7CDD7),
                fontSize: 15,
                height: 1.48,
                fontWeight: FontWeight.w500,
              ),
            ),
      ],
    );
  }
}

class _InfoLink extends StatelessWidget {
  const _InfoLink({required this.label, required this.url});

  final String label;
  final String url;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: 'Open $label',
      child: InkWell(
        onTap: () => _openUrl(url),
        borderRadius: BorderRadius.circular(4),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: Text(
            label,
            style: const TextStyle(
              color: FumicTheme.accent,
              fontSize: 15,
              height: 1.48,
              fontWeight: FontWeight.w800,
              decoration: TextDecoration.underline,
              decorationColor: FumicTheme.accent,
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _openUrl(String value) async {
    await Clipboard.setData(ClipboardData(text: value));
    try {
      if (Platform.isWindows) {
        await Process.start('cmd', ['/c', 'start', '', value]);
      } else if (Platform.isMacOS) {
        await Process.start('open', [value]);
      } else if (Platform.isLinux) {
        await Process.start('xdg-open', [value]);
      }
    } on Object {
      return;
    }
  }
}

class _ShortcutCard extends StatelessWidget {
  const _ShortcutCard({required this.keys, required this.action});

  final String keys;
  final String action;

  @override
  Widget build(BuildContext context) {
    return _Surface(
      child: Row(
        children: [
          Container(
            width: 132,
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
            decoration: BoxDecoration(
              color: const Color(0xFF15213A),
              borderRadius: BorderRadius.circular(7),
              border: Border.all(color: const Color(0xFF506AB0)),
            ),
            alignment: Alignment.center,
            child: Text(
              keys,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Color(0xFF9CB2FF),
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              action,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Color(0xFFC7CDD7),
                fontSize: 15,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ProjectPill extends StatelessWidget {
  const _ProjectPill({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      decoration: BoxDecoration(
        color: const Color(0xCC1B232E),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: FumicTheme.accent),
          const SizedBox(width: 8),
          Text(label, style: const TextStyle(fontWeight: FontWeight.w900)),
        ],
      ),
    );
  }
}

class _Surface extends StatelessWidget {
  const _Surface({
    required this.child,
    this.padding = const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
  });

  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF242C38), Color(0xFF1B2430)],
        ),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.16),
            blurRadius: 22,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: child,
    );
  }
}
