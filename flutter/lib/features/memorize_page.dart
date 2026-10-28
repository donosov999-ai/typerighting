import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';

import '../data/key_statistics_store.dart';
import '../data/local_repository.dart';
import '../design_system/templates.dart';
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
            if (run == null)
              LayoutBuilder(
                builder: (context, box) {
                  final tokens = Theme.of(context).extension<TypeFreeTokens>()!;
                  final muted = Theme.of(context).colorScheme.onSurfaceVariant;
                  Widget panel(Widget child) => Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: tokens['raisedSurface'],
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: tokens['border']),
                    ),
                    child: child,
                  );
                  Widget chip(
                    Key key,
                    String label,
                    bool on,
                    VoidCallback? tap,
                  ) => ChoiceChip(
                    key: key,
                    showCheckmark: false,
                    label: SizedBox(
                      width: double.infinity,
                      child: Text(label, textAlign: TextAlign.center),
                    ),
                    selected: on,
                    onSelected: tap == null ? null : (_) => tap(),
                  );
                  // D4: what to learn (work) and how long a fragment is.
                  final setup = Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      panel(
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(
                              memorizeCopy(widget.language, 'work'),
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                for (final s in ['raven', 'classic']) ...[
                                  if (s != 'raven') const SizedBox(width: 8),
                                  Expanded(
                                    child: chip(
                                      ValueKey('memorize-source-$s'),
                                      library.title(s, widget.language),
                                      source == s,
                                      saving
                                          ? null
                                          : () => setState(() {
                                              source = s;
                                              page = 0;
                                            }),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 10),
                      panel(
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(
                              widget.tr('mem.len.label'),
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 8),
                            for (var i = 0; i < 4; i++)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 6),
                                child: chip(
                                  ValueKey('memorize-length-$i'),
                                  lengthLabel(i),
                                  lengthIndex == i,
                                  saving ? null : () => selectLength(i),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  );
                  final list = Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      panel(
                        Column(
                          children: [
                            for (
                              var i = page * 12;
                              i < min((page + 1) * 12, pieces.length);
                              i++
                            ) ...[
                              if (i != page * 12) const Divider(height: 1),
                              InkWell(
                                key: ValueKey('memorize-piece-$i'),
                                onTap: saving ? null : () => start(i),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 10,
                                  ),
                                  child: Row(
                                    children: [
                                      CircleAvatar(
                                        radius: 14,
                                        child: Text(
                                          '${i + 1}',
                                          style: const TextStyle(fontSize: 12),
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Text(
                                          pieces[i],
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      Icon(Icons.play_arrow, color: muted),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      Wrap(
                        spacing: 12,
                        runSpacing: 8,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          IconButton(
                            tooltip: widget.tr('nav.back'),
                            onPressed: page == 0
                                ? null
                                : () => setState(() => page--),
                            icon: const Icon(Icons.chevron_left),
                          ),
                          Text(
                            '${page + 1}/${max(1, (pieces.length / 12).ceil())}',
                          ),
                          IconButton(
                            tooltip: widget.tr('mem.next'),
                            onPressed: (page + 1) * 12 >= pieces.length
                                ? null
                                : () => setState(() => page++),
                            icon: const Icon(Icons.chevron_right),
                          ),
                        ],
                      ),
                    ],
                  );
                  final intro = Text(
                    widget.tr('mem.intro'),
                    style: TextStyle(color: muted),
                  );
                  if (box.maxWidth < 800) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        intro,
                        const SizedBox(height: 12),
                        setup,
                        const SizedBox(height: 12),
                        list,
                      ],
                    );
                  }
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      intro,
                      const SizedBox(height: 12),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(child: list),
                          const SizedBox(width: 16),
                          SizedBox(width: 280, child: setup),
                        ],
                      ),
                    ],
                  );
                },
              )
            else ...[
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
                  language: widget.language,
                  model: widget.keyboard,
                  expected: run.visible(run.typing.pos)
                      ? run.typing.expected
                      : null,
                  ru: widget.language == 'ru',
                ),
              ] else
                // D5: on wide screens the pass result sits beside the typed
                // text, as on the sketch; narrow keeps it in one column.
                LayoutBuilder(
                  builder: (context, box) {
                    final panel = Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
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
                                    style: Theme.of(context)
                                        .textTheme
                                        .headlineMedium,
                                  ),
                                  Text(
                                    '${result.accuracy}% · ${widget.tr(run.finished ? 'mem.recall' : 'st.accuracy')}',
                                  ),
                                  if (run.finished)
                                    Text(
                                      '${run.gain}% · ${widget.tr('mem.gain')}',
                                    ),
                                  if (run.finished)
                                    Text(
                                      run.medal,
                                      style: Theme.of(context)
                                          .textTheme
                                          .headlineMedium,
                                    ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        if (run.finished) ...[
                          // J4: every pass of the piece with its real numbers.
                          Card(
                            key: const ValueKey('memorize-passes'),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              child: Column(
                                children: [
                                  for (final (i, p) in run.passResults.indexed)
                                    Padding(
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 5,
                                      ),
                                      child: Row(
                                        children: [
                                          Icon(
                                            Icons.check_circle,
                                            size: 18,
                                            color: Theme.of(context)
                                                .extension<
                                                  TypeFreeTokens
                                                >()!['success'],
                                          ),
                                          const SizedBox(width: 8),
                                          // Label and numbers wrap at 320 px / 200 %.
                                          Expanded(
                                            child: Wrap(
                                              alignment:
                                                  WrapAlignment.spaceBetween,
                                              spacing: 12,
                                              children: [
                                                Text(
                                                  '${i + 1}. ${widget.tr('mem.lvl.${memorizeLevels[min(i, memorizeLevels.length - 1)]}')}',
                                                ),
                                                Text(
                                                  '${p.accuracy}% · ${p.wpm} ${widget.tr('st.wpm')} · ${p.elapsedMs ~/ 60000}:${((p.elapsedMs ~/ 1000) % 60).toString().padLeft(2, '0')}',
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
                                ],
                              ),
                            ),
                          ),
                          Text(
                            widget.tr(
                              run.lengthIncreased ? 'mem.lenup' : 'mem.done',
                            ),
                          ),
                          if (run.lengthIncreased)
                            Text(lengthLabel(run.lengthIndex)),
                          Text(widget.tr('mem.gain.hint')),
                        ] else
                          Text(
                            '${widget.tr('mem.next.hint')} ${widget.tr('mem.lvl.${memorizeLevels[run.level + 1]}')}',
                          ),
                        if (saving) const LinearProgressIndicator(),
                        if (saved)
                          Text(competitionCopy(widget.language, 'saved')),
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
                                  widget.tr(
                                    run.finished ? 'k.again' : 'mem.next',
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ],
                    );
                    if (box.maxWidth < 900) return panel;
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Card(
                            child: Padding(
                              padding: const EdgeInsets.all(12),
                              child: PatternView(session: run.typing),
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        SizedBox(width: 340, child: panel),
                      ],
                    );
                  },
                ),
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

String memorizeCopy(String language, String key) {
  const langs = ['ru', 'en', 'es', 'de', 'fr', 'it', 'pt'];
  const words = <String, List<String>>{
    'work': [
      'Выберите произведение',
      'Choose a work',
      'Elige una obra',
      'Werk wählen',
      'Choisissez une œuvre',
      'Scegli un’opera',
      'Escolha uma obra',
    ],
  };
  final i = langs.indexOf(language);
  return words[key]?[i < 0 ? 1 : i] ?? key;
}
