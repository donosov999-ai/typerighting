import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../audio/typefree_sound.dart';
import '../data/artifact_export.dart';
import '../data/key_statistics_store.dart';
import '../data/local_repository.dart';
import '../design_system/templates.dart';
import '../domain/exam.dart';
import '../domain/key_statistics.dart';
import 'exam_certificate.dart';
import 'keyboard_guide.dart';
import 'practice_widgets.dart';

class ExamPage extends StatefulWidget {
  const ExamPage({
    super.key,
    required this.repository,
    required this.keyStatistics,
    required this.catalog,
    required this.language,
    required this.profile,
    required this.keyboard,
    required this.tr,
    required this.onSaved,
    required this.onExit,
    this.clock,
    this.onTyping,
    this.exporter,
  });
  final LocalRepository repository;
  final KeyStatisticsStore keyStatistics;
  final Map<String, dynamic> catalog;
  final String language, profile;
  final KeyboardModel keyboard;
  final String Function(String) tr;
  final int Function()? clock;
  final VoidCallback? onTyping;
  final VoidCallback onExit;
  final ArtifactExporter? exporter;
  final Future<void> Function(Map<String, dynamic>, List<Map<String, dynamic>>)
  onSaved;
  @override
  State<ExamPage> createState() => ExamPageState();
}

class ExamPageState extends State<ExamPage> with WidgetsBindingObserver {
  final entry = TextEditingController(),
      targetController = TextEditingController(text: '35'),
      nameController = TextEditingController(),
      inputFocus = FocusNode();
  ExamSession? engine;
  Timer? hudTimer;
  int duration = 10;
  String previous = '', id = '', examName = '';
  bool ignore = false,
      saving = false,
      saved = false,
      exporting = false,
      foreground = true;
  String? error, exportStatus;
  RecordedHistory? captured;
  Map<String, dynamic>? point;
  Uint8List? certificate;
  int now() => widget.clock?.call() ?? DateTime.now().millisecondsSinceEpoch;
  String get nameKey => 'certificateName_${widget.profile}';
  void loadName() {
    final raw = (widget.repository.data['prefs'] as Map)[nameKey];
    nameController.text = raw is String ? raw : '';
  }

  @override
  void initState() {
    super.initState();
    loadName();
    entry.addListener(edit);
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didUpdateWidget(covariant ExamPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.language != widget.language ||
        oldWidget.profile != widget.profile ||
        oldWidget.keyboard.snapshot['layoutName'] !=
            widget.keyboard.snapshot['layoutName']) {
      hudTimer?.cancel();
      engine = null;
      resetCheckpoint();
      loadName();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    foreground = state == AppLifecycleState.resumed;
    hudTimer?.cancel();
    if (foreground && engine != null && !engine!.finished) {
      if (now() >= engine!.endAt) {
        unawaited(finishAndSave(reason: 'timeout'));
      } else {
        startHud();
        requestInput();
      }
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
    certificate = null;
    error = null;
    exportStatus = null;
    clearInput();
  }

  void requestInput() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && foreground && engine != null && !engine!.finished) {
        inputFocus.requestFocus();
      }
    });
  }

  Future<void> start() async {
    if (saving || exporting) return;
    final target = num.tryParse(
      targetController.text.trim().isEmpty
          ? '35'
          : targetController.text.trim(),
    );
    if (target == null ||
        !target.isFinite ||
        target < 5 ||
        target > 120 ||
        ![1, 5, 10].contains(duration)) {
      setState(() => error = examCopy(widget.language, 'settingsError'));
      return;
    }
    final pool = examClassics(widget.catalog, widget.language)
      ..shuffle(Random());
    if (pool.isEmpty) {
      setState(() => error = examCopy(widget.language, 'noTexts'));
      return;
    }
    setState(() {
      saving = true;
      error = null;
    });
    final name = nameController.text.trim();
    if (name.length > 512) {
      setState(() {
        saving = false;
        error = examCopy(widget.language, 'nameTooLong');
      });
      return;
    }
    try {
      await widget.keyStatistics.commit((doc) {
        (doc['prefs'] as Map)[nameKey] = name;
      });
      if (!mounted) return;
      setState(() {
        examName = name;
        id =
            'exam-${DateTime.now().microsecondsSinceEpoch}-${Random().nextInt(0x7fffffff)}';
        engine = ExamSession(
          exercises: pool,
          durationMinutes: duration,
          target: target,
          clock: now,
          record: (ch, ok, at) {
            final key = widget.keyboard.hit(
              ch,
              ru: widget.language == 'ru',
            )?['id'];
            if (key is String) widget.keyStatistics.record(key, ok, at);
          },
        )..onWrong = () => appSound.effect('error');
        resetCheckpoint();
      });
      startHud();
      requestInput();
    } catch (_) {
      if (mounted) {
        setState(() {
          saving = false;
          error = examCopy(widget.language, 'saveError');
        });
      }
    }
  }

  void startHud() {
    hudTimer?.cancel();
    if (!foreground || engine == null || engine!.finished) return;
    hudTimer = Timer.periodic(const Duration(milliseconds: 250), (_) {
      if (!mounted || engine == null || engine!.finished) {
        hudTimer?.cancel();
        return;
      }
      if (now() >= engine!.endAt) {
        unawaited(finishAndSave(reason: 'timeout'));
      } else {
        setState(() {});
      }
    });
  }

  void restoreInput(String text) {
    ignore = true;
    previous = text;
    entry.value = TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
    ignore = false;
  }

  void edit() {
    if (ignore ||
        saving ||
        !foreground ||
        engine == null ||
        engine!.finished ||
        entry.value.composing.isValid && !entry.value.composing.isCollapsed) {
      return;
    }
    widget.onTyping?.call();
    final text = entry.text, run = engine!;
    if (text == previous) return;
    if (previous.startsWith(text)) {
      for (var i = text.length; i < previous.length; i++) {
        run.press('Backspace');
      }
      previous = text;
    } else if (text.startsWith(previous)) {
      final added = text.substring(previous.length);
      var boundary = -1;
      for (var i = 0; i < added.length; i++) {
        final ch = widget.keyboard.bridge(added[i], run.typing.expected ?? '');
        if (run.press(ch)) boundary = i + 1;
        if (run.finished) break;
      }
      if (boundary >= 0) {
        restoreInput(added.substring(boundary));
      } else {
        previous = text;
      }
    } else {
      restoreInput(previous);
      return;
    }
    if (run.finished) {
      unawaited(finishAndSave(reason: run.endReason ?? 'timeout'));
    }
    setState(() {});
  }

  Future<bool> checkpointForExit() async {
    if (saving || exporting) return false;
    hudTimer?.cancel();
    if (engine == null) return true;
    return finishAndSave(
      reason: engine!.finished ? engine!.endReason ?? 'manual' : 'navigation',
    );
  }

  Future<bool> finishAndSave({String reason = 'manual'}) async {
    if (saving) return false;
    final run = engine;
    if (run == null) return true;
    hudTimer?.cancel();
    final result = run.finish(reason: reason);
    if (saved) return true;
    captured ??= widget.keyStatistics.recorder.take(now());
    final record = captured!;
    point ??= {
      'id': id,
      'exercise': 'exam',
      'title': widget.tr('ex.title'),
      'language': widget.language,
      'profile': widget.profile,
      'mode': 'exam',
      'difficulty':
          '${widget.language}/exam/${run.durationMinutes}/${run.target}',
      't': run.finishedAt!,
      'wpm': result.net,
      'accuracy': result.accuracy,
      'errors': result.errors,
      'elapsedMs': result.elapsedMs,
      'len': record.len,
      'errKeys': record.errorKeys,
      'typed': result.typed,
      'gross': result.gross,
      'target': run.target,
      'durationMinutes': run.durationMinutes,
      'fullDuration': run.fullDuration,
      'endedBy': run.endReason,
      'completedExercises': run.completedExercises,
      'historyEligible': record.eligible(result.net),
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
        rows.add(point!);
        fresh = true;
        if (record.eligible(result.net)) {
          final history = legacy['tr_history'] is String
              ? List<dynamic>.from(
                  jsonDecode(legacy['tr_history'] as String) as List,
                )
              : <dynamic>[];
          history.add(
            record.point(result.net, result.accuracy, point!['t'] as int),
          );
          legacy['tr_history'] = jsonEncode(
            history.length > 300
                ? history.sublist(history.length - 300)
                : history,
          );
        }
      });
      saved = true;
      if (fresh && record.eligible(result.net)) {
        try {
          await widget.onSaved(point!, earlier);
        } catch (_) {
          /* Optional companion. */
        }
      }
      return true;
    } catch (_) {
      error = examCopy(widget.language, 'saveError');
      return false;
    } finally {
      saving = false;
      if (mounted) setState(() {});
    }
  }

  Future<void> exportCertificate() async {
    final run = engine;
    if (run == null || run.result == null || !saved || exporting) return;
    setState(() {
      exporting = true;
      exportStatus = null;
    });
    try {
      certificate ??= await renderExamCertificate(
        metrics: run.result!,
        target: run.target,
        durationMinutes: run.durationMinutes,
        finishedAt: run.finishedAt!,
        name: examName,
        language: widget.language,
        tr: widget.tr,
      );
      final outcome = await (widget.exporter ?? saveArtifact)(
        'TypeFree-test-${run.result!.net}wpm.png',
        certificate!,
        'image/png',
      );
      exportStatus = examCopy(
        widget.language,
        outcome == ArtifactExportOutcome.cancelled
            ? 'cancelled'
            : 'fileRequested',
      );
    } catch (_) {
      exportStatus = examCopy(widget.language, 'exportError');
    } finally {
      exporting = false;
      if (mounted) setState(() {});
    }
  }

  @override
  void dispose() {
    hudTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    entry.removeListener(edit);
    entry.dispose();
    targetController.dispose();
    nameController.dispose();
    inputFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final run = engine, result = engine?.result;
    final tokens = Theme.of(context).extension<TypeFreeTokens>()!;
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    Widget panel(Widget child, {EdgeInsets? padding}) => Container(
      padding: padding ?? const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: tokens['raisedSurface'],
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: tokens['border']),
      ),
      child: child,
    );
    Widget cell(String label, Widget value) => Expanded(
      child: Column(
        children: [
          Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, color: muted),
          ),
          value,
        ],
      ),
    );
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1000),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (run == null) ...[
              Text(widget.tr('ex.desc'), style: TextStyle(color: muted)),
              const SizedBox(height: 12),
              panel(
                Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      widget.tr('ex.duration'),
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        for (final minutes in [1, 5, 10]) ...[
                          if (minutes != 1) const SizedBox(width: 8),
                          Expanded(
                            child: ChoiceChip(
                              key: ValueKey('exam-duration-$minutes'),
                              showCheckmark: false,
                              label: SizedBox(
                                width: double.infinity,
                                child: Text(
                                  '$minutes ${widget.tr('ex.min')}',
                                  textAlign: TextAlign.center,
                                ),
                              ),
                              selected: duration == minutes,
                              onSelected: saving
                                  ? null
                                  : (_) => setState(() => duration = minutes),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      key: const ValueKey('exam-target'),
                      controller: targetController,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: InputDecoration(
                        labelText: widget.tr('ex.target'),
                        border: const OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      key: const ValueKey('exam-name'),
                      controller: nameController,
                      maxLength: 120,
                      decoration: InputDecoration(
                        labelText: widget.tr('ex.name'),
                        border: const OutlineInputBorder(),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              FilledButton(
                key: const ValueKey('exam-start'),
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(52),
                ),
                onPressed: saving ? null : start,
                child: Text(widget.tr('ex.start')),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: saving ? null : widget.onExit,
                child: Text(widget.tr('ex.cancel')),
              ),
            ] else if (result == null) ...[
              panel(
                Row(
                  children: [
                    cell(
                      examCopy(widget.language, 'left'),
                      Semantics(
                        excludeSemantics: true,
                        label: examTime(run.remainingMs),
                        child: Text(
                          examTime(run.remainingMs),
                          style: const TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ),
                    cell(
                      widget.tr('ex.net'),
                      Text(
                        '${run.metrics.net}',
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    cell(
                      widget.tr('st.accuracy'),
                      Text(
                        '${run.metrics.accuracy}%',
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
                padding: const EdgeInsets.symmetric(vertical: 8),
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      '${widget.tr('ex.target.short')}: ${run.target}',
                      style: TextStyle(color: muted),
                    ),
                  ),
                  OutlinedButton(
                    key: const ValueKey('exam-finish'),
                    onPressed: () => finishAndSave(),
                    child: Text(widget.tr('ex.finish')),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              LinearProgressIndicator(
                value: (1 - run.remainingMs / (run.durationMinutes * 60000))
                    .clamp(0.0, 1.0),
              ),
              const SizedBox(height: 12),
              Text(run.exercise['title'] as String),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: PatternView(session: run.typing),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                key: const ValueKey('exam-input'),
                controller: entry,
                focusNode: inputFocus,
                minLines: 2,
                maxLines: 2,
                textInputAction: TextInputAction.newline,
                autocorrect: false,
                enableSuggestions: false,
                enableInteractiveSelection: false,
                smartDashesType: SmartDashesType.disabled,
                smartQuotesType: SmartQuotesType.disabled,
                inputFormatters: [PracticeCommitFormatter()],
                onEditingComplete: () {},
                decoration: InputDecoration(
                  labelText: examCopy(widget.language, 'input'),
                  border: const OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              KeyboardGuide(
                language: widget.language,
                model: widget.keyboard,
                expected: run.typing.expected,
                ru: widget.language == 'ru',
              ),
            ] else ...[
              Text(
                widget.tr('ex.result'),
                style: Theme.of(context).textTheme.titleLarge,
              ),
              Text(widget.tr(run.goalMet ? 'ex.pass' : 'ex.fail')),
              if (!run.fullDuration) Text(examCopy(widget.language, 'early')),
              Semantics(
                key: ValueKey('exam-result-$id'),
                container: true,
                excludeSemantics: true,
                label:
                    '${widget.tr('ex.net')}: ${result.net}, ${widget.tr('ex.gross')}: ${result.gross}, ${widget.tr('st.accuracy')}: ${result.accuracy}%, ${examCopy(widget.language, 'actual')}: ${examElapsedTime(result.elapsedMs)}, ${result.typed + result.errors} ${widget.tr('ex.keystrokes')}, ${widget.tr('ex.duration')}: ${run.durationMinutes} ${widget.tr('ex.min')}',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    panel(
                      Row(
                        children: [
                          cell(
                            widget.tr('ex.net'),
                            Text(
                              '${result.net}',
                              style: const TextStyle(
                                fontSize: 30,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                          cell(
                            widget.tr('ex.gross'),
                            Text(
                              '${result.gross}',
                              style: const TextStyle(
                                fontSize: 30,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                          cell(
                            widget.tr('st.accuracy'),
                            Text(
                              '${result.accuracy}%',
                              style: const TextStyle(
                                fontSize: 30,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ],
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                    const SizedBox(height: 8),
                    panel(
                      Column(
                        children: [
                          for (final (icon, label, value) in [
                            (
                              Icons.flag_outlined,
                              '${widget.tr('ex.target.short')} (${run.target})',
                              widget.tr(run.goalMet ? 'ex.pass' : 'ex.fail'),
                            ),
                            (
                              Icons.schedule,
                              examCopy(widget.language, 'actual'),
                              examElapsedTime(result.elapsedMs),
                            ),
                            (
                              Icons.keyboard_outlined,
                              widget.tr('ex.keystrokes'),
                              '${result.typed + result.errors}',
                            ),
                            (
                              Icons.timer_outlined,
                              widget.tr('ex.duration'),
                              '${run.durationMinutes} ${widget.tr('ex.min')}',
                            ),
                          ])
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 4),
                              child: Row(
                                children: [
                                  Icon(icon, size: 18, color: muted),
                                  const SizedBox(width: 8),
                                  Expanded(child: Text(label)),
                                  Flexible(
                                    child: Text(
                                      value,
                                      textAlign: TextAlign.end,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w600,
                                      ),
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
              if (saving) const LinearProgressIndicator(),
              if (saved) Text(examCopy(widget.language, 'saved')),
              const SizedBox(height: 12),
              Wrap(
                spacing: 12,
                runSpacing: 8,
                children: [
                  if (!saved)
                    FilledButton(
                      key: const ValueKey('exam-retry-save'),
                      onPressed: saving ? null : () => finishAndSave(),
                      child: Text(widget.tr('ex.finish')),
                    ),
                  if (saved)
                    FilledButton(
                      key: const ValueKey('exam-certificate'),
                      onPressed: exporting ? null : exportCertificate,
                      child: Text(widget.tr('ex.cert')),
                    ),
                  OutlinedButton(
                    key: const ValueKey('exam-again'),
                    onPressed: saving || exporting || !saved
                        ? null
                        : () => setState(() {
                            engine = null;
                            resetCheckpoint();
                          }),
                    child: Text(widget.tr('ex.again')),
                  ),
                  OutlinedButton(
                    onPressed: saving || exporting ? null : widget.onExit,
                    child: Text(widget.tr('ex.cancel')),
                  ),
                ],
              ),
              if (exporting) const LinearProgressIndicator(),
              if (exportStatus != null) Text(exportStatus!),
              const SizedBox(height: 12),
              Text(examCopy(widget.language, 'local')),
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
