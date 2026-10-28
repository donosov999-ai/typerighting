import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:typefree_flutter_foundation/audio/typefree_sound.dart';
import 'package:typefree_flutter_foundation/data/local_repository.dart';
import 'package:typefree_flutter_foundation/design_system/templates.dart';
import 'package:typefree_flutter_foundation/main.dart';

import 'practice_flow_test.dart' show AppearanceMemory;
import 'storage_transfer_test.dart' show MemoryStore;

/// A4 companion, src/companion.ts + main.ts rules: phone without keyboard
/// starts here; the explicit button remembers «trainer», a hardware key does
/// not; learn opened from it returns to it; the F4 switch brings it back.
void main() {
  testWidgets('companion start, explicit trainer, hardware key, return, settings switch', (tester) async {
    final resources = (await tester.runAsync(Resources.load))!;
    final repo = LocalRepository(MemoryStore());
    await repo.load();
    await repo.transaction((d) {
      (d['prefs'] as Map)['pet'] = false;
      (d['prefs'] as Map)['profile'] = 'm';
    });
    final appearance = AppearanceController(resources.registry, AppearanceMemory(), existingInstall: true);
    await tester.binding.setSurfaceSize(const Size(390, 1200));
    Future<TypeFreeAppState> start({bool phone = true}) async {
      final key = GlobalKey<TypeFreeAppState>();
      await tester.pumpWidget(const SizedBox());
      await tester.pumpWidget(TypeFreeApp(key: key, resources: resources, repository: repo, appearance: appearance, phone: phone));
      await tester.pump();
      return key.currentState!;
    }

    var app = await start();
    expect(app.section, AppSection.companion);
    expect(find.byType(NavigationBar), findsNothing);
    expect(find.text('Печатать вслепую — нужна клавиатура'), findsOneWidget);

    // Learn opened from the companion comes back to it.
    await tester.tap(find.text('Обучение'));
    await tester.pump();
    expect(app.section, AppSection.learn);
    await tester.tap(find.byTooltip('← Назад'));
    await tester.pumpAndSettle(const Duration(milliseconds: 300));
    expect(app.section, AppSection.companion);

    // A hardware key opens the trainer but is not remembered.
    await simulateKeyDownEvent(LogicalKeyboardKey.keyA);
    await simulateKeyUpEvent(LogicalKeyboardKey.keyA);
    await tester.pump();
    expect(app.section, AppSection.practiceMenu);
    expect((repo.data['prefs'] as Map)['appMode'], isNull);
    app = await start();
    expect(app.section, AppSection.companion, reason: 'phone still starts in companion');

    // The explicit button is remembered: next start goes to the trainer.
    await tester.tap(find.text('Всё равно открыть тренажёр →'));
    await tester.pumpAndSettle(const Duration(milliseconds: 300));
    expect(app.section, AppSection.practiceMenu);
    expect((repo.data['prefs'] as Map)['appMode'], 'trainer');
    app = await start();
    expect(app.section, AppSection.today);

    // F4 switch brings the companion back and remembers it, even off-phone.
    await app.showSection(AppSection.settingsSound);
    await tester.pump();
    final row = find.ancestor(of: find.text('Компаньон'), matching: find.byType(MergeSemantics));
    await tester.ensureVisible(row);
    await tester.tap(find.descendant(of: row, matching: find.byType(Switch)));
    await tester.pumpAndSettle(const Duration(milliseconds: 300));
    expect(app.section, AppSection.companion);
    expect((repo.data['prefs'] as Map)['appMode'], 'companion');
    app = await start(phone: false);
    expect(app.section, AppSection.companion);

    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    appSound.stopMetronome();
    appearance.dispose();
    await tester.binding.setSurfaceSize(null);
  });
}
