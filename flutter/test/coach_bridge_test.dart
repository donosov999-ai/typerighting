import 'package:ecosystem_coach/ecosystem_coach.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:typefree_flutter_foundation/data/coach_bridge.dart';
import 'package:typefree_flutter_foundation/data/key_statistics_store.dart';
import 'package:typefree_flutter_foundation/data/local_repository.dart';
import 'package:typefree_flutter_foundation/data/string_store.dart';
import 'package:typefree_flutter_foundation/design_system/templates.dart';
import 'package:typefree_flutter_foundation/main.dart';

import 'practice_flow_test.dart' show AppearanceMemory;

class _Store implements StringStore {
  final values = <String, String>{};
  @override
  Future<String?> read(String key) async => values[key];
  @override
  Future<void> write(String key, String value) async => values[key] = value;
}

/// Stand-in server: `dashboard` answers with the student's teachers,
/// `result_submit` records the event.
class _Transport implements CoachTransport {
  _Transport({this.apps = const []});
  final List<Map<String, Object?>> apps;
  final calls = <String>[];
  final sent = <Map<String, Object?>>[];
  bool fail = false;
  @override
  Future<Object?> call(String action, Map<String, Object?> payload) async {
    calls.add(action);
    if (fail) throw const CoachException('coach_unavailable');
    if (action == 'dashboard') {
      return {
        'coaches': [
          {'connection_id': 'c1', 'coach_name': 'Teacher', 'apps': apps},
        ],
      };
    }
    sent.add(payload);
    return {'stored': true};
  }
}

const _consentAt = '2026-11-01T00:00:00.000Z';
final _consentMs = DateTime.parse(_consentAt).millisecondsSinceEpoch;

Map<String, dynamic> _row(String id, {int? t}) => {
  'id': id,
  'title': 'Secret title',
  'exercise': 'alpha_fwd',
  'language': 'en',
  'profile': 'm',
  'mode': 'practice',
  'difficulty': 'en/classic/false/qwerty/false',
  't': t ?? _consentMs + 60000,
  'wpm': 48,
  'accuracy': 96,
  'errors': 2,
  'elapsedMs': 30000,
  'len': 120,
  'errKeys': {'k': 2},
};

/// A training save exactly as the trainer pages do it: one commit adds the row.
Future<LocalRepository> _save(List<Map<String, dynamic>> rows) async {
  final repo = LocalRepository(_Store());
  final stats = KeyStatisticsStore(repo);
  for (final row in rows) {
    await stats.commit((doc) => (doc['sessions'] as List).add(row));
  }
  await pumpEventQueue();
  return repo;
}

void main() {
  tearDown(() => KeyStatisticsStore.onSessionSaved = null);

  test(
    'cabinet is off by default: no TF_COACH flag → no instance, no hook',
    () {
      expect(TypeFreeCoach.enabled, isFalse);
      expect(TypeFreeCoach.instance, isNull);
      expect(KeyStatisticsStore.onSessionSaved, isNull);
    },
  );

  test('without the flag a saved training sends nothing', () async {
    final t = _Transport(
      apps: [
        {
          'app_id': 'typerighting',
          'scopes': ['completion', 'metrics', 'history'],
          'granted_at': _consentAt,
        },
      ],
    );
    // Built but not observing — the state when main() skipped the cabinet.
    TypeFreeCoach(CoachClient(t, appId: 'typerighting'));
    final repo = await _save([_row('s1')]);
    expect((repo.data['sessions'] as List).length, 1);
    expect(t.calls, isEmpty);
  });

  test(
    'finished training → projection → result_submit, within the scopes',
    () async {
      final t = _Transport(
        apps: [
          {
            'app_id': 'typerighting',
            'scopes': ['completion', 'metrics', 'history'],
            'granted_at': _consentAt,
          },
          {
            'app_id': 'psygames',
            'scopes': ['completion', 'errors'],
            'granted_at': '2020-01-01T00:00:00Z',
          },
        ],
      );
      final coach = TypeFreeCoach(CoachClient(t, appId: 'typerighting'))
        ..observe();
      addTearDown(coach.dispose);
      await _save([_row('s1'), _row('s2')]);

      expect(t.sent, hasLength(2));
      expect(
        t.calls.where((c) => c == 'dashboard'),
        hasLength(1),
        reason: 'consent read once, then cached',
      );
      final first = t.sent.first;
      expect(first['app_id'], 'typerighting');
      expect(first['event'], {
        'event_id': 's1',
        'kind': 'typing',
        'mode': 'practice',
        'exercise_ref': 'alpha_fwd',
        'occurred_at': DateTime.fromMillisecondsSinceEpoch(
          _consentMs + 60000,
          isUtc: true,
        ).toIso8601String(),
        'metrics': {
          'language': 'en',
          'wpm': 48,
          'accuracy': 96,
          'elapsed_ms': 30000,
          'errors': 2,
        },
      });
      expect('$first', isNot(contains('Secret title')));
      expect(
        (first['event'] as Map).containsKey('errors'),
        isFalse,
        reason: 'no errors scope for TypeFree',
      );
    },
  );

  test(
    'no consent for TypeFree, or a session from before it → nothing leaves',
    () async {
      final other = _Transport(
        apps: [
          {
            'app_id': 'psygames',
            'scopes': ['completion', 'metrics', 'history'],
            'granted_at': _consentAt,
          },
        ],
      );
      final a = TypeFreeCoach(CoachClient(other, appId: 'typerighting'))
        ..observe();
      await _save([_row('s1')]);
      expect(other.sent, isEmpty);
      a.dispose();

      final t = _Transport(
        apps: [
          {
            'app_id': 'typerighting',
            'scopes': ['completion', 'history'],
            'granted_at': _consentAt,
          },
        ],
      );
      final b = TypeFreeCoach(CoachClient(t, appId: 'typerighting'))..observe();
      addTearDown(b.dispose);
      await _save([_row('old', t: _consentMs - 1)]);
      expect(t.sent, isEmpty);
    },
  );

  test(
    'cabinet failure never breaks the save; consent is retried later',
    () async {
      final t = _Transport(
        apps: [
          {
            'app_id': 'typerighting',
            'scopes': ['completion', 'history'],
            'granted_at': _consentAt,
          },
        ],
      )..fail = true;
      final coach = TypeFreeCoach(CoachClient(t, appId: 'typerighting'))
        ..observe();
      addTearDown(coach.dispose);
      final repo = LocalRepository(_Store());
      final stats = KeyStatisticsStore(repo);
      await stats.commit((doc) => (doc['sessions'] as List).add(_row('s1')));
      await pumpEventQueue();
      expect(
        (repo.data['sessions'] as List).single['id'],
        's1',
        reason: 'saved although the cabinet is down',
      );
      expect(t.sent, isEmpty);

      t.fail = false;
      await stats.commit((doc) => (doc['sessions'] as List).add(_row('s2')));
      await pumpEventQueue();
      expect([for (final p in t.sent) (p['event'] as Map)['event_id']], ['s2']);
    },
  );

  test('a throwing listener does not fail the commit', () async {
    KeyStatisticsStore.onSessionSaved = (_) => throw StateError('boom');
    final repo = await _save([_row('s1')]);
    expect((repo.data['sessions'] as List), hasLength(1));
  });

  test('links: invite path /invite?code= opens the accept screen; /join/ and foreign schemes do not', () async {
    final coach = TypeFreeCoach(
      CoachClient(_Transport(), appId: 'typerighting'),
    );
    final code = 'a' * 48;
    expect(
      await coach.handleLink(
        Uri.parse('pro.typefree.app://coach/join/$code'),
        language: 'en',
      ),
      isFalse,
    );
    expect(
      await coach.handleLink(
        Uri.parse('com.psygames.app://coach/invite?code=$code'),
        language: 'en',
      ),
      isFalse,
    );
    expect(
      await coach.handleLink(
        Uri.parse('pro.typefree.app://coach/invite?code=short'),
        language: 'en',
      ),
      isFalse,
    );
  });

  testWidgets('invite link pushes AcceptInviteScreen in the app navigator', (
    tester,
  ) async {
    final coach = TypeFreeCoach(
      CoachClient(_Transport(), appId: 'typerighting'),
    );
    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: TypeFreeCoach.navigatorKey,
        home: const SizedBox(),
      ),
    );
    final ok = await coach.handleLink(
      Uri.parse('pro.typefree.app://coach/invite?code=${'b' * 48}'),
      language: 'ru',
    );
    expect(ok, isTrue);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byType(AcceptInviteScreen), findsOneWidget);
    expect(
      find.byTooltip('Назад'),
      findsOneWidget,
      reason: 'TypeFree frame, Russian back label',
    );
  });

  test('settings labels follow the app language (ru, otherwise en)', () {
    final coach = TypeFreeCoach(
      CoachClient(_Transport(), appId: 'typerighting'),
    );
    expect(coach.strings('ru').teacherTitle, 'Кабинет преподавателя');
    expect(coach.strings('ru').myCoaches, 'Мои преподаватели');
    expect(coach.strings('de').teacherTitle, CoachStrings.en.teacherTitle);
  });

  testWidgets(
    'settings: two cabinet rows only when the cabinet is built in; tap opens the cabinet',
    (tester) async {
      final resources = (await tester.runAsync(Resources.load))!;
      final repo = LocalRepository(_Store());
      await repo.load();
      await tester.binding.setSurfaceSize(const Size(1280, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      Future<void> openSettings() async {
        await tester.pumpWidget(
          TypeFreeApp(
            key: UniqueKey(),
            resources: resources,
            repository: repo,
            appearance: AppearanceController(
              resources.registry,
              AppearanceMemory(),
              existingInstall: true,
            ),
          ),
        );
        await tester.pump();
        final app = tester.state<TypeFreeAppState>(find.byType(TypeFreeApp));
        await app.showSection(AppSection.settings);
        await tester.pump();
        await tester.pump();
      }

      await openSettings();
      expect(
        find.byKey(const ValueKey('settings-coach-teacher')),
        findsNothing,
      );

      TypeFreeCoach.instance = TypeFreeCoach(
        CoachClient(_Transport(), appId: 'typerighting'),
      );
      addTearDown(() => TypeFreeCoach.instance = null);
      await openSettings();
      expect(
        find.byKey(const ValueKey('settings-coach-teacher')),
        findsOneWidget,
      );
      expect(find.byKey(const ValueKey('settings-coach-mine')), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('settings-coach-teacher')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.byType(TeacherCabinetScreen), findsOneWidget);
    },
  );

  test('training titles: TypeFree words for mode and public exercise, never raw ids', () async {
    final content = (await Resources.load()).content;
    CoachEventView ev(
      String mode,
      String? ref, {
      String app = 'typerighting',
    }) => CoachEventView(
      id: 'x',
      appId: app,
      kind: 'typing',
      mode: mode,
      exerciseRef: ref,
    );
    String t(CoachEventView e, String l) =>
        coachEventTitle(e, language: l, content: content);

    expect(t(ev('course', 'course-12'), 'ru'), 'Курс печати · Урок 12');
    expect(t(ev('course', 'course-12'), 'en'), 'Typing course · Lesson 12');
    expect(
      t(ev('practice', 'my-own-text'), 'ru'),
      'Практика',
      reason: 'own texts have no catalog title',
    );
    final first = ((content['catalog'] as Map)['ru'] as List).first as Map;
    expect(
      t(ev('practice', first['id'] as String), 'ru'),
      'Практика · ${first['title']}',
    );
    expect(
      t(ev('compete', 'alpha_fwd'), 'ru'),
      startsWith('Тест-соревнование · '),
    );
    expect(t(ev('compete', 'alpha_fwd'), 'ru'), isNot(contains('alpha_fwd')));
    expect(t(ev('exam', 'exam'), 'en'), 'Typing Test');
    expect(t(ev('recall', 'recall'), 'ru'), 'Память');
    expect(
      t(ev('schulte', 'schulte:5x5', app: 'psygames'), 'ru'),
      defaultEventTitle(ev('schulte', 'schulte:5x5', app: 'psygames')),
    );
  });

  test('strings carry the coach/2 additions for both languages', () {
    final coach = TypeFreeCoach(
      CoachClient(_Transport(), appId: 'typerighting'),
    );
    for (final l in ['ru', 'en', 'de']) {
      final s = coach.strings(l);
      expect(s.eventsCount, contains('{n}'));
      expect(s.lastAt, contains('{date}'));
      for (final v in [
        s.sharedScopes,
        s.metricScore,
        s.metricTime,
        s.metricLevel,
        s.metricErrors,
        s.warmup,
      ]) {
        expect(v, isNotEmpty);
      }
    }
  });
}
