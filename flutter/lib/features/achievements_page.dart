import 'package:flutter/material.dart';

import '../data/achievement_store.dart';
import '../data/local_repository.dart';
import '../data/progress_view.dart';
import '../domain/progress_metrics.dart';
import '../design_system/templates.dart';

/// «Достижения» (F2): the eleven source badges with real progress toward the
/// locked ones. The source keeps only badge ids (tr_ach), no unlock dates, so
/// earned cards say «получено» without a date instead of inventing one.
class AchievementsPage extends StatefulWidget {
  const AchievementsPage({
    super.key,
    required this.repository,
    required this.language,
    required this.tr,
    this.clock,
  });
  final LocalRepository repository;
  final String language;
  final String Function(String) tr;
  final int Function()? clock;
  @override
  State<AchievementsPage> createState() => _AchievementsPageState();
}

String achievementsCopy(String language, String key) {
  const langs = ['ru', 'en', 'es', 'de', 'fr', 'it', 'pt'];
  const words = <String, List<String>>{
    'all': ['Все', 'All', 'Todos', 'Alle', 'Tous', 'Tutti', 'Todos'],
    'earned': [
      'Получены',
      'Unlocked',
      'Obtenidos',
      'Erreicht',
      'Obtenus',
      'Ottenuti',
      'Obtidos',
    ],
    'locked': [
      'Закрыты',
      'Locked',
      'Bloqueados',
      'Gesperrt',
      'Verrouillés',
      'Bloccati',
      'Bloqueados',
    ],
    'got': [
      'Получено',
      'Unlocked',
      'Obtenido',
      'Erreicht',
      'Obtenu',
      'Ottenuto',
      'Obtido',
    ],
    'none': [
      'Пока ничего — первая тренировка откроет «Первые шаги».',
      'Nothing yet — your first session unlocks “First steps”.',
      'Nada aún: tu primera sesión desbloquea «Primeros pasos».',
      'Noch nichts – die erste Sitzung schaltet „Erste Schritte“ frei.',
      'Rien pour l’instant : la première séance débloque « Premiers pas ».',
      'Ancora niente: la prima sessione sblocca «Primi passi».',
      'Nada ainda — a primeira sessão desbloqueia «Primeiros passos».',
    ],
    'allDone': [
      'Все достижения получены!',
      'All achievements unlocked!',
      '¡Todos los logros obtenidos!',
      'Alle Erfolge erreicht!',
      'Tous les succès obtenus !',
      'Tutti i traguardi raggiunti!',
      'Todas as conquistas obtidas!',
    ],
    'archived': [
      'Другие сохранённые достижения',
      'Other preserved achievements',
      'Otros logros conservados',
      'Weitere gespeicherte Erfolge',
      'Autres succès conservés',
      'Altri traguardi conservati',
      'Outras conquistas guardadas',
    ],
  };
  final i = langs.indexOf(language);
  return words[key]?[i < 0 ? 1 : i] ?? key;
}

class _AchievementsPageState extends State<AchievementsPage> {
  int tab = 0;
  int now() => widget.clock?.call() ?? DateTime.now().millisecondsSinceEpoch;

  @override
  Widget build(BuildContext context) {
    String c(String k) => achievementsCopy(widget.language, k);
    final doc = widget.repository.data;
    final stored = ProgressView(doc).achievements.toSet();
    final earned = {...stored, ...eligibleAchievementIds(doc, now())};
    final metrics = milestoneMetrics(doc, now());
    final count = milestones.where((m) => earned.contains(m.id)).length;
    final shown = milestones.where(
      (m) => switch (tab) {
        1 => earned.contains(m.id),
        2 => !earned.contains(m.id),
        _ => true,
      },
    );
    final archived = stored.where((id) => !milestones.any((m) => m.id == id));
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    widget.tr('ach.sub'),
                    style: TextStyle(color: scheme.onSurfaceVariant),
                  ),
                ),
                Text(
                  '$count / ${milestones.length}',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            DefaultTabController(
              length: 3,
              initialIndex: tab,
              child: TabBar(
                onTap: (i) => setState(() => tab = i),
                tabs: [
                  for (final k in ['all', 'earned', 'locked'])
                    Tab(height: 40, text: c(k)),
                ],
              ),
            ),
            const SizedBox(height: 12),
            if (shown.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Text(
                  c(tab == 1 ? 'none' : 'allDone'),
                  textAlign: TextAlign.center,
                ),
              )
            else
              LayoutBuilder(
                builder: (context, box) {
                  final scale = MediaQuery.textScalerOf(context).scale(14) / 14;
                  final per = (box.maxWidth / (112 * scale)).floor().clamp(
                    1,
                    4,
                  );
                  const gap = 8.0;
                  final w = (box.maxWidth - gap * (per - 1)) / per;
                  return Wrap(
                    spacing: gap,
                    runSpacing: gap,
                    children: [
                      for (final m in shown)
                        SizedBox(
                          width: w,
                          child: _Badge(
                            milestone: m,
                            title: widget.tr('ach.${m.id}'),
                            earned: earned.contains(m.id),
                            value: metrics[m.metric]!,
                            got: c('got'),
                          ),
                        ),
                    ],
                  );
                },
              ),
            if (archived.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text(
                  '${c('archived')}: ${archived.join(', ')}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({
    required this.milestone,
    required this.title,
    required this.earned,
    required this.value,
    required this.got,
  });
  final Milestone milestone;
  final String title, got;
  final bool earned;
  final num value;
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final tokens = Theme.of(context).extension<TypeFreeTokens>()!;
    final ring = earned ? tokens['success'] : tokens['border'];
    final shownValue = value > milestone.goal ? milestone.goal : value;
    final progress = '${shownValue.round()} / ${milestone.goal}';
    return Semantics(
      label: '$title · ${earned ? got : progress}',
      excludeSemantics: true,
      child: Container(
        padding: const EdgeInsets.fromLTRB(8, 12, 8, 10),
        decoration: BoxDecoration(
          color: tokens['raisedSurface'],
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: tokens['border']),
        ),
        child: Column(
          children: [
            Container(
              width: 56,
              height: 56,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: ring.withValues(alpha: earned ? .18 : .4),
                border: Border.all(color: ring, width: 3),
              ),
              child: earned
                  ? Text(milestone.icon, style: const TextStyle(fontSize: 26))
                  : Icon(Icons.lock_outline, color: scheme.onSurfaceVariant),
            ),
            const SizedBox(height: 8),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            if (earned)
              Text(
                got,
                style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
              )
            else ...[
              Text(
                progress,
                style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
              ),
              const SizedBox(height: 4),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: (shownValue / milestone.goal).toDouble(),
                  minHeight: 6,
                  backgroundColor: tokens['border'],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
