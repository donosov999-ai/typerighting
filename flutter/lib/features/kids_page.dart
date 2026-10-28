import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../audio/typefree_sound.dart';
import '../data/local_repository.dart';
import '../domain/kids.dart';
import 'competition_page.dart' show competitionCopy;
import 'keyboard_guide.dart';
import 'practice_widgets.dart';

class KidsPage extends StatefulWidget {
  const KidsPage({
    super.key,
    required this.repository,
    required this.levels,
    required this.activity,
    required this.keyboard,
    required this.tr,
    required this.language,
    required this.onAI,
    this.onTyping,
  });
  final LocalRepository repository;
  final List<KidsLevel> levels;
  final KidsActivity activity;
  final KeyboardModel keyboard;
  final String Function(String) tr;
  final String language;
  final VoidCallback onAI;
  final VoidCallback? onTyping;
  @override
  State<KidsPage> createState() => KidsPageState();
}

class KidsPageState extends State<KidsPage> with WidgetsBindingObserver {
  late KidsSession engine;
  final entry = TextEditingController(),
      inputFocus = FocusNode(),
      resultFocus = FocusNode(),
      autoFocus = FocusNode();
  Timer? nextTimer;
  bool saving = false,
      saved = false,
      foreground = true,
      autoNext = true,
      exiting = false,
      ignore = false;
  String previous = '', say = '';
  String? error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    final raw = (widget.repository.data['legacy'] as Map)['tr_kids'];
    final stars = raw is String
        ? (jsonDecode(raw) as Map)['stars'] as Map
        : <String, dynamic>{};
    final known = <int, int>{};
    for (final e in stars.entries) {
      final id = int.tryParse('${e.key}');
      if (id != null && id > 0 && e.value is int) known[id] = e.value as int;
    }
    engine = KidsSession(
      levels: widget.levels,
      progress: KidsProgress(known),
      activity: widget.activity,
      bridge: (input, expected) => widget.keyboard.bridge(input, expected),
    );
    entry.addListener(edit);
  }

  @override
  void dispose() {
    nextTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    entry.dispose();
    inputFocus.dispose();
    resultFocus.dispose();
    autoFocus.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    foreground = state == AppLifecycleState.resumed;
    nextTimer?.cancel();
    if (foreground) {
      scheduleNext();
    }
  }

  void requestInput() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted &&
          foreground &&
          !exiting &&
          engine.phase == KidsPhase.level) {
        inputFocus.requestFocus();
      }
    });
  }

  void resetInput() {
    ignore = true;
    entry.clear();
    previous = '';
    ignore = false;
  }

  void start(int id) {
    if (saving || !engine.start(id)) return;
    nextTimer?.cancel();
    resetInput();
    setState(() {
      saved = false;
      error = null;
      exiting = false;
      say = widget.tr(
        engine.level!.language == 'ru' ? 'k.startRu' : 'k.startEn',
      );
    });
    requestInput();
  }

  void edit() {
    if (ignore ||
        saving ||
        engine.phase != KidsPhase.level ||
        entry.value.composing.isValid && !entry.value.composing.isCollapsed) {
      return;
    }
    final text = entry.text;
    if (text == previous) return;
    // Backspace and replacement cannot erase a child's earlier error or position.
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
      final word = engine.wordIndex;
      final outcome = engine.press(text[i]);
      if (outcome.wrong) {
        say = widget.tr('k.note1');
        appSound.effect('catSad');
      } else {
        // Source kids.ts: speak(ch) after a correct letter (RU/EN samples).
        appSound.speak(text[i], widget.language);
        if (engine.wordIndex != word) {
          say = widget.tr('k.noerr');
          if (engine.phase != KidsPhase.done) appSound.effect('catHappy');
        }
      }
      if (engine.phase == KidsPhase.done) {
        // Source finishLevel: fanfare, then one chime per earned star.
        appSound.effect('fanfare');
        for (var s = 0; s < (engine.result?.stars ?? 0); s++) {
          appSound.effect('star');
        }
        unawaited(save());
        break;
      }
    }
    previous = text;
    setState(() {});
  }

  Future<bool> save({bool schedule = true}) async {
    if (saving) return false;
    final result = engine.result;
    if (result == null || saved) return true;
    nextTimer?.cancel();
    setState(() {
      saving = true;
      error = null;
    });
    try {
      // Merge into the latest document, preserving unrecognised/future IDs and
      // higher imported stars. A retry is idempotent and cannot lower a best.
      await widget.repository.transaction((doc) {
        final legacy = doc['legacy'] as Map;
        final raw = legacy['tr_kids'];
        final current = raw is String
            ? Map<String, dynamic>.from(jsonDecode(raw) as Map)
            : <String, dynamic>{};
        final stars = Map<String, dynamic>.from(current['stars'] as Map? ?? {});
        final key = '${result.levelId}';
        stars[key] = max(stars[key] as int? ?? 0, result.stars);
        current['stars'] = stars;
        legacy['tr_kids'] = jsonEncode(current);
      });
      final stored = jsonDecode(
        (widget.repository.data['legacy'] as Map)['tr_kids'] as String,
      ) as Map;
      for (final e in (stored['stars'] as Map).entries) {
        final id = int.tryParse('${e.key}');
        if (id != null && id > 0 && e.value is int && (e.value as int) > 0) {
          engine.progress.record(id, e.value as int);
        }
      }
      saved = true;
      return true;
    } catch (_) {
      error = competitionCopy(widget.language, 'saveError');
      return false;
    } finally {
      saving = false;
      if (mounted) {
        setState(() {});
        if (saved && schedule) {
          scheduleNext();
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted && !exiting && foreground) resultFocus.requestFocus();
          });
        }
      }
    }
  }

  Future<bool> checkpointForExit() async {
    nextTimer?.cancel();
    exiting = true;
    final ok = await save(schedule: false);
    if (!ok) {
      exiting = false;
      scheduleNext();
    }
    return ok;
  }

  void scheduleNext() {
    nextTimer?.cancel();
    if (mounted &&
        foreground &&
        !exiting &&
        saved &&
        !saving &&
        autoNext &&
        engine.phase == KidsPhase.done &&
        engine.hasNext) {
      nextTimer = Timer(const Duration(milliseconds: 3500), next);
    }
  }

  void next() {
    if (!saved || saving || engine.phase != KidsPhase.done) return;
    nextTimer?.cancel();
    if (engine.hasNext) {
      start(engine.level!.id + 1);
    } else {
      toMap();
    }
  }

  void toMap() {
    if (saving || engine.result != null && !saved) return;
    nextTimer?.cancel();
    setState(() => engine.toMap());
  }

  Widget cat() => Image.asset(
    'assets/learning/typing-cat.webp',
    height: 100,
    excludeFromSemantics: true,
  );
  @override
  Widget build(BuildContext context) {
    final tr = widget.tr;
    if (engine.phase == KidsPhase.map) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(tr('k.hello')),
          const SizedBox(height: 12),
          if (engine.restSuggested) Text(tr('k.rest')),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: widget.onAI,
              icon: const Icon(Icons.auto_awesome),
              label: Text(tr('learn.title')),
            ),
          ),
          for (final language in ['ru', 'en']) ...[
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Text(
                tr('k.block.$language'),
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                for (final level in widget.levels.where(
                  (l) => l.language == language,
                ))
                  OutlinedButton(
                    key: ValueKey('kids-level-${level.id}'),
                    onPressed: engine.progress.unlocked(level.id)
                        ? () => start(level.id)
                        : null,
                    child: Padding(
                      padding: const EdgeInsets.all(8),
                      child: Text(
                        '${tr('k.level')} ${level.id}\n${engine.progress.unlocked(level.id) ? '⭐' * (engine.progress.stars[level.id] ?? 0) : '🔒'}',
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ],
      );
    }
    if (engine.phase == KidsPhase.done) {
      final result = engine.result!;
      return Focus(
        focusNode: resultFocus,
        onKeyEvent: (_, event) {
          if (!resultFocus.hasPrimaryFocus ||
              event is! KeyDownEvent ||
              !saved ||
              saving) {
            return KeyEventResult.ignored;
          }
          if (event.logicalKey == LogicalKeyboardKey.enter ||
              event.logicalKey == LogicalKeyboardKey.space) {
            next();
            return KeyEventResult.handled;
          }
          return KeyEventResult.ignored;
        },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            cat(),
            Text(
              '${tr('k.level')} ${result.levelId} ${tr('k.passed')}',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            Text(
              '⭐' * result.stars + '☆' * (3 - result.stars),
              style: const TextStyle(fontSize: 36),
            ),
            Text(tr('k.note${result.stars}')),
            if (engine.restSuggested)
              Padding(
                padding: const EdgeInsets.all(12),
                child: Text(tr('k.rest')),
              ),
            if (saving) const LinearProgressIndicator(),
            if (saved) Text(competitionCopy(widget.language, 'saved')),
            if (error != null) ...[
              Text(
                error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
              TextButton(
                onPressed: saving ? null : () => save(),
                child: Text(kidsRetry(widget.language)),
              ),
            ],
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                OutlinedButton(
                  onPressed: saved && !saving
                      ? () => start(result.levelId)
                      : null,
                  child: Text(tr('k.again')),
                ),
                OutlinedButton(
                  onPressed: saved && !saving ? toMap : null,
                  child: Text(tr('k.map')),
                ),
                if (engine.hasNext)
                  FilledButton(
                    onPressed: saved && !saving ? next : null,
                    child: Text(tr('k.next')),
                  ),
              ],
            ),
            if (engine.hasNext)
              CheckboxListTile(
                focusNode: autoFocus,
                value: autoNext,
                onChanged: saving
                    ? null
                    : (v) {
                        setState(() => autoNext = v!);
                        scheduleNext();
                      },
                title: Text(tr('k.autonext')),
              ),
          ],
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton(onPressed: toMap, child: Text(tr('k.back'))),
        ),
        Text(
          '${tr('k.level')} ${engine.level!.id} · ${tr('k.word')} ${engine.wordIndex + 1} / 5',
        ),
        Text(
          engine.errors == 0
              ? tr('k.noerr')
              : '${tr('k.errors')}: ${engine.errors}',
        ),
        cat(),
        Text(say),
        PatternView(session: engine.typing!),
        const SizedBox(height: 12),
        TextField(
          key: const ValueKey('kids-input'),
          controller: entry,
          focusNode: inputFocus,
          autocorrect: false,
          enableSuggestions: false,
          enableInteractiveSelection: false,
          minLines: 2,
          maxLines: 2,
          textInputAction: TextInputAction.newline,
          smartDashesType: SmartDashesType.disabled,
          smartQuotesType: SmartQuotesType.disabled,
          inputFormatters: [PracticeCommitFormatter()],
          onEditingComplete: () {},
          decoration: InputDecoration(
            border: const OutlineInputBorder(),
            labelText: tr('k.word'),
          ),
        ),
        const SizedBox(height: 12),
        KeyboardGuide(
          model: widget.keyboard,
          expected: engine.expected,
          ru: engine.level!.language == 'ru',
        ),
      ],
    );
  }
}

String kidsRetry(String language) =>
    const {
      'ru': 'Повторить сохранение',
      'en': 'Retry saving',
      'es': 'Reintentar guardado',
      'de': 'Speichern wiederholen',
      'fr': 'Réessayer l’enregistrement',
      'it': 'Riprova salvataggio',
      'pt': 'Tentar salvar novamente',
    }[language] ??
    'Retry saving';
