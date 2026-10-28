import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../data/artifact_export.dart';
import '../data/local_repository.dart';
import '../data/progress_view.dart';
import '../data/achievement_store.dart';
import '../domain/progress_metrics.dart';
import '../domain/session_context.dart';

class ProgressPage extends StatefulWidget {
  const ProgressPage({
    super.key,
    required this.repository,
    required this.profile,
    required this.language,
    required this.tr,
    required this.onWeak,
    this.exporter,
    this.clock,
  });
  final LocalRepository repository;
  final String profile, language;
  final String Function(String) tr;
  final VoidCallback onWeak;
  final ArtifactExporter? exporter;
  final int Function()? clock;
  @override
  State<ProgressPage> createState() => _ProgressPageState();
}

class _ProgressPageState extends State<ProgressPage> {
  final target = TextEditingController();
  String? series, status;
  bool saving = false;
  int now() => widget.clock?.call() ?? DateTime.now().millisecondsSinceEpoch;
  @override
  void initState() {
    super.initState();
    target.text = '${targetValue()}';
  }

  int targetValue() {
    final raw = (widget.repository.data['legacy'] as Map)['tr_target_wpm'];
    final value = raw is String ? num.tryParse(raw) : null;
    return value != null && value.isFinite && value > 0 ? value.round() : 40;
  }

  @override
  void dispose() {
    target.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant ProgressPage old) {
    super.didUpdateWidget(old);
    if (old.profile != widget.profile || old.language != widget.language)
      series = null;
  }

  Future<void> saveTarget() async {
    final value = int.tryParse(target.text);
    if (value == null || value < 1 || !value.toDouble().isFinite) {
      setState(() => status = copy('invalid'));
      return;
    }
    setState(() => saving = true);
    try {
      await widget.repository.transaction((d) {
        (d['legacy'] as Map)['tr_target_wpm'] = '$value';
      });
      if (mounted) setState(() => status = copy('saved'));
    } catch (_) {
      if (mounted) setState(() => status = copy('failed'));
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  Future<void> export() async {
    if (saving) return;
    setState(() => saving = true);
    try {
      final rows = ProgressView(widget.repository.data).timeline;
      // Explicit export of local history only: no credentials, preferences,
      // teacher permissions, names or private source texts.
      final bytes = Uint8List.fromList(
        utf8.encode(
          jsonEncode({
            'schema': 'typefree.history/1',
            'exportedAt': now(),
            'sessions': rows,
          }),
        ),
      );
      final result = await (widget.exporter ?? saveArtifact)(
        'TypeFree-history-${now()}.json',
        bytes,
        'application/json',
      );
      if (mounted)
        setState(
          () => status = copy(
            result == ArtifactExportOutcome.cancelled
                ? 'cancelled'
                : result == ArtifactExportOutcome.requested
                ? 'requested'
                : 'saved',
          ),
        );
    } catch (_) {
      if (mounted) setState(() => status = copy('failed'));
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  String copy(String key) => progressCopy(widget.language, key);
  @override
  Widget build(BuildContext context) {
    final view = ProgressView(widget.repository.data), rows = view.timeline;
    final known = rows
        .where(
          (r) =>
              r['origin'] == 'flutter' &&
              r['profile'] == widget.profile &&
              r['language'] == widget.language &&
              sessionSeriesKey(r) != null,
        )
        .toList();
    final groups = <String, List<Map<String, dynamic>>>{};
    for (final row in known) {
      groups.putIfAbsent(sessionSeriesKey(row)!, () => []).add(row);
    }
    if (!groups.containsKey(series)) series = groups.keys.firstOrNull;
    final selected = groups[series] ?? [];
    final ordered = List<Map<String, dynamic>>.from(selected)
      ..sort((a, b) => (a['t'] as num).compareTo(b['t'] as num));
    final speeds = ordered.map((r) => r['wpm'] as num).toList();
    final forecast = speedForecast(speeds, targetValue());
    final earned = view.achievements.toSet();
    final eligible = eligibleAchievementIds(
      widget.repository.data,
      now(),
    ).toSet();
    final allEarned = {...earned, ...eligible};
    final stamps = rows
        .where((r) => r['historyEligible'] != false)
        .map((r) => r['t'] as num);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          widget.tr('prog.title'),
          style: Theme.of(context).textTheme.headlineMedium,
        ),
        Text(copy('local')),
        const SizedBox(height: 12),
        Wrap(
          spacing: 16,
          runSpacing: 8,
          children: [
            Text('${widget.tr('prog.sessions')}: ${rows.length}'),
            Text('${copy('streak')}: ${utcStreak(stamps, now())}'),
            Text('${copy('course')}: ${view.courseStars}'),
            Text('${copy('kids')}: ${view.kidsStars}'),
          ],
        ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: widget.onWeak,
          icon: const Icon(Icons.track_changes),
          label: Text(widget.tr('weak.title')),
        ),
        const SizedBox(height: 12),
        Text(copy('series'), style: Theme.of(context).textTheme.titleMedium),
        Text(copy('seriesHint')),
        if (groups.isNotEmpty)
          DropdownButtonFormField<String>(
            key: ValueKey('progress-series-$series'),
            initialValue: series,
            isExpanded: true,
            items: groups.entries
                .map(
                  (e) => DropdownMenuItem(
                    value: e.key,
                    child: Text(
                      '${e.value.first['title']} · ${e.value.first['difficulty']}',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                )
                .toList(),
            onChanged: (v) => setState(() => series = v),
          ),
        if (speeds.length >= 2) ...[
          const SizedBox(height: 12),
          Semantics(
            label: 'WPM: ${speeds.join(', ')}',
            child: SizedBox(
              height: 160,
              child: CustomPaint(
                painter: _SpeedChart(
                  speeds.skip(max(0, speeds.length - 40)).toList(),
                  Theme.of(context).colorScheme.primary,
                ),
              ),
            ),
          ),
          Wrap(
            spacing: 16,
            runSpacing: 8,
            children: [
              Text('${widget.tr('prog.sessions')}: ${speeds.length}'),
              Text('${widget.tr('prog.max')}: ${speeds.reduce(max)} WPM'),
              Text('${widget.tr('prog.last')}: ${speeds.last} WPM'),
            ],
          ),
        ] else
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Text(widget.tr('prog.empty')),
          ),
        const SizedBox(height: 12),
        TextField(
          key: const ValueKey('progress-target'),
          controller: target,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            labelText: widget.tr('set.targetwpm'),
            border: const OutlineInputBorder(),
          ),
        ),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton(
            onPressed: saving ? null : saveTarget,
            child: Text(copy('saveTarget')),
          ),
        ),
        Text(
          forecast == null
              ? copy('noForecast')
              : '${widget.tr('prog.to')} ${forecast.target} WPM ≈ ${forecast.sessions} ${widget.tr('prog.sess')} · R² ${forecast.certainty.toStringAsFixed(2)}',
        ),
        const SizedBox(height: 20),
        ExpansionTile(
          initiallyExpanded: true,
          title: Text(
            '${widget.tr('ach.title')} · ${milestones.where((b) => allEarned.contains(b.id)).length}/${milestones.length}',
          ),
          subtitle: Text(copy('globalBadges')),
          children: [
            Wrap(
              spacing: 10,
              runSpacing: 8,
              children: [
                for (final badge in milestones)
                  Semantics(
                    label:
                        '${widget.tr('ach.${badge.id}')} · ${copy(allEarned.contains(badge.id) ? 'earned' : 'locked')}',
                    child: Chip(
                      avatar: Icon(
                        allEarned.contains(badge.id)
                            ? Icons.check_circle
                            : Icons.lock_outline,
                      ),
                      label: Text(
                        '${badge.icon} ${widget.tr('ach.${badge.id}')}',
                      ),
                    ),
                  ),
              ],
            ),
            if (earned.any((id) => !milestones.any((b) => b.id == id)))
              Text(
                '${copy('archivedBadges')}: ${earned.where((id) => !milestones.any((b) => b.id == id)).join(', ')}',
              ),
          ],
        ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: saving ? null : export,
          icon: const Icon(Icons.download_outlined),
          label: Text(copy('export')),
        ),
        if (status != null)
          Text(status!, key: const ValueKey('progress-status')),
        if (saving) const LinearProgressIndicator(),
        if (view.legacyTimeline.isNotEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Text(copy('unknown')),
          ),
        for (final row in rows)
          Card(
            child: ListTile(
              title: Text(
                row['origin'] == 'legacy'
                    ? copy('oldSession')
                    : row['title'] as String,
              ),
              subtitle: Text(
                '${DateTime.fromMillisecondsSinceEpoch((row['t'] as num).toInt()).toLocal()}${row['origin'] == 'flutter' ? ' · ${row['profile']} / ${row['language']} / ${row['mode']}' : ''}',
              ),
              trailing: Text(
                '${row['wpm']} WPM\n${(row['accuracy'] as num).toStringAsFixed(0)}%',
              ),
            ),
          ),
        if (view.banks.isNotEmpty)
          ExpansionTile(
            title: Text(copy('banks')),
            children: [
              for (final e in view.banks.entries)
                ListTile(
                  title: Text(e.key),
                  subtitle: Text(
                    '${copy('completed')}: ${(e.value['done'] as List).length} · ${e.value['bestWpm']} WPM · ${e.value['bestAcc']}%',
                  ),
                ),
            ],
          ),
      ],
    );
  }
}

class _SpeedChart extends CustomPainter {
  _SpeedChart(this.values, this.color);
  final List<num> values;
  final Color color;
  @override
  void paint(Canvas canvas, Size size) {
    if (values.length < 2) return;
    final low = values.reduce(min),
        high = values.reduce(max),
        span = max(1, high - low);
    final path = Path();
    for (var i = 0; i < values.length; i++) {
      final x = 8 + i / (values.length - 1) * (size.width - 16),
          y = size.height - 12 - (values[i] - low) / span * (size.height - 24);
      if (i == 0)
        path.moveTo(x, y);
      else
        path.lineTo(x, y);
      canvas.drawCircle(Offset(x, y), 3, Paint()..color = color);
    }
    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5,
    );
  }

  @override
  bool shouldRepaint(covariant _SpeedChart old) =>
      old.values != values || old.color != color;
}

String progressCopy(String language, String key) {
  const languages = ['ru', 'en', 'es', 'de', 'fr', 'it', 'pt'];
  const words = {
    'local': [
      'История на этом устройстве',
      'History on this device',
      'Historial en este dispositivo',
      'Verlauf auf diesem Gerät',
      'Historique sur cet appareil',
      'Cronologia su questo dispositivo',
      'Histórico neste dispositivo',
    ],
    'streak': [
      'Серия дней (UTC)',
      'Day streak (UTC)',
      'Racha (UTC)',
      'Tagesserie (UTC)',
      'Série de jours (UTC)',
      'Serie di giorni (UTC)',
      'Sequência de dias (UTC)',
    ],
    'course': [
      'Звёзды курса',
      'Course stars',
      'Estrellas del curso',
      'Kurssterne',
      'Étoiles du cours',
      'Stelle del corso',
      'Estrelas do curso',
    ],
    'kids': [
      'Звёзды детского курса',
      'Child course stars',
      'Estrellas infantiles',
      'Kinderkurs-Sterne',
      'Étoiles du cours enfant',
      'Stelle corso bambini',
      'Estrelas do curso infantil',
    ],
    'series': [
      'Сопоставимые тренировки',
      'Comparable sessions',
      'Sesiones comparables',
      'Vergleichbare Sitzungen',
      'Séances comparables',
      'Sessioni confrontabili',
      'Sessões comparáveis',
    ],
    'seriesHint': [
      'График и прогноз: один профиль, язык, режим и сложность.',
      'Chart and forecast use one profile, language, mode and difficulty.',
      'Gráfico y previsión: mismo perfil, idioma, modo y dificultad.',
      'Diagramm und Prognose: gleiches Profil, Sprache, Modus und Schwierigkeit.',
      'Graphique et prévision : mêmes profil, langue, mode et difficulté.',
      'Grafico e previsione: stesso profilo, lingua, modalità e difficoltà.',
      'Gráfico e previsão: mesmo perfil, idioma, modo e dificuldade.',
    ],
    'saveTarget': [
      'Сохранить цель',
      'Save target',
      'Guardar meta',
      'Ziel speichern',
      'Enregistrer l’objectif',
      'Salva obiettivo',
      'Salvar meta',
    ],
    'noForecast': [
      'Для этой серии прогноз пока не сформирован.',
      'No forecast is available for this series yet.',
      'Aún no hay datos estables para prever.',
      'Noch kein ausreichend stabiler Trend für eine Prognose.',
      'Pas encore assez de données stables pour une prévision.',
      'Dati stabili insufficienti per una previsione.',
      'Ainda faltam dados estáveis para uma previsão.',
    ],
    'globalBadges': [
      'Общие достижения устройства, включая прежние.',
      'Device-wide achievements, including previous ones.',
      'Logros del dispositivo, incluidos los anteriores.',
      'Geräteweite Erfolge einschließlich früherer.',
      'Succès de l’appareil, y compris les anciens.',
      'Traguardi del dispositivo, inclusi quelli precedenti.',
      'Conquistas do dispositivo, incluindo anteriores.',
    ],
    'earned': [
      'Получено',
      'Earned',
      'Obtenido',
      'Erreicht',
      'Obtenu',
      'Ottenuto',
      'Obtido',
    ],
    'locked': [
      'Пока закрыто',
      'Locked',
      'Bloqueado',
      'Gesperrt',
      'Verrouillé',
      'Bloccato',
      'Bloqueado',
    ],
    'archivedBadges': [
      'Другие сохранённые достижения',
      'Other preserved achievements',
      'Otros logros guardados',
      'Andere erhaltene Erfolge',
      'Autres succès conservés',
      'Altri traguardi conservati',
      'Outras conquistas preservadas',
    ],
    'export': [
      'Экспорт всей истории (JSON)',
      'Export all history (JSON)',
      'Exportar todo el historial (JSON)',
      'Gesamten Verlauf exportieren (JSON)',
      'Exporter tout l’historique (JSON)',
      'Esporta tutta la cronologia (JSON)',
      'Exportar todo o histórico (JSON)',
    ],
    'saved': [
      'Сохранено',
      'Saved',
      'Guardado',
      'Gespeichert',
      'Enregistré',
      'Salvato',
      'Salvo',
    ],
    'requested': [
      'Файл передан для сохранения',
      'File handed off for saving',
      'Archivo enviado para guardar',
      'Datei zum Speichern übergeben',
      'Fichier transmis pour enregistrement',
      'File inviato per il salvataggio',
      'Arquivo enviado para salvar',
    ],
    'cancelled': [
      'Сохранение отменено',
      'Save cancelled',
      'Guardado cancelado',
      'Speichern abgebrochen',
      'Enregistrement annulé',
      'Salvataggio annullato',
      'Salvamento cancelado',
    ],
    'failed': [
      'Не удалось сохранить. Можно повторить.',
      'Could not save. You can retry.',
      'No se pudo guardar. Reintenta.',
      'Speichern fehlgeschlagen. Erneut versuchen.',
      'Échec de l’enregistrement. Réessayez.',
      'Salvataggio fallito. Riprova.',
      'Não foi possível salvar. Tente novamente.',
    ],
    'invalid': [
      'Введите целую положительную скорость WPM.',
      'Enter a positive whole-number WPM target.',
      'Introduce un objetivo WPM entero positivo.',
      'Positives ganzzahliges WPM-Ziel eingeben.',
      'Saisissez un objectif WPM entier positif.',
      'Inserisci un obiettivo WPM intero positivo.',
      'Insira uma meta WPM inteira positiva.',
    ],
    'unknown': [
      'В старых записях неизвестны профиль, язык и упражнение. Они сохранены отдельно от сопоставимых серий.',
      'Old records lack profile, language and exercise metadata. They stay outside comparable series.',
      'Los registros antiguos no indican perfil, idioma ni ejercicio; quedan fuera de series comparables.',
      'Alte Einträge ohne Profil, Sprache und Übung gehören nicht zu vergleichbaren Serien.',
      'Les anciens résultats sans profil, langue ni exercice restent hors des séries comparables.',
      'I vecchi risultati senza profilo, lingua o esercizio restano fuori dalle serie confrontabili.',
      'Registros antigos sem perfil, idioma ou exercício ficam fora das séries comparáveis.',
    ],
    'oldSession': [
      'Тренировка из прежней версии',
      'Session from the previous version',
      'Sesión de la versión anterior',
      'Sitzung aus der vorherigen Version',
      'Séance de l’ancienne version',
      'Sessione della versione precedente',
      'Sessão da versão anterior',
    ],
    'banks': [
      'Прогресс по наборам',
      'Progress by collection',
      'Progreso por conjunto',
      'Fortschritt nach Sammlung',
      'Progrès par collection',
      'Progressi per raccolta',
      'Progresso por coleção',
    ],
    'completed': [
      'Пройдено',
      'Completed',
      'Completado',
      'Abgeschlossen',
      'Terminé',
      'Completato',
      'Concluído',
    ],
  };
  final index = languages.indexOf(language);
  return words[key]?[index < 0 ? 1 : index] ?? key;
}
