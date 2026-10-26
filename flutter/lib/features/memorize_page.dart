import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';

import '../data/key_statistics_store.dart';
import '../data/local_repository.dart';
import '../domain/key_statistics.dart';
import '../domain/memorize.dart';
import 'competition_page.dart' show competitionCopy;
import 'keyboard_guide.dart';
import 'practice_widgets.dart';

class MemorizePage extends StatefulWidget {
  const MemorizePage({
    super.key,
    required this.repository,
    required this.keyStatistics,
    required this.catalog,
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
  final Map<String, dynamic> catalog;
  final String language, profile;
  final KeyboardModel keyboard;
  final String Function(String) tr;
  final int Function()? clock;
  final VoidCallback? onTyping;
  final Future<void> Function(Map<String, dynamic>, List<Map<String, dynamic>>)
  onSaved;
  @override
  State<MemorizePage> createState() => MemorizePageState();
}

class MemorizePageState extends State<MemorizePage> {
  final entry = TextEditingController(), focus = FocusNode();
  MemorizeSession? engine;
  String source = 'raven', previous = '', runId = '';
  bool ignore = false, saving = false, saved = false;
  String? error;
  int page = 0;
  RecordedHistory? captured;
  Map<String, dynamic>? point;
  MemorizeLibrary get library => MemorizeLibrary(widget.catalog);
  int now() => widget.clock?.call() ?? DateTime.now().millisecondsSinceEpoch;
  int get lengthIndex {
    final value =
        int.tryParse(
          (widget.repository.data['legacy'] as Map)['tr_mem_len']?.toString() ??
              '',
        ) ??
        0;
    return value >= 0 && value < 4 ? value : 0;
  }

  String lengthLabel(int index) => memorizeLengths[index] == 0
      ? widget.tr('mem.len.full')
      : '${memorizeLengths[index]} ${widget.tr('mem.len.words')}';
  @override
  void initState() {
    super.initState();
    entry.addListener(edit);
  }

  @override
  void didUpdateWidget(covariant MemorizePage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.language != widget.language ||
        oldWidget.profile != widget.profile) {
      engine = null;
      page = 0;
      clearInput();
    }
  }

  void clearInput() {
    ignore = true;
    previous = '';
    entry.clear();
    ignore = false;
  }

  void resetCheckpoint() {
    saved = false;
    saving = false;
    captured = null;
    point = null;
    error = null;
    clearInput();
  }

  void start(int index) {
    setState(() {
      runId =
          'memorize-${DateTime.now().microsecondsSinceEpoch}-${Random().nextInt(0x7fffffff)}';
      engine = MemorizeSession(
        library: library,
        source: source,
        language: widget.language,
        lengthIndex: lengthIndex,
        pieceIndex: index,
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
      resetCheckpoint();
    });
    focus.requestFocus();
  }

  Future<void> selectLength(int index) async {
    if (saving) return;
    setState(() {
      saving = true;
      error = null;
    });
    try {
      await widget.keyStatistics.commit((doc) {
        (doc['legacy'] as Map)['tr_mem_len'] = '$index';
      });
      page = 0;
    } catch (_) {
      error = competitionCopy(widget.language, 'saveError');
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  void edit() {
    if (ignore ||
        saving ||
        engine == null ||
        engine!.typing.finished ||
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
      if (engine!.typing.finished) {
        unawaited(finishAndSave());
        break;
      }
    }
    previous = text;
    setState(() {});
  }

  Future<bool> finishAndSave() async {
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
    final record = captured!, id = '$runId-${run.level}';
    point ??= {
      'id': id,
      'title':
          '${library.title(source, widget.language)} — ${run.pieceIndex + 1} · ${widget.tr('mem.pass')} ${run.level + 1}/5',
      'exercise': 'memorize-$source-${run.pieceIndex}',
      'language': widget.language,
      'profile': widget.profile,
      'mode': 'memorize',
      'difficulty':
          '${widget.language}/$source/${run.activeLengthIndex}/${run.levelKey}',
      't': now(),
      'wpm': result.wpm,
      'accuracy': result.accuracy,
      'elapsedMs': result.elapsedMs,
      'errors': result.errors,
      'len': record.len,
      'errKeys': record.errorKeys,
      'pass': run.level,
      'recall': result.accuracy,
      'gain': run.gain,
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
        if (run.finished && run.lengthIncreased) {
          final current =
              int.tryParse(legacy['tr_mem_len']?.toString() ?? '') ?? 0;
          legacy['tr_mem_len'] = '${max(current, run.lengthIndex)}';
        }
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

  Future<void> toMenu() async {
    if (await finishAndSave() && mounted) {
      setState(() {
        engine = null;
        page = 0;
      });
    }
  }

  @override
  void dispose() {
    entry.removeListener(edit);
    entry.dispose();
    focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final run = engine, result = engine?.result;
    final pieces = library.pieces(source, widget.language, lengthIndex);
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1000),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (run == null) ...[
              Text(widget.tr('mem.intro')),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final s in ['raven', 'classic'])
                    ChoiceChip(
                      key: ValueKey('memorize-source-$s'),
                      label: Text(library.title(s, widget.language)),
                      selected: source == s,
                      onSelected: saving
                          ? null
                          : (_) => setState(() {
                              source = s;
                              page = 0;
                            }),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              Text(widget.tr('mem.len.label')),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (var i = 0; i < 4; i++)
                    ChoiceChip(
                      key: ValueKey('memorize-length-$i'),
                      label: Text(lengthLabel(i)),
                      selected: lengthIndex == i,
                      onSelected: saving ? null : (_) => selectLength(i),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              for (
                var i = page * 12;
                i < min((page + 1) * 12, pieces.length);
                i++
              )
                Card(
                  child: ListTile(
                    key: ValueKey('memorize-piece-$i'),
                    title: Text(
                      '${library.title(source, widget.language)} — ${i + 1}',
                    ),
                    subtitle: Text(pieces[i]),
                    trailing: const Icon(Icons.play_arrow),
                    onTap: saving ? null : () => start(i),
                  ),
                ),
              Wrap(
                spacing: 12,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  IconButton(
                    tooltip: widget.tr('nav.back'),
                    onPressed: page == 0 ? null : () => setState(() => page--),
                    icon: const Icon(Icons.chevron_left),
                  ),
                  Text('${page + 1}/${max(1, (pieces.length / 12).ceil())}'),
                  IconButton(
                    tooltip: widget.tr('mem.next'),
                    onPressed: (page + 1) * 12 >= pieces.length
                        ? null
                        : () => setState(() => page++),
                    icon: const Icon(Icons.chevron_right),
                  ),
                ],
              ),
            ] else ...[
              Wrap(
                spacing: 12,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text(
                    '${widget.tr('mem.pass')} ${run.level + 1}/5',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  Text(widget.tr('mem.lvl.${run.levelKey}')),
                  OutlinedButton(
                    onPressed: saving ? null : toMenu,
                    child: Text(widget.tr('nav.tomap')),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              LinearProgressIndicator(
                value: (run.level + (run.typing.finished ? 1 : 0)) / 5,
              ),
              const SizedBox(height: 12),
              if (result == null) ...[
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: PatternView(
                      session: run.typing,
                      displayPattern: run.displayPattern,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  key: const ValueKey('memorize-input'),
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
                    run.press('\n');
                    setState(() {});
                  },
                  decoration: InputDecoration(
                    border: const OutlineInputBorder(),
                    labelText: competitionCopy(widget.language, 'input'),
                  ),
                ),
                const SizedBox(height: 12),
                // Deliberate fix: the old keyboard revealed every hidden expected letter.
                KeyboardGuide(
                  model: widget.keyboard,
                  expected: run.visible(run.typing.pos)
                      ? run.typing.expected
                      : null,
                  ru: widget.language == 'ru',
                ),
              ] else ...[
                Semantics(
                  key: ValueKey('memorize-result-${run.level}'),
                  container: true,
                  excludeSemantics: true,
                  label:
                      '${result.wpm} ${widget.tr('st.wpm')}, ${result.accuracy}% ${widget.tr(run.finished ? 'mem.recall' : 'st.accuracy')}${run.finished ? ', ${run.gain}% ${widget.tr('mem.gain')}' : ''}',
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Wrap(
                        spacing: 24,
                        runSpacing: 16,
                        children: [
                          Text(
                            '${result.wpm} ${widget.tr('st.wpm')}',
                            style: Theme.of(context).textTheme.headlineMedium,
                          ),
                          Text(
                            '${result.accuracy}% · ${widget.tr(run.finished ? 'mem.recall' : 'st.accuracy')}',
                          ),
                          if (run.finished)
                            Text('${run.gain}% · ${widget.tr('mem.gain')}'),
                          if (run.finished)
                            Text(
                              run.medal,
                              style: Theme.of(context).textTheme.headlineMedium,
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
                if (run.finished) ...[
                  Text(
                    widget.tr(run.lengthIncreased ? 'mem.lenup' : 'mem.done'),
                  ),
                  if (run.lengthIncreased) Text(lengthLabel(run.lengthIndex)),
                  Text(widget.tr('mem.gain.hint')),
                ] else
                  Text(
                    '${widget.tr('mem.next.hint')} ${widget.tr('mem.lvl.${memorizeLevels[run.level + 1]}')}',
                  ),
                if (saving) const LinearProgressIndicator(),
                if (saved) Text(competitionCopy(widget.language, 'saved')),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 12,
                  runSpacing: 8,
                  children: [
                    if (!saved)
                      FilledButton(
                        onPressed: saving ? null : finishAndSave,
                        child: Text(widget.tr('ex.finish')),
                      ),
                    if (saved)
                      FilledButton(
                        key: const ValueKey('memorize-next'),
                        onPressed: saving
                            ? null
                            : () {
                                setState(() {
                                  if (run.finished) {
                                    run.nextPiece();
                                  } else {
                                    run.nextPass();
                                  }
                                  resetCheckpoint();
                                });
                                focus.requestFocus();
                              },
                        child: Text(
                          widget.tr(run.finished ? 'k.again' : 'mem.next'),
                        ),
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
          ],
        ),
      ),
    );
  }
}
