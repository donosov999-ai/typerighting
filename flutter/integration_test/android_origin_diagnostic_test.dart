import 'dart:convert';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:typefree_flutter_foundation/data/webview_migration.dart';
import 'package:typefree_flutter_foundation/data/local_repository.dart';
import 'package:typefree_flutter_foundation/features/migration_gate.dart';

import '../test/storage_transfer_test.dart' show MemoryStore;

class DelayedStore extends MemoryStore {
  final entered = Completer<void>();
  final release = Completer<void>();
  @override
  Future<void> write(String key, String value) async {
    if (!entered.isCompleted) {
      entered.complete();
      await release.future;
    }
    await super.write(key, value);
  }
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('read timeout before import starts keeps retry available', (
    tester,
  ) async {
    final repo = LocalRepository(MemoryStore());
    var done = false;
    await tester.pumpWidget(
      TauriMigrationGate(
        repository: repo,
        origin: tauriAndroidOrigin,
        timeout: Duration.zero,
        onDone: () => done = true,
      ),
    );
    await tester.pump(const Duration(milliseconds: 200));
    expect(done, true);
    expect(needsWebviewMigration(repo.data), true);
    expect((repo.data['legacy'] as Map), isEmpty);
  });

  testWidgets('failed migration write opens app and leaves retry available', (
    tester,
  ) async {
    final store = MemoryStore()..fail = true;
    final repo = LocalRepository(store);
    var done = false;
    await tester.pumpWidget(
      TauriMigrationGate(
        repository: repo,
        origin: tauriAndroidOrigin,
        onDone: () => done = true,
      ),
    );
    for (var i = 0; i < 120 && !done; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(done, true);
    expect(needsWebviewMigration(repo.data), true);
    expect((repo.data['legacy'] as Map), isEmpty);
  });

  testWidgets(
    'migration does not launch app while an import write is pending',
    (tester) async {
      final store = DelayedStore();
      final repo = LocalRepository(store);
      var done = false;
      await tester.pumpWidget(
        TauriMigrationGate(
          repository: repo,
          origin: tauriAndroidOrigin,
          timeout: const Duration(seconds: 3),
          slowWriteAfter: const Duration(seconds: 1),
          onDone: () => done = true,
        ),
      );
      for (var i = 0; i < 25 && !store.entered.isCompleted; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(
        store.entered.isCompleted,
        true,
        reason: 'WebView did not begin import',
      );
      final webview = tester.widget<WebViewWidget>(find.byType(WebViewWidget));
      await webview.platform.params.controller.runJavaScript(
        '''TypeFreeMigration.postMessage(JSON.stringify({ok:true, values:{tr_dark:"1"}}));''',
      );
      await tester.pump(const Duration(seconds: 4));
      final launchedBeforeCommit = done;
      expect(
        find.byKey(const ValueKey('migration-slow-write')),
        findsOneWidget,
      );
      store.release.complete();
      for (var i = 0; i < 30 && !done; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      await tester.pump(const Duration(milliseconds: 200));
      expect(
        launchedBeforeCommit,
        false,
        reason: 'the user could start before the import finishes',
      );
      expect(done, true);
      expect(needsWebviewMigration(repo.data), false);
      expect(
        (repo.data['legacy'] as Map).containsKey('tr_dark'),
        false,
        reason: 'duplicate messages during an import must be ignored',
      );
    },
  );

  testWidgets('actual migration gate finishes and records read', (
    tester,
  ) async {
    final repo = LocalRepository(MemoryStore());
    var done = false;
    await tester.pumpWidget(
      TauriMigrationGate(
        repository: repo,
        origin: tauriAndroidOrigin,
        onDone: () => done = true,
      ),
    );
    for (var i = 0; i < 120 && !done; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(done, true, reason: 'migration gate did not return');
    expect(
      needsWebviewMigration(repo.data),
      false,
      reason: 'migration read did not commit',
    );
    final webview = tester.widget<WebViewWidget>(find.byType(WebViewWidget));
    await webview.platform.params.controller.runJavaScript(
      '''TypeFreeMigration.postMessage(JSON.stringify({ok:true, values:{tr_dark:"1"}}));''',
    );
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(
      (repo.data['legacy'] as Map).containsKey('tr_dark'),
      false,
      reason: 'A message after the gate completed must not import more data',
    );
  });

  testWidgets('Android WebView reports whether the old origin is readable', (
    tester,
  ) async {
    String? message;
    final controller = WebViewController();
    await controller.setJavaScriptMode(JavaScriptMode.unrestricted);
    await controller.setNavigationDelegate(NavigationDelegate());
    await controller.addJavaScriptChannel(
      'TypeFreeMigration',
      onMessageReceived: (m) {
        message = m.message;
      },
    );
    await controller.loadHtmlString(
      webviewMigrationPage.replaceFirst(
        'var o={};',
        '''localStorage.setItem("tr_lang","en");
        localStorage.setItem("tr_history", JSON.stringify([{t:1700000000000,wpm:41,acc:97,len:45}]));
        localStorage.setItem("tr_progress_ruWords", JSON.stringify({bestWpm:42,bestAcc:97,done:["ruw-1"],lastIdx:1}));
        localStorage.setItem("tr_keystats", JSON.stringify({a:{ok:6,err:2}}));
        var o={};''',
      ),
      baseUrl: tauriAndroidOrigin,
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Stack(
            children: [
              SizedBox(
                width: 1,
                height: 1,
                child: Opacity(
                  opacity: 0,
                  child: WebViewWidget(controller: controller),
                ),
              ),
              const Center(child: CircularProgressIndicator()),
            ],
          ),
        ),
      ),
    );
    for (var i = 0; i < 120 && message == null; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    debugPrint('migration-origin diagnostic: received=${message != null}');
    expect(message, isNotNull, reason: 'No response from old origin');
    expect(
      jsonDecode(message!)['ok'],
      true,
      reason: 'WebView could not read localStorage at the old origin',
    );
    final repo = LocalRepository(MemoryStore());
    var done = false;
    await tester.pumpWidget(
      TauriMigrationGate(
        repository: repo,
        origin: tauriAndroidOrigin,
        onDone: () => done = true,
      ),
    );
    for (var i = 0; i < 120 && !done; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(done, true);
    expect(needsWebviewMigration(repo.data), false);
    expect((repo.data['legacy'] as Map)['tr_lang'], 'en');
    final legacy = repo.data['legacy'] as Map;
    final archive = repo.data['legacyArchive'] as Map;
    expect(jsonDecode(legacy['tr_history'])[0]['wpm'], 41);
    expect(
      jsonDecode(legacy['tr_progress_ruWords'])['done'],
      contains('ruw-1'),
    );
    expect(jsonDecode(legacy['tr_keystats'])['a']['err'], 2);
    expect(archive['tr_history'], legacy['tr_history']);
  });
}
