import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:typefree_flutter_foundation/data/local_repository.dart';
import 'package:typefree_flutter_foundation/design_system/templates.dart';
import 'package:typefree_flutter_foundation/main.dart';

import 'practice_flow_test.dart' show AppearanceMemory;
import 'storage_transfer_test.dart' show MemoryStore;

/// Same-ID update 29.10: the old app kept no tr_lang (it followed the
/// device), so with nothing chosen the app follows the device language,
/// not a fixed «ru»; a chosen or imported language still wins.
void main() {
  Future<TypeFreeAppState> boot(
    WidgetTester tester,
    String? device,
    Map<String, dynamic> prefs,
  ) async {
    final resources = (await tester.runAsync(Resources.load))!;
    final repo = LocalRepository(MemoryStore());
    await repo.load();
    await repo.transaction(
      (d) => (d['prefs'] as Map).addAll(<String, dynamic>{
        'pet': false,
        'profile': 'm',
        ...prefs,
      }),
    );
    final key = GlobalKey<TypeFreeAppState>();
    await tester.pumpWidget(
      TypeFreeApp(
        key: key,
        resources: resources,
        repository: repo,
        appearance: AppearanceController(
          resources.registry,
          AppearanceMemory(),
          existingInstall: true,
        ),
        deviceLanguage: device,
      ),
    );
    await tester.pump();
    return key.currentState!;
  }

  testWidgets('device language when none chosen; choice wins', (tester) async {
    expect((await boot(tester, 'en', {})).language, 'en');
    expect((await boot(tester, 'de', {})).language, 'de');
    expect((await boot(tester, 'en', {'lang': 'ru'})).language, 'ru');
    expect((await boot(tester, null, {})).language, 'ru', reason: 'tests');
  });

  testWidgets('no Russian labels in an English trainer', (tester) async {
    final app = await boot(tester, 'en', {});
    await app.showSection(AppSection.practice);
    await tester.pump();
    expect(find.text('Type here'), findsOneWidget);
    expect(find.text('Печатайте здесь'), findsNothing);
    expect(find.byTooltip('Previous'), findsOneWidget);
    expect(find.byTooltip('Предыдущее'), findsNothing);
  });
}
