import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:synapse_pet/synapse_pet.dart';

import 'data/platform_store.dart';
import 'data/local_repository.dart';
import 'design_system/templates.dart';
import 'design_system/synapse_header.dart';
import 'domain/typing.dart';
import 'features/keyboard_guide.dart';

const languages = ['ru', 'en', 'es', 'de', 'fr', 'it', 'pt'];

// Product vocabulary uses the shared advisor's public phrase injection API.
// Selection rules, facts, suppression and animations remain owned by Synapse.
Advisor typingAdvisor(String locale) {
  final phrases = {
    for (final e in defaultPhrases.entries)
      e.key: Map<String, List<String>>.from(e.value),
  };
  phrases['better']!['ru'] = [
    '{score} — лучше прошлой тренировки ({prev}).',
    'Было {prev}, стало {score}.',
  ];
  phrases['clean']!['ru'] = [
    'Ни одной ошибки в этой тренировке.',
    'Чисто: ноль ошибок.',
  ];
  return Advisor(locale: locale, phrases: phrases);
}

class PreferenceStore implements AppearanceStore {
  final prefs = SharedPreferencesAsync();
  @override
  Future<void> save(Map<String, Object> value) =>
      prefs.setString(appearanceKey, jsonEncode(value));
}

class Resources {
  Resources(this.content, this.keyboards, this.registry);
  final Map<String, dynamic> content, keyboards;
  final TemplateRegistry registry;
  static Future<Resources> load() async => Resources(
    jsonDecode(await rootBundle.loadString('assets/baseline/catalog.json'))
        as Map<String, dynamic>,
    jsonDecode(await rootBundle.loadString('assets/baseline/keyboard.json'))
        as Map<String, dynamic>,
    TemplateRegistry.parse(
      jsonDecode(await rootBundle.loadString('assets/templates/registry.json'))
          as Map<String, dynamic>,
    ),
  );
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    final resources = await Resources.load();
    final repo = LocalRepository(await openPlatformStore());
    await repo.load();
    Map<String, dynamic>? saved;
    final raw = await SharedPreferencesAsync().getString(appearanceKey);
    try {
      if (raw != null) saved = jsonDecode(raw) as Map<String, dynamic>;
    } catch (_) {}
    runApp(
      TypeFreeApp(
        resources: resources,
        repository: repo,
        appearance: AppearanceController(
          resources.registry,
          PreferenceStore(),
          existingInstall: false,
          saved: saved,
        ),
      ),
    );
  } catch (_) {
    runApp(
      const MaterialApp(
        home: Scaffold(
          body: Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Text(
                'Не удалось прочитать локальные данные. Исходная копия сохранена. Не очищайте хранилище.',
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class TypeFreeApp extends StatefulWidget {
  const TypeFreeApp({
    super.key,
    required this.resources,
    required this.repository,
    required this.appearance,
    this.clock,
  });
  final Resources resources;
  final LocalRepository repository;
  final AppearanceController appearance;
  final MillisecondClock? clock;
  @override
  State<TypeFreeApp> createState() => TypeFreeAppState();
}

class TypeFreeAppState extends State<TypeFreeApp> with WidgetsBindingObserver {
  late String language, profile, bank, layout;
  late TypingSession session;
  late KeyboardModel keyboard;
  late SynapseController assistant, headerAssistant;
  late BuildContext surface;
  final entry = TextEditingController(), inputFocus = FocusNode();
  Timer? timer;
  String previousInput = '', sessionId = '', textBank = 'ruWords';
  bool plain = false,
      block = true,
      bridge = true,
      flow = false,
      showKeyboard = true;
  bool pet = true,
      motion = true,
      saved = false,
      saving = false,
      historyPage = false,
      ignoreInput = false;
  int index = 0;
  String? custom, error;
  List<Map<String, dynamic>> get exercises => custom != null
      ? [
          {
            'id': 'custom',
            'bank': 'custom',
            'title': tr('custom.title'),
            'lines': custom!.split('\n'),
          },
        ]
      : List<Map<String, dynamic>>.from(
          (widget.resources.content['catalog'] as Map)[language] as List,
        ).where((e) => e['bank'] == bank).toList();
  Map<String, dynamic> get exercise =>
      exercises[index.clamp(0, exercises.length - 1)];
  List<Map<String, dynamic>> get history => List<Map<String, dynamic>>.from(
    widget.repository.data['sessions'] as List,
  );
  String tr(String key) {
    final v = (widget.resources.content['dict'] as Map)[key];
    return v is Map ? (v[language] ?? v['en'] ?? key).toString() : key;
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    final p = widget.repository.data['prefs'] as Map;
    language = languages.contains(p['lang']) ? p['lang'] as String : 'ru';
    profile = ['m', 'f', 'kids'].contains(p['profile'])
        ? p['profile'] as String
        : 'm';
    bank = (p['bank'] as String?) ?? (language == 'ru' ? 'ruWords' : 'classic');
    layout = ['auto', 'qwerty', 'azerty', 'qwertz'].contains(p['layout'])
        ? p['layout'] as String
        : 'auto';
    textBank = (p['textBank'] as String?) ?? bank;
    index = (p['index'] as num?)?.toInt() ?? 0;
    plain = p['plain'] == true;
    flow = p['flow'] == true;
    block = p['block'] != false;
    bridge = p['bridge'] != false;
    pet = p['pet'] != false;
    motion = p['motion'] != false;
    showKeyboard = p['keyboard'] != false;
    createAssistant();
    loadKeyboard();
    reset();
    entry.addListener(edit);
    timer = Timer.periodic(const Duration(milliseconds: 250), (_) {
      if (mounted && session.startedAt != null && !session.finished) {
        setState(() {});
      }
    });
  }

  void createAssistant() {
    final raw =
        (widget.repository.data['prefs'] as Map)['synapseMemory_$profile'];
    AdvisorMemory? memory;
    try {
      if (raw is String) {
        memory = AdvisorMemory.fromJson(raw);
      }
    } catch (_) {}
    assistant = SynapseController(
      advisor: typingAdvisor(language),
      memory: memory,
      enabled: pet,
    );
    headerAssistant = SynapseController(
      advisor: typingAdvisor(language),
      enabled: pet,
    );
  }

  @override
  void dispose() {
    timer?.cancel();
    entry.removeListener(edit);
    entry.dispose();
    inputFocus.dispose();
    assistant.dispose();
    headerAssistant.dispose();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      headerAssistant.wake();
    } else {
      headerAssistant.sleep();
    }
  }

  void loadKeyboard() {
    final os =
        defaultTargetPlatform == TargetPlatform.macOS ||
            defaultTargetPlatform == TargetPlatform.iOS
        ? 'mac'
        : 'windows';
    final l = layout == 'auto'
        ? (language == 'fr'
              ? 'azerty'
              : language == 'de'
              ? 'qwertz'
              : 'qwerty')
        : layout;
    keyboard = KeyboardModel(
      Map<String, dynamic>.from(
        (widget.resources.keyboards[os] as Map)[l] as Map,
      ),
    );
  }

  void reset() {
    if (exercises.isEmpty) {
      bank = language == 'ru' ? 'ruWords' : 'classic';
      custom = null;
      index = 0;
    }
    index = index.clamp(0, exercises.length - 1);
    var lines = List<String>.from(exercise['lines'] as List);
    if (plain) lines = plainPractice(lines);
    if (lines.isEmpty) lines = [' '];
    session = TypingSession(
      flow ? [lines.join(' ')] : lines,
      clock: widget.clock,
    );
    sessionId =
        '${DateTime.now().microsecondsSinceEpoch}-${Random().nextInt(0x7fffffff)}';
    saved = false;
    saving = false;
    error = null;
    previousInput = '';
    ignoreInput = true;
    entry.clear();
    ignoreInput = false;
  }

  void edit() {
    if (ignoreInput ||
        entry.value.composing.isValid && !entry.value.composing.isCollapsed ||
        session.finished) {
      return;
    }
    final text = entry.text;
    if (text == previousInput) return;
    var common = 0;
    while (common < text.length &&
        common < previousInput.length &&
        text[common] == previousInput[common]) {
      common++;
    }
    for (var n = common; n < previousInput.length; n++) {
      session.backspace();
    }
    for (var n = common; n < text.length; n++) {
      final ch = bridge
          ? keyboard.bridge(text[n], session.expected ?? '')
          : text[n];
      session.press(ch, blockOnError: block);
      if (session.finished) break;
    }
    previousInput = text;
    if (headerAssistant.pose != SynapsePose.idle) {
      headerAssistant.preview(SynapsePreviewAction.idle);
    }
    setState(() {});
    if (session.finished) unawaited(saveResult());
  }

  void enter() {
    if (session.finished) {
      if (saved) next();
      return;
    }
    session.press('\n', blockOnError: block);
    setState(() {});
    if (session.finished) unawaited(saveResult());
  }

  Future<void> savePrefs() async {
    try {
      await widget.repository.transaction((doc) {
        (doc['prefs'] as Map).addAll(<String, dynamic>{
          'lang': language,
          'profile': profile,
          'bank': bank,
          'plain': plain,
          'textBank': textBank,
          'index': index,
          'block': block,
          'bridge': bridge,
          'flow': flow,
          'keyboard': showKeyboard,
          'layout': layout,
          'pet': pet,
          'motion': motion,
        });
      });
    } catch (_) {
      if (mounted) {
        setState(
          () => error = 'Настройки не сохранены. Проверьте свободное место.',
        );
      }
    }
  }

  SessionFact fact(Map<String, dynamic> p) => SessionFact(
    gameId: 'typefree.practice',
    outcome: Outcome.finished,
    at: DateTime.fromMillisecondsSinceEpoch(p['t'] as int),
    score: p['wpm'] as int,
    errors: p['errors'] as int,
    timeSeconds: ((p['elapsedMs'] as int) / 1000).round(),
    difficulty: p['difficulty'] as String,
    mode: 'practice',
    unit: 'WPM',
  );
  Future<void> saveResult() async {
    if (saved || saving) return;
    setState(() {
      saving = true;
      error = null;
    });
    final stats = session.stats,
        ex = exercise,
        id = sessionId,
        currentProfile = profile;
    final point = <String, dynamic>{
      'id': id,
      'exercise': ex['id'],
      'title': ex['title'],
      'language': language,
      'profile': profile,
      'difficulty': '$language/${ex['bank']}/$plain/$layout/$flow',
      'mode': 'practice',
      't': DateTime.now().millisecondsSinceEpoch,
      ...stats.toJson(),
      'len': session.attemptedKeys,
    };
    final earlier = history;
    var fresh = false;
    try {
      await widget.repository.transaction((doc) {
        final sessions = doc['sessions'] as List, legacy = doc['legacy'] as Map;
        if (sessions.any((x) => x['id'] == id)) return;
        final key =
            'tr_progress_${ex['bank']}${plain && ex['bank'] != 'digits' ? '_plain' : ''}';
        final record = legacy[key] is String
            ? jsonDecode(legacy[key] as String) as Map
            : <String, dynamic>{};
        final done = List<String>.from((record['done'] as List?) ?? []);
        if (!done.contains(ex['id'])) done.add(ex['id'] as String);
        legacy[key] = jsonEncode({
          'done': done,
          'lastIdx': index,
          'bestWpm': max((record['bestWpm'] as num?) ?? 0, stats.wpm),
          'bestAcc': max((record['bestAcc'] as num?) ?? 0, stats.accuracy),
        });
        if (stats.wpm > 0 && session.attemptedKeys >= 10) {
          sessions.add(point);
          fresh = true;
          final h = legacy['tr_history'] is String
              ? List<dynamic>.from(
                  jsonDecode(legacy['tr_history'] as String) as List,
                )
              : <dynamic>[];
          h.add({
            't': point['t'],
            'wpm': stats.wpm,
            'acc': stats.accuracy,
            'len': session.attemptedKeys,
            'ms': stats.elapsedMs,
            'err': stats.errors,
            'score':
                (stats.wpm *
                        (stats.accuracy / 100) *
                        min(1, session.attemptedKeys / 50))
                    .round(),
          });
          legacy['tr_history'] = jsonEncode(
            h.length > 300 ? h.sublist(h.length - 300) : h,
          );
        }
      });
      if (mounted) setState(() => saved = true);
      if (fresh && mounted) {
        try {
          await assistant.onGameSaved(
            fact(point),
            earlier
                .where((p) => p['profile'] == currentProfile)
                .map(fact)
                .toList(),
            game: GameInfo(
              id: 'typefree.practice',
              name: tr('hub.train'),
              category: 'typing',
            ),
          );
          await widget.repository.transaction((doc) {
            (doc['prefs'] as Map)['synapseMemory_$currentProfile'] = assistant
                .memory
                .toJson();
          });
        } catch (_) {
          /* Pet failure cannot undo or duplicate saved progress. */
        }
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => error = 'Результат не сохранён. История осталась прежней. Повторите сохранение.',
        );
      }
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  void next([int delta = 1]) {
    if (saving || session.finished && !saved) return;
    setState(() {
      index = (index + delta) % exercises.length;
      reset();
    });
    unawaited(savePrefs());
    inputFocus.requestFocus();
  }

  Future<void> openAssistant() async {
    if (!pet) return;
    headerAssistant.preview(SynapsePreviewAction.greeting);
    await showModalBottomSheet<void>(
      context: surface,
      isScrollControlled: true,
      builder: (c) => SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Синапс',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Закрыть',
                      onPressed: () => Navigator.pop(c),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
                TickerMode(
                  enabled: motion && !MediaQuery.disableAnimationsOf(c),
                  child: SynapsePet(controller: assistant, size: 180),
                ),
                if (assistant.current == null)
                  Text(
                    history.isEmpty
                        ? 'Начните тренировку — здесь появится ваш прогресс.'
                        : 'Сохранено тренировок: ${history.length}. Последняя точность: ${history.last['accuracy']}%.',
                  ),
              ],
            ),
          ),
        ),
      ),
    );
    if (mounted) inputFocus.requestFocus();
  }

  Future<void> settings() async {
    await showDialog<void>(
      context: surface,
      builder: (c) => StatefulBuilder(
        builder: (c, update) => AlertDialog(
          title: Text(tr('hub.settings')),
          content: SizedBox(
            width: 480,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Шаблон оформления'),
                  for (final t in widget.appearance.registry.templates.values)
                    ChoiceChip(
                      label: Text(t.title),
                      selected: widget.appearance.selection.templateId == t.id,
                      onSelected: (_) {
                        widget.appearance.preview(
                          t.id,
                          widget.appearance.selection.brightness,
                        );
                        update(() {});
                      },
                    ),
                  DropdownButton<ThemeMode>(
                    value: widget.appearance.selection.brightness,
                    items: ThemeMode.values
                        .map(
                          (m) => DropdownMenuItem(
                            value: m,
                            child: Text(switch (m) {
                              ThemeMode.system => 'Системная',
                              ThemeMode.light => 'Светлая',
                              ThemeMode.dark => 'Тёмная',
                            }),
                          ),
                        )
                        .toList(),
                    onChanged: (m) {
                      widget.appearance.preview(
                        widget.appearance.selection.templateId,
                        m!,
                      );
                      update(() {});
                    },
                  ),
                  DropdownButton<String>(
                    value: profile,
                    items: ['m', 'f', 'kids']
                        .map(
                          (p) => DropdownMenuItem(
                            value: p,
                            child: Text(
                              p == 'kids'
                                  ? 'Детский профиль'
                                  : p == 'f'
                                  ? 'Мягкий профиль'
                                  : 'Классический профиль',
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: saving
                        ? null
                        : (p) {
                            setState(() {
                              profile = p!;
                              assistant.dispose();
                              headerAssistant.dispose();
                              createAssistant();
                            });
                            update(() {});
                          },
                  ),
                  DropdownButton<String>(
                    value: layout,
                    items: ['auto', 'qwerty', 'azerty', 'qwertz']
                        .map(
                          (l) => DropdownMenuItem(
                            value: l,
                            child: Text(l.toUpperCase()),
                          ),
                        )
                        .toList(),
                    onChanged: (l) {
                      setState(() {
                        layout = l!;
                        loadKeyboard();
                      });
                      update(() {});
                    },
                  ),
                  for (final row in <(String, bool, void Function(bool))>[
                    (tr('tb.block'), block, (v) => block = v),
                    (tr('tb.keyb'), showKeyboard, (v) => showKeyboard = v),
                    (tr('set.bridge'), bridge, (v) => bridge = v),
                    (
                      'Синапс',
                      pet,
                      (v) {
                        pet = v;
                        assistant.enabled = v;
                        headerAssistant.enabled = v;
                      },
                    ),
                    ('Анимация Синапса', motion, (v) => motion = v),
                  ])
                    SwitchListTile(
                      title: Text(row.$1),
                      value: row.$2,
                      onChanged: (v) {
                        setState(() => row.$3(v));
                        update(() {});
                      },
                    ),
                  const Text(
                    'Другие режимы ещё переносятся. Пробная версия хранит данные отдельно от установленного приложения.',
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                widget.appearance.cancel();
                Navigator.pop(c);
              },
              child: const Text('Отменить оформление'),
            ),
            FilledButton(
              onPressed: () async {
                final ok = await widget.appearance.apply();
                await savePrefs();
                if (!c.mounted) return;
                if (ok) {
                  Navigator.pop(c);
                } else {
                  update(() {});
                }
              },
              child: const Text('Сохранить'),
            ),
          ],
        ),
      ),
    );
    widget.appearance.cancel();
    if (mounted) inputFocus.requestFocus();
  }

  Future<void> customText() async {
    final editor = TextEditingController(text: custom);
    final result = await showDialog<String>(
      context: surface,
      builder: (c) => AlertDialog(
        title: Text(tr('custom.title')),
        content: SizedBox(
          width: 500,
          child: TextField(
            controller: editor,
            maxLines: 6,
            autofocus: true,
            decoration: InputDecoration(hintText: tr('custom.ph')),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c),
            child: Text(tr('custom.cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(c, editor.text),
            child: Text(tr('custom.start')),
          ),
        ],
      ),
    );
    // Dispose after the dialog's closing animation releases EditableText.
    Future<void>.delayed(const Duration(milliseconds: 400), editor.dispose);
    if (result != null && result.trim().isNotEmpty) {
      setState(() {
        custom = result;
        index = 0;
        reset();
      });
    }
    if (mounted) inputFocus.requestFocus();
  }

  Widget face(BuildContext c) => Image.asset(
    'packages/synapse_pet/assets/synapse/images/synapse/head.png',
    fit: BoxFit.contain,
  );

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.appearance,
    builder: (c, _) => MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'TypeFree · пробная версия',
      theme: widget.appearance.theme(
        WidgetsBinding.instance.platformDispatcher.platformBrightness,
        profileId: profile,
      ),
      home: Builder(
        builder: (c) {
          surface = c;
          return screen(c);
        },
      ),
    ),
  );
  Widget screen(BuildContext c) {
    final stats = session.stats;
    void change(VoidCallback action) {
      if (saving) return;
      setState(() {
        action();
        reset();
      });
      unawaited(savePrefs());
    }

    final controls = Wrap(
      spacing: 12,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        DropdownButton<String>(
          isExpanded: true,
          value: bank,
          items:
              (language == 'ru'
                      ? [
                          'ruWords',
                          'ruPhrases',
                          'classic',
                          'poemHymn',
                          'digits',
                        ]
                      : ['classic', 'poemHymn', 'digits'])
                  .map(
                    (b) =>
                        DropdownMenuItem(value: b, child: Text(tr('bank.$b'))),
                  )
                  .toList(),
          onChanged: saving
              ? null
              : (b) => change(() {
                  custom = null;
                  bank = b!;
                  if (bank != 'digits') textBank = bank;
                  index = 0;
                }),
        ),
        TextButton.icon(
          onPressed: saving ? null : customText,
          icon: const Icon(Icons.edit_outlined),
          label: Text(tr('custom.title')),
        ),
        FilterChip(
          label: const Text('Без пунктуации'),
          selected: plain,
          onSelected: saving ? null : (v) => change(() => plain = v),
        ),
        FilterChip(
          label: const Text('Только цифры'),
          selected: bank == 'digits',
          onSelected: saving
              ? null
              : (v) => change(() {
                  custom = null;
                  bank = v ? 'digits' : textBank;
                  index = 0;
                }),
        ),
        FilterChip(
          label: Text(tr('tb.flow')),
          selected: flow,
          onSelected: saving ? null : (v) => change(() => flow = v),
        ),
      ],
    );
    final completion = Wrap(
      spacing: 12,
      children: [
        if (saving)
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text('Сохранение…'),
          ),
        if (!saved && !saving)
          FilledButton(
            onPressed: saveResult,
            child: const Text('Повторить сохранение'),
          ),
        if (saved)
          FilledButton(onPressed: () => next(), child: Text(tr('done.next'))),
        if (saved)
          OutlinedButton(
            onPressed: () => next(0),
            child: Text(tr('done.again')),
          ),
        if (saved && pet)
          TextButton(
            onPressed: openAssistant,
            child: const Text('Синапс · мой результат'),
          ),
      ],
    );
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'TypeFree',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        actions: [
          DropdownButton<String>(
            value: language,
            items: languages
                .map(
                  (l) =>
                      DropdownMenuItem(value: l, child: Text(l.toUpperCase())),
                )
                .toList(),
            onChanged: saving
                ? null
                : (l) => change(() {
                    language = l!;
                    custom = null;
                    bank = language == 'ru' ? 'ruWords' : 'classic';
                    textBank = bank;
                    index = 0;
                    loadKeyboard();
                    assistant.dispose();
                    headerAssistant.dispose();
                    createAssistant();
                  }),
          ),
          IconButton(
            tooltip: tr('hub.settings'),
            onPressed: settings,
            icon: const Icon(Icons.settings_outlined),
          ),
          SynapseHeaderButton(
            enabled: pet,
            portrait: face(c),
            onOpen: openAssistant,
          ),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        height: 56,
        selectedIndex: historyPage ? 1 : 0,
        onDestinationSelected: (v) => setState(() => historyPage = v == 1),
        destinations: [
          NavigationDestination(
            icon: const Icon(Icons.keyboard_outlined),
            label: tr('hub.train'),
          ),
          NavigationDestination(
            icon: const Icon(Icons.insights_outlined),
            label: tr('prog.title'),
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(12),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1320),
              child: LayoutBuilder(
                builder: (c, bounds) {
                  final wide = bounds.maxWidth >= 1100;
                  final practice = Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (!wide) controls,
                      const SizedBox(height: 6),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              exercise['title'] as String,
                              style: Theme.of(c).textTheme.titleLarge,
                            ),
                          ),
                          IconButton(
                            tooltip: 'Предыдущее',
                            onPressed: () => next(-1),
                            icon: const Icon(Icons.chevron_left),
                          ),
                          Text('${index + 1} / ${exercises.length}'),
                          IconButton(
                            tooltip: 'Следующее',
                            onPressed: () => next(),
                            icon: const Icon(Icons.chevron_right),
                          ),
                        ],
                      ),
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(8),
                          child: PatternView(session: session),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 24,
                        runSpacing: 8,
                        children: [
                          Text('${stats.wpm} WPM'),
                          Text('${stats.accuracy}% · ${tr('st.accuracy')}'),
                          Text('${stats.errors} · ${tr('st.errors')}'),
                          Text(
                            '${(stats.elapsedMs / 1000).toStringAsFixed(1)} s',
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      TextField(
                        key: const ValueKey('practice-input'),
                        controller: entry,
                        focusNode: inputFocus,
                        autofocus: true,
                        enabled: !session.finished,
                        autocorrect: false,
                        enableSuggestions: false,
                        enableInteractiveSelection: false,
                        smartDashesType: SmartDashesType.disabled,
                        smartQuotesType: SmartQuotesType.disabled,
                        inputFormatters: [PracticeCommitFormatter()],
                        onSubmitted: (_) => enter(),
                        decoration: const InputDecoration(
                          border: OutlineInputBorder(),
                          labelText: 'Печатайте здесь',
                          hintText: 'Ввод с клавиатуры',
                        ),
                      ),
                      if (showKeyboard) ...[
                        const SizedBox(height: 8),
                        Card(
                          child: Padding(
                            padding: const EdgeInsets.all(8),
                            child: KeyboardGuide(
                              model: keyboard,
                              expected: session.expected,
                              ru: language == 'ru',
                            ),
                          ),
                        ),
                      ],
                      if (error != null)
                        Text(
                          error!,
                          style: TextStyle(
                            color: Theme.of(c).colorScheme.error,
                          ),
                        ),
                      if (!wide && session.finished) completion,
                    ],
                  );
                  if (historyPage) return historyView(c);
                  if (!wide) return practice;
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: practice),
                      const SizedBox(width: 20),
                      SizedBox(
                        width: 240,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            const Text(
                              'Настройки практики',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 12),
                            controls,
                            if (session.finished) ...[
                              const SizedBox(height: 16),
                              completion,
                            ],
                            const SizedBox(height: 24),
                            const Text(
                              'Пробная версия Flutter. Данные хранятся отдельно от установленного приложения.',
                              style: TextStyle(fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget historyView(BuildContext c) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Text(tr('prog.title'), style: Theme.of(c).textTheme.headlineMedium),
      if (history.isEmpty)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 32),
          child: Text(tr('prog.empty')),
        ),
      for (final p in history.reversed)
        Card(
          child: ListTile(
            title: Text(p['title'] as String),
            subtitle: Text(
              DateTime.fromMillisecondsSinceEpoch(p['t'] as int)
                  .toLocal()
                  .toString(),
            ),
            trailing: Text('${p['wpm']} WPM · ${p['accuracy']}%'),
          ),
        ),
    ],
  );
}

class PatternView extends StatefulWidget {
  const PatternView({super.key, required this.session});
  final TypingSession session;
  @override
  State<PatternView> createState() => _PatternViewState();
}

class _PatternViewState extends State<PatternView> {
  final scroll = ScrollController();
  @override
  void dispose() {
    scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final session = widget.session;
    final t = Theme.of(context).extension<TypeFreeTokens>()!;
    final span = TextSpan(
      style: TextStyle(
        fontSize: 28,
        height: 1.6,
        fontFamily: 'monospace',
        color: t['text'],
      ),
      children: List.generate(
        session.pattern.length,
        (i) => TextSpan(
          text: session.pattern[i],
          style: TextStyle(
            color: i == session.pos
                ? t['onExpectedKey']
                : session.marks[i] == 1
                ? t['success']
                : session.marks[i] == 2
                ? t['danger']
                : t['text'],
            backgroundColor: i == session.pos ? t['expectedKey'] : null,
          ),
        ),
      ),
    );
    return SizedBox(
      height: 62,
      child: LayoutBuilder(
        builder: (context, bounds) {
          final painter = TextPainter(
            text: span,
            textDirection: TextDirection.ltr,
            textScaler: MediaQuery.textScalerOf(context),
          )..layout(maxWidth: bounds.maxWidth);
          final y = painter
              .getOffsetForCaret(
                TextPosition(
                  offset: session.pos.clamp(0, session.pattern.length),
                ),
                Rect.zero,
              )
              .dy;
          final lineHeight = painter.preferredLineHeight;
          painter.dispose();
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted || !scroll.hasClients) return;
            final current = scroll.offset;
            final bottom = y + lineHeight;
            final target = y < current
                ? y
                : bottom > current + 62
                ? bottom - 62
                : current;
            final clamped = target.clamp(0.0, scroll.position.maxScrollExtent);
            if ((current - clamped).abs() > .5) scroll.jumpTo(clamped);
          });
          return SingleChildScrollView(
            controller: scroll,
            child: Text.rich(span),
          );
        },
      ),
    );
  }
}

class PracticeCommitFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue old,
    TextEditingValue next,
  ) {
    if (next.composing.isValid && !next.composing.isCollapsed) return next;
    if (old.composing.isValid && !old.composing.isCollapsed) return next;
    return next.text.length - old.text.length > 1 ? old : next;
  }
}
