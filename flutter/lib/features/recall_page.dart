import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../audio/typefree_sound.dart';
import '../data/key_statistics_store.dart';
import '../data/local_repository.dart';
import '../design_system/templates.dart';
import '../domain/key_statistics.dart';
import '../domain/recall.dart';
import 'competition_page.dart' show competitionCopy;
import 'keyboard_guide.dart';
import 'practice_widgets.dart';

class RecallPage extends StatefulWidget {
  const RecallPage({
    super.key,
    required this.repository,
    required this.keyStatistics,
    required this.corpus,
    required this.adaptation,
    required this.language,
    required this.profile,
    required this.keyboard,
    required this.tr,
    required this.onSaved,
    this.clock,
    this.onTyping,
  });
  final LocalRepository repository;
  final KeyStatisticsStore keyStatistics;
  final String corpus, language, profile;
  final RecallAdaptation adaptation;
  final KeyboardModel keyboard;
  final String Function(String) tr;
  final int Function()? clock;
  final VoidCallback? onTyping;
  final Future<void> Function(Map<String, dynamic>, List<Map<String, dynamic>>)
  onSaved;
  @override
  State<RecallPage> createState() => RecallPageState();
}

class RecallPageState extends State<RecallPage> with WidgetsBindingObserver {
  final entry = TextEditingController(),
      inputFocus = FocusNode(),
      resultFocus = FocusNode();
  RecallSession? engine;
  Timer? phaseTimer;
  String previous = '', id = '';
  bool ignore = false,
      saving = false,
      saved = false,
      autoAdvance = true,
      exiting = false,
      foreground = true;
  String? error;
  int revealDeadline = 0;
  RecordedHistory? captured;
  Map<String, dynamic>? point;
  int now() => widget.clock?.call() ?? DateTime.now().millisecondsSinceEpoch;
  @override
  void initState() {
    super.initState();
    entry.addListener(edit);
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didUpdateWidget(covariant RecallPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.language != widget.language ||
        oldWidget.profile != widget.profile ||
        oldWidget.keyboard.snapshot['layoutName'] !=
            widget.keyboard.snapshot['layoutName']) {
      if (engine != null && engine!.result == null) {
        widget.keyStatistics.recorder.discardSession();
      }
      phaseTimer?.cancel();
      engine = null;
      resetCheckpoint();
      exiting = false;
    } else if (exiting) {
      // Parent checkpoint followed by a rebuild with unchanged settings.
      exiting = false;
      resumeTimers();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    foreground = state == AppLifecycleState.resumed;
    if (!foreground) {
      phaseTimer?.cancel();
      if (engine?.revealing == true && mounted) setState(() => engine!.hide());
    } else {
      resumeTimers();
      requestInput();
    }
  }

  void clearInput() {
    ignore = true;
    previous = '';
    entry.clear();
    ignore = false;
  }

  void resetCheckpoint() {
    saving = false;
    saved = false;
    captured = null;
    point = null;
    error = null;
    clearInput();
  }

  void requestInput() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted &&
          foreground &&
          !exiting &&
          engine?.revealing == false &&
          engine?.result == null) {
        inputFocus.requestFocus();
      }
    });
  }

  void startRound() {
    if (saving) return;
    phaseTimer?.cancel();
    try {
      widget.keyStatistics.recorder.discardSession();
      setState(() {
        if (engine == null) {
          engine = RecallSession(
            corpus: widget.corpus,
            adaptation: widget.adaptation,
            clock: now,
            record: (ch, ok, at) {
              final key = widget.keyboard.hit(
                ch,
                ru: widget.language == 'ru',
              )?['id'];
              if (key is String) {
                widget.keyStatistics.record(key, ok, at, timed: false);
              }
            },
          );
        } else {
          engine!.startRound();
        }
        // Source recall: start chime when the words are shown.
        appSound.effect('start');
        id =
            'recall-${DateTime.now().microsecondsSinceEpoch}-${Random().nextInt(0x7fffffff)}';
        resetCheckpoint();
        exiting = false;
        revealDeadline = now() + engine!.revealMs;
      });
      resumeTimers();
    } catch (_) {
      setState(() => error = recallCopy(widget.language, 'noWords'));
    }
  }

  void resumeTimers() {
    phaseTimer?.cancel();
    if (!mounted || !foreground || exiting) return;
    final run = engine;
    if (run == null) return;
    if (run.revealing) {
      phaseTimer = Timer(
        Duration(milliseconds: max(0, revealDeadline - now())),
        hide,
      );
    } else if (run.result != null && saved && autoAdvance && !saving) {
      phaseTimer = Timer(
        const Duration(milliseconds: 3500),
        () => unawaited(nextRound()),
      );
    }
  }

  void hide() {
    phaseTimer?.cancel();
    if (engine == null || !engine!.revealing || exiting) return;
    setState(() => engine!.hide());
    requestInput();
  }

  void edit() {
    if (ignore ||
        saving ||
        engine == null ||
        engine!.revealing ||
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
        phaseTimer?.cancel();
        unawaited(finishAndSave());
        break;
      }
    }
    previous = text;
    setState(() {});
  }

  Future<bool> checkpointForExit() async {
    phaseTimer?.cancel();
    exiting = true;
    final success = await finishAndSave(scheduleNext: false);
    if (!success) {
      exiting = false;
      resumeTimers();
    }
    return success;
  }

  String? soundedRound;

  Future<bool> finishAndSave({bool scheduleNext = true}) async {
    if (saving) return false;
    final run = engine, result = engine?.result;
    if (result != null && soundedRound != id) {
      soundedRound = id;
      appSound.effect('fanfare');
      for (var s = 0; s < result.stars; s++) {
        appSound.effect('star');
      }
    }
    if (run == null || result == null) {
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
    if (saved) return true;
    captured ??= widget.keyStatistics.recorder.take(now());
    final record = captured!;
    point ??= {
      'id': id,
      'exercise': 'recall',
      'title':
          '${widget.tr('span.title')} · ${spanWords(result.completedSpan, widget.language, widget.tr)}',
      'language': widget.language,
      'profile': widget.profile,
      'mode': 'recall',
      'difficulty': '${widget.language}/recall/${result.completedSpan}',
      't': now(),
      'wpm': result.wpm,
      'accuracy': result.accuracy,
      'elapsedMs': result.elapsedMs,
      'errors': result.errors,
      'len': record.len,
      'errKeys': record.errorKeys,
      'completedSpan': result.completedSpan,
      'nextSpan': result.nextSpan,
      'bestSpan': result.bestSpan,
      'stars': result.stars,
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
        final best =
            num.tryParse(legacy['tr_span_best']?.toString() ?? '') ?? 3;
        legacy['tr_span_best'] = '${max(best, result.bestSpan)}';
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
      if (mounted) {
        setState(() {});
        if (saved && scheduleNext) {
          resumeTimers();
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted && !exiting && foreground && engine?.result != null) {
              resultFocus.requestFocus();
            }
          });
        }
      }
    }
  }

  Future<void> nextRound() async {
    phaseTimer?.cancel();
    if (saving || engine?.result == null) return;
    if (await finishAndSave(scheduleNext: false) && mounted && !exiting) {
      startRound();
    }
  }

  Future<void> toMenu() async {
    if (await checkpointForExit() && mounted) {
      if (engine?.result == null) {
        widget.keyStatistics.recorder.discardSession();
      }
      setState(() {
        engine = null;
        exiting = false;
      });
    }
  }

  @override
  void dispose() {
    if (engine != null && engine!.result == null) {
      widget.keyStatistics.recorder.discardSession();
    }
    phaseTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    entry.removeListener(edit);
    entry.dispose();
    inputFocus.dispose();
    resultFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final run = engine, result = engine?.result;
    return Focus(
      focusNode: resultFocus,
      onKeyEvent: (_, event) {
        if (resultFocus.hasPrimaryFocus &&
            event is KeyDownEvent &&
            result != null &&
            [
              LogicalKeyboardKey.enter,
              LogicalKeyboardKey.space,
            ].contains(event.logicalKey)) {
          unawaited(nextRound());
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1000),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (run != null) ...[
                Text(widget.tr('span.intro')),
                const SizedBox(height: 12),
              ],
              if (run == null) ...[
                // J5: what the mode is, the current set and the record.
                Row(
                  children: [
                    Icon(
                      Icons.psychology_outlined,
                      size: 44,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        widget.tr('span.intro'),
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Card(
                  margin: EdgeInsets.zero,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        for (final (label, value) in [
                          (
                            recallCopy(widget.language, 'current'),
                            spanWords(
                              widget.adaptation.span,
                              widget.language,
                              widget.tr,
                            ),
                          ),
                          (
                            widget.tr('span.best'),
                            spanWords(
                              widget.adaptation.bestSpan.toInt(),
                              widget.language,
                              widget.tr,
                            ),
                          ),
                        ])
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 6),
                            child: Wrap(
                              alignment: WrapAlignment.spaceBetween,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              spacing: 12,
                              children: [
                                Text(label),
                                Text(
                                  value,
                                  style: const TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  recallCopy(widget.language, 'recordHint'),
                  style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 16),
                FilledButton(
                  key: const ValueKey('recall-start'),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(52),
                  ),
                  onPressed: startRound,
                  child: Text(widget.tr('span.start')),
                ),
              ] else if (result == null) ...[
                Wrap(
                  spacing: 12,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      '${widget.tr('span.level')} ${run.roundSpan - 2} · ${spanWords(run.roundSpan, widget.language, widget.tr)}',
                    ),
                    OutlinedButton(
                      onPressed: toMenu,
                      child: Text(widget.tr('nav.back')),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                // D6: two steps — remember, then type from memory.
                Row(
                  children: [
                    for (final (i, key) in [
                      (0, 'span.show'),
                      (1, 'span.recall'),
                    ]) ...[
                      if (i == 1)
                        Expanded(
                          child: Divider(
                            indent: 8,
                            endIndent: 8,
                            color: Theme.of(context).colorScheme.outline,
                          ),
                        ),
                      Icon(
                        (i == 0) == run.revealing
                            ? Icons.radio_button_checked
                            : Icons.radio_button_unchecked,
                        size: 18,
                        color: (i == 0) == run.revealing
                            ? Theme.of(context).colorScheme.primary
                            : Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          widget.tr(key),
                          style: TextStyle(
                            fontWeight: (i == 0) == run.revealing
                                ? FontWeight.w700
                                : FontWeight.w400,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 6),
                SizedBox(
                  height: 8,
                  child: run.revealing
                      ? TweenAnimationBuilder<double>(
                          key: ValueKey(id),
                          tween: Tween(begin: 1, end: 0),
                          duration: Duration(milliseconds: run.revealMs),
                          builder: (context, value, _) =>
                              LinearProgressIndicator(value: value),
                        )
                      : const SizedBox(),
                ),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    // While showing: the words as tiles; then the masked line.
                    child: run.revealing
                        ? Wrap(
                            key: const ValueKey('recall-tiles'),
                            spacing: 8,
                            runSpacing: 8,
                            alignment: WrapAlignment.center,
                            children: [
                              for (final w in run.typing.pattern.split(' '))
                                if (w.isNotEmpty)
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 12,
                                    ),
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(
                                        color: Theme.of(context)
                                            .colorScheme
                                            .outline,
                                      ),
                                    ),
                                    child: Text(
                                      w,
                                      style: const TextStyle(fontSize: 24),
                                    ),
                                  ),
                            ],
                          )
                        : PatternView(
                            key: const ValueKey('recall-pattern'),
                            session: run.typing,
                            displayPattern: run.displayPattern,
                          ),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  key: const ValueKey('recall-input'),
                  controller: entry,
                  focusNode: inputFocus,
                  enabled: !run.revealing,
                  autocorrect: false,
                  enableSuggestions: false,
                  enableInteractiveSelection: false,
                  smartDashesType: SmartDashesType.disabled,
                  smartQuotesType: SmartQuotesType.disabled,
                  inputFormatters: [PracticeCommitFormatter()],
                  onEditingComplete: () {},
                  decoration: InputDecoration(
                    border: const OutlineInputBorder(),
                    labelText: competitionCopy(widget.language, 'input'),
                  ),
                ),
                const SizedBox(height: 12),
                // Recall must never expose the hidden next letter through key hints.
                KeyboardGuide(
                  language: widget.language,
                  model: widget.keyboard,
                  expected: null,
                  ru: widget.language == 'ru',
                ),
                const SizedBox(height: 12),
                if (run.revealing)
                  FilledButton(
                    key: const ValueKey('recall-ready'),
                    onPressed: hide,
                    child: Text(widget.tr('span.ready')),
                  ),
              ] else ...[
                Semantics(
                  key: ValueKey('recall-result-$id'),
                  container: true,
                  excludeSemantics: true,
                  label:
                      '${result.accuracy}% ${recallCopy(widget.language, 'accuracy')}, ${result.completedSpan} ${recallCopy(widget.language, 'completed')}, ${nextSetText(result.nextSpan, widget.language)}, ${widget.tr('span.best')}: ${result.bestSpan}, ${result.stars} / 3 ★. ${recallCopy(widget.language, 'recordHint')}',
                  child: Builder(
                    builder: (context) {
                      // J6: which words came back right — a word is right only if no
                      // key was wrong in it, even a blocked and corrected one.
                      final pattern = run.typing.pattern;
                      final words = <(String, bool)>[];
                      var i = 0;
                      for (final w in pattern.split(' ')) {
                        if (w.isNotEmpty) {
                          var ok = true;
                          for (var k = i; k < i + w.length; k++) {
                            if (k >= run.typing.marks.length ||
                                run.typing.marks[k] != 1 ||
                                run.typing.missedAt.contains(k)) {
                              ok = false;
                            }
                          }
                          words.add((w, ok));
                        }
                        i += w.length + 1;
                      }
                      final right = words.where((w) => w.$2).length;
                      final scheme = Theme.of(context).colorScheme;
                      final tokens = Theme.of(context)
                          .extension<TypeFreeTokens>()!;
                      Widget stat(String label, String value) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Wrap(
                          alignment: WrapAlignment.spaceBetween,
                          spacing: 12,
                          children: [
                            Text(label),
                            Text(
                              value,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ),
                      );
                      return Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    result.up
                                        ? Icons.check_circle
                                        : Icons.replay_circle_filled,
                                    size: 36,
                                    color: result.up
                                        ? tokens['success']
                                        : scheme.primary,
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      widget.tr(
                                        result.up ? 'span.up' : 'span.down',
                                      ),
                                      style: const TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ),
                                  Text(
                                    '${'★' * result.stars}${'☆' * (3 - result.stars)}',
                                    style: TextStyle(
                                      fontSize: 22,
                                      color: scheme.primary,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              for (final (n, (w, ok)) in words.indexed)
                                Container(
                                  margin: const EdgeInsets.only(bottom: 4),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(8),
                                    color: ok
                                        ? null
                                        : tokens['danger'].withValues(
                                            alpha: .15,
                                          ),
                                  ),
                                  child: Row(
                                    children: [
                                      SizedBox(
                                        width: 24,
                                        child: Text(
                                          '${n + 1}',
                                          style: TextStyle(
                                            color: scheme.onSurfaceVariant,
                                          ),
                                        ),
                                      ),
                                      Expanded(child: Text(w)),
                                      Icon(
                                        ok ? Icons.check : Icons.close,
                                        size: 18,
                                        color: ok
                                            ? tokens['success']
                                            : tokens['danger'],
                                      ),
                                    ],
                                  ),
                                ),
                              const Divider(),
                              stat(
                                recallCopy(widget.language, 'right'),
                                '$right / ${words.length}',
                              ),
                              stat(
                                recallCopy(widget.language, 'accuracy'),
                                '${result.accuracy}%',
                              ),
                              stat(
                                widget.tr('span.best'),
                                spanWords(
                                  result.bestSpan.toInt(),
                                  widget.language,
                                  widget.tr,
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 4,
                                ),
                                child: Text(
                                  '${nextSetText(result.nextSpan, widget.language)}',
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                recallCopy(widget.language, 'recordHint'),
                                style: TextStyle(
                                  fontSize: 12,
                                  color: scheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
                if (saving) const LinearProgressIndicator(),
                if (saved) Text(competitionCopy(widget.language, 'saved')),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 12,
                  runSpacing: 8,
                  children: [
                    FilledButton(
                      key: const ValueKey('recall-next'),
                      onPressed: saving ? null : nextRound,
                      child: Text(widget.tr(saved ? 'span.next' : 'ex.finish')),
                    ),
                    OutlinedButton(
                      onPressed: saving ? null : toMenu,
                      child: Text(widget.tr('k.map')),
                    ),
                    TextButton(
                      key: const ValueKey('recall-auto'),
                      onPressed: () {
                        setState(() => autoAdvance = !autoAdvance);
                        resumeTimers();
                      },
                      child: Text(
                        recallCopy(
                          widget.language,
                          autoAdvance ? 'pause' : 'resume',
                        ),
                      ),
                    ),
                  ],
                ),
                if (autoAdvance && saved && !saving)
                  Text(widget.tr('k.autonext')),
              ],
              if (error != null)
                Text(
                  error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

String recallCopy(String language, String key) {
  const languages = ['ru', 'en', 'es', 'de', 'fr', 'it', 'pt'];
  const values = {
    'right': [
      'Правильно слов',
      'Words right',
      'Palabras correctas',
      'Richtige Wörter',
      'Mots justes',
      'Parole giuste',
      'Palavras certas',
    ],
    'current': [
      'Текущий набор',
      'Current set',
      'Conjunto actual',
      'Aktueller Satz',
      'Série actuelle',
      'Serie attuale',
      'Conjunto atual',
    ],
    'accuracy': [
      'Точность введённых символов',
      'Character accuracy',
      'Precisión de caracteres',
      'Zeichengenauigkeit',
      'Précision des caractères',
      'Precisione dei caratteri',
      'Precisão dos caracteres',
    ],
    'completed': [
      'слов завершено',
      'words completed',
      'palabras completadas',
      'Wörter abgeschlossen',
      'mots terminés',
      'parole completate',
      'palavras concluídas',
    ],
    'nextLength': [
      'слов в следующем наборе',
      'words in next set',
      'palabras en el siguiente grupo',
      'Wörter im nächsten Satz',
      'mots dans la prochaine série',
      'parole nel prossimo gruppo',
      'palavras no próximo conjunto',
    ],
    'recordHint': [
      'Рекорд — достигнутая длина следующего набора.',
      'Record means the next set size reached.',
      'El récord indica el tamaño del siguiente grupo alcanzado.',
      'Der Rekord ist die erreichte Größe des nächsten Satzes.',
      'Le record indique la taille atteinte de la prochaine série.',
      'Il record indica la dimensione raggiunta del prossimo gruppo.',
      'O recorde indica o tamanho alcançado do próximo conjunto.',
    ],
    'pause': [
      'Остановить автопереход',
      'Pause automatic next',
      'Pausar avance automático',
      'Automatischen Wechsel pausieren',
      'Suspendre le passage automatique',
      'Pausa avanzamento automatico',
      'Pausar avanço automático',
    ],
    'resume': [
      'Включить автопереход',
      'Enable automatic next',
      'Activar avance automático',
      'Automatischen Wechsel aktivieren',
      'Activer le passage automatique',
      'Attiva avanzamento automatico',
      'Ativar avanço automático',
    ],
    'noWords': [
      'В этом корпусе нет подходящих слов.',
      'No eligible words in this corpus.',
      'No hay palabras aptas en este corpus.',
      'Keine geeigneten Wörter in diesem Korpus.',
      'Aucun mot adapté dans ce corpus.',
      'Nessuna parola adatta in questo corpus.',
      'Não há palavras adequadas neste corpus.',
    ],
  };
  final i = languages.indexOf(language);
  return values[key]![i < 0 ? 1 : i];
}

/// «3 слова», «5 слов», «1 слово» (the source always said «слов»); English
/// singular; other languages keep the dictionary word.
String spanWords(int n, String language, String Function(String) tr) {
  if (language == 'ru') {
    final d10 = n % 10, d100 = n % 100;
    final form = d100 >= 11 && d100 <= 14
        ? 'слов'
        : d10 == 1
        ? 'слово'
        : d10 >= 2 && d10 <= 4
        ? 'слова'
        : 'слов';
    return '$n $form';
  }
  if (language == 'en' && n == 1) return '1 word';
  return '$n ${tr('span.words')}';
}

/// «4 слова в следующем наборе» (Russian needs the plural form).
String nextSetText(int n, String language) => language == 'ru'
    ? '${spanWords(n, 'ru', (_) => '')} в следующем наборе'
    : '$n ${recallCopy(language, 'nextLength')}';
