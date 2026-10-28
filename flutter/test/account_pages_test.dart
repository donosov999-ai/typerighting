import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:typefree_flutter_foundation/audio/typefree_sound.dart';
import 'package:typefree_flutter_foundation/data/artifact_export.dart';
import 'package:typefree_flutter_foundation/data/local_repository.dart';
import 'package:typefree_flutter_foundation/design_system/templates.dart';
import 'package:typefree_flutter_foundation/main.dart';

import 'practice_flow_test.dart' show AppearanceMemory;
import 'storage_transfer_test.dart' show MemoryStore;

/// F5/F6 are honest LOCAL states: reachable from «Ещё», export works,
/// nothing that needs a service pretends to work.
void main() {
  testWidgets('account and data pages: honest states, working export', (
    tester,
  ) async {
    final resources = (await tester.runAsync(Resources.load))!;
    final repo = LocalRepository(MemoryStore());
    await repo.load();
    await repo.transaction(
      (d) => (d['prefs'] as Map).addAll(<String, dynamic>{
        'profile': 'm',
        'pet': false,
      }),
    );
    final appearance = AppearanceController(
      resources.registry,
      AppearanceMemory(),
      existingInstall: true,
    );
    String? exported;
    Future<ArtifactExportOutcome> exporter(
      String name,
      List<int> bytes,
      String type,
    ) async {
      exported = name;
      return ArtifactExportOutcome.saved;
    }

    await tester.binding.setSurfaceSize(const Size(430, 1400));
    final key = GlobalKey<TypeFreeAppState>();
    await tester.pumpWidget(
      TypeFreeApp(
        key: key,
        resources: resources,
        repository: repo,
        appearance: appearance,
        artifactExporter: exporter,
        initialSection: AppSection.more,
        phone: false,
      ),
    );
    await tester.pump();
    final app = key.currentState!;

    await tester.tap(find.text('Аккаунт'));
    await tester.pump();
    expect(app.section, AppSection.account);
    expect(find.text('Без аккаунта уже можно заниматься'), findsOneWidget);
    expect(find.text('Сервис не подключён'), findsOneWidget);
    expect(
      find.byType(TextField),
      findsNothing,
      reason: 'no fake sign-in form',
    );

    await app.showSection(AppSection.more);
    await tester.pump();
    await tester.tap(find.text('Данные и разрешения'));
    await tester.pump();
    expect(app.section, AppSection.dataPermissions);
    for (final s in tester.widgetList<Switch>(find.byType(Switch))) {
      expect(
        s.onChanged,
        isNull,
        reason: 'no service — permissions cannot be granted',
      );
    }
    await tester.tap(find.byKey(const ValueKey('data-export')));
    await tester.pumpAndSettle();
    expect(exported, startsWith('TypeFree-history-'));
    expect(find.byKey(const ValueKey('data-status')), findsOneWidget);

    // I5 entry: «Перенести прогресс из прежней версии» → page → back to F6.
    await tester.ensureVisible(find.byKey(const ValueKey('data-transfer')));
    await tester.tap(find.byKey(const ValueKey('data-transfer')));
    await tester.pump();
    expect(app.section, AppSection.transfer);
    expect(find.byKey(const ValueKey('transfer-choose')), findsOneWidget);
    await tester.tap(find.byTooltip('← Назад'));
    await tester.pump();
    expect(app.section, AppSection.dataPermissions);

    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    appSound.stopMetronome();
    appearance.dispose();
    await tester.binding.setSurfaceSize(null);
  });
}
