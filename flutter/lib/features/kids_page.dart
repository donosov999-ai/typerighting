import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../audio/typefree_sound.dart';
import '../data/local_repository.dart';
import '../design_system/templates.dart';
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
      final scheme = Theme.of(context).colorScheme;
      final tokens = Theme.of(context).extension<TypeFreeTokens>()!;
      final stars = widget.levels.fold<int>(
        0,
        (n, l) => n + (engine.progress.stars[l.id] ?? 0),
      );
      final current = widget.levels.firstWhere(
        (l) =>
            engine.progress.unlocked(l.id) &&
            (engine.progress.stars[l.id] ?? 0) == 0,
        orElse: () => widget.levels.last,
      );
      // D2: one level as a round node with its stars (or a lock).
      Widget node(KidsLevel level, double size) {
        final open = engine.progress.unlocked(level.id);
        final got = engine.progress.stars[level.id] ?? 0;
        final now = level.id == current.id;
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            OutlinedButton(
              key: ValueKey('kids-level-${level.id}'),
              onPressed: open ? () => start(level.id) : null,
              style: OutlinedButton.styleFrom(
                shape: const CircleBorder(),
                fixedSize: Size.square(size),
                minimumSize: Size.square(size),
                padding: EdgeInsets.zero,
                backgroundColor: now
                    ? tokens['success']
                    : open
                    ? tokens['raisedSurface']
                    : tokens['canvas'],
                side: BorderSide(
                  color: now
                      ? scheme.primary
                      : open
                      ? const Color(0xFFF5B82E)
                      : tokens['border'],
                  width: now ? 3 : 2,
                ),
              ),
              child: Text(
                '${level.id}',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: open ? scheme.onSurface : scheme.onSurfaceVariant,
                ),
              ),
            ),
            const SizedBox(height: 2),
            open
                ? Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      for (var i = 1; i <= 3; i++)
                        Icon(
                          i <= got ? Icons.star : Icons.star_border,
                          size: 13,
                          color: const Color(0xFFF5B82E),
                        ),
                    ],
                  )
                : Icon(Icons.lock, size: 14, color: scheme.onSurfaceVariant),
          ],
        );
      }

      BoxDecoration box() => BoxDecoration(
        color: tokens['raisedSurface'],
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: tokens['border']),
      );
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Cat with the greeting, and the honest star count.
          Wrap(
            spacing: 12,
            runSpacing: 12,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Image.asset(
                'assets/learning/typing-cat.webp',
                height: 96,
                excludeFromSemantics: true,
              ),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 320),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: box(),
                  child: Text(tr('k.hello')),
                ),
              ),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: box(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.star, color: Color(0xFFF5B82E)),
                        const SizedBox(width: 4),
                        Text(
                          '$stars / ${widget.levels.length * 3}',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                    Text('${tr('k.level')} ${current.id}'),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (engine.restSuggested) Text(tr('k.rest')),
          for (final language in ['ru', 'en']) ...[
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Text(
                tr('k.block.$language'),
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
            LayoutBuilder(
              builder: (context, box) {
                final levels = widget.levels
                    .where((l) => l.language == language)
                    .toList();
                final per = box.maxWidth >= 600 ? 6 : 5;
                final size = box.maxWidth >= 600 ? 60.0 : 48.0;
                final rows = <List<KidsLevel>>[
                  for (var i = 0; i < levels.length; i += per)
                    levels.sublist(i, min(i + per, levels.length)),
                ];
                // A winding path: every other row runs right-to-left.
                return Column(
                  children: [
                    for (final (r, row) in rows.indexed)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Stack(
                          children: [
                            Positioned(
                              left: 24,
                              right: 24,
                              top: size / 2 - 2,
                              child: Container(
                                height: 4,
                                decoration: BoxDecoration(
                                  color: tokens['border'],
                                  borderRadius: BorderRadius.circular(2),
                                ),
                              ),
                            ),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceAround,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Short reversed rows keep the gap on the
                                // left so the path stays continuous.
                                if (r.isOdd)
                                  for (var k = row.length; k < per; k++)
                                    SizedBox(width: size),
                                for (final l in r.isOdd ? row.reversed : row)
                                  node(l, size),
                                if (r.isEven)
                                  for (var k = row.length; k < per; k++)
                                    SizedBox(width: size),
                              ],
                            ),
                          ],
                        ),
                      ),
                  ],
                );
              },
            ),
          ],
          const SizedBox(height: 8),
          FilledButton.icon(
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(48),
            ),
            onPressed: widget.onAI,
            icon: const Icon(Icons.auto_awesome),
            label: Text(tr('learn.title')),
          ),
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
            // J3: happy cat, the level, big stars and the note.
            Wrap(
              alignment: WrapAlignment.center,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 16,
              runSpacing: 8,
              children: [
                Image.asset(
                  'assets/learning/typing-cat.webp',
                  height: 140,
                  excludeFromSemantics: true,
                ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '${tr('k.level')} ${result.levelId} ${tr('k.passed')}',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Semantics(
                      label: '${result.stars} / 3 ★',
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          for (var i = 1; i <= 3; i++)
                            Icon(
                              i <= result.stars
                                  ? Icons.star_rounded
                                  : Icons.star_outline_rounded,
                              size: 56,
                              color: const Color(0xFFF5B82E),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              tr('k.note${result.stars}'),
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 12),
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
            if (engine.hasNext)
              FilledButton(
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(52),
                ),
                onPressed: saved && !saving ? next : null,
                child: Text(tr('k.next')),
              ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: saved && !saving
                        ? () => start(result.levelId)
                        : null,
                    child: Text(tr('k.again')),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton(
                    onPressed: saved && !saving ? toMap : null,
                    child: Text(tr('k.map')),
                  ),
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
          language: widget.language,
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
