import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';

import '../audio/typefree_sound.dart';
import '../data/local_repository.dart';
import '../design_system/templates.dart';
import '../data/key_statistics_store.dart';
import '../domain/learning.dart';
import '../domain/key_statistics.dart';
import 'keyboard_guide.dart';
import 'practice_widgets.dart';

class LearningPage extends StatefulWidget {
  const LearningPage({
    super.key,
    required this.repository,
    required this.keyStatistics,
    required this.corpus,
    required this.normalization,
    required this.language,
    required this.profile,
    required this.keyboard,
    required this.adaptation,
    required this.tr,
    required this.onExit,
    required this.onSaved,
    this.clock,
    this.hardKeys = false,
    this.onTyping,
  });
  final LocalRepository repository;
  final KeyStatisticsStore keyStatistics;
  final String corpus, language, profile;
  final Map<String, String> normalization;
  final KeyboardModel keyboard;
  final LearningAdaptation adaptation;
  final String Function(String) tr;
  final VoidCallback onExit;
  final Future<void> Function(Map<String, dynamic>, List<Map<String, dynamic>>)
  onSaved;
  final int Function()? clock;
  final bool hardKeys;
  final VoidCallback? onTyping;
  @override
  State<LearningPage> createState() => LearningPageState();
}

class LearningPageState extends State<LearningPage> {
  final entry = TextEditingController(), focus = FocusNode();
  late LearningSession engine;
  String previous = '', id = '';
  bool ignore = false,
      paused = false,
      saving = false,
      saved = false,
      levelSaveFailed = false,
      disposed = false;
  String? error;
  RecordedHistory? captured;
  int now() => widget.clock?.call() ?? DateTime.now().millisecondsSinceEpoch;
  @override
  void initState() {
    super.initState();
    startRun();
    entry.addListener(edit);
  }

  @override
  void didUpdateWidget(covariant LearningPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.language != widget.language ||
        oldWidget.profile != widget.profile) {
      startRun();
    }
    engine.hardKeys = widget.hardKeys;
  }

  void startRun() {
    id =
        'learn-${DateTime.now().microsecondsSinceEpoch}-${Random().nextInt(0x7fffffff)}';
    engine = LearningSession(
      corpus: widget.corpus,
      language: widget.language,
      profile: widget.profile,
      keyboard: widget.keyboard.snapshot,
      normalization: widget.normalization,
      clock: now,
      statistics: () => widget.keyStatistics.currentStats,
      adaptation: widget.adaptation,
      hardKeys: widget.hardKeys,
      record: (ch, ok, at) {
        final key = widget.keyboard.hit(ch, ru: widget.language == 'ru')?['id'];
        if (key is String) widget.keyStatistics.record(key, ok, at);
      },
    );
    paused = false;
    saved = false;
    saving = false;
    captured = null;
    error = null;
    clearInput();
  }

  void clearInput() {
    ignore = true;
    previous = '';
    entry.clear();
    ignore = false;
  }

  void edit() {
    if (ignore ||
        paused ||
        saving ||
        entry.value.composing.isValid && !entry.value.composing.isCollapsed) {
      return;
    }
    widget.onTyping?.call();
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
    for (var i = previous.length; i < text.length; i++) {
      final level = engine.kidsLevel, difficulty = engine.adultDifficulty;
      final ch = widget.keyboard.bridge(text[i], engine.typing.expected ?? '');
      final next = engine.press(ch);
      if (engine.kidsLevel > level || engine.adultDifficulty > difficulty) {
        appSound.effect('upgrade');
      }
      if (engine.kidsLevel != level) unawaited(persistLevel());
      if (next) {
        clearInput();
        setState(() {});
        return;
      }
    }
    previous = text;
    setState(() {});
  }

  Future<void> persistLevel() async {
    final level = engine.kidsLevel;
    try {
      await widget.keyStatistics.commit((doc) {
        (doc['legacy'] as Map)['tr_kids_ai_lvl'] = '$level';
      });
      if (mounted && !disposed) setState(() => levelSaveFailed = false);
    } catch (_) {
      if (mounted && !disposed) setState(() => levelSaveFailed = true);
    }
  }

  Future<bool> finishAndSave() async {
    if (saved) return true;
    if (saving) return false;
    if (mounted && !disposed) {
      setState(() {
        paused = true;
        saving = true;
        error = null;
      });
    }
    final metrics = engine.metrics,
        wpm = (engine.metrics['mastery']! / 5).round();
    // The original calls pushHistory only after mastery becomes positive.
    if (metrics['mastery']! > 0) {
      captured ??= widget.keyStatistics.recorder.take(now());
    }
    final record = captured;
    final point = <String, dynamic>{
      'id': id,
      'exercise': 'learning',
      'title': widget.tr('learn.title'),
      'language': widget.language,
      'profile': widget.profile,
      'mode': 'learn',
      'difficulty':
          '${widget.language}/learn/${engine.hand}/${engine.adultDifficulty}/${engine.kidsLevel}',
      't': now(),
      'wpm': wpm,
      'accuracy': metrics['accuracy'],
      'errors': engine.errors,
      'elapsedMs': engine.ms,
      'typed': engine.correct,
      'len': record?.len ?? 0,
      'errKeys': record?.errorKeys ?? <String, int>{},
      'mastery': metrics['mastery'],
      'tempo': metrics['tempo'],
      'rhythm': metrics['rhythm'],
      'lines': engine.lines,
      'kidsScore': engine.kidsScore,
    };
    final before = List<Map<String, dynamic>>.from(
      widget.repository.data['sessions'] as List,
    );
    var fresh = false;
    try {
      await widget.keyStatistics.commit((doc) {
        final rows = doc['sessions'] as List, legacy = doc['legacy'] as Map;
        if (rows.any((r) => r['id'] == id)) return;
        if (widget.profile == 'kids') {
          legacy['tr_kids_ai_lvl'] = '${engine.kidsLevel}';
        }
        if (record != null && record.eligible(wpm)) {
          rows.add(point);
          fresh = true;
          final history = legacy['tr_history'] is String
              ? List<dynamic>.from(
                  jsonDecode(legacy['tr_history'] as String) as List,
                )
              : <dynamic>[];
          history.add(
            record.point(wpm, metrics['accuracy']!, point['t'] as int),
          );
          legacy['tr_history'] = jsonEncode(
            history.length > 300
                ? history.sublist(history.length - 300)
                : history,
          );
        }
      });
      saved = true;
      levelSaveFailed = false;
      if (fresh) {
        try {
          await widget.onSaved(point, before);
        } catch (_) {
          /* Optional companion never invalidates the saved result. */
        }
      }
      return true;
    } catch (_) {
      error = learningCopy(widget.language, 'saveError');
      return false;
    } finally {
      saving = false;
      if (mounted && !disposed) setState(() {});
    }
  }

  @override
  void dispose() {
    disposed = true;
    if (!saved && !saving) unawaited(finishAndSave());
    entry.removeListener(edit);
    entry.dispose();
    focus.dispose();
    super.dispose();
  }

  /// Source learn.ts masteryLevel: start <70 ≤ good <200 ≤ working <300 ≤ pro.
  String masteryLabel(int v) => widget.tr(
    v >= 300
        ? 'learn.lvl.pro'
        : v >= 200
        ? 'learn.lvl.work'
        : v >= 70
        ? 'learn.lvl.good'
        : 'learn.lvl.start',
  );

  @override
  Widget build(BuildContext context) {
    final m = engine.metrics, kids = widget.profile == 'kids';
    final scheme = Theme.of(context).colorScheme;
    final tokens = Theme.of(context).extension<TypeFreeTokens>()!;
    final muted = scheme.onSurfaceVariant;
    Widget panel(Widget child, {EdgeInsets? padding}) => Container(
      padding: padding ?? const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: tokens['raisedSurface'],
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: tokens['border']),
      ),
      child: child,
    );
    // D1 header: what this mode does.
    final header = panel(
      Row(
        children: [
          Icon(
            Icons.psychology_alt_outlined,
            size: 34,
            color: tokens['success'],
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              widget.tr(kids ? 'learn.intro.kids' : 'learn.intro'),
              style: TextStyle(fontSize: 13, color: muted),
            ),
          ),
        ],
      ),
    );
    final hands = SegmentedButton<String>(
      showSelectedIcon: false,
      segments: [
        for (final hand in ['left', 'both', 'right'])
          ButtonSegment(
            value: hand,
            label: Text(widget.tr('learn.hand.$hand')),
          ),
      ],
      selected: {engine.hand},
      onSelectionChanged: paused || saving
          ? null
          : (sel) {
              setState(() {
                engine.changeHand(sel.first);
                clearInput();
              });
              focus.requestFocus();
            },
    );
    Widget kpi(IconData icon, String value, String label, Color color) =>
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
            child: Column(
              children: [
                Icon(icon, size: 20, color: color),
                Text(
                  value,
                  maxLines: 1,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  label,
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 11.5, color: muted),
                ),
              ],
            ),
          ),
        );
    final kpis = kids
        ? panel(
            Row(
              children: [
                Image.asset(
                  'assets/learning/kids-cat-${engine.mood}.webp',
                  width: 72,
                  height: 72,
                  semanticLabel: learningCopy(widget.language, 'cat'),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '★ ${engine.kidsScore}',
                        style: Theme.of(context).textTheme.headlineMedium,
                      ),
                      Text(
                        '${m['accuracy']}% · ${widget.tr('st.accuracy')} · ${widget.tr('span.level')} ${engine.kidsLevel + 1}',
                        style: TextStyle(color: muted),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          )
        : panel(
            Row(
              children: [
                kpi(
                  Icons.speed,
                  '${m['tempo']}',
                  widget.tr('learn.tempo'),
                  scheme.primary,
                ),
                kpi(
                  Icons.graphic_eq,
                  '${m['rhythm']}%',
                  widget.tr('learn.rhythm'),
                  tokens['success'],
                ),
                kpi(
                  Icons.track_changes,
                  '${m['accuracy']}%',
                  widget.tr('st.accuracy'),
                  tokens['success'],
                ),
                kpi(
                  Icons.bar_chart,
                  '${m['mastery']}',
                  '${widget.tr('learn.mastery')} · ${masteryLabel(m['mastery']!)}',
                  scheme.primary,
                ),
              ],
            ),
            padding: const EdgeInsets.symmetric(vertical: 4),
          );
    final typing = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: PatternView(session: engine.typing),
          ),
        ),
        const SizedBox(height: 8),
        if (!paused)
          TextField(
            key: const ValueKey('learning-input'),
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
              if (!paused && !saving) {
                engine.press('\n');
                setState(() {});
              }
            },
            decoration: InputDecoration(
              border: const OutlineInputBorder(),
              labelText: learningCopy(widget.language, 'input'),
            ),
          ),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: KeyboardGuide(
              language: widget.language,
              model: widget.keyboard,
              expected: paused ? null : engine.typing.expected,
              ru: widget.language == 'ru',
            ),
          ),
        ),
      ],
    );
    final status = <Widget>[
      if (levelSaveFailed)
        Text(
          learningCopy(widget.language, 'levelError'),
          style: TextStyle(color: scheme.error),
        ),
      if (error != null) Text(error!, style: TextStyle(color: scheme.error)),
    ];
    final actions = Wrap(
      spacing: 12,
      runSpacing: 8,
      children: [
        FilledButton(
          onPressed: saving
              ? null
              : () async {
                  if (await finishAndSave()) widget.onExit();
                },
          child: Text(
            saving
                ? learningCopy(widget.language, 'saving')
                : widget.tr('ex.finish'),
          ),
        ),
        if (paused && saved)
          OutlinedButton(
            onPressed: () {
              setState(startRun);
              focus.requestFocus();
            },
            child: Text(widget.tr('done.again')),
          ),
      ],
    );
    // Right panel (D1): the current focus and the honest session facts —
    // the source keeps no per-hand progress, so none is drawn.
    final side = panel(
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            learningCopy(widget.language, 'focus'),
            style: TextStyle(fontSize: 12, color: muted),
          ),
          Text(
            kids
                ? '${widget.tr('span.level')} ${engine.kidsLevel + 1}'
                : widget.tr('learn.hand.${engine.hand}'),
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 10),
          Text(
            '${engine.lines} ${widget.tr('learn.lines')}',
            style: TextStyle(color: muted),
          ),
          if (!kids) ...[
            const SizedBox(height: 10),
            Text(
              widget.tr('learn.tip'),
              style: TextStyle(fontSize: 12, color: muted),
            ),
          ],
          const SizedBox(height: 12),
          ...status,
          actions,
        ],
      ),
    );
    return LayoutBuilder(
      builder: (context, box) {
        final wide = box.maxWidth >= 1000;
        final main = Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            header,
            const SizedBox(height: 10),
            if (!kids) ...[hands, const SizedBox(height: 10)],
            kpis,
            const SizedBox(height: 10),
            typing,
            if (!wide) ...[
              const SizedBox(height: 12),
              if (!kids)
                Text(
                  widget.tr('learn.tip'),
                  style: TextStyle(fontSize: 12, color: muted),
                ),
              ...status,
              const SizedBox(height: 12),
              actions,
            ],
          ],
        );
        if (!wide) return main;
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: main),
            const SizedBox(width: 16),
            SizedBox(width: 260, child: side),
          ],
        );
      },
    );
  }
}

String learningCopy(String language, String key) {
  const languages = ['ru', 'en', 'es', 'de', 'fr', 'it', 'pt'];
  const values = {
    'input': [
      'Печатайте здесь',
      'Type here',
      'Escribe aquí',
      'Hier tippen',
      'Tapez ici',
      'Digita qui',
      'Digite aqui',
    ],
    'saving': [
      'Сохранение…',
      'Saving…',
      'Guardando…',
      'Speichern…',
      'Enregistrement…',
      'Salvataggio…',
      'Salvando…',
    ],
    'saveError': [
      'Не удалось сохранить результат. Повторите; прежние данные сохранены.',
      'Could not save. Retry; previous data is preserved.',
      'No se pudo guardar. Reintenta; los datos anteriores se conservan.',
      'Speichern fehlgeschlagen. Erneut versuchen; bisherige Daten bleiben erhalten.',
      'Échec de sauvegarde. Réessayez ; les données précédentes sont conservées.',
      'Salvataggio non riuscito. Riprova; i dati precedenti sono conservati.',
      'Falha ao salvar. Tente novamente; os dados anteriores foram preservados.',
    ],
    'levelError': [
      'Уровень пока не записан. Завершите занятие для повторной записи.',
      'Level not saved yet. Finish the session to retry.',
      'Nivel aún no guardado. Termina la sesión para reintentar.',
      'Stufe noch nicht gespeichert. Beende die Sitzung für einen neuen Versuch.',
      'Niveau non enregistré. Terminez la séance pour réessayer.',
      'Livello non salvato. Termina la sessione per riprovare.',
      'Nível ainda não salvo. Termine a sessão para tentar novamente.',
    ],
    'focus': [
      'Текущий фокус',
      'Current focus',
      'Enfoque actual',
      'Aktueller Fokus',
      'Focus actuel',
      'Focus attuale',
      'Foco atual',
    ],
    'cat': [
      'Котик: настроение по точности и очкам',
      'Cat: mood based on accuracy and points',
      'Gato: ánimo según precisión y puntos',
      'Katze: Stimmung nach Genauigkeit und Punkten',
      'Chat : humeur selon la précision et les points',
      'Gatto: umore secondo precisione e punti',
      'Gato: humor conforme precisão e pontos',
    ],
  };
  final i = languages.indexOf(language);
  return values[key]?[i < 0 ? 1 : i] ?? key;
}
