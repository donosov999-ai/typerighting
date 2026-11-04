import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:synapse_pet/synapse_pet.dart';

import 'data/content_selection.dart';
import 'data/platform_store.dart';
import 'data/local_repository.dart';
import 'data/artifact_export.dart';
import 'data/key_statistics_store.dart';
import 'domain/key_statistics.dart';
import 'domain/adaptive.dart';
import 'domain/learning.dart';
import 'features/learning_page.dart';
import 'features/competition_page.dart';
import 'features/memorize_page.dart';
import 'features/recall_page.dart';
import 'features/exam_page.dart';
import 'features/kids_page.dart';
import 'domain/kids.dart';
import 'domain/recall.dart';
import 'features/progress_page.dart';
import 'features/settings_pages.dart';
import 'features/profile_page.dart';
import 'features/achievements_page.dart';
import 'features/companion_page.dart';
import 'features/speed_home.dart';
import 'features/synapse_panel.dart';
import 'features/result_card.dart';
import 'features/trainer_parts.dart';
import 'features/library_page.dart';
import 'features/account_pages.dart';
import 'data/achievement_store.dart';
import 'data/progress_view.dart';
import 'domain/progress_metrics.dart' show utcStreak;
import 'audio/typefree_sound.dart';
import 'design_system/templates.dart';
import 'design_system/synapse_header.dart';
import 'domain/typing.dart';
import 'domain/session_context.dart';
import 'features/keyboard_guide.dart';
import 'features/practice_widgets.dart';
import 'features/course_page.dart';
import 'features/today_page.dart';
import 'features/migration_gate.dart';
import 'data/webview_migration.dart';
import 'features/transfer_page.dart';
import 'features/weak_keys_page.dart';
import 'domain/today.dart';
import 'features/common_copy.dart';
export 'features/practice_widgets.dart' show PracticeCommitFormatter;

const languages = ['ru', 'en', 'es', 'de', 'fr', 'it', 'pt'];

/// A saved numeric bank cannot be the text bank to restore on toggle-off.
String _availableTextBank(
  Map<String, dynamic> catalog,
  String language,
  String bank,
) {
  final items = ((catalog['catalog'] as Map)[language] as List?) ?? const [];
  final banks = [for (final item in items) (item as Map)['bank'] as String];
  if (bank != 'digits' && banks.contains(bank)) return bank;
  return banks.firstWhere((b) => b != 'digits', orElse: () => bank);
}

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
  Resources(
    this.content,
    this.keyboards,
    this.registry,
    this.course,
    this.learning, [
    this.kids = const {},
  ]);
  final Map<String, dynamic> content, keyboards, course, learning, kids;
  final TemplateRegistry registry;
  static Future<Resources> load() async => Resources(
    applyContentSelection(
      jsonDecode(await rootBundle.loadString('assets/baseline/catalog.json'))
          as Map<String, dynamic>,
      await _releaseSelection(),
    ).catalog,
    jsonDecode(await rootBundle.loadString('assets/baseline/keyboard.json'))
        as Map<String, dynamic>,
    TemplateRegistry.parse(
      jsonDecode(await rootBundle.loadString('assets/templates/registry.json'))
          as Map<String, dynamic>,
    ),

    jsonDecode(await rootBundle.loadString('assets/baseline/course.json'))
        as Map<String, dynamic>,
    jsonDecode(await rootBundle.loadString('assets/baseline/learning.json'))
        as Map<String, dynamic>,
    jsonDecode(await rootBundle.loadString('assets/baseline/kids.json'))
        as Map<String, dynamic>,
  );

  /// The author's release selection shipped with the build; none → full catalog.
  static Future<Object?> _releaseSelection() async {
    try {
      return jsonDecode(
        await rootBundle.loadString('assets/content/release-selection.json'),
      );
    } catch (_) {
      return null;
    }
  }
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
    // Built after the migration below, so imported progress counts at once.
    final device = PlatformDispatcher.instance.locale.languageCode;
    final mobile =
        !kIsWeb &&
        (defaultTargetPlatform == TargetPlatform.android ||
            defaultTargetPlatform == TargetPlatform.iOS);
    void start() => runApp(
      TypeFreeApp(
        deviceLanguage: languages.contains(device) ? device : 'en',
        resources: resources,
        repository: repo,
        migrationPending: mobile && needsWebviewMigration(repo.data),
        welcome: needsWelcome(repo.data),
        appearance: AppearanceController(
          resources.registry,
          PreferenceStore(),
          existingInstall: (repo.data['receipts'] as Map).isNotEmpty,
          legacyDark: (repo.data['legacy'] as Map)['tr_dark'] == null
              ? null
              : (repo.data['legacy'] as Map)['tr_dark'] == '1',
          saved: saved,
        ),
      ),
    );
    // Same-ID update from the Tauri app: read its WebView storage once.
    if (mobile && needsWebviewMigration(repo.data)) {
      runApp(
        TauriMigrationGate(
          repository: repo,
          onDone: start,
          origin: defaultTargetPlatform == TargetPlatform.iOS
              ? tauriIosOrigin
              : tauriAndroidOrigin,
        ),
      );
    } else {
      start();
    }
  } catch (_) {
    runApp(
      const MaterialApp(
        home: Scaffold(
          body: Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Text(startupFailedText),
            ),
          ),
        ),
      ),
    );
  }
}

/// Version shown in Settings: the store build passes its own
/// (--dart-define=TYPEFREE_VERSION); otherwise the app this candidate replaces.
const appVersion = String.fromEnvironment(
  'TYPEFREE_VERSION',
  defaultValue: '2.60.4',
);

/// Built with the store ID (pro.typefree.app): it takes over the old app's
/// data, so the «kept separately» candidate note would be untrue.
const sameIdBuild = bool.fromEnvironment('TYPEFREE_SAME_ID');

enum AppSection {
  today,
  practiceMenu,
  practice,
  course,
  learn,
  compete,
  memorize,
  recall,
  exam,
  kids,
  progress,
  weakKeys,
  more,
  settings,
  settingsInput,
  settingsSound,
  profileLanguage,
  achievements,
  welcome,
  companion,
  library,
  account,
  dataPermissions,
  transfer,
}

/// Source rule: onboarding while no profile was ever chosen (tr_profile,
/// imported into prefs.profile).
bool needsWelcome(Map<String, dynamic> doc) =>
    !const ['m', 'f', 'kids'].contains((doc['prefs'] as Map)['profile']);

class TypeFreeApp extends StatefulWidget {
  const TypeFreeApp({
    super.key,
    required this.resources,
    required this.repository,
    required this.appearance,
    this.clock,
    this.artifactExporter,
    this.transferPicker,
    this.initialSection = AppSection.today,
    this.welcome = false,
    this.phone,
    this.deviceLanguage,
    this.migrationPending = false,
  });
  final Resources resources;
  final LocalRepository repository;
  final AppearanceController appearance;
  final MillisecondClock? clock;
  final ArtifactExporter? artifactExporter;

  /// I5 file source (tests); null = the system file picker.
  final TransferFilePicker? transferPicker;
  final AppSection initialSection;

  /// Start on A1 «Добро пожаловать» (see [needsWelcome]).
  final bool welcome;

  /// Phone without a physical keyboard (null = detect from the platform).
  final bool? phone;

  /// Language when none was chosen and the old app stored none: the device
  /// language if supported, else English (null keeps the old «ru» default).
  final String? deviceLanguage;
  final bool migrationPending;
  @override
  State<TypeFreeApp> createState() => TypeFreeAppState();
}

class TypeFreeAppState extends State<TypeFreeApp> with WidgetsBindingObserver {
  late String language, profile, bank, layout;
  bool weakMode = false, showHeat = false, hardKeys = false;
  final learningKey = GlobalKey<LearningPageState>();
  final competitionKey = GlobalKey<CompetitionPageState>();
  final memorizeKey = GlobalKey<MemorizePageState>();
  final recallKey = GlobalKey<RecallPageState>();
  final examKey = GlobalKey<ExamPageState>();
  final kidsKey = GlobalKey<KidsPageState>();
  final kidsActivity = KidsActivity();
  late RecallAdaptation recallAdaptation;
  late LearningAdaptation learningAdaptation;
  int weakReturnIndex = 0;
  List<String> weakLines = [];
  int examMinutes = 10;
  late TypingSession session;
  late KeyStatisticsStore keyStatistics;
  final progressMessenger = GlobalKey<ScaffoldMessengerState>();
  RecordedHistory? recordedHistory;
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
      ignoreInput = false;
  bool hidePattern = false, soundOn = true, voiceOn = false, metroOn = false;
  bool appForeground = true;
  int metroBpm = 120;
  double textSize = 1;
  late AppSection section;
  int? courseStartLessonId;

  /// Companion (A4): started on a phone without a keyboard; learn/compete
  /// opened from it return there (source companionMode).
  bool companionMode = false;
  late bool phone;

  /// Saved choice: 'trainer' | 'companion' | null (source tr_mode).
  String? appMode;
  AppSection get menuHome =>
      companionMode ? AppSection.companion : AppSection.practiceMenu;

  /// The trainer opened from C1 returns to the library, not the menu.
  bool practiceFromLibrary = false;

  List<LibraryBank> get libraryBanks {
    final all = List<Map<String, dynamic>>.from(
      (widget.resources.content['catalog'] as Map)[language] as List,
    );
    final legacy = widget.repository.data['legacy'] as Map;
    return [
      for (final id in {for (final e in all) e['bank'] as String})
        LibraryBank(
          id,
          all.where((e) => e['bank'] == id).length,
          legacy['tr_progress_$id'] is String
              ? ((jsonDecode(legacy['tr_progress_$id'] as String)
                            as Map)['done']
                        as List? ??
                    [])
                .length
              : 0,
        ),
    ];
  }

  void openBank(String id) {
    if (saving) return;
    setState(() {
      custom = null;
      weakMode = false;
      bank = id;
      if (bank != 'digits') textBank = bank;
      index = 0;
      reset();
      practiceFromLibrary = true;
      section = AppSection.practice;
    });
    unawaited(savePrefs());
  }

  /// F2 opens from «Ещё» and from «Прогресс»; back and the tab follow it.
  AppSection achievementsBack = AppSection.more;
  bool get historyPage => section == AppSection.progress;
  bool get coursePage => section == AppSection.course;
  bool get inSettings =>
      section == AppSection.settings ||
      section == AppSection.settingsInput ||
      section == AppSection.settingsSound ||
      section == AppSection.profileLanguage ||
      section == AppSection.achievements ||
      section == AppSection.account ||
      section == AppSection.dataPermissions ||
      section == AppSection.transfer;
  Future<bool> finishLearning() async {
    if (section == AppSection.kids) {
      return await kidsKey.currentState?.checkpointForExit() ?? true;
    }
    if (section == AppSection.exam) {
      return await examKey.currentState?.checkpointForExit() ?? true;
    }
    if (section == AppSection.recall) {
      return await recallKey.currentState?.checkpointForExit() ?? true;
    }
    if (section == AppSection.memorize) {
      return await memorizeKey.currentState?.finishAndSave() ?? true;
    }
    if (section == AppSection.compete) {
      return await competitionKey.currentState?.finishAndSave() ?? true;
    }
    if (section != AppSection.learn) return true;
    return await learningKey.currentState?.finishAndSave() ?? true;
  }

  Future<void> showSection(AppSection next) async {
    if (next != section && !await finishLearning()) return;
    if (!mounted) return;
    setState(() {
      // Only openBank enters the trainer «from the library».
      if (next != section) practiceFromLibrary = false;
      section = next;
    });
  }

  int index = 0;
  String? custom, error;
  List<Map<String, dynamic>> get exercises => weakMode
      ? [
          {
            'id': 'weak',
            'bank': 'weak',
            'title': tr('weak.title'),
            'lines': weakLines,
          },
        ]
      : custom != null
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
    final lifecycle = WidgetsBinding.instance.lifecycleState;
    appForeground = lifecycle == null || lifecycle == AppLifecycleState.resumed;
    final prefs = widget.repository.data['prefs'] as Map;
    final savedMode =
        prefs['appMode'] ??
        (widget.repository.data['legacy'] as Map)['tr_mode'];
    appMode = savedMode == 'trainer' || savedMode == 'companion'
        ? savedMode as String
        : null;
    phone = widget.phone ?? detectPhone();
    section = widget.welcome ? AppSection.welcome : widget.initialSection;
    if (section == AppSection.today && companionStart) {
      section = AppSection.companion;
      companionMode = true;
    }
    HardwareKeyboard.instance.addHandler(hardwareKey);
    keyStatistics = KeyStatisticsStore(
      widget.repository,
      onAchievements: (ids) {
        appSound.effect('star');
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          progressMessenger.currentState?.showSnackBar(
            SnackBar(
              content: Text(
                '${tr('ach.unlocked')} ${ids.map((id) => tr('ach.$id')).join(', ')}',
              ),
            ),
          );
        });
      },
    );
    WidgetsBinding.instance.addObserver(this);
    final p = widget.repository.data['prefs'] as Map;
    language = languages.contains(p['lang'])
        ? p['lang'] as String
        : widget.deviceLanguage ?? 'ru';
    profile = ['m', 'f', 'kids'].contains(p['profile'])
        ? p['profile'] as String
        : 'm';
    bank = availableBank(
      widget.resources.content,
      language,
      (p['bank'] as String?) ?? (language == 'ru' ? 'ruWords' : 'classic'),
    );
    layout = ['auto', 'qwerty', 'azerty', 'qwertz'].contains(p['layout'])
        ? p['layout'] as String
        : 'auto';
    textBank = _availableTextBank(
      widget.resources.content,
      language,
      (p['textBank'] as String?) ?? bank,
    );
    index = (p['index'] as num?)?.toInt() ?? 0;
    plain = p['plain'] == true;
    flow = p['flow'] == true;
    block = p['block'] != false;
    bridge = p['bridge'] != false;
    pet = p['pet'] != false;
    motion = p['motion'] != false;
    showKeyboard = p['keyboard'] != false;
    showHeat = p['heat'] == true;
    hardKeys = p['hardkeys'] == true;
    // Settings not yet kept by Flutter fall back to the imported source keys.
    final oldPrefs = widget.repository.data['legacy'] as Map;
    bool flag(String key, String legacyKey, bool fallback) => p[key] is bool
        ? p[key] as bool
        : oldPrefs[legacyKey] is String
        ? oldPrefs[legacyKey] == '1'
        : fallback;
    hidePattern = flag('hide', 'tr_hide', false);
    soundOn = p['sound'] is bool
        ? p['sound'] as bool
        : oldPrefs['tr_sound'] != '0';
    voiceOn = flag('voice', 'tr_voice', false);
    metroOn = flag('metronome', 'tr_metro', false);
    metroBpm =
        ((p['bpm'] as num?) ??
                num.tryParse('${oldPrefs['tr_metro_bpm'] ?? ''}') ??
                120)
            .toInt()
            .clamp(60, 200);
    textSize = [.9, 1.0, 1.15].contains(p['textSize'])
        ? (p['textSize'] as num).toDouble()
        : 1;
    appSound.enabled = () => soundOn;
    appSound.voiceEnabled = () => voiceOn;
    final level = (widget.repository.data['legacy'] as Map)['tr_kids_ai_lvl'];
    learningAdaptation = LearningAdaptation(
      kidsLevel: level is String ? (jsonDecode(level) as num).toInt() : 0,
    );
    final recallBest =
        num.tryParse(
          (widget.repository.data['legacy'] as Map)['tr_span_best']
                  ?.toString() ??
              '',
        ) ??
        3;
    recallAdaptation = RecallAdaptation(bestSpan: max(3, recallBest));
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

  /// Source isPhoneNoKeyboard: touch platform and the short side under 600.
  static bool detectPhone() {
    final mobile =
        defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS;
    final views = WidgetsBinding.instance.platformDispatcher.views;
    if (!mobile || views.isEmpty) return false;
    final v = views.first;
    return v.physicalSize.shortestSide / v.devicePixelRatio < 600;
  }

  bool get companionStart =>
      appMode != 'trainer' && (appMode == 'companion' || phone);

  /// First real hardware key press on the companion opens the trainer, not
  /// remembered (a keyboard plugged in for a minute must not lock the phone
  /// into the trainer). Ignored inside learn/compete opened from it.
  bool hardwareKey(KeyEvent e) {
    if (section != AppSection.companion || e is! KeyDownEvent) return false;
    final ch = e.character;
    final k = HardwareKeyboard.instance;
    if (ch == null || ch.length != 1 || k.isControlPressed) return false;
    if (k.isMetaPressed || k.isAltPressed) return false;
    openTrainerFromCompanion(false);
    return true;
  }

  void openTrainerFromCompanion(bool persist) {
    setState(() {
      companionMode = false;
      section = AppSection.practiceMenu;
      if (persist) appMode = 'trainer';
    });
    if (persist) unawaited(savePrefs());
  }

  void openCompanion() {
    setState(() {
      appMode = 'companion';
      companionMode = true;
      section = AppSection.companion;
    });
    unawaited(savePrefs());
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(hardwareKey);
    appSound.stopMetronome();
    timer?.cancel();
    keyStatistics.dispose();
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
    appForeground = state == AppLifecycleState.resumed;
    if (state == AppLifecycleState.resumed) {
      headerAssistant.wake();
      syncMetronome();
    } else {
      appSound.stopMetronome();
      headerAssistant.sleep();
      unawaited(
        keyStatistics.flush().catchError((Object e) {
          keyStatistics.lastError = e;
        }),
      );
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
    // Reset only temporary session counters, not queued key evidence.
    if (section == AppSection.practice) {
      keyStatistics.recorder.discardSession();
    }
    if (exercises.isEmpty) {
      bank = availableBank(
        widget.resources.content,
        language,
        language == 'ru' ? 'ruWords' : 'classic',
      );
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
    lastRecord = false;
    recordedHistory = null;
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
      recordPress(ch);
      if (session.finished) break;
    }
    previousInput = text;
    if (headerAssistant.pose != SynapsePose.idle) {
      headerAssistant.idle();
    }
    setState(() {});
    if (session.finished) unawaited(saveResult());
  }

  void enter() {
    if (session.finished) {
      if (saved) next();
      return;
    }
    recordPress('\n');
    setState(() {});
    if (session.finished) unawaited(saveResult());
  }

  void recordPress(String ch) {
    if (session.finished) return;
    final expected = session.expected ?? '';
    final result = session.press(ch, blockOnError: block);
    if (result.wrong) appSound.effect('error');
    if (expected.isNotEmpty && expected != ' ' && expected != '\n') {
      final id = keyboard.hit(
        expected,
        ru: RegExp('[а-яё]', caseSensitive: false).hasMatch(session.pattern),
      )?['id'];
      if (id is String) {
        keyStatistics.record(
          id,
          !result.wrong,
          widget.clock?.call() ?? DateTime.now().millisecondsSinceEpoch,
        );
      }
    }
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
          'index': weakMode ? weakReturnIndex : index,
          'block': block,
          'bridge': bridge,
          'flow': flow,
          'keyboard': showKeyboard,
          'heat': showHeat,
          'hardkeys': hardKeys,
          'layout': layout,
          'pet': pet,
          'motion': motion,
          'hide': hidePattern,
          'sound': soundOn,
          'voice': voiceOn,
          'metronome': metroOn,
          'bpm': metroBpm,
          'textSize': textSize,
          'appMode': ?appMode,
        });
      });
    } catch (_) {
      if (mounted) {
        setState(
          () => error = commonCopy(language, 'settingsNotSaved'),
        );
      }
    }
  }

  SessionFact fact(Map<String, dynamic> p) => SessionFact(
    gameId: typefreeGameId(p['mode'] as String),
    outcome: Outcome.finished,
    at: DateTime.fromMillisecondsSinceEpoch(p['t'] as int),
    score: p['wpm'] as int,
    errors: p['errors'] as int,
    timeSeconds: ((p['elapsedMs'] as int) / 1000).round(),
    difficulty: p['difficulty'] as String,
    mode: (p['mode'] as String?) ?? 'practice',
    unit: 'WPM',
  );
  Future<void> saveResult() async {
    if (saved || saving || !session.finished) return;
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
      'mode': weakMode ? 'weak' : 'practice',
      't': DateTime.now().millisecondsSinceEpoch,
      ...stats.toJson(),
      'len': session.attemptedKeys,
    };
    final captured = recordedHistory ??= keyStatistics.recorder.take(
      widget.clock?.call() ?? DateTime.now().millisecondsSinceEpoch,
    );
    point['len'] = captured.len;
    point['errKeys'] = captured.errorKeys;
    final earlier = history;
    var fresh = false, isRecord = false;
    try {
      await keyStatistics.commit((doc) {
        final sessions = doc['sessions'] as List, legacy = doc['legacy'] as Map;
        if (sessions.any((x) => x['id'] == id)) return;
        isRecord = false;
        if (ex['bank'] != 'weak') {
          final key =
              'tr_progress_${ex['bank']}${plain && ex['bank'] != 'digits' ? '_plain' : ''}';
          final record = legacy[key] is String
              ? jsonDecode(legacy[key] as String) as Map
              : <String, dynamic>{};
          final done = List<String>.from((record['done'] as List?) ?? []);
          if (!done.contains(ex['id'])) done.add(ex['id'] as String);
          // Source recordFinish: a record is a positive WPM above the saved best.
          isRecord =
              stats.wpm > 0 && stats.wpm > ((record['bestWpm'] as num?) ?? 0);
          legacy[key] = jsonEncode({
            'done': done,
            'lastIdx': index,
            'bestWpm': max((record['bestWpm'] as num?) ?? 0, stats.wpm),
            'bestAcc': max((record['bestAcc'] as num?) ?? 0, stats.accuracy),
          });
        }
        if (captured.eligible(stats.wpm)) {
          sessions.add(point);
          fresh = true;
          final h = legacy['tr_history'] is String
              ? List<dynamic>.from(
                  jsonDecode(legacy['tr_history'] as String) as List,
                )
              : <dynamic>[];
          h.add(captured.point(stats.wpm, stats.accuracy, point['t'] as int));
          legacy['tr_history'] = jsonEncode(
            h.length > 300 ? h.sublist(h.length - 300) : h,
          );
        }
      });
      if (mounted) {
        setState(() {
          saved = true;
          lastRecord = isRecord;
        });
      }
      appSound.effect(isRecord ? 'record' : 'success');
      if (fresh && mounted) {
        try {
          await assistant.onGameSaved(
            fact(point),
            comparableHistory(point, earlier).map(fact).toList(),
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
          () => error = commonCopy(language, 'resultNotSaved'),
        );
      }
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  void next([int delta = 1]) {
    if (saving || session.finished && !saved) return;
    if (weakMode && delta != 0) {
      unawaited(startWeak());
      return;
    }
    setState(() {
      index = (index + delta) % exercises.length;
      reset();
    });
    unawaited(savePrefs());
    // The field was disabled while the result showed; focus it after the
    // rebuild re-enables it, or the next keystrokes go nowhere.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) inputFocus.requestFocus();
    });
  }

  /// Desktop: the Synapse panel sits beside the content (never over the
  /// active text); phones get a sheet. Both have Close (§7).
  bool synapseSide = false;

  /// The last saved result beat the bank's best WPM (source recordFinish).
  bool lastRecord = false;

  Widget synapsePanel(BuildContext c, VoidCallback close) => SynapsePanel(
    language: language,
    tr: tr,
    history: history,
    controller: assistant,
    portrait: face(c),
    animate: motion && !MediaQuery.disableAnimationsOf(c),
    onClose: close,
    onWeak: () {
      close();
      unawaited(showSection(AppSection.weakKeys));
    },
  );

  int get navIndex => section == AppSection.today
      ? 0
      : historyPage ||
            section == AppSection.weakKeys ||
            (section == AppSection.achievements &&
                achievementsBack == AppSection.progress)
      ? 2
      : section == AppSection.more || inSettings
      ? 3
      : 1;

  void navGo(int v) {
    companionMode = false;
    showSection(
      [
        AppSection.today,
        AppSection.practiceMenu,
        AppSection.progress,
        AppSection.more,
      ][v],
    );
  }

  List<(IconData, IconData, String)> get navItems => [
    (Icons.home_outlined, Icons.home, shellText(language, 'today')),
    (
      Icons.grid_view_outlined,
      Icons.grid_view_rounded,
      shellText(language, 'practice'),
    ),
    (Icons.insights_outlined, Icons.insights, shellText(language, 'progress')),
    (Icons.more_horiz, Icons.more_horiz, shellText(language, 'more')),
  ];

  /// B1: on wide screens the sections sit in a side rail, not a bottom bar.
  bool railShown(BuildContext c) =>
      section != AppSection.companion && MediaQuery.sizeOf(c).width >= 1100;

  Widget withRail(BuildContext c, Widget body) {
    if (!railShown(c)) return body;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        NavigationRail(
          selectedIndex: navIndex,
          onDestinationSelected: navGo,
          labelType: NavigationRailLabelType.all,
          minWidth: 88,
          leading: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text.rich(
              TextSpan(
                children: [
                  const TextSpan(text: 'Type'),
                  TextSpan(
                    text: 'Free',
                    style: TextStyle(color: Theme.of(c).colorScheme.primary),
                  ),
                ],
              ),
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
            ),
          ),
          destinations: [
            for (final d in navItems)
              NavigationRailDestination(
                icon: Icon(d.$1),
                selectedIcon: Icon(d.$2),
                label: Text(d.$3),
              ),
          ],
        ),
        const VerticalDivider(width: 1),
        Expanded(child: body),
      ],
    );
  }

  Widget withSynapseSide(BuildContext c, Widget body) {
    if (!synapseSide || !pet || MediaQuery.sizeOf(c).width < 960) return body;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(child: body),
        const VerticalDivider(width: 1),
        SizedBox(
          width: 360,
          child: SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: synapsePanel(c, () {
                setState(() => synapseSide = false);
                inputFocus.requestFocus();
              }),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> openAssistant() async {
    if (!pet) return;
    headerAssistant.greet();
    if (MediaQuery.sizeOf(surface).width >= 960) {
      setState(() => synapseSide = !synapseSide);
      return;
    }
    await showModalBottomSheet<void>(
      context: surface,
      isScrollControlled: true,
      builder: (c) => SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: synapsePanel(c, () => Navigator.pop(c)),
        ),
      ),
    );
    if (mounted) inputFocus.requestFocus();
  }

  Future<void> settings() => showSection(AppSection.settings);

  Future<void> changeLanguage(String next) async {
    if (saving || next == language) return;
    if (!await finishLearning() || !mounted || saving) return;
    setState(() {
      weakMode = false;
      language = next;
      custom = null;
      bank = availableBank(
        widget.resources.content,
        language,
        language == 'ru' ? 'ruWords' : 'classic',
      );
      textBank = bank;
      index = 0;
      loadKeyboard();
      assistant.dispose();
      headerAssistant.dispose();
      createAssistant();
      reset();
    });
    await savePrefs();
  }

  Future<void> finishWelcome(String picked) async {
    setState(() {
      profile = picked;
      companionMode = companionStart;
      section = companionMode ? AppSection.companion : AppSection.today;
      assistant.dispose();
      headerAssistant.dispose();
      createAssistant();
    });
    await savePrefs();
  }

  Future<void> changeProfile(String next) async {
    if (saving || next == profile) return;
    if (!await finishLearning() || !mounted) return;
    setState(() {
      profile = next;
      assistant.dispose();
      headerAssistant.dispose();
      createAssistant();
    });
    await savePrefs();
  }

  int get targetWpm {
    final raw = (widget.repository.data['legacy'] as Map)['tr_target_wpm'];
    final v = raw is String ? num.tryParse(raw) : null;
    return v != null && v.isFinite && v > 0 ? v.round() : 40;
  }

  /// One handler for every switch of the settings pages (source settings modal).
  Future<void> changeSetting(String key, Object value) async {
    if (key == 'layout') {
      if (!await finishLearning() || !mounted) return;
    }
    if (key == 'targetWpm') {
      await widget.repository.transaction((d) {
        (d['legacy'] as Map)['tr_target_wpm'] = '$value';
      });
      if (mounted) setState(() {});
      return;
    }
    setState(() {
      switch (key) {
        case 'hide':
          hidePattern = value as bool;
        case 'block':
          block = value as bool;
        case 'keyboard':
          showKeyboard = value as bool;
        case 'heat':
          showHeat = value as bool;
        case 'hardkeys':
          hardKeys = value as bool;
        case 'bridge':
          bridge = value as bool;
        case 'layout':
          layout = value as String;
          loadKeyboard();
        case 'sound':
          soundOn = value as bool;
        case 'voice':
          voiceOn = value as bool;
        case 'metronome':
          metroOn = value as bool;
        case 'bpm':
          metroBpm = value as int;
        case 'textSize':
          textSize = value as double;
        case 'pet':
          pet = value as bool;
          assistant.enabled = pet;
          headerAssistant.enabled = pet;
        case 'motion':
          motion = value as bool;
        case 'companion':
          appMode = value as bool ? 'companion' : 'trainer';
          companionMode = value;
          if (value) section = AppSection.companion;
      }
    });
    await savePrefs();
  }

  SettingsValues get settingsValues => SettingsValues(
    hide: hidePattern,
    block: block,
    keyboard: showKeyboard,
    layout: layout,
    heat: showHeat,
    hardKeys: hardKeys,
    bridge: bridge,
    targetWpm: targetWpm,
    sound: soundOn,
    voice: voiceOn,
    voiceAvailable: language == 'ru' || language == 'en',
    metronome: metroOn,
    bpm: metroBpm,
    pet: pet,
    motion: motion,
    textSize: textSize,
    companion: appMode == 'companion' || (appMode == null && phone),
    version: appVersion,
  );

  /// Source: the metronome ticks only in ordinary practice, never in menus,
  /// modals, tests or other modes (src/main.ts syncMetronome).
  void syncMetronome() {
    if (appForeground && metroOn && section == AppSection.practice) {
      appSound.startMetronome(metroBpm);
    } else {
      appSound.stopMetronome();
    }
  }

  Future<void> startWeak() async {
    if (saving || session.finished && !saved) return;
    try {
      await keyStatistics.flush();
    } catch (_) {
      /* Pending evidence remains available for generation and retry. */
    }
    if (!mounted) return;
    final stats = keyStatistics.currentStats;
    final letters = letterInventory(
      keyboard.snapshot,
      language == 'ru' ? 'ru' : 'en',
      activeLayout: true,
    );
    final corpus =
        (widget.resources.content['corpus'] as Map)[language] as String;
    final lines = weakDrill(corpus, language, stats, letters);
    if (lines.isEmpty) return;
    setState(() {
      if (!weakMode) weakReturnIndex = index;
      weakMode = true;
      weakLines = lines;
      index = 0;
      section = AppSection.practice;
      reset();
    });
    inputFocus.requestFocus();
  }

  void exitWeak() {
    if (saving || session.finished && !saved) return;
    setState(() {
      weakMode = false;
      index = weakReturnIndex;
      reset();
    });
    inputFocus.requestFocus();
  }

  Future<void> customText() async {
    final result = await Navigator.of(surface).push<String>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (c) =>
            CustomTextPage(tr: tr, language: language, initial: custom),
      ),
    );
    if (result != null && result.trim().isNotEmpty) {
      setState(() {
        weakMode = false;
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
      scaffoldMessengerKey: progressMessenger,
      // «Размер текста» multiplies the user's system text scale.
      builder: (context, child) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) syncMetronome();
        });
        final base = MediaQuery.of(context);
        return MediaQuery(
          data: base.copyWith(
            textScaler: TextScaler.linear(base.textScaler.scale(1) * textSize),
          ),
          child: child!,
        );
      },
      debugShowCheckedModeBanner: false,
      title: commonCopy(language, 'appTitle'),
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
    final heat = showHeat
        ? keyHeatMap(keyStatistics.currentStats)
        : <String, double>{};
    void change(VoidCallback action) {
      if (saving) return;
      setState(() {
        action();
        reset();
      });
      unawaited(savePrefs());
    }

    // Banks the author's release selection left for this language.
    final banks = {
      for (final e
          in (widget.resources.content['catalog'] as Map)[language] as List)
        (e as Map)['bank'] as String,
    };
    final digitsActive = bank == 'digits' && custom == null && !weakMode;
    final bankPicker = DropdownButton<String>(
      isExpanded: true,
      underline: const SizedBox(),
      value: bank,
      items:
          (language == 'ru'
                  ? ['ruWords', 'ruPhrases', 'classic', 'poemHymn', 'digits']
                  : ['classic', 'poemHymn', 'digits'])
              .where(banks.contains)
              .map(
                (b) => DropdownMenuItem(
                  value: b,
                  child: Text(tr('bank.$b'), overflow: TextOverflow.ellipsis),
                ),
              )
              .toList(),
      onChanged: saving
          ? null
          : (b) => change(() {
              custom = null;
              weakMode = false;
              bank = b!;
              if (bank != 'digits') textBank = bank;
              index = 0;
            }),
    );
    // Options of the exercise (B1 right pane; a sheet on narrow screens).
    // [close] dismisses the sheet before an action that leaves the options.
    Widget options(VoidCallback refresh, {VoidCallback? close}) {
      Widget check(String label, bool value, ValueChanged<bool>? on) =>
          CheckboxListTile(
            value: value,
            dense: true,
            contentPadding: EdgeInsets.zero,
            controlAffinity: ListTileControlAffinity.leading,
            title: Text(label, style: const TextStyle(fontSize: 15)),
            onChanged: saving || on == null
                ? null
                : (v) {
                    on(v!);
                    refresh();
                  },
          );
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          check(
            practiceCopy(language, 'plain'),
            plain,
            (v) => change(() => plain = v),
          ),
          if (banks.contains('digits'))
            check(
              practiceCopy(language, 'digits'),
              digitsActive,
              banks.any((b) => b != 'digits') || !digitsActive ? (v) => change(() {
                custom = null;
                weakMode = false;
                bank = v ? 'digits' : textBank;
                index = 0;
              }) : null,
            ),
          check(tr('tb.flow'), flow, (v) => change(() => flow = v)),
          check(tr('tb.heat'), showHeat, (v) {
            setState(() => showHeat = v);
            unawaited(savePrefs());
          }),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(48),
              alignment: Alignment.centerLeft,
            ),
            onPressed: saving
                ? null
                : () {
                    close?.call();
                    if (weakMode) {
                      exitWeak();
                    } else {
                      unawaited(startWeak());
                    }
                  },
            icon: const Icon(Icons.bar_chart),
            label: Text(weakMode ? tr('nav.back') : tr('tb.weak')),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(48),
              alignment: Alignment.centerLeft,
            ),
            onPressed: saving
                ? null
                : () {
                    close?.call();
                    unawaited(customText());
                  },
            icon: const Icon(Icons.edit_outlined),
            label: Text(tr('custom.title')),
          ),
        ],
      );
    }

    void showOptions() => unawaited(
      showModalBottomSheet<void>(
        context: c,
        isScrollControlled: true,
        builder: (sheet) => SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
            child: StatefulBuilder(
              builder: (sheet, set) => options(
                () => set(() {}),
                close: () => Navigator.pop(sheet),
              ),
            ),
          ),
        ),
      ),
    );

    Widget completionCard({bool wide = false}) => ResultCard(
      wide: wide,
      language: language,
      tr: tr,
      profile: profile,
      wpm: stats.wpm,
      accuracy: stats.accuracy,
      errors: stats.errors,
      saved: saved,
      saving: saving,
      record: lastRecord,
      onNext: () => next(),
      onAgain: () => next(0),
      onRetrySave: saveResult,
      pet: pet
          ? resultPet(
              assistant,
              motion && !MediaQuery.disableAnimationsOf(c),
              size: wide ? 200 : 110,
            )
          : null,
      onSynapse: pet ? openAssistant : null,
    );
    final completion = completionCard();
    if (section == AppSection.welcome) {
      return Scaffold(
        body: SafeArea(
          child: WelcomePage(
            language: language,
            tr: tr,
            onLanguage: (l) => unawaited(changeLanguage(l)),
            onDone: (p) => unawaited(finishWelcome(p)),
          ),
        ),
      );
    }
    return Scaffold(
      appBar: AppBar(
        toolbarHeight: section == AppSection.today
            ? 52 * MediaQuery.textScalerOf(c).scale(14) / 14
            : 56,
        leading:
            section == AppSection.practice ||
                coursePage ||
                section == AppSection.learn ||
                section == AppSection.compete ||
                section == AppSection.memorize ||
                section == AppSection.recall ||
                section == AppSection.exam ||
                section == AppSection.kids ||
                section == AppSection.weakKeys ||
                section == AppSection.library ||
                inSettings
            ? IconButton(
                tooltip: tr('nav.back'),
                onPressed: () => showSection(
                  section == AppSection.weakKeys
                      ? AppSection.progress
                      : section == AppSection.transfer
                      ? AppSection.dataPermissions
                      : section == AppSection.achievements
                      ? achievementsBack
                      : section == AppSection.settings ||
                            section == AppSection.profileLanguage ||
                            section == AppSection.account ||
                            section == AppSection.dataPermissions
                      ? AppSection.more
                      : section == AppSection.settingsInput ||
                            section == AppSection.settingsSound
                      ? AppSection.settings
                      : section == AppSection.practice && practiceFromLibrary
                      ? AppSection.library
                      : menuHome,
                ),
                icon: const Icon(Icons.arrow_back),
              )
            : null,
        title: section == AppSection.today
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    shellText(language, 'today'),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 1),
                  Text(
                    shellText(language, 'intro'),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 10),
                  ),
                ],
              )
            : Text(
                section == AppSection.today
                    ? shellText(language, 'today')
                    : section == AppSection.practiceMenu
                    ? shellText(language, 'practice')
                    : section == AppSection.weakKeys
                    ? tr('weak.title')
                    : historyPage
                    ? shellText(language, 'progress')
                    : section == AppSection.more
                    ? shellText(language, 'more')
                    : section == AppSection.settings
                    ? tr('hub.settings')
                    : section == AppSection.settingsInput
                    ? settingsCopy(language, 'input')
                    : section == AppSection.settingsSound
                    ? settingsCopy(language, 'sound')
                    : section == AppSection.profileLanguage
                    ? profileCopy(language, 'title')
                    : section == AppSection.achievements
                    ? tr('ach.title')
                    : section == AppSection.companion
                    ? settingsCopy(language, 'companion')
                    : section == AppSection.library
                    ? libraryCopy(language, 'title')
                    : section == AppSection.account
                    ? accountCopy(language, 'account')
                    : section == AppSection.dataPermissions
                    ? accountCopy(language, 'data')
                    : section == AppSection.transfer
                    ? transferCopy(language, 'short')
                    : section == AppSection.kids
                    ? tr('k.title')
                    : section == AppSection.exam
                    ? tr('ex.title')
                    : section == AppSection.recall
                    ? tr('span.title')
                    : section == AppSection.memorize
                    ? tr('mem.title')
                    : section == AppSection.compete
                    ? tr('compete.title')
                    : section == AppSection.learn
                    ? tr('learn.title')
                    : coursePage
                    ? tr('course.title')
                    : tr('hub.train'),
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
        actions: [
          if (section == AppSection.today)
            IconButton(
              tooltip: shellText(language, 'progress'),
              onPressed: () => showSection(AppSection.progress),
              icon: const Icon(Icons.calendar_today_outlined, size: 20),
            ),
          // Sheets A–M draw no language picker or gear in the header: the
          // language lives in «Ещё → Профиль и язык», settings in «Ещё».
          // The gear stays where settings are needed mid-task: the trainer
          // and the companion (its F4 switch).
          if (section == AppSection.practice ||
              section == AppSection.companion)
            IconButton(
              tooltip: tr('hub.settings'),
              onPressed: settings,
              icon: const Icon(Icons.settings_outlined),
            ),
          SynapseHeaderButton(
            enabled: pet,
            portrait: face(c),
            onOpen: openAssistant,
            label: synapseName(language),
            showLabel: MediaQuery.sizeOf(c).width >= 960,
          ),
        ],
      ),
      bottomNavigationBar: section == AppSection.companion || railShown(c)
          ? null
          : NavigationBar(
              height: 56,
              selectedIndex: navIndex,
              onDestinationSelected: navGo,
              destinations: [
                for (final d in navItems)
                  NavigationDestination(
                    icon: Icon(d.$1),
                    selectedIcon: Icon(d.$2),
                    label: d.$3,
                  ),
              ],
            ),
      body: withRail(c, withSynapseSide(c, SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
            12,
            section == AppSection.today ? 0 : 12,
            12,
            12,
          ),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1320),
              child: LayoutBuilder(
                builder: (c, bounds) {
                  final wide = bounds.maxWidth >= 1100;
                  final practice = Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      PracticeHeader(
                        language: language,
                        bankPicker: bankPicker,
                        index: index,
                        count: exercises.length,
                        onPrev: () => next(-1),
                        onNext: () => next(),
                        onOptions: wide ? null : showOptions,
                      ),
                      // Narrow: options live in the sheet, so show which
                      // ones are on (J1/J2) — each can be switched off here.
                      if (!wide && (plain || flow || showHeat || digitsActive))
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Wrap(
                            spacing: 8,
                            runSpacing: 4,
                            children: [
                              for (final (on, label, off) in [
                                (
                                  digitsActive,
                                  practiceCopy(language, 'digits'),
                                  banks.any((b) => b != 'digits') ? () => change(() {
                                    bank = textBank;
                                    index = 0;
                                  }) : null,
                                ),
                                (
                                  plain,
                                  practiceCopy(language, 'plain'),
                                  () => change(() => plain = false),
                                ),
                                (
                                  flow,
                                  tr('tb.flow'),
                                  () => change(() => flow = false),
                                ),
                                (
                                  showHeat,
                                  tr('tb.heat'),
                                  () {
                                    setState(() => showHeat = false);
                                    unawaited(savePrefs());
                                  },
                                ),
                              ])
                                if (on)
                                  InputChip(
                                    label: Text(label),
                                    selected: true,
                                    showCheckmark: false,
                                    onPressed: showOptions,
                                    deleteIcon: const Icon(
                                      Icons.close,
                                      size: 18,
                                    ),
                                    onDeleted: saving ? null : off,
                                  ),
                            ],
                          ),
                        ),
                      if (custom != null || weakMode)
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(
                            exercise['title'] as String,
                            style: Theme.of(c).textTheme.titleMedium,
                          ),
                        ),
                      const SizedBox(height: 10),
                      if (weakMode)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: Text(tr('weak.hint')),
                        ),
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(8),
                          child: hidePattern
                              ? SizedBox(
                                  height: 62,
                                  child: Center(
                                    child: Text(
                                      tr('hint.hidden'),
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontStyle: FontStyle.italic,
                                        color: Theme.of(c)
                                            .colorScheme
                                            .onSurfaceVariant,
                                      ),
                                    ),
                                  ),
                                )
                              : PatternView(session: session),
                        ),
                      ),
                      // B3: a short landscape screen keeps one thin line of
                      // numbers so the keyboard moves up.
                      if (!wide && MediaQuery.sizeOf(c).height < 500)
                        Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Text(
                            '${stats.wpm} WPM · ${stats.accuracy}% · ${stats.errors} · ${(stats.elapsedMs / 1000).toStringAsFixed(1)} s',
                            style: TextStyle(
                              fontSize: 12.5,
                              color: Theme.of(c).colorScheme.onSurfaceVariant,
                            ),
                          ),
                        )
                      else if (!wide) ...[
                        const SizedBox(height: 8),
                        StatTiles(
                          language: language,
                          wpm: stats.wpm,
                          accuracy: stats.accuracy,
                          errors: stats.errors,
                          elapsedMs: stats.elapsedMs,
                          compact: true,
                        ),
                      ],
                      const SizedBox(height: 8),
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
                        onEditingComplete: () {},
                        onSubmitted: (_) => enter(),
                        decoration: InputDecoration(
                          border: const OutlineInputBorder(),
                          labelText: commonCopy(language, 'typeHere'),
                          hintText: commonCopy(language, 'keyboardInput'),
                        ),
                      ),
                      // M3 (sheet 13): on a desktop the finished result
                      // takes the keyboard's place — big Synapse + tiles.
                      if (wide && session.finished) ...[
                        const SizedBox(height: 8),
                        completionCard(wide: true),
                      ] else if (showKeyboard) ...[
                        const SizedBox(height: 8),
                        Card(
                          child: Padding(
                            padding: const EdgeInsets.all(8),
                            child: KeyboardGuide(
                                language: language,
                              model: keyboard,
                              heat: heat,
                              expected: session.expected,
                              ru: language == 'ru',
                            ),
                          ),
                        ),
                      ],
                      if (showHeat)
                        Text(
                          heat.isEmpty
                              ? adaptiveNoData(language)
                              : '${tr('heat.mastered')} → ${tr('heat.weak')}',
                          style: Theme.of(c).textTheme.bodySmall,
                        ),
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
                  if (section == AppSection.today) return todayView(c);
                  if (section == AppSection.practiceMenu) {
                    return practiceMenu(c);
                  }
                  if (section == AppSection.more) return moreView(c);
                  if (section == AppSection.settings) {
                    return SettingsHub(
                      language: language,
                      values: settingsValues,
                      onInput: () => showSection(AppSection.settingsInput),
                      onSound: () => showSection(AppSection.settingsSound),
                    );
                  }
                  if (section == AppSection.account) {
                    return AccountPage(language: language);
                  }
                  if (section == AppSection.dataPermissions) {
                    return DataPage(
                      language: language,
                      repository: widget.repository,
                      exporter: widget.artifactExporter,
                      clock: widget.clock,
                      onTransfer: () => showSection(AppSection.transfer),
                    );
                  }
                  if (section == AppSection.transfer) {
                    return TransferPage(
                      language: language,
                      repository: widget.repository,
                      pick: widget.transferPicker ?? pickTransferFile,
                    );
                  }
                  if (section == AppSection.library) {
                    return LibraryPage(
                      key: ValueKey('library-$language'),
                      language: language,
                      tr: tr,
                      banks: libraryBanks,
                      onOpen: openBank,
                    );
                  }
                  if (section == AppSection.companion) {
                    final doc = widget.repository.data;
                    final rows = ProgressView(doc).timeline
                        .where((r) => r['historyEligible'] != false)
                        .toList();
                    return CompanionPage(
                      migrationNotice: migrationNotice(),
                      tr: tr,
                      language: language,
                      streak: utcStreak(
                        rows.map((r) => r['t'] as num),
                        DateTime.now().millisecondsSinceEpoch,
                      ),
                      sessions: rows.length,
                      best: rows.fold<num>(
                        0,
                        (n, r) => max(n, r['wpm'] as num),
                      ),
                      earned: {
                        ...ProgressView(doc).achievements,
                        ...eligibleAchievementIds(
                          doc,
                          DateTime.now().millisecondsSinceEpoch,
                        ),
                      },
                      onTrainer: () => openTrainerFromCompanion(true),
                      onLearn: () => showSection(AppSection.learn),
                      onCompete: () => showSection(AppSection.compete),
                    );
                  }
                  if (section == AppSection.achievements) {
                    return AchievementsPage(
                      repository: widget.repository,
                      language: language,
                      tr: tr,
                      clock: widget.clock,
                    );
                  }
                  if (section == AppSection.profileLanguage) {
                    return ListenableBuilder(
                      listenable: widget.appearance,
                      builder: (c, _) => ProfileLanguagePage(
                        language: language,
                        profile: profile,
                        tr: tr,
                        appearance: widget.appearance,
                        busy: saving,
                        onProfile: (p) => unawaited(changeProfile(p)),
                        onLanguage: (l) => unawaited(changeLanguage(l)),
                      ),
                    );
                  }
                  if (section == AppSection.settingsInput) {
                    return InputSettingsPage(
                      language: language,
                      tr: tr,
                      values: settingsValues,
                      onChanged: (k, v) => unawaited(changeSetting(k, v)),
                    );
                  }
                  if (section == AppSection.settingsSound) {
                    return ListenableBuilder(
                      listenable: widget.appearance,
                      builder: (_, _) => SoundSettingsPage(
                        language: language,
                        tr: tr,
                        values: settingsValues,
                        appearance: widget.appearance,
                        onChanged: (k, v) => unawaited(changeSetting(k, v)),
                        onTestSound: () => appSound.effect('record'),
                      ),
                    );
                  }
                  if (historyPage) return historyView(c);
                  if (section == AppSection.weakKeys) {
                    return WeakKeysPage(
                      keyboard: keyboard,
                      statistics: keyStatistics.currentStats,
                      sessions: history,
                      language: language,
                      profile: profile,
                      tr: tr,
                      onGenerate: startWeak,
                    );
                  }
                  if (section == AppSection.kids) {
                    final rows = widget.resources.kids['levels'];
                    if (rows is! List || rows.isEmpty) {
                      return Text(tr('err.load'));
                    }
                    return KidsPage(
                      key: kidsKey,
                      repository: widget.repository,
                      levels: rows
                          .map(
                            (row) => KidsLevel.fromJson(
                              Map<String, dynamic>.from(row as Map),
                            ),
                          )
                          .toList(),
                      activity: kidsActivity,
                      keyboard: keyboard,
                      tr: tr,
                      language: language,
                      onAI: () => unawaited(showSection(AppSection.learn)),
                      onTyping: () {
                        if (headerAssistant.pose != SynapsePose.idle) {
                          headerAssistant.idle();
                        }
                      },
                    );
                  }
                  if (section == AppSection.exam) {
                    return ExamPage(
                      key: examKey,
                      initialMinutes: examMinutes,
                      exporter: widget.artifactExporter,
                      repository: widget.repository,
                      keyStatistics: keyStatistics,
                      catalog: Map<String, dynamic>.from(
                        widget.resources.content['catalog'] as Map,
                      ),
                      language: language,
                      profile: profile,
                      keyboard: keyboard,
                      tr: tr,
                      clock: widget.clock,
                      onExit: () => showSection(menuHome),
                      onTyping: () {
                        if (headerAssistant.pose != SynapsePose.idle) {
                          headerAssistant.idle();
                        }
                      },
                      onSaved: (point, earlier) async {
                        if (!mounted ||
                            point['profile'] != profile ||
                            point['language'] != language) {
                          return;
                        }
                        await assistant.onGameSaved(
                          fact(point),
                          comparableHistory(point, earlier).map(fact).toList(),
                          game: GameInfo(
                            id: 'typefree.exam',
                            name: tr('ex.title'),
                            category: 'typing',
                          ),
                        );
                        await widget.repository.transaction((d) {
                          (d['prefs'] as Map)['synapseMemory_$profile'] =
                              assistant.memory.toJson();
                        });
                      },
                    );
                  }
                  if (section == AppSection.recall) {
                    return RecallPage(
                      key: recallKey,
                      repository: widget.repository,
                      keyStatistics: keyStatistics,
                      corpus:
                          (widget.resources.content['corpus'] as Map)[language]
                              as String,
                      adaptation: recallAdaptation,
                      language: language,
                      profile: profile,
                      keyboard: keyboard,
                      tr: tr,
                      clock: widget.clock,
                      onTyping: () {
                        if (headerAssistant.pose != SynapsePose.idle) {
                          headerAssistant.idle();
                        }
                      },
                      onSaved: (point, earlier) async {
                        if (!mounted ||
                            point['profile'] != profile ||
                            point['language'] != language) {
                          return;
                        }
                        await assistant.onGameSaved(
                          fact(point),
                          comparableHistory(point, earlier).map(fact).toList(),
                          game: GameInfo(
                            id: 'typefree.recall',
                            name: tr('span.title'),
                            category: 'typing',
                          ),
                        );
                        await widget.repository.transaction((d) {
                          (d['prefs'] as Map)['synapseMemory_$profile'] =
                              assistant.memory.toJson();
                        });
                      },
                    );
                  }
                  if (section == AppSection.memorize) {
                    return MemorizePage(
                      key: memorizeKey,
                      repository: widget.repository,
                      keyStatistics: keyStatistics,
                      catalog: Map<String, dynamic>.from(
                        widget.resources.content['catalog'] as Map,
                      ),
                      language: language,
                      profile: profile,
                      keyboard: keyboard,
                      tr: tr,
                      clock: widget.clock,
                      onTyping: () {
                        if (headerAssistant.pose != SynapsePose.idle) {
                          headerAssistant.idle();
                        }
                      },
                      onSaved: (point, earlier) async {
                        if (!mounted ||
                            point['profile'] != profile ||
                            point['language'] != language) {
                          return;
                        }
                        await assistant.onGameSaved(
                          fact(point),
                          comparableHistory(point, earlier).map(fact).toList(),
                          game: GameInfo(
                            id: 'typefree.memorize',
                            name: tr('mem.title'),
                            category: 'typing',
                          ),
                        );
                        await widget.repository.transaction((d) {
                          (d['prefs'] as Map)['synapseMemory_$profile'] =
                              assistant.memory.toJson();
                        });
                      },
                    );
                  }
                  if (section == AppSection.compete) {
                    return CompetitionPage(
                      key: competitionKey,
                      repository: widget.repository,
                      keyStatistics: keyStatistics,
                      language: language,
                      profile: profile,
                      keyboard: keyboard,
                      tr: tr,
                      clock: widget.clock,
                      onExit: () => showSection(menuHome),
                      onTyping: () {
                        if (headerAssistant.pose != SynapsePose.idle) {
                          headerAssistant.idle();
                        }
                      },
                      onSaved: (point, earlier) async {
                        if (!mounted ||
                            point['profile'] != profile ||
                            point['language'] != language) {
                          return;
                        }
                        await assistant.onGameSaved(
                          fact(point),
                          comparableHistory(point, earlier).map(fact).toList(),
                          game: GameInfo(
                            id: 'typefree.compete',
                            name: tr('compete.title'),
                            category: 'typing',
                          ),
                        );
                        await widget.repository.transaction((d) {
                          (d['prefs'] as Map)['synapseMemory_$profile'] =
                              assistant.memory.toJson();
                        });
                      },
                    );
                  }
                  if (section == AppSection.learn) {
                    return LearningPage(
                      key: learningKey,
                      repository: widget.repository,
                      keyStatistics: keyStatistics,
                      corpus:
                          (widget.resources.content['corpus'] as Map)[language]
                              as String,
                      normalization: Map<String, String>.from(
                        widget.resources.learning['normalization'] as Map,
                      ),
                      language: language,
                      profile: profile,
                      keyboard: keyboard,
                      adaptation: learningAdaptation,
                      tr: tr,
                      clock: widget.clock,
                      hardKeys: hardKeys,
                      onTyping: () {
                        if (headerAssistant.pose != SynapsePose.idle) {
                          headerAssistant.idle();
                        }
                      },
                      onExit: () => showSection(menuHome),
                      onSaved: (point, earlier) async {
                        if (!mounted ||
                            point['profile'] != profile ||
                            point['language'] != language) {
                          return;
                        }
                        await assistant.onGameSaved(
                          fact(point),
                          comparableHistory(point, earlier).map(fact).toList(),
                          game: GameInfo(
                            id: 'typefree.learn',
                            name: tr('learn.title'),
                            category: 'typing',
                          ),
                        );
                        await widget.repository.transaction((d) {
                          (d['prefs'] as Map)['synapseMemory_$profile'] =
                              assistant.memory.toJson();
                        });
                      },
                    );
                  }
                  if (coursePage) {
                    return CoursePage(
                      keyStatistics: keyStatistics,
                      key: ValueKey('course-$language-$profile'),
                      initialLessonId: courseStartLessonId,
                      data: widget.resources.course,
                      repository: widget.repository,
                      language: language,
                      profile: profile,
                      keyboard: keyboard,
                      tr: tr,
                      clock: widget.clock,
                      onSaved: (point, earlier) async {
                        if (!mounted ||
                            point['profile'] != profile ||
                            point['language'] != language) {
                          return;
                        }
                        try {
                          await assistant.onGameSaved(
                            fact(point),
                            comparableHistory(
                              point,
                              earlier,
                            ).map(fact).toList(),
                            game: GameInfo(
                              id: 'typefree.course',
                              name: tr('course.title'),
                              category: 'typing',
                            ),
                          );
                          await widget.repository.transaction((d) {
                            (d['prefs'] as Map)['synapseMemory_$profile'] =
                                assistant.memory.toJson();
                          });
                        } catch (_) {
                          /* Result was saved; optional companion never invalidates it. */
                        }
                      },
                    );
                  }
                  if (!wide) return practice;
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: practice),
                      const SizedBox(width: 20),
                      SizedBox(
                        width: 300,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // Live numbers; the finished result is the M3
                            // card in the main column (no duplicate here).
                            if (!session.finished)
                              StatTiles(
                                language: language,
                                wpm: stats.wpm,
                                accuracy: stats.accuracy,
                                errors: stats.errors,
                                elapsedMs: stats.elapsedMs,
                              ),
                            const SizedBox(height: 16),
                            Text(
                              practiceCopy(language, 'options'),
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 4),
                            options(() {}),
                            if (!sameIdBuild) ...[
                              const SizedBox(height: 24),
                              Text(
                                commonCopy(language, 'candidateNote'),
                                style: TextStyle(fontSize: 12),
                              ),
                            ],
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
      ))),
    );
  }

  /// Average WPM of this profile per day, the last seven days (null = none).
  List<double?> weekWpm() {
    final now = DateTime.now();
    final day0 = DateTime(now.year, now.month, now.day - 6);
    final sums = List<double>.filled(7, 0), counts = List<int>.filled(7, 0);
    for (final r in history) {
      if (r['profile'] != profile || r['wpm'] is! num) continue;
      final d = DateTime.fromMillisecondsSinceEpoch((r['t'] as num).toInt());
      final i = DateTime(d.year, d.month, d.day).difference(day0).inDays;
      if (i < 0 || i > 6) continue;
      sums[i] += (r['wpm'] as num).toDouble();
      counts[i]++;
    }
    return [for (var i = 0; i < 7; i++) counts[i] == 0 ? null : sums[i] / counts[i]];
  }

  Widget? migrationNotice() => widget.migrationPending
      ? Card(
          key: const ValueKey('home-migration-pending'),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(progressCopy(language, 'migrationPending')),
                TextButton(
                  key: const ValueKey('home-migration-open'),
                  onPressed: () => showSection(AppSection.progress),
                  child: Text(progressCopy(language, 'migrationOpen')),
                ),
              ],
            ),
          ),
        )
      : null;

  Widget todayView(BuildContext c) {
    final lessons = List<Map<String, dynamic>>.from(
      (widget.resources.course['lessons'] as Map)[language] as List,
    );
    final summary = TodaySummary(
      widget.repository.data,
      profile: profile,
      language: language,
      now: DateTime.now(),
      lessonCount: lessons.length,
    );
    final lesson = lessons[summary.nextLesson - 1];
    final title =
        tr(lesson['titleKey'] as String) +
        (lesson['titleArg'] == null ? '' : ': ${lesson['titleArg']}');
    final layout = widget.appearance.registry
        .resolve(widget.appearance.selection.templateId)
        .layoutId;
    if (layout == 'speed-home-v1') {
      return SpeedHome(
        migrationNotice: migrationNotice(),
        language: language,
        summary: summary,
        lessonTitle: title,
        customTitle: tr('custom.title'),
        modes: [
          for (final m in modeEntries)
            HomeMode(m.home, m.title, m.subtitle, m.onTap),
        ],
        weakKeys: weakLetters(
          keyStatistics.currentStats,
          letterInventory(
            keyboard.snapshot,
            language == 'ru' ? 'ru' : 'en',
            activeLayout: true,
          ),
          count: 3,
        ),
        week: weekWpm(),
        onStart: () => showSection(AppSection.practice),
        onSpeedTest: () => openExam(1),
        onCustomText: () async {
          await showSection(AppSection.practice);
          await customText();
        },
        onCourse: () {
          setState(() {
            courseStartLessonId = summary.nextLesson;
            section = AppSection.course;
          });
        },
        onWeak: () => unawaited(startWeak()),
        onProgress: () => showSection(AppSection.progress),
      );
    }
    return TodayPage(
      migrationNotice: migrationNotice(),
      summary: summary,
      language: language,
      lessonTitle: title,
      onPractice: () => showSection(AppSection.practice),
      onCourse: () {
        setState(() {
          courseStartLessonId = summary.nextLesson;
          section = AppSection.course;
        });
      },
      onProgress: () => showSection(AppSection.progress),
    );
  }

  /// The eight modes: one list for the Practice menu and the speed home, so
  /// both open exactly the same pages. `home` is the speed-home icon (ref
  /// DESIGN_REF 29.10: Тренировка = keyboard, not a runner).
  List<({IconData icon, IconData home, int accent, String title, String subtitle, VoidCallback onTap})>
  get modeEntries => [
    (
      icon: Icons.bolt,
      home: Icons.keyboard_outlined,
      accent: 0xFFF07B2B,
      title: tr('hub.train'),
      subtitle: tr('hub.train.d'),
      onTap: () => showSection(AppSection.library),
    ),
    (
      icon: Icons.menu_book_outlined,
      home: Icons.menu_book_outlined,
      accent: 0xFF3B82F6,
      title: tr('course.title'),
      subtitle: tr('hub.course.d'),
      onTap: () {
        setState(() {
          courseStartLessonId = null;
          section = AppSection.course;
        });
      },
    ),
    (
      icon: Icons.psychology_alt_outlined,
      home: Icons.auto_awesome_outlined,
      accent: 0xFF8B5CF6,
      title: tr('learn.title'),
      subtitle: tr('hub.learn.d'),
      onTap: () => showSection(AppSection.learn),
    ),
    (
      icon: Icons.emoji_events_outlined,
      home: Icons.emoji_events_outlined,
      accent: 0xFFE5484D,
      title: tr('compete.title'),
      subtitle: tr('hub.compete.d.store'),
      onTap: () => showSection(AppSection.compete),
    ),
    (
      icon: Icons.description_outlined,
      home: Icons.description_outlined,
      accent: 0xFF22B07D,
      title: tr('mem.title'),
      subtitle: tr('hub.mem.d'),
      onTap: () => showSection(AppSection.memorize),
    ),
    (
      icon: Icons.extension_outlined,
      home: Icons.layers_outlined,
      accent: 0xFFF5B82E,
      title: tr('span.title'),
      subtitle: tr('hub.span.d'),
      onTap: () => showSection(AppSection.recall),
    ),
    (
      icon: Icons.speed,
      home: Icons.speed,
      accent: 0xFF14A3A3,
      title: tr('ex.title'),
      subtitle: tr('hub.exam.d'),
      onTap: () => openExam(10),
    ),
    (
      icon: Icons.pets_outlined,
      home: Icons.sentiment_satisfied_alt_outlined,
      accent: 0xFFE879A6,
      title: tr('k.title'),
      subtitle: tr('profile.kids.desc'),
      onTap: () => showSection(AppSection.kids),
    ),
  ];

  /// Typing test with a preselected length (home quick launch: 1 minute).
  void openExam(int minutes) {
    examMinutes = minutes;
    showSection(AppSection.exam);
  }

  Widget practiceMenu(BuildContext c) =>
      menuPage(c, shellText(language, 'choose'), [
        for (final m in modeEntries)
          modeTile(m.icon, m.accent, m.title, m.subtitle, m.onTap),
      ]);

  /// A3/A5 list page: subtitle under the app bar title, then coloured rows.
  Widget menuPage(BuildContext c, String subtitle, List<Widget> rows) => Center(
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 620),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            subtitle,
            style: Theme.of(c).textTheme.bodyMedium
                ?.copyWith(color: Theme.of(c).colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: 12),
          ...rows,
        ],
      ),
    ),
  );

  Widget modeTile(
    IconData icon,
    int accent,
    String title,
    String subtitle,
    VoidCallback action,
  ) => NavTile(
    icon: icon,
    accent: Color(accent),
    title: title,
    subtitle: subtitle,
    onTap: action,
  );

  Widget moreView(BuildContext c) =>
      menuPage(c, profileCopy(language, 'more.d'), [
        modeTile(
          Icons.settings_outlined,
          0xFF64748B,
          tr('hub.settings'),
          settingsCopy(language, 'sound.d'),
          settings,
        ),
        modeTile(
          Icons.person_outline,
          0xFF4F8DFD,
          profileCopy(language, 'title'),
          profileCopy(language, 'title.d'),
          () => showSection(AppSection.profileLanguage),
        ),
        modeTile(
          Icons.emoji_events_outlined,
          0xFFF07B2B,
          tr('ach.title'),
          profileCopy(language, 'ach.d'),
          () {
            achievementsBack = AppSection.more;
            showSection(AppSection.achievements);
          },
        ),
        modeTile(
          Icons.cloud_outlined,
          0xFF3B82F6,
          accountCopy(language, 'account'),
          accountCopy(language, 'account.d'),
          () => showSection(AppSection.account),
        ),
        modeTile(
          Icons.verified_user_outlined,
          0xFF22B07D,
          accountCopy(language, 'data'),
          accountCopy(language, 'data.d'),
          () => showSection(AppSection.dataPermissions),
        ),
        modeTile(
          Icons.insights_outlined,
          0xFF14A3A3,
          shellText(language, 'progress'),
          tr('hub.progress.d'),
          () => showSection(AppSection.progress),
        ),
        const SizedBox(height: 8),
        Text(
          shellText(language, 'local'),
          style: Theme.of(c).textTheme.bodySmall,
        ),
      ]);

  Widget historyView(BuildContext c) => ProgressPage(
    repository: widget.repository,
    migrationPending: widget.migrationPending,
    profile: profile,
    language: language,
    tr: tr,
    onWeak: () => unawaited(showSection(AppSection.weakKeys)),
    onAchievements: () {
      achievementsBack = AppSection.progress;
      unawaited(showSection(AppSection.achievements));
    },
    exporter: widget.artifactExporter,
    clock: widget.clock,
  );
}
