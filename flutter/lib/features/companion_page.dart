import 'package:flutter/material.dart';

import '../domain/progress_metrics.dart';
import '../design_system/templates.dart';

/// «Компаньон» (A4) — port of src/companion.ts: a phone without a physical
/// keyboard cannot teach touch typing, so it opens on what works without one
/// (method, competition, progress, badges); the trainer is behind a button or
/// opens by itself on the first hardware key press.
class CompanionPage extends StatelessWidget {
  const CompanionPage({
    super.key,
    required this.tr,
    required this.language,
    required this.streak,
    required this.sessions,
    required this.best,
    required this.earned,
    required this.onTrainer,
    required this.onLearn,
    required this.onCompete,
  });
  final String Function(String) tr;
  final String language;
  final int streak, sessions;
  final num best;
  final Set<String> earned;
  final VoidCallback onTrainer, onLearn, onCompete;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final tokens = Theme.of(context).extension<TypeFreeTokens>()!;
    final muted = scheme.onSurfaceVariant;
    final count = milestones.where((m) => earned.contains(m.id)).length;
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 8),
            ExcludeSemantics(
              child: SizedBox(
                height: 150,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Icon(
                      Icons.smartphone_outlined,
                      size: 150,
                      color: tokens['border'],
                    ),
                    Icon(Icons.keyboard_outlined, size: 56, color: muted),
                    Icon(
                      Icons.do_not_disturb_alt,
                      size: 92,
                      color: scheme.primary,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              tr('cpn.h1'),
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            Text(
              tr('cpn.sub'),
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: muted),
            ),
            const SizedBox(height: 16),
            FilledButton(
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(48),
              ),
              onPressed: onTrainer,
              child: Text(tr('cpn.train'), textAlign: TextAlign.center),
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                const Expanded(child: Divider()),
                Flexible(
                  flex: 3,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Text(
                      tr('cpn.hint'),
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 12, color: muted),
                    ),
                  ),
                ),
                const Expanded(child: Divider()),
              ],
            ),
            const SizedBox(height: 10),
            LayoutBuilder(
              builder: (context, box) {
                final scale = MediaQuery.textScalerOf(context).scale(14) / 14;
                final two = box.maxWidth >= 2 * 150 * scale;
                final w = two ? (box.maxWidth - 8) / 2 : box.maxWidth;
                return Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    SizedBox(
                      width: w,
                      child: _Quick(
                        icon: Icons.menu_book_outlined,
                        accent: const Color(0xFF8B5CF6),
                        title: tr('cpn.learn'),
                        subtitle: tr('cpn.learnP'),
                        onTap: onLearn,
                      ),
                    ),
                    SizedBox(
                      width: w,
                      child: _Quick(
                        icon: Icons.emoji_events_outlined,
                        accent: const Color(0xFFE5484D),
                        title: tr('compete.title'),
                        subtitle: tr('cpn.compP.store'),
                        onTap: onCompete,
                      ),
                    ),
                  ],
                );
              },
            ),
            if (sessions > 0) ...[
              const SizedBox(height: 12),
              _Panel(
                title:
                    '${tr('cpn.progress')}${streak > 0 ? ' · 🔥 $streak' : ''}',
                child: Text(
                  '${tr('prog.sessions')}: $sessions · ${tr('prog.max')}: $best WPM',
                  style: TextStyle(color: muted),
                ),
              ),
            ],
            const SizedBox(height: 12),
            _Panel(
              title: '${tr('ach.sub')} — $count/${milestones.length}',
              child: Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final m in milestones)
                    Semantics(
                      label: tr('ach.${m.id}'),
                      selected: earned.contains(m.id),
                      child: Opacity(
                        opacity: earned.contains(m.id) ? 1 : .3,
                        child: Text(
                          m.icon,
                          style: const TextStyle(fontSize: 22),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Quick extends StatelessWidget {
  const _Quick({
    required this.icon,
    required this.accent,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });
  final IconData icon;
  final Color accent;
  final String title, subtitle;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<TypeFreeTokens>()!;
    return Material(
      color: tokens['raisedSurface'],
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: tokens['border']),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(10),
          // Icon row on top: the title gets the full card width, so long
          // words («Тест-соревнование») never break mid-word.
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: accent,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(icon, size: 20, color: Colors.white),
                  ),
                  const Spacer(),
                  const Icon(Icons.chevron_right, size: 20),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 11.5,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Panel extends StatelessWidget {
  const _Panel({required this.title, required this.child});
  final String title;
  final Widget child;
  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<TypeFreeTokens>()!;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: tokens['raisedSurface'],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: tokens['border']),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          child,
        ],
      ),
    );
  }
}
