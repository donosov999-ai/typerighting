import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';

import '../data/local_repository.dart';
import '../design_system/templates.dart';
import '../data/key_statistics_store.dart';
import '../domain/key_statistics.dart';
import '../domain/course.dart';
import 'keyboard_guide.dart';
import 'trainer_parts.dart' show StatTiles;
import 'practice_widgets.dart';
import 'common_copy.dart';

class CoursePage extends StatefulWidget {
  const CoursePage({
    super.key,
    required this.data,
    required this.repository,
    required this.language,
    required this.profile,
    required this.keyboard,
    required this.tr,
    required this.onSaved,
    this.clock,
    this.initialLessonId,
    required this.keyStatistics,
  });
  final Map<String, dynamic> data;
  final LocalRepository repository;
  final KeyStatisticsStore keyStatistics;
  final String language, profile;
  final KeyboardModel keyboard;
  final String Function(String) tr;
  final Future<void> Function(Map<String, dynamic>, List<Map<String, dynamic>>)
  onSaved;
  final int Function()? clock;
  final int? initialLessonId;
  @override
  State<CoursePage> createState() => CoursePageState();
}

class CoursePageState extends State<CoursePage> {
  final entry = TextEditingController(), focus = FocusNode();
  CourseAttempt? attempt;
  RecordedHistory? recordedHistory;
  Map<String, dynamic>? lesson;
  bool ignore = false, saving = false, saved = false;
  String previous = '', id = '';
  String? error;
  Timer? timer;
  int now() => widget.clock?.call() ?? DateTime.now().millisecondsSinceEpoch;
  List<Map<String, dynamic>> get lessons => List<Map<String, dynamic>>.from(
    (widget.data['lessons'] as Map)[widget.language] as List,
  );
  Map get stars {
    final raw =
        (widget.repository.data['legacy']
            as Map)['tr_course_${widget.language}'];
    return raw is String ? (jsonDecode(raw) as Map)['stars'] as Map : {};
  }

  String title(Map l) =>
      widget.tr(l['titleKey'] as String) +
      (l['titleArg'] == null ? '' : ': ${l['titleArg']}');
  @override
  void initState() {
    super.initState();
    entry.addListener(edit);
    if (widget.initialLessonId != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final matches = lessons.where((l) => l['id'] == widget.initialLessonId);
        if (mounted && matches.isNotEmpty) start(matches.first);
      });
    }
    timer = Timer.periodic(const Duration(milliseconds: 250), (_) {
      if (mounted && attempt?.startedAt != null && !attempt!.finished) {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    timer?.cancel();
    entry.removeListener(edit);
    entry.dispose();
    focus.dispose();
    super.dispose();
  }

  void start(Map<String, dynamic> l) {
    if (saving || !courseUnlocked(l['id'] as int, stars)) return;
    final random = Random();
    setState(() {
      lesson = l;
      attempt = CourseAttempt(
        CourseGenerator(widget.data, random.nextInt).lines(widget.language, l),
        clock: now,
      );
      saved = false;
      recordedHistory = null;
      error = null;
      id =
          'course-${DateTime.now().microsecondsSinceEpoch}-${random.nextInt(0x7fffffff)}';
      clearInput();
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) focus.requestFocus();
    });
  }

  void clearInput() {
    ignore = true;
    entry.clear();
    previous = '';
    ignore = false;
  }

  void edit() {
    final a = attempt;
    if (ignore ||
        a == null ||
        a.finished ||
        entry.value.composing.isValid && !entry.value.composing.isCollapsed) {
      return;
    }
    final text = entry.text;
    if (text == previous) return;
    // The original course ignores Backspace. Restore the committed prefix.
    if (!text.startsWith(previous)) {
      ignore = true;
      entry.value = TextEditingValue(
        text: previous,
        selection: TextSelection.collapsed(offset: previous.length),
      );
      ignore = false;
      return;
    }
    for (var i = previous.length; i < text.length; i++) {
      final expected = a.session.expected ?? '';
      final ch = widget.keyboard.bridge(text[i], expected);
      final ru = RegExp(
        '[а-яё]',
        caseSensitive: false,
      ).hasMatch(a.session.pattern);
      final changedLine = a.press(ch);
      if (expected.isNotEmpty && expected != ' ' && expected != '\n') {
        final keyId = widget.keyboard.hit(expected, ru: ru)?['id'];
        if (keyId is String) {
          widget.keyStatistics.record(keyId, ch == expected, now());
        }
      }
      if (changedLine) {
        clearInput();
        setState(() {});
        return;
      }
      if (a.finished) break;
    }
    previous = text;
    setState(() {});
    if (a.finished) unawaited(saveResult());
  }

  Future<void> saveResult() async {
    final a = attempt, l = lesson;
    if (a == null || l == null || !a.finished || saved || saving) return;
    setState(() {
      saving = true;
      error = null;
    });
    final stat = a.session.stats;
    final point = <String, dynamic>{
      'id': id,
      'exercise': 'course-${l['id']}',
      'title': title(l),
      'language': widget.language,
      'profile': widget.profile,
      'mode': 'course',
      'difficulty': '${widget.language}/course/${l['id']}',
      't': DateTime.now().millisecondsSinceEpoch,
      ...stat.toJson(),
      'errors': a.errors,
      'elapsedMs': a.finishedAt! - a.startedAt!,
      'len': a.attemptedKeys,
      'stars': a.stars,
    };
    final captured = recordedHistory ??= widget.keyStatistics.recorder.take(
      now(),
    );
    point['len'] = captured.len;
    point['errKeys'] = captured.errorKeys;
    final before = List<Map<String, dynamic>>.from(
      widget.repository.data['sessions'] as List,
    );
    var fresh = false;
    try {
      await widget.keyStatistics.commit((doc) {
        final rows = doc['sessions'] as List, legacy = doc['legacy'] as Map;
        if (rows.any((r) => r['id'] == id)) return;
        final key = 'tr_course_${widget.language}';
        final progress = legacy[key] is String
            ? Map<String, dynamic>.from(
                jsonDecode(legacy[key] as String) as Map,
              )
            : <String, dynamic>{'stars': <String, dynamic>{}};
        final marks = progress['stars'] as Map;
        marks['${l['id']}'] = max((marks['${l['id']}'] as num?) ?? 0, a.stars);
        legacy[key] = jsonEncode(progress);
        if (captured.eligible(stat.wpm)) {
          rows.add(point);
          fresh = true;
          final h = legacy['tr_history'] is String
              ? List<dynamic>.from(
                  jsonDecode(legacy['tr_history'] as String) as List,
                )
              : <dynamic>[];
          h.add(captured.point(stat.wpm, stat.accuracy, point['t'] as int));
          legacy['tr_history'] = jsonEncode(
            h.length > 300 ? h.sublist(h.length - 300) : h,
          );
        }
      });
      if (mounted) setState(() => saved = true);
      if (fresh) await widget.onSaved(point, before);
    } catch (_) {
      if (mounted) {
        setState(
          () => error = commonCopy(widget.language, 'resultNotSaved'),
        );
      }
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final a = attempt;
    if (a == null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            widget.tr('course.title'),
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          Text(widget.tr('course.intro')),
          const SizedBox(height: 12),
          // C2: a numbered timeline; the next lesson to take is highlighted.
          for (final (i, l) in lessons.indexed)
            _LessonRow(
              key: ValueKey('course-lesson-${l['id']}'),
              number: i + 1,
              title: title(l),
              keys: ((l['newKeys'] as String?)?.isNotEmpty ?? false)
                  ? l['newKeys'] as String
                  : (l['pool'] as String? ?? ''),
              stars: (stars['${l['id']}'] as num?)?.toInt(),
              starsLabel: commonCopy(widget.language, 'stars'),
              unlocked: courseUnlocked(l['id'] as int, stars),
              current:
                  l ==
                  lessons.firstWhere(
                    (x) =>
                        courseUnlocked(x['id'] as int, stars) &&
                        stars['${x['id']}'] == null,
                    orElse: () => lessons.last,
                  ),
              last: i == lessons.length - 1,
              continueLabel: _courseCopy(widget.language, 'continue'),
              onTap: () => start(l),
            ),
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            TextButton.icon(
              onPressed: saving
                  ? null
                  : () {
                      setState(() {
                        attempt = null;
                        lesson = null;
                        clearInput();
                      });
                    },
              icon: const Icon(Icons.arrow_back),
              label: Text(widget.tr('course.title')),
            ),
            Expanded(
              child: Text(
                title(lesson!),
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            Text('${a.line + 1} / ${a.lines.length}'),
          ],
        ),
        // C3: lesson progress by lines.
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 2, 4, 8),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: (a.line + (a.finished ? 1 : 0)) / a.lines.length,
              minHeight: 6,
            ),
          ),
        ),
        // While typing: the line and live numbers; once done the result
        // block below replaces both (C4).
        if (!a.finished) ...[
          Card(
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: PatternView(session: a.session),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Text(
              '${a.session.stats.wpm} WPM · ${a.session.stats.accuracy}% · ${_courseCopy(widget.language, 'lessonErrors')}: ${a.errors}',
            ),
          ),
        ],
        if (!a.finished)
          TextField(
            key: const ValueKey('course-input'),
            controller: entry,
            focusNode: focus,
            enabled: !a.finished,
            autocorrect: false,
            enableSuggestions: false,
            enableInteractiveSelection: false,
            smartDashesType: SmartDashesType.disabled,
            smartQuotesType: SmartQuotesType.disabled,
            inputFormatters: [PracticeCommitFormatter()],
            decoration: InputDecoration(
              border: const OutlineInputBorder(),
              labelText: commonCopy(widget.language, 'typeLine'),
            ),
          ),
        if (a.finished) ...[
          const SizedBox(height: 8),
          // C4: the lesson result — stars large, then the lesson numbers.
          Semantics(
            label:
                '${commonCopy(widget.language, 'stars')}: ${a.stars} · ${commonCopy(widget.language, 'lastLineSpeed')}: ${a.session.stats.wpm} WPM',
            excludeSemantics: true,
            child: LayoutBuilder(
              builder: (context, box) {
                final stars = Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (var s = 1; s <= 3; s++)
                      Icon(
                        s <= a.stars
                            ? Icons.star_rounded
                            : Icons.star_outline_rounded,
                        size: 40,
                        color: const Color(0xFFF5B82E),
                      ),
                  ],
                );
                final tiles = StatTiles(
                  language: widget.language,
                  wpm: a.session.stats.wpm,
                  accuracy: a.session.stats.accuracy,
                  errors: a.errors,
                  elapsedMs: a.session.stats.elapsedMs,
                  compact: true,
                );
                // Wide: one strip so the keyboard stays on the first screen.
                if (box.maxWidth >= 720) {
                  return Row(
                    children: [
                      stars,
                      const SizedBox(width: 12),
                      Expanded(child: tiles),
                    ],
                  );
                }
                return Column(
                  children: [stars, const SizedBox(height: 6), tiles],
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Text(
              _courseCopy(widget.language, 'lastLine'),
              style: TextStyle(
                fontSize: 11.5,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 12,
            children: [
              if (saving) Text(commonCopy(widget.language, 'saving')),
              if (!saved && !saving)
                FilledButton(
                  onPressed: saveResult,
                  child: Text(commonCopy(widget.language, 'retrySave')),
                ),
              if (saved) ...[
                OutlinedButton(
                  onPressed: () => start(lesson!),
                  child: Text(widget.tr('done.again')),
                ),
                if ((lesson!['id'] as int) < lessons.length)
                  FilledButton(
                    onPressed: () => start(lessons[lesson!['id'] as int]),
                    child: Text(widget.tr('done.next')),
                  ),
              ],
            ],
          ),
        ],
        if (error != null)
          Text(
            error!,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        const SizedBox(height: 8),
        KeyboardGuide(
          language: widget.language,
          model: widget.keyboard,
          expected: a.session.expected,
          ru: widget.language == 'ru',
        ),
      ],
    );
  }
}

String _courseCopy(String language, String key) {
  const langs = ['ru', 'en', 'es', 'de', 'fr', 'it', 'pt'];
  const words = <String, List<String>>{
    'lessonErrors': [
      'Ошибки за урок',
      'Lesson errors',
      'Errores de la lección',
      'Fehler in der Lektion',
      'Erreurs de la leçon',
      'Errori della lezione',
      'Erros da lição',
    ],
    'lastLine': [
      'Скорость и время — по последней строке, ошибки — за весь урок',
      'Speed and time: last line; errors: whole lesson',
      'Velocidad y tiempo: última línea; errores: toda la lección',
      'Tempo und Zeit: letzte Zeile; Fehler: ganze Lektion',
      'Vitesse et temps : dernière ligne ; erreurs : toute la leçon',
      'Velocità e tempo: ultima riga; errori: tutta la lezione',
      'Velocidade e tempo: última linha; erros: toda a lição',
    ],
    'continue': [
      'Продолжить',
      'Continue',
      'Continuar',
      'Weiter',
      'Continuer',
      'Continua',
      'Continuar',
    ],
  };
  final i = langs.indexOf(language);
  return words[key]?[i < 0 ? 1 : i] ?? key;
}

class _LessonRow extends StatelessWidget {
  const _LessonRow({
    super.key,
    required this.number,
    required this.title,
    required this.keys,
    required this.stars,
    required this.unlocked,
    required this.current,
    required this.last,
    required this.continueLabel,
    required this.starsLabel,
    required this.onTap,
  });
  final int number;
  final String title, keys, continueLabel, starsLabel;
  final int? stars;
  final bool unlocked, current, last;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final tokens = Theme.of(context).extension<TypeFreeTokens>()!;
    final dot = current
        ? scheme.primary
        : unlocked
        ? tokens['success']
        : tokens['border'];
    final chips = keys.split('').where((k) => k.trim().isNotEmpty).toList();
    return Stack(
      children: [
        // Connector to the next lesson, as tall as this row.
        if (!last)
          Positioned(
            left: 19,
            top: 44,
            bottom: 0,
            child: Container(width: 2, color: tokens['border']),
          ),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 40,
              child: Padding(
                padding: const EdgeInsets.only(top: 14),
                child: Container(
                  width: 30,
                  height: 30,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(color: dot, shape: BoxShape.circle),
                  child: Text(
                    '$number',
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      color: unlocked ? Colors.white : scheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Semantics(
                  button: unlocked,
                  enabled: unlocked,
                  child: Material(
                    color: tokens['raisedSurface'],
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(
                        color: current ? scheme.primary : tokens['border'],
                        width: current ? 2 : 1,
                      ),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: InkWell(
                      onTap: unlocked ? onTap : null,
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
                        child: LayoutBuilder(
                          builder: (context, box) {
                            final scale =
                                MediaQuery.textScalerOf(context).scale(14) / 14;
                            // «Продолжить» beside the text only when it fits.
                            final side = box.maxWidth >= 330 * scale;
                            final info = Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  title,
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                    color: unlocked
                                        ? null
                                        : scheme.onSurfaceVariant,
                                  ),
                                ),
                                if (chips.isNotEmpty) ...[
                                  const SizedBox(height: 6),
                                  Wrap(
                                    spacing: 4,
                                    runSpacing: 4,
                                    children: [
                                      for (final k in chips.take(12))
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 6,
                                            vertical: 1,
                                          ),
                                          decoration: BoxDecoration(
                                            borderRadius: BorderRadius.circular(
                                              4,
                                            ),
                                            border: Border.all(
                                              color: tokens['border'],
                                            ),
                                          ),
                                          child: Text(
                                            k,
                                            style: const TextStyle(
                                              fontSize: 12,
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                ],
                                if (stars != null || unlocked) ...[
                                  const SizedBox(height: 4),
                                  Semantics(
                                    label: '$starsLabel: ${stars ?? 0}',
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        for (var s = 1; s <= 3; s++)
                                          Icon(
                                            s <= (stars ?? 0)
                                                ? Icons.star
                                                : Icons.star_border,
                                            size: 18,
                                            color: scheme.primary,
                                          ),
                                      ],
                                    ),
                                  ),
                                ],
                              ],
                            );
                            final button = FilledButton(
                              onPressed: onTap,
                              child: Text(continueLabel),
                            );
                            if (current && !side) {
                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  info,
                                  const SizedBox(height: 8),
                                  button,
                                ],
                              );
                            }
                            return Row(
                              children: [
                                Expanded(child: info),
                                const SizedBox(width: 6),
                                if (current)
                                  button
                                else
                                  Icon(
                                    unlocked
                                        ? Icons.chevron_right
                                        : Icons.lock_outline,
                                    color: scheme.onSurfaceVariant,
                                  ),
                              ],
                            );
                          },
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
