/// Teacher cabinet stand: the six cabinet screens in TypeFree's frame and
/// theme, on a stand-in server (made-up names, no network, no account).
/// For screenshots and design review only — the app entry point is main.dart.
///
///   flutter build ios --simulator --debug -t lib/coach_preview.dart
///   xcrun simctl openurl DEVICE 'pro.typefree.app://preview?screen=2&lang=ru'
///
/// screen: 1 sign-in · 2 teacher cabinet with students · 3 a student's
/// trainings · 4 invite with its link · 5 consent · 6 my teachers.
library;

import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:ecosystem_coach/ecosystem_coach.dart';
import 'package:flutter/material.dart';

import 'data/coach_bridge.dart';
import 'data/coach_projection.dart';
import 'design_system/templates.dart';
import 'main.dart' show Resources, PreferenceStore;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final resources = await Resources.load();
  final appearance = AppearanceController(
    resources.registry,
    PreferenceStore(),
    existingInstall: true,
  );
  runApp(_Stand(appearance: appearance, content: resources.content));
}

class _Stand extends StatefulWidget {
  const _Stand({required this.appearance, required this.content});
  final AppearanceController appearance;
  final Map<String, dynamic> content;
  @override
  State<_Stand> createState() => _StandState();
}

class _StandState extends State<_Stand> {
  final _nav = GlobalKey<NavigatorState>();
  StreamSubscription<Uri>? _sub;
  int _screen = const int.fromEnvironment('COACH_SCREEN', defaultValue: 2);
  String _lang = const String.fromEnvironment('COACH_LANG', defaultValue: 'ru');

  @override
  void initState() {
    super.initState();
    _sub = AppLinks().uriLinkStream.listen((u) {
      if (u.host != 'preview') return;
      setState(() {
        _screen = int.tryParse(u.queryParameters['screen'] ?? '') ?? _screen;
        _lang = u.queryParameters['lang'] ?? _lang;
        _invited = false;
      });
      _nav.currentState?.pushAndRemoveUntil(
        PageRouteBuilder<void>(pageBuilder: (_, _, _) => _page()),
        (_) => false,
      );
    }, onError: (Object _) {});
  }

  @override
  void dispose() {
    unawaited(_sub?.cancel());
    super.dispose();
  }

  Widget _page() {
    final strings = _lang == 'ru' ? CoachStrings.ru : CoachStrings.en;
    final frame = typeFreeCoachFrame(_lang);
    final client = CoachClient(_StandServer(), appId: 'typerighting');
    final signedIn = _StandAuth(signedIn: true);
    String title(CoachEventView e) =>
        coachEventTitle(e, language: _lang, content: widget.content);
    return switch (_screen) {
      1 => TeacherCabinetScreen(
        client: CoachClient(
          _StandServer(signedIn: false),
          appId: 'typerighting',
        ),
        auth: _StandAuth(signedIn: false),
        strings: strings,
        frame: frame,
      ),
      3 => StudentDetailScreen(
        client: client,
        student: CoachDashboard.fromJson(_StandServer.board).students.first,
        strings: strings,
        frame: frame,
        eventTitle: title,
      ),
      4 => TeacherCabinetScreen(
        client: client,
        auth: signedIn,
        strings: strings,
        eventTitle: title,
        // Press «Invite» once the screen is up, as a teacher would.
        frame: (context, title, body, actions) {
          final invite = actions.where(
            (a) => a.key == const Key('coach-invite'),
          );
          if (invite.isNotEmpty && !_invited) {
            _invited = true;
            WidgetsBinding.instance.addPostFrameCallback(
              (_) => invite.first.onPressed(),
            );
          }
          return frame(context, title, body, actions);
        },
      ),
      5 => AcceptInviteScreen(
        client: client,
        code: 'c0ffee' * 8,
        studentName: _lang == 'ru' ? 'Аня Петрова' : 'Anna Peters',
        auth: signedIn,
        strings: strings,
        frame: frame,
      ),
      6 => MyCoachesScreen(
        client: client,
        auth: signedIn,
        strings: strings,
        frame: frame,
      ),
      _ => TeacherCabinetScreen(
        client: client,
        auth: signedIn,
        strings: strings,
        frame: frame,
        eventTitle: title,
      ),
    };
  }

  bool _invited = false;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.appearance,
    builder: (c, _) => MaterialApp(
      navigatorKey: _nav,
      debugShowCheckedModeBanner: false,
      theme: widget.appearance.theme(Brightness.light),
      home: Builder(builder: (_) => _page()),
    ),
  );
}

class _StandAuth extends ChangeNotifier implements CoachAuth {
  _StandAuth({required this.signedIn});
  @override
  final bool signedIn;
  @override
  String? get email => signedIn ? 'teacher@example.com' : null;
  @override
  bool get googleAvailable => true;
  @override
  Future<void> signInWithGoogle() async {}
  @override
  Future<void> sendEmailLink(String email) async {}
  @override
  Future<void> signOut() async {}
}

/// Answers like `ecosystem_coach_v2` would, from made-up data.
class _StandServer implements CoachTransport {
  _StandServer({this.signedIn = true});

  /// Signed out: the real transport refuses every call before the network.
  final bool signedIn;
  static final _now = DateTime.now().toUtc();
  static String _ago(int minutes) =>
      _now.subtract(Duration(minutes: minutes)).toIso8601String();

  static final board = <String, Object?>{
    'profile': {'name': 'Marina Sokolova'},
    'students': [
      {
        'connection_id': 's1',
        'student_name': 'Anna Peters',
        'since': _ago(60 * 24 * 9),
        'apps': [
          {
            'app_id': 'typerighting',
            'scopes': ['completion', 'metrics', 'errors', 'history'],
            'granted_at': _ago(60 * 24 * 9),
            'events': 14,
            'last_at': _ago(35),
          },
          {
            'app_id': 'psygames',
            'scopes': ['completion', 'metrics'],
            'granted_at': _ago(60 * 24 * 5),
            'events': 6,
            'last_at': _ago(60 * 26),
          },
        ],
      },
      {
        'connection_id': 's2',
        'student_name': 'Leo Martin',
        'since': _ago(60 * 24 * 3),
        'apps': [
          {
            'app_id': 'typerighting',
            'scopes': ['completion', 'metrics', 'history'],
            'granted_at': _ago(60 * 24 * 3),
            'events': 5,
            'last_at': _ago(60 * 4),
          },
        ],
      },
      {
        'connection_id': 's3',
        'student_name': 'Sofia Lee',
        'since': _ago(60 * 24),
        'apps': [
          {
            'app_id': 'typerighting',
            'scopes': ['completion'],
            'granted_at': _ago(60 * 24),
            'events': 1,
            'last_at': _ago(60 * 20),
          },
        ],
      },
    ],
    'coaches': [
      {
        'connection_id': 'c1',
        'coach_name': 'Marina Sokolova',
        'since': _ago(60 * 24 * 9),
        'apps': [
          {
            'app_id': 'typerighting',
            'scopes': ['completion', 'metrics', 'history'],
            'granted_at': _ago(60 * 24 * 9),
          },
        ],
      },
      {
        'connection_id': 'c2',
        'coach_name': 'Daniel Brooks',
        'since': _ago(60 * 24 * 2),
        'apps': [
          {
            'app_id': 'typerighting',
            'scopes': ['completion'],
            'granted_at': _ago(60 * 24 * 2),
          },
          {
            'app_id': 'psygames',
            'scopes': ['completion', 'metrics', 'errors'],
            'granted_at': _ago(60 * 24 * 2),
          },
        ],
      },
    ],
  };

  /// A TypeFree history row as the server stores it: through the real
  /// projection (all scopes granted), exactly what the app would send.
  static Map<String, Object?> _event(Map<String, dynamic> row, int ago) {
    final json = coachProjection(
      {
        ...row,
        't': _now.subtract(Duration(minutes: ago)).millisecondsSinceEpoch,
      },
      scopes: const {'completion', 'metrics', 'errors', 'history'},
      consentSince: 0,
    )!;
    return {...json, 'id': json['event_id'], 'app_id': 'typerighting'};
  }

  @override
  Future<Object?> call(String action, Map<String, Object?> payload) async {
    if (!signedIn) throw const CoachException('coach_sign_in_required');
    switch (action) {
      case 'dashboard':
        return board;
      case 'student_events':
        if (payload['app_id'] == 'psygames') {
          return {
            'events': [
              {
                'id': 'p1',
                'app_id': 'psygames',
                'kind': 'game',
                'mode': 'schulte',
                'exercise_ref': 'schulte:5x5',
                'occurred_at': _ago(60 * 26),
                'metrics': {'score': 120, 'time_seconds': 41},
              },
            ],
          };
        }
        return {
          'events': [
            _event({
              'id': 'e1',
              'mode': 'course',
              'exercise': 'course-12',
              'language': 'ru',
              'wpm': 52,
              'accuracy': 97,
              'errors': 3,
              'elapsedMs': 41000,
              'typed': 160,
              'stars': 3,
              'errKeys': {'k': 2, 'semicolon': 1},
            }, 35),
            _event({
              'id': 'e2',
              'mode': 'practice',
              'exercise': 'classic-ru-1',
              'language': 'ru',
              'wpm': 48,
              'accuracy': 95,
              'errors': 5,
              'elapsedMs': 64000,
              'typed': 300,
              'errKeys': {'j': 3, 'f': 2},
            }, 60 * 3),
            _event({
              'id': 'e3',
              'mode': 'compete',
              'exercise': 'alpha_fwd',
              'language': 'ru',
              'wpm': 61,
              'accuracy': 98,
              'errors': 1,
              'elapsedMs': 9500,
              'typed': 33,
              'medal': 'silver',
              'errKeys': {'q': 1},
            }, 60 * 27),
            _event({
              'id': 'e4',
              'mode': 'exam',
              'exercise': 'exam',
              'language': 'ru',
              'wpm': 45,
              'accuracy': 96,
              'errors': 9,
              'elapsedMs': 300000,
              'typed': 1100,
              'target': 40,
              'durationMinutes': 5,
              'errKeys': {'b': 4, 'n': 5},
            }, 60 * 50),
          ],
        };
      case 'invite_create':
        return {
          'code': '7f3a9c2e5b81d4f06a2e9c7b3d51f8a40c6e2b9d7a15f3c8',
          'expires_at': _now.add(const Duration(days: 7)).toIso8601String(),
        };
      case 'invite_preview':
        return {
          'coach_name': 'Marina Sokolova',
          'expires_at': _now.add(const Duration(days: 6)).toIso8601String(),
        };
      default:
        return {'stored': false};
    }
  }
}
