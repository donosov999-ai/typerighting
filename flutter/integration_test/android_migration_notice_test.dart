import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:typefree_flutter_foundation/data/local_repository.dart';
import 'package:typefree_flutter_foundation/data/webview_migration.dart';
import 'package:typefree_flutter_foundation/design_system/templates.dart';
import 'package:typefree_flutter_foundation/features/migration_gate.dart';
import 'package:typefree_flutter_foundation/main.dart';

import '../test/practice_flow_test.dart' show AppearanceMemory;
import '../test/storage_transfer_test.dart' show MemoryStore;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('timeout shows home notice and opens progress', (tester) async {
    final resources = await Resources.load();
    final repo = LocalRepository(MemoryStore());
    await repo.load();
    final appearance = AppearanceController(
      resources.registry,
      AppearanceMemory(),
      existingInstall: false,
    );
    final key = GlobalKey<TypeFreeAppState>();
    var finished = false;
    await tester.pumpWidget(
      StatefulBuilder(
        builder: (context, update) {
          if (!finished) {
            return TauriMigrationGate(
              repository: repo,
              origin: tauriAndroidOrigin,
              timeout: Duration.zero,
              onDone: () => update(() => finished = true),
            );
          }
          return TypeFreeApp(
            key: key,
            resources: resources,
            repository: repo,
            appearance: appearance,
            phone: true,
            migrationPending: needsWebviewMigration(repo.data),
          );
        },
      ),
    );
    for (var i = 0; i < 30 && !finished; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(finished, true);
    await tester.pump(const Duration(seconds: 1));
    expect(needsWebviewMigration(repo.data), true);
    expect(
      find.byKey(const ValueKey('home-migration-pending')),
      findsOneWidget,
    );
    final action = find.byKey(const ValueKey('home-migration-open'));
    await tester.ensureVisible(action);
    await tester.tap(action);
    await tester.pump(const Duration(seconds: 1));
    expect(key.currentState!.section, AppSection.progress);
    expect(
      find.byKey(const ValueKey('progress-migration-pending')),
      findsOneWidget,
    );
    expect((repo.data['legacy'] as Map), isEmpty);
    await tester.pumpWidget(const SizedBox());
    appearance.dispose();
  });
}
