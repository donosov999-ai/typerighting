import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';

import '../data/local_repository.dart';
import '../domain/course.dart';
import 'keyboard_guide.dart';
import 'practice_widgets.dart';

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
  });
  final Map<String, dynamic> data;
  final LocalRepository repository;
  final String language, profile;
  final KeyboardModel keyboard;
  final String Function(String) tr;
  final Future<void> Function(Map<String, dynamic>, List<Map<String, dynamic>>)
  onSaved;
  final int Function()? clock;
  @override
  State<CoursePage> createState() => CoursePageState();
}

class CoursePageState extends State<CoursePage> {
  final entry = TextEditingController(), focus = FocusNode();
  CourseAttempt? attempt;
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
      if (a.press(ch)) {
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
    final before = List<Map<String, dynamic>>.from(
      widget.repository.data['sessions'] as List,
    );
    var fresh = false;
    try {
      await widget.repository.transaction((doc) {
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
        if (stat.wpm > 0 && a.attemptedKeys >= 10) {
          rows.add(point);
          fresh = true;
          final h = legacy['tr_history'] is String
              ? List<dynamic>.from(
                  jsonDecode(legacy['tr_history'] as String) as List,
                )
              : <dynamic>[];
          h.add({
            't': point['t'],
            'wpm': stat.wpm,
            'acc': stat.accuracy,
            'len': a.attemptedKeys,
            'ms': point['elapsedMs'],
            'err': a.errors,
            'score':
                (stat.wpm *
                        (stat.accuracy / 100) *
                        min(1, a.attemptedKeys / 50))
                    .round(),
          });
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
          () => error = 'Результат не сохранён. Повторите запись; прежние данные сохранены.',
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
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              for (final l in lessons)
                SizedBox(
                  width: 280,
                  child: OutlinedButton(
                    onPressed: courseUnlocked(l['id'] as int, stars)
                        ? () => start(l)
                        : null,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Row(
                        children: [
                          Icon(
                            courseUnlocked(l['id'] as int, stars)
                                ? Icons.keyboard
                                : Icons.lock_outline,
                          ),
                          const SizedBox(width: 8),
                          Expanded(child: Text('${l['id']}. ${title(l)}')),
                          if ((stars['${l['id']}'] as num?) != null)
                            Semantics(
                              label: 'Звёзд: ${stars['${l['id']}']}',
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: List.generate(
                                  stars['${l['id']}'] as int,
                                  (_) => Icon(
                                    Icons.star,
                                    size: 16,
                                    color: Theme.of(context)
                                        .colorScheme
                                        .primary,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
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
        Card(
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: PatternView(session: a.session),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Text(
            '${a.session.stats.wpm} WPM · ${a.session.stats.accuracy}% · ${a.errors} ошибок за урок',
          ),
        ),
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
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              labelText: 'Печатайте строку',
            ),
          ),
        if (a.finished) ...[
          const SizedBox(height: 8),
          Text(
            'Звёзд: ${a.stars} · скорость последней строки: ${a.session.stats.wpm} WPM',
          ),
          Wrap(
            spacing: 12,
            children: [
              if (saving) const Text('Сохранение…'),
              if (!saved && !saving)
                FilledButton(
                  onPressed: saveResult,
                  child: const Text('Повторить сохранение'),
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
          model: widget.keyboard,
          expected: a.session.expected,
          ru: widget.language == 'ru',
        ),
      ],
    );
  }
}
