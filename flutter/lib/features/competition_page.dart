import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';

import '../data/key_statistics_store.dart';
import '../data/local_repository.dart';
import '../design_system/templates.dart';
import '../domain/competition.dart';
import '../domain/key_statistics.dart';
import 'keyboard_guide.dart';
import 'practice_widgets.dart';

class CompetitionPage extends StatefulWidget {
  const CompetitionPage({
    super.key,
    required this.repository,
    required this.keyStatistics,
    required this.language,
    required this.profile,
    required this.keyboard,
    required this.tr,
    required this.onExit,
    required this.onSaved,
    this.clock,
    this.onTyping,
  });
  final LocalRepository repository;
  final KeyStatisticsStore keyStatistics;
  final String language, profile;
  final KeyboardModel keyboard;
  final String Function(String) tr;
  final VoidCallback onExit;
  final VoidCallback? onTyping;
  final int Function()? clock;
  final Future<void> Function(Map<String, dynamic>, List<Map<String, dynamic>>)
  onSaved;
  @override
  State<CompetitionPage> createState() => CompetitionPageState();
}

class CompetitionPageState extends State<CompetitionPage> {
  final entry = TextEditingController(), focus = FocusNode();
  CompetitionSession? engine;
  String previous = '', id = '';
  bool ignore = false, saving = false, saved = false;
  String? error;
  RecordedHistory? captured;
  Map<String, dynamic>? point;
  Timer? ghostTimer;
  List<CompetitionTick> ghost = [];
  int ghostPosition = 0;
  int now() => widget.clock?.call() ?? DateTime.now().millisecondsSinceEpoch;
  Map<String, dynamic> get best {
    final raw = (widget.repository.data['legacy'] as Map)['tr_compete'];
    return raw is String
        ? Map<String, dynamic>.from(jsonDecode(raw) as Map)
        : {};
  }

  Map<String, dynamic>? storedReplay(String discipline) {
    Map<String, dynamic>? latest;
    for (final raw in widget.repository.data['sessions'] as List) {
      if (raw is! Map ||
          raw['t'] is! num ||
          raw['mode'] != 'compete' ||
          raw['profile'] != widget.profile ||
          raw['exercise'] != discipline ||
          raw['contentLanguage'] != competitionLanguage(widget.language)) {
        continue;
      }
      final pattern = raw['pattern'], ticks = raw['timeline'];
      if (pattern is! String ||
          pattern.isEmpty ||
          pattern.length > 16000 ||
          ticks is! List ||
          ticks.isEmpty ||
          ticks.length > 5000) {
        continue;
      }
      var previousTime = -1;
      var valid = true;
      for (final tick in ticks) {
        if (tick is! Map ||
            tick['c'] is! String ||
            (tick['c'] as String).length != 1 ||
            tick['t'] is! int ||
            (tick['t'] as int) < previousTime ||
            (tick['t'] as int) < 0) {
          valid = false;
          break;
        }
        previousTime = tick['t'] as int;
      }
      if (valid) {
        final recorded = ticks
            .map(
              (tick) => CompetitionTick(tick['c'] as String, tick['t'] as int),
            )
            .toList();
        // Partial recordings (including the 5000-key cap) cannot reproduce a
        // completed race. Keep the record but do not offer it as a full ghost.
        valid =
            competitionReplayPosition(pattern, recorded, previousTime) ==
            pattern.length;
      }
      if (valid &&
          (latest == null || (raw['t'] as num) > (latest['t'] as num))) {
        latest = Map<String, dynamic>.from(raw);
      }
    }
    return latest;
  }

  @override
  void initState() {
    super.initState();
    entry.addListener(edit);
  }

  @override
  void didUpdateWidget(covariant CompetitionPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.language != widget.language ||
        oldWidget.profile != widget.profile) {
      if (engine != null && engine!.result == null) {
        widget.keyStatistics.recorder.discardSession();
      }
      ghostTimer?.cancel();
      engine = null;
      ghost = [];
      clearInput();
    }
  }

  void clearInput() {
    ignore = true;
    previous = '';
    entry.clear();
    ignore = false;
  }

  void start(String discipline, {Map<String, dynamic>? replay}) {
    widget.keyStatistics.recorder.discardSession();
    ghostTimer?.cancel();
    setState(() {
      id =
          'compete-${DateTime.now().microsecondsSinceEpoch}-${Random().nextInt(0x7fffffff)}';
      ghost = replay == null
          ? []
          : (replay['timeline'] as List)
                .map((t) => CompetitionTick(t['c'] as String, t['t'] as int))
                .toList();
      ghostPosition = 0;
      engine = CompetitionSession(
        discipline: discipline,
        language: widget.language,
        clock: now,
        previousBest:
            (best['${discipline}_${competitionLanguage(widget.language)}']
                as num?) ??
            0,
        pattern: replay?['pattern'] as String?,
        record: (ch, ok, at) {
          final key = widget.keyboard.hit(
            ch,
            ru: competitionLanguage(widget.language) == 'ru',
          )?['id'];
          if (key is String) widget.keyStatistics.record(key, ok, at);
        },
      );
      saving = false;
      saved = false;
      error = null;
      captured = null;
      point = null;
      clearInput();
    });
    if (ghost.isNotEmpty) {
      ghostTimer = Timer.periodic(const Duration(milliseconds: 50), (_) {
        final race = engine;
        if (!mounted || race == null || race.result != null) {
          ghostTimer?.cancel();
          return;
        }
        final pos = race.startedAt == 0
            ? 0
            : competitionReplayPosition(
                race.typing.pattern,
                ghost,
                now() - race.startedAt,
              );
        if (ghostPosition != pos) setState(() => ghostPosition = pos);
      });
    }
    focus.requestFocus();
  }

  void edit() {
    if (ignore ||
        saving ||
        engine == null ||
        engine!.result != null ||
        entry.value.composing.isValid && !entry.value.composing.isCollapsed) {
      return;
    }
    final text = entry.text;
    if (text == previous) return;
    if (!text.startsWith(previous)) {
      ignore = true;
      entry.value = TextEditingValue(
        text: previous,
        selection: TextSelection.collapsed(offset: previous.length),
      );
      ignore = false;
      return;
    }
    widget.onTyping?.call();
    for (var i = previous.length; i < text.length; i++) {
      engine!.press(
        widget.keyboard.bridge(text[i], engine!.typing.expected ?? ''),
      );
      if (engine!.result != null) {
        ghostTimer?.cancel();
        unawaited(finishAndSave());
        break;
      }
    }
    previous = text;
    setState(() {});
  }

  Future<bool> finishAndSave() async {
    if (saving) return false;
    if (saved) return true;
    final race = engine, result = engine?.result;
    if (race == null || result == null) {
      try {
        await widget.keyStatistics.flush();
        return true;
      } catch (_) {
        if (mounted) {
          setState(() => error = competitionCopy(widget.language, 'saveError'));
        }
        return false;
      }
    }
    captured ??= widget.keyStatistics.recorder.take(now());
    final record = captured!;
    point ??= {
      'id': id,
      'exercise': race.discipline,
      'title': widget.tr('comp.${race.discipline}'),
      'language': widget.language,
      'contentLanguage': race.language,
      'profile': widget.profile,
      'mode': 'compete',
      'difficulty': '${race.language}/${race.discipline}',
      't': now(),
      'wpm': result.wpm,
      'accuracy': result.accuracy,
      'errors': result.errors,
      'elapsedMs': result.elapsedMs,
      'len': record.len,
      'errKeys': record.errorKeys,
      'medal': result.medal,
      'pattern': race.typing.pattern,
      'timeline': race.timeline.map((t) => t.toJson()).toList(),
    };
    final earlier = List<Map<String, dynamic>>.from(
      widget.repository.data['sessions'] as List,
    );
    var fresh = false;
    if (mounted) {
      setState(() {
        saving = true;
        error = null;
      });
    }
    try {
      await widget.keyStatistics.commit((doc) {
        final rows = doc['sessions'] as List, legacy = doc['legacy'] as Map;
        if (rows.any((r) => r['id'] == id)) return;
        final records = legacy['tr_compete'] is String
            ? Map<String, dynamic>.from(
                jsonDecode(legacy['tr_compete'] as String) as Map,
              )
            : <String, dynamic>{};
        // Compare inside the transaction; an old captured snapshot cannot lower a record.
        if (result.accuracy >= 90 &&
            result.wpm > ((records[race.bestKey] as num?) ?? 0)) {
          records[race.bestKey] = result.wpm;
          legacy['tr_compete'] = jsonEncode(records);
        }
        // Retain the completed race/replay even if source pushHistory is ineligible.
        // The legacy history still follows its >=10 physical-key, positive-WPM gate.
        rows.add(point!);
        fresh = true;
        if (record.eligible(result.wpm)) {
          final history = legacy['tr_history'] is String
              ? List<dynamic>.from(
                  jsonDecode(legacy['tr_history'] as String) as List,
                )
              : <dynamic>[];
          history.add(
            record.point(result.wpm, result.accuracy, point!['t'] as int),
          );
          legacy['tr_history'] = jsonEncode(
            history.length > 300
                ? history.sublist(history.length - 300)
                : history,
          );
        }
      });
      saved = true;
      if (fresh) {
        try {
          await widget.onSaved(point!, earlier);
        } catch (_) {
          /* Optional companion. */
        }
      }
      return true;
    } catch (_) {
      error = competitionCopy(widget.language, 'saveError');
      return false;
    } finally {
      saving = false;
      if (mounted) setState(() {});
    }
  }

  @override
  void dispose() {
    if (engine != null && engine!.result == null) {
      widget.keyStatistics.recorder.discardSession();
    }
    ghostTimer?.cancel();
    entry.removeListener(edit);
    entry.dispose();
    focus.dispose();
    super.dispose();
  }

  List<String> get _alpha => competitionContent(
    'alpha_fwd',
    widget.language,
  ).split('').where((c) => c.trim().isNotEmpty).toList();

  @override
  Widget build(BuildContext context) {
    final race = engine, result = engine?.result;
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1000),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (race == null) ...[
              Text(widget.tr('compete.intro.store')),
              if (widget.language != 'en' && widget.language != 'ru')
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Text(competitionCopy(widget.language, 'english')),
                ),
              const SizedBox(height: 8),
              // E1: a tile per discipline, a preview of what is typed and
              // the personal best on the right (local, this device only).
              for (final d in competitionDisciplines)
                _DisciplineRow(
                  key: ValueKey('competition-$d'),
                  accentBadge: d == 'alpha_fwd' || d == 'sprint',
                  badge: const {
                    'alpha_fwd': 'АБ',
                    'alpha_rev': 'ЯА',
                    'words': 'Tt',
                    'digits': '123',
                  }[d],
                  title: widget.tr('comp.$d'),
                  preview: d == 'alpha_fwd'
                      ? '${_alpha.take(4).join(' ')} … ${_alpha.last}'
                      : d == 'alpha_rev'
                      ? '${_alpha.reversed.take(4).join(' ')} … ${_alpha.first}'
                      : d == 'digits'
                      ? '0 1 2 3 4 5 6 7 8 9'
                      : widget.tr('comp.hint'),
                  bestLabel: widget.tr('comp.best'),
                  best: best['${d}_${competitionLanguage(widget.language)}']
                      ?.toString(),
                  unit: widget.tr('st.wpm'),
                  onTap: () => start(d),
                  replay: storedReplay(d) == null
                      ? null
                      : IconButton(
                          key: ValueKey('stored-replay-$d'),
                          tooltip: competitionCopy(widget.language, 'ghost'),
                          icon: const Icon(Icons.replay),
                          onPressed: () => start(d, replay: storedReplay(d)),
                        ),
                ),
            ] else ...[
              Wrap(
                spacing: 12,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text(
                    widget.tr('comp.${race.discipline}'),
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  OutlinedButton(
                    onPressed: saving
                        ? null
                        : () async {
                            if (await finishAndSave() && mounted) {
                              if (engine?.result == null) {
                                widget.keyStatistics.recorder.discardSession();
                              }
                              ghostTimer?.cancel();
                              setState(() => engine = null);
                            }
                          },
                    child: Text(widget.tr('nav.tomap')),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (result == null) ...[
                Text(widget.tr('comp.hint')),
                const SizedBox(height: 8),
                // E2: live time, speed, accuracy and the personal best.
                Builder(
                  builder: (context) {
                    final tokens = Theme.of(context)
                        .extension<TypeFreeTokens>()!;
                    final muted = Theme.of(context)
                        .colorScheme
                        .onSurfaceVariant;
                    final stats = race.typing.stats;
                    final record =
                        best['${race.discipline}_${competitionLanguage(widget.language)}'];
                    Widget cell(String label, String value) => Expanded(
                      child: Column(
                        children: [
                          Text(
                            label,
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 11.5, color: muted),
                          ),
                          Text(
                            value,
                            maxLines: 1,
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                    );
                    return Container(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      decoration: BoxDecoration(
                        color: tokens['raisedSurface'],
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: tokens['border']),
                      ),
                      child: Row(
                        children: [
                          cell(
                            competitionCopy(widget.language, 'time'),
                            '${(stats.elapsedMs / 1000).toStringAsFixed(1)} s',
                          ),
                          cell(widget.tr('st.wpm'), '${stats.wpm}'),
                          cell(widget.tr('st.accuracy'), '${stats.accuracy}%'),
                          cell(widget.tr('comp.best'), '${record ?? '—'}'),
                        ],
                      ),
                    );
                  },
                ),
                const SizedBox(height: 8),
                if (ghost.isNotEmpty) ...[
                  Text(competitionCopy(widget.language, 'ghost')),
                  LinearProgressIndicator(
                    value: (ghostPosition / race.typing.pattern.length).clamp(
                      0.0,
                      1.0,
                    ),
                  ),
                  const SizedBox(height: 8),
                  LinearProgressIndicator(
                    value: race.typing.pos / race.typing.pattern.length,
                  ),
                ],
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: PatternView(session: race.typing),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  key: const ValueKey('competition-input'),
                  controller: entry,
                  focusNode: focus,
                  autofocus: true,
                  autocorrect: false,
                  enableSuggestions: false,
                  enableInteractiveSelection: false,
                  smartDashesType: SmartDashesType.disabled,
                  smartQuotesType: SmartQuotesType.disabled,
                  inputFormatters: [PracticeCommitFormatter()],
                  onEditingComplete: () {},
                  onSubmitted: (_) {
                    race.press('\n');
                    setState(() {});
                  },
                  decoration: InputDecoration(
                    border: const OutlineInputBorder(),
                    labelText: competitionCopy(widget.language, 'input'),
                  ),
                ),
                const SizedBox(height: 12),
                KeyboardGuide(
                  language: widget.language,
                  model: widget.keyboard,
                  expected: race.typing.expected,
                  ru: race.language == 'ru',
                ),
              ] else ...[
                // E3: the three big numbers, the details, record banner.
                Builder(
                  builder: (context) {
                    final tokens = Theme.of(context)
                        .extension<TypeFreeTokens>()!;
                    final scheme = Theme.of(context).colorScheme;
                    final muted = scheme.onSurfaceVariant;
                    final record =
                        best['${race.discipline}_${competitionLanguage(widget.language)}'];
                    BoxDecoration box([Color? border]) => BoxDecoration(
                      color: tokens['raisedSurface'],
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: border ?? tokens['border']),
                    );
                    Widget big(String label, String value) => Expanded(
                      child: Column(
                        children: [
                          Text(
                            label,
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 12, color: muted),
                          ),
                          Text(
                            value,
                            maxLines: 1,
                            style: const TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                    );
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          decoration: box(),
                          child: Row(
                            children: [
                              big(widget.tr('st.wpm'), '${result.wpm}'),
                              big(
                                widget.tr('st.accuracy'),
                                '${result.accuracy}%',
                              ),
                              big(
                                widget.tr('comp.best'),
                                '${record ?? result.wpm}',
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: box(),
                          child: Column(
                            children: [
                              for (final (icon, label, value) in [
                                (
                                  Icons.schedule,
                                  competitionCopy(widget.language, 'time'),
                                  '${(result.elapsedMs / 1000).toStringAsFixed(1)} s',
                                ),
                                (
                                  Icons.keyboard_outlined,
                                  competitionCopy(widget.language, 'chars'),
                                  '${result.characters}',
                                ),
                                (
                                  Icons.error_outline,
                                  widget.tr('st.errors'),
                                  '${result.errors}',
                                ),
                                (
                                  Icons.military_tech_outlined,
                                  competitionCopy(widget.language, 'medal'),
                                  competitionCopy(
                                    widget.language,
                                    result.medal,
                                  ),
                                ),
                              ])
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 4,
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(icon, size: 18, color: muted),
                                      const SizedBox(width: 8),
                                      Expanded(child: Text(label)),
                                      Text(
                                        value,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                            ],
                          ),
                        ),
                        if (result.isRecord) ...[
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: box(tokens['success']),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.emoji_events_outlined,
                                  color: tokens['success'],
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    widget.tr('comp.record'),
                                    style: TextStyle(
                                      fontWeight: FontWeight.w700,
                                      color: tokens['success'],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    );
                  },
                ),
                if (saving) const LinearProgressIndicator(),
                if (saved) Text(competitionCopy(widget.language, 'saved')),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 12,
                  runSpacing: 8,
                  children: [
                    FilledButton(
                      onPressed: saved
                          ? () => start(race.discipline)
                          : saving
                          ? null
                          : finishAndSave,
                      child: Text(
                        widget.tr(saved ? 'done.again' : 'ex.finish'),
                      ),
                    ),
                    if (saved)
                      OutlinedButton(
                        key: const ValueKey('competition-ghost'),
                        onPressed: () => start(race.discipline, replay: point),
                        child: Text(competitionCopy(widget.language, 'ghost')),
                      ),
                  ],
                ),
              ],
            ],
            if (error != null)
              Text(
                error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            const SizedBox(height: 20),
            Text(competitionCopy(widget.language, 'local')),
          ],
        ),
      ),
    );
  }
}

String competitionCopy(String language, String key) {
  const languages = ['ru', 'en', 'es', 'de', 'fr', 'it', 'pt'];
  const values = {
    'time': ['время', 'time', 'tiempo', 'Zeit', 'temps', 'tempo', 'tempo'],
    'chars': [
      'Набрано символов',
      'Characters typed',
      'Caracteres',
      'Zeichen',
      'Caractères',
      'Caratteri',
      'Caracteres',
    ],
    'medal': [
      'Медаль',
      'Medal',
      'Medalla',
      'Medaille',
      'Médaille',
      'Medaglia',
      'Medalha',
    ],
    'gold': ['Золото', 'Gold', 'Oro', 'Gold', 'Or', 'Oro', 'Ouro'],
    'silver': [
      'Серебро',
      'Silver',
      'Plata',
      'Silber',
      'Argent',
      'Argento',
      'Prata',
    ],
    'bronze': [
      'Бронза',
      'Bronze',
      'Bronce',
      'Bronze',
      'Bronze',
      'Bronzo',
      'Bronze',
    ],
    'ribbon': [
      'Участие',
      'Participation',
      'Participación',
      'Teilnahme',
      'Participation',
      'Partecipazione',
      'Participação',
    ],
    'input': [
      'Печатайте здесь',
      'Type here',
      'Escribe aquí',
      'Hier tippen',
      'Tapez ici',
      'Digita qui',
      'Digite aqui',
    ],
    'saved': [
      'Результат сохранён на устройстве',
      'Result saved on this device',
      'Resultado guardado en este dispositivo',
      'Ergebnis auf diesem Gerät gespeichert',
      'Résultat enregistré sur cet appareil',
      'Risultato salvato sul dispositivo',
      'Resultado salvo neste dispositivo',
    ],
    'saveError': [
      'Не удалось сохранить. Повторите сохранение перед выходом.',
      'Could not save. Retry before leaving.',
      'No se pudo guardar. Reintenta antes de salir.',
      'Speichern fehlgeschlagen. Vor dem Verlassen erneut versuchen.',
      'Échec de l’enregistrement. Réessayez avant de quitter.',
      'Salvataggio non riuscito. Riprova prima di uscire.',
      'Falha ao salvar. Tente novamente antes de sair.',
    ],
    'english': [
      'Для этого языка соревнования используют английские тексты.',
      'Races use English texts for this language.',
      'Las carreras usan textos en inglés para este idioma.',
      'Rennen verwenden für diese Sprache englische Texte.',
      'Les courses utilisent des textes anglais pour cette langue.',
      'Le gare usano testi inglesi per questa lingua.',
      'As corridas usam textos em inglês neste idioma.',
    ],
    'ghost': [
      'Гонка со своим повтором',
      'Race your replay',
      'Compite con tu repetición',
      'Gegen eigene Wiederholung antreten',
      'Courir contre votre replay',
      'Gareggia con il tuo replay',
      'Corra contra seu replay',
    ],
    'local': [
      'Результаты сохраняются на этом устройстве. Онлайн-рейтинг, лига и вызовы пока недоступны.',
      'Results stay on this device. Online rankings, league and challenges are not available yet.',
      'Los resultados se guardan en este dispositivo. La clasificación, la liga y los desafíos aún no están disponibles.',
      'Ergebnisse bleiben auf diesem Gerät. Online-Rangliste, Liga und Herausforderungen sind noch nicht verfügbar.',
      'Les résultats restent sur cet appareil. Le classement en ligne, la ligue et les défis ne sont pas encore disponibles.',
      'I risultati restano su questo dispositivo. Classifica online, lega e sfide non sono ancora disponibili.',
      'Os resultados ficam neste dispositivo. Ranking online, liga e desafios ainda não estão disponíveis.',
    ],
  };
  final i = languages.indexOf(language);
  return values[key]![i < 0 ? 1 : i];
}

class _DisciplineRow extends StatelessWidget {
  const _DisciplineRow({
    super.key,
    required this.badge,
    required this.accentBadge,
    required this.title,
    required this.preview,
    required this.bestLabel,
    required this.best,
    required this.unit,
    required this.onTap,
    this.replay,
  });
  final String? badge, best;
  final bool accentBadge;
  final String title, preview, bestLabel, unit;
  final VoidCallback onTap;
  final Widget? replay;
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final tokens = Theme.of(context).extension<TypeFreeTokens>()!;
    final muted = scheme.onSurfaceVariant;
    final badgeColor = accentBadge
        ? scheme.primary
        : scheme.brightness == Brightness.dark
        ? const Color(0xFF68D7F2)
        : const Color(0xFF08728D);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: tokens['raisedSurface'],
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: tokens['border']),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
            child: Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: badgeColor, width: 1.5),
                  ),
                  child: badge == null
                      ? Icon(Icons.bolt, color: badgeColor)
                      : Text(
                          badge!,
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            color: badgeColor,
                          ),
                        ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        preview,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 12, color: muted),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      bestLabel,
                      style: TextStyle(fontSize: 11, color: muted),
                    ),
                    Text(
                      best == null ? '—' : '$best $unit',
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
                replay ?? const Icon(Icons.chevron_right),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
