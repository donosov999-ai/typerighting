import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:typefree_flutter_foundation/design_system/templates.dart';
import 'package:typefree_flutter_foundation/design_system/synapse_header.dart';

Map<String, dynamic> source() =>
    jsonDecode(File('assets/templates/registry.json').readAsStringSync())
        as Map<String, dynamic>;
TemplateRegistry registry() => TemplateRegistry.parse(source());

class TestStore implements AppearanceStore {
  Map<String, Object>? saved;
  int calls = 0;
  bool fail = false;
  Completer<void>? gate;
  @override
  Future<void> save(Map<String, Object> value) async {
    calls++;
    if (gate != null) await gate!.future;
    if (fail) throw StateError('disk full');
    saved = {...value};
  }
}

class SessionProbe extends StatefulWidget {
  const SessionProbe({super.key});
  @override
  State<SessionProbe> createState() => SessionProbeState();
}

class SessionProbeState extends State<SessionProbe> {
  final text = TextEditingController();
  final focus = FocusNode();
  final startedAt = DateTime.utc(2026, 10, 25);
  int completions = 0;
  @override
  void dispose() {
    text.dispose();
    focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Column(
      children: [
        TextField(
          key: const ValueKey('typing'),
          controller: text,
          focusNode: focus,
        ),
        Text('$completions', key: const ValueKey('completion')),
        const Text('Синапс'),
      ],
    ),
  );
}

void main() {
  test('registry rejects incomplete tokens and lost assistant slot', () {
    final broken = source();
    (((broken['templates'] as List).first as Map)['variants'] as Map)['dark']
        .remove('keyboardLegend');
    expect(() => TemplateRegistry.parse(broken), throwsFormatException);
    final missing = source();
    missing['requiredSlots'] = List.filled(7, 'app.header');
    expect(() => TemplateRegistry.parse(missing), throwsFormatException);
    final duplicate = source();
    (duplicate['templates'] as List).add(
      (duplicate['templates'] as List).first,
    );
    expect(() => TemplateRegistry.parse(duplicate), throwsFormatException);
  });

  test(
    'existing users keep classic with legacy brightness; new users get orange',
    () {
      final a = AppearanceController(
        registry(),
        TestStore(),
        existingInstall: true,
        legacyDark: false,
      );
      expect(a.selection.templateId, 'classic-blue');
      expect(a.selection.brightness, ThemeMode.light);
      final b = AppearanceController(
        registry(),
        TestStore(),
        existingInstall: false,
      );
      // New installs open the speed home (design 29.10, Denis's choice).
      expect(b.selection.templateId, 'midnight-speed-v1');
      expect(b.selection.brightness, ThemeMode.system);
      a.dispose();
      b.dispose();
    },
  );

  test(
    'preview and cancel never persist; apply persists appearance only',
    () async {
      final s = TestStore();
      final a = AppearanceController(registry(), s, existingInstall: true);
      a.preview('midnight-orange', ThemeMode.dark);
      expect(s.calls, 0);
      a.cancel();
      expect(a.selection.templateId, 'classic-blue');
      a.preview('midnight-orange', ThemeMode.dark);
      expect(await a.apply(), true);
      expect(s.saved, {
        'schema': 1,
        'templateId': 'midnight-orange',
        'brightness': 'dark',
      });
      a.dispose();
      final restored = AppearanceController(
        registry(),
        s,
        existingInstall: true,
        saved: Map<String, dynamic>.from(s.saved!),
      );
      expect(restored.selection.templateId, 'midnight-orange');
      expect(restored.selection.brightness, ThemeMode.dark);
      restored.dispose();
    },
  );

  test('unknown saved template falls back; bad preview and save failure do not commit', () async {
    final s = TestStore()..fail = true;
    final a = AppearanceController(
      registry(),
      s,
      existingInstall: false,
      saved: {'schema': 1, 'templateId': 'gone', 'brightness': 'dark'},
    );
    expect(a.selection.templateId, 'classic-blue');
    expect(
      () => a.preview('url:https://elsewhere', ThemeMode.light),
      throwsFormatException,
    );
    a.preview('midnight-orange', ThemeMode.light);
    expect(await a.apply(), false);
    expect(a.selection.templateId, 'classic-blue');
    expect(s.saved, isNull);
    a.dispose();
  });

  test('async apply is serialized and safe when disposed', () async {
    final s = TestStore()..gate = Completer<void>();
    final a = AppearanceController(registry(), s, existingInstall: true);
    a.preview('midnight-orange', ThemeMode.dark);
    final first = a.apply();
    expect(await a.apply(), false);
    expect(() => a.preview('classic-blue', ThemeMode.light), throwsStateError);
    a.dispose();
    s.gate!.complete();
    expect(await first, true);
    expect(s.calls, 1);
  });

  test('brightness and profile tokens are orthogonal to template ID', () {
    final a = AppearanceController(
      registry(),
      TestStore(),
      existingInstall: true,
    );
    expect(a.theme(Brightness.dark).brightness, Brightness.dark);
    expect(a.theme(Brightness.light).brightness, Brightness.light);
    final female = a
        .theme(Brightness.light, profileId: 'f')
        .colorScheme
        .primary;
    final male = a.theme(Brightness.light, profileId: 'm').colorScheme.primary;
    expect(female, isNot(male));
    expect(a.selection.templateId, 'classic-blue');
    a.dispose();
  });

  testWidgets(
    'theme switch preserves mounted session, text, caret, focus, time and result count',
    (tester) async {
      final a = AppearanceController(
        registry(),
        TestStore(),
        existingInstall: true,
      );
      final key = GlobalKey<SessionProbeState>();
      await tester.pumpWidget(
        MaterialApp(
          home: AppearanceTheme(
            controller: a,
            systemBrightness: Brightness.light,
            child: SessionProbe(key: key),
          ),
        ),
      );
      await tester.tap(find.byKey(const ValueKey('typing')));
      await tester.enterText(find.byKey(const ValueKey('typing')), 'привет123');
      final before = key.currentState!;
      final selection = before.text.selection;
      final time = before.startedAt;
      a.preview('midnight-orange', ThemeMode.dark);
      await tester.pumpAndSettle();
      expect(key.currentState, same(before));
      expect(before.text.text, 'привет123');
      expect(before.text.selection, selection);
      expect(before.focus.hasFocus, true);
      expect(before.startedAt, time);
      expect(before.completions, 0);
      a.cancel();
      await tester.pumpAndSettle();
      a.preview('midnight-orange', ThemeMode.light);
      await a.apply();
      await tester.pumpAndSettle();
      expect(key.currentState, same(before));
      expect(before.text.text, 'привет123');
      expect(before.completions, 0);
      await tester.pumpWidget(const SizedBox());
      a.dispose();
    },
  );

  testWidgets(
    'Synapse header hosts shared portrait, opens on tap and stops when disabled',
    (tester) async {
      var opens = 0;
      Widget app(bool enabled, Widget? portrait) => MaterialApp(
        home: Scaffold(
          appBar: AppBar(
            actions: [
              SynapseHeaderButton(
                enabled: enabled,
                portrait: portrait,
                onOpen: () => opens++,
              ),
            ],
          ),
        ),
      );
      const face = SizedBox(
        key: ValueKey('shared-portrait'),
        width: 40,
        height: 40,
      );
      await tester.pumpWidget(app(true, face));
      expect(find.byKey(const ValueKey('shared-portrait')), findsOneWidget);
      await tester.tap(find.byType(IconButton));
      expect(opens, 1);
      await tester.pumpWidget(app(false, face));
      expect(find.byKey(const ValueKey('shared-portrait')), findsNothing);
      await tester.pumpWidget(app(true, null));
      expect(
        tester.widget<IconButton>(find.byType(IconButton)).onPressed,
        isNull,
      );
      expect(opens, 1);
    },
  );
}
