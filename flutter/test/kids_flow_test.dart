import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:typefree_flutter_foundation/main.dart';
import 'package:typefree_flutter_foundation/features/kids_page.dart';
import 'package:typefree_flutter_foundation/features/keyboard_guide.dart';
import 'package:typefree_flutter_foundation/data/local_repository.dart';
import 'package:typefree_flutter_foundation/design_system/templates.dart';

import 'storage_transfer_test.dart' show MemoryStore;
import 'practice_flow_test.dart' show AppearanceMemory;

Future<void> complete(
  WidgetTester tester,
  KidsPageState page, {
  VoidCallback? beforeLast,
}) async {
  await tester.ensureVisible(find.byKey(const ValueKey('kids-input')));
  await tester.tap(find.byKey(const ValueKey('kids-input')));
  final all = page.engine.level!.words.join();
  var prefix = page.entry.text;
  for (var i = 0; i < all.length; i++) {
    if (i == all.length - 1) beforeLast?.call();
    prefix += all[i];
    tester.testTextInput.updateEditingValue(
      TextEditingValue(
        text: prefix,
        selection: TextSelection.collapsed(offset: prefix.length),
      ),
    );
    await tester.pump();
  }
  await tester.pump();
}

void main() {
  testWidgets(
    'real child map, blocked input, atomic stars failure/retry, auto timer, route cleanup and reload',
    (tester) async {
      final resources = (await tester.runAsync(Resources.load))!;
      final store = MemoryStore();
      // Repository intentionally uses the same failure-injectable store below.
      final data = LocalRepository(store);
      await data.transaction((d) {
        (d['prefs'] as Map).addAll(<String, dynamic>{
          'lang': 'ru',
          'pet': false,
          'motion': false,
        });
        (d['legacy'] as Map)['tr_kids'] = jsonEncode({
          'stars': {'33': 2, 'future': 1},
        });
      });
      final key = GlobalKey<TypeFreeAppState>();
      final appearance = AppearanceController(
        resources.registry,
        AppearanceMemory(),
        existingInstall: false,
      );
      await tester.binding.setSurfaceSize(const Size(1280, 1000));
      await tester.pumpWidget(
        TypeFreeApp(
          key: key,
          initialSection: AppSection.practiceMenu,
          resources: resources,
          repository: data,
          appearance: appearance,
        ),
      );
      await tester.pump();
      await tester.ensureVisible(find.byIcon(Icons.pets_outlined));
      await tester.tap(find.byIcon(Icons.pets_outlined));
      await tester.pump();
      final page = key.currentState!.kidsKey.currentState!;
      expect(find.byKey(const ValueKey('kids-level-33')), findsOneWidget);
      expect(
        tester
            .widget<OutlinedButton>(find.byKey(const ValueKey('kids-level-10')))
            .onPressed,
        isNull,
      );
      await tester.ensureVisible(find.byKey(const ValueKey('kids-level-1')));
      await tester.tap(find.byKey(const ValueKey('kids-level-1')));
      await tester.pump();
      expect(page.engine.level!.words, ['кот', 'дом', 'сок', 'лес', 'мяч']);
      expect(find.textContaining('WPM'), findsNothing);
      expect(
        tester.widget<KeyboardGuide>(find.byType(KeyboardGuide)).expected,
        'к',
      );
      await tester.ensureVisible(find.byKey(const ValueKey('kids-input')));
      await tester.tap(find.byKey(const ValueKey('kids-input')));
      tester.testTextInput.updateEditingValue(
        const TextEditingValue(
          text: '§',
          selection: TextSelection.collapsed(offset: 1),
        ),
      );
      await tester.pump();
      expect(page.engine.errors, 1);
      expect(page.engine.typing!.pos, 0);
      // Source kids.ts OOPS_L: the cat reacts to a wrong key, it does not
      // announce «Уровень пройден» mid-level (seen on the Android emulator).
      expect(kidsOops['ru'], contains(page.say));
      tester.testTextInput.updateEditingValue(const TextEditingValue());
      await tester.pump();
      expect(page.entry.text, '§');
      expect(page.engine.errors, 1);
      await complete(tester, page, beforeLast: () => store.fail = true);
      expect(page.saved, false);
      expect(page.error, isNotNull);
      expect(page.engine.result!.stars, 2);
      expect(page.engine.playedThisSession, 1);
      expect(await page.checkpointForExit(), false);
      expect(key.currentState!.section, AppSection.kids);
      expect(jsonDecode((data.data['legacy'] as Map)['tr_kids'])['stars'], {
        '33': 2,
        'future': 1,
      });
      await tester.pump(const Duration(seconds: 4));
      expect(page.engine.level!.id, 1);
      store.fail = false;
      expect(await page.save(), true);
      await tester.pump();
      expect(jsonDecode((data.data['legacy'] as Map)['tr_kids'])['stars'], {
        '33': 2,
        'future': 1,
        '1': 2,
      });
      expect(await page.save(), true);
      expect(page.engine.playedThisSession, 1);
      await tester.pump(const Duration(milliseconds: 3499));
      expect(page.engine.level!.id, 1);
      await tester.pump(const Duration(milliseconds: 1));
      await tester.pump();
      expect(page.engine.level!.id, 2);
      // Interrupted second lesson does not invent a completion.
      await key.currentState!.showSection(AppSection.practiceMenu);
      await tester.pump();
      await tester.pump(const Duration(seconds: 4));
      await tester.ensureVisible(find.byIcon(Icons.pets_outlined));
      await tester.tap(find.byIcon(Icons.pets_outlined));
      await tester.pump();
      expect(
        key.currentState!.kidsKey.currentState!.engine.playedThisSession,
        1,
      );
      expect(
        key.currentState!.kidsKey.currentState!.engine.progress.stars[1],
        2,
      );
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
      final reloaded = LocalRepository(store);
      await reloaded.load();
      expect(jsonDecode((reloaded.data['legacy'] as Map)['tr_kids'])['stars'], {
        '33': 2,
        'future': 1,
        '1': 2,
      });
      expect(data.data['sessions'], isEmpty);
      await tester.binding.setSurfaceSize(null);
    },
  );
  testWidgets(
    'child result focused controls retain Space, background stops next and three-level pause is visible',
    (tester) async {
      final resources = (await tester.runAsync(Resources.load))!,
          repo = LocalRepository(MemoryStore());
      await repo.transaction((d) {
        (d['prefs'] as Map).addAll(<String, dynamic>{
          'lang': 'en',
          'profile': 'kids',
          'pet': false,
          'motion': false,
        });
      });
      final key = GlobalKey<TypeFreeAppState>();
      await tester.binding.setSurfaceSize(const Size(1280, 1000));
      await tester.pumpWidget(
        TypeFreeApp(
          key: key,
          initialSection: AppSection.kids,
          resources: resources,
          repository: repo,
          appearance: AppearanceController(
            resources.registry,
            AppearanceMemory(),
            existingInstall: false,
          ),
        ),
      );
      await tester.pump();
      final page = key.currentState!.kidsKey.currentState!;
      for (var id = 1; id <= 3; id++) {
        page.start(id);
        await tester.pump();
        await complete(tester, page);
        expect(page.saved, true);
        if (id < 3) {
          page.next();
          await tester.pump();
        }
      }
      expect(page.engine.restSuggested, true);
      expect(find.textContaining('Take a little break'), findsOneWidget);
      page.didChangeAppLifecycleState(AppLifecycleState.inactive);
      await tester.pump(const Duration(seconds: 5));
      expect(page.engine.level!.id, 3);
      page.didChangeAppLifecycleState(AppLifecycleState.resumed);
      await tester.pump();
      // The focused checkbox must toggle, not trigger the page's next shortcut.
      final checkbox = find.byType(CheckboxListTile);
      await tester.ensureVisible(checkbox);
      await tester.tap(checkbox);
      await tester.pump();
      expect(page.autoNext, false);
      page.autoFocus.requestFocus();
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.space);
      await tester.pump();
      expect(page.autoNext, true);
      expect(page.engine.level!.id, 3);
      await tester.sendKeyEvent(LogicalKeyboardKey.space);
      await tester.pump();
      expect(page.autoNext, false);
      await tester.pump(const Duration(seconds: 5));
      expect(page.engine.level!.id, 3);
      page.toMap();
      await tester.pump();
      expect(find.textContaining('Take a little break'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
      await tester.binding.setSurfaceSize(null);
    },
  );
}
