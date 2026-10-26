import 'package:flutter/material.dart';

import '../domain/adaptive.dart';
import '../domain/key_statistics.dart';
import '../design_system/templates.dart';
import 'keyboard_guide.dart';

class WeakKeysPage extends StatelessWidget {
  const WeakKeysPage({
    super.key,
    required this.keyboard,
    required this.statistics,
    required this.sessions,
    required this.language,
    required this.profile,
    required this.tr,
    required this.onGenerate,
  });
  final KeyboardModel keyboard;
  final Map<String, dynamic> statistics;
  final List<Map<String, dynamic>> sessions;
  final String language, profile;
  final String Function(String) tr;
  final VoidCallback onGenerate;
  @override
  Widget build(BuildContext context) {
    final letters = letterInventory(
      keyboard.snapshot,
      language == 'ru' ? 'ru' : 'en',
    );
    final weak = weakLetters(statistics, letters),
        recover = recoveryLetters(statistics, letters);
    final heat = keyHeatMap(statistics);
    final tokens = Theme.of(context).extension<TypeFreeTokens>()!;
    final latest = <bool, Map<String, dynamic>>{};
    for (final row in sessions) {
      if (row['profile'] != profile ||
          row['language'] != language ||
          !['practice', 'weak'].contains(row['mode'])) {
        continue;
      }
      final difficulty = (row['difficulty'] as String).split('/');
      if (difficulty.length < 3 || !['true', 'false'].contains(difficulty[2])) {
        continue;
      }
      latest[difficulty[2] == 'true'] = row;
    }
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 820),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: KeyboardGuide(
                  model: keyboard,
                  expected: null,
                  ru: language == 'ru',
                  heat: heat,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '${tr('heat.mastered')} → ${tr('heat.weak')}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 12),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      tr('weak.title'),
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    if (weak.isNotEmpty)
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: weak
                            .map(
                              (ch) => Chip(
                                label: Text(ch.toUpperCase()),
                                backgroundColor: tokens['danger'].withValues(
                                  alpha: .2,
                                ),
                              ),
                            )
                            .toList(),
                      )
                    else
                      Text(adaptiveNoData(language)),
                    if (recover.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          '${adaptiveCopy(language, 'recovery')}: ${recover.join(' · ')}',
                        ),
                      ),
                    const SizedBox(height: 12),
                    FilledButton.icon(
                      onPressed: onGenerate,
                      icon: const Icon(Icons.keyboard_outlined),
                      label: Text(adaptiveCopy(language, 'generate')),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 12,
              runSpacing: 8,
              children: [
                for (final plain in [false, true])
                  SizedBox(
                    width: 260,
                    child: Card(
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              adaptiveCopy(
                                language,
                                plain ? 'plain' : 'original',
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              latest[plain] == null
                                  ? '—'
                                  : '${latest[plain]!['wpm']} WPM · ${latest[plain]!['accuracy']}%',
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              adaptiveCopy(language, 'scope'),
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}
