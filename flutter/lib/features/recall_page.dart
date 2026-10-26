import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data/key_statistics_store.dart';
import '../data/local_repository.dart';
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

  Future<bool> finishAndSave({bool scheduleNext = true}) async {
    if (saving) return false;
    final run = engine, result = engine?.result;
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
          '${widget.tr('span.title')} · ${result.completedSpan} ${widget.tr('span.words')}',
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
      setState(() {
        engine = null;
        exiting = false;
      });
    }
  }

  @override
  void dispose() {
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
        if (event is KeyDownEvent &&
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
              Text(widget.tr('span.intro')),
              const SizedBox(height: 12),
              if (run == null) ...[
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Wrap(
                      spacing: 24,
                      runSpacing: 12,
                      children: [
                        Text(
                          '${widget.adaptation.span} ${widget.tr('span.words')}',
                          style: Theme.of(context).textTheme.headlineMedium,
                        ),
                        Text(
                          '${widget.tr('span.best')}: ${widget.adaptation.bestSpan}',
                        ),
                      ],
                    ),
                  ),
                ),
                Text(recallCopy(widget.language, 'recordHint')),
                const SizedBox(height: 12),
                FilledButton(
                  key: const ValueKey('recall-start'),
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
                      '${widget.tr('span.level')} ${run.roundSpan - 2} · ${run.roundSpan} ${widget.tr('span.words')}',
                    ),
                    OutlinedButton(
                      onPressed: toMenu,
                      child: Text(widget.tr('nav.back')),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(widget.tr(run.revealing ? 'span.show' : 'span.recall')),
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
                    child: PatternView(
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
                      '${result.accuracy}% ${recallCopy(widget.language, 'accuracy')}, ${result.completedSpan} ${recallCopy(widget.language, 'completed')}, ${result.nextSpan} ${recallCopy(widget.language, 'nextLength')}, ${widget.tr('span.best')}: ${result.bestSpan}, ${result.stars} / 3 ★. ${recallCopy(widget.language, 'recordHint')}',
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${'★' * result.stars}${'☆' * (3 - result.stars)}',
                            style: Theme.of(context).textTheme.headlineMedium,
                          ),
                          const SizedBox(height: 12),
                          Wrap(
                            spacing: 24,
                            runSpacing: 12,
                            children: [
                              Text(
                                '${result.accuracy}%',
                                style: Theme.of(context)
                                    .textTheme
                                    .headlineMedium,
                              ),
                              Text(
                                '${result.completedSpan} ${recallCopy(widget.language, 'completed')}',
                              ),
                              Text(
                                '${result.nextSpan} ${recallCopy(widget.language, 'nextLength')}, ${widget.tr('span.best')}: ${result.bestSpan}, ${result.stars} / 3 ★. ${recallCopy(widget.language, 'recordHint')}',
                              ),
                            ],
                          ),
                          Text(recallCopy(widget.language, 'accuracy')),
                          Text('${widget.tr('span.best')}: ${result.bestSpan}'),
                          Text(recallCopy(widget.language, 'recordHint')),
                        ],
                      ),
                    ),
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
