import 'dart:convert';

import 'package:crypto/crypto.dart';

import 'legacy_transfer.dart';
import 'legacy_values.dart';
import 'local_repository.dart';

/// Same-ID update from the Tauri app (pro.typefree.app 2.60.x): its progress
/// stays in the Android WebView storage of this origin — Tauri 2 serves
/// `http://tauri.localhost` while `useHttpsScheme` is unset (2.60.4 config).
const tauriAndroidOrigin = 'http://tauri.localhost/';

/// iOS: WKWebView of the Tauri app serves its own custom scheme.
const tauriIosOrigin = 'tauri://localhost/';

/// prefs flag: the one-time WebView read finished (imported or nothing there).
const webviewMigrationFlag = 'webviewMigration';

/// Reads every localStorage pair of the origin and posts it to Dart.
const webviewMigrationPage =
    '<!doctype html><meta charset="utf-8"><script>'
    'var o={};try{for(var i=0;i<localStorage.length;i++){var k=localStorage.key(i);'
    'o[k]=localStorage.getItem(k);}TypeFreeMigration.postMessage(JSON.stringify({ok:true,values:o}));}'
    'catch(e){TypeFreeMigration.postMessage(JSON.stringify({ok:false,error:String(e)}));}'
    '</script>';

enum WebviewMigrationResult { nothing, imported, alreadyImported, conflict }

class WebviewMigrationOutcome {
  const WebviewMigrationOutcome(this.result, {this.kept = 0, this.skipped = 0});
  final WebviewMigrationResult result;
  final int kept, skipped;
}

/// Imports the old app's values through the same allowlist, validators and
/// all-or-nothing transfer as the I5 file import. Invalid or foreign keys are
/// skipped one by one (an old app may hold keys of other features); a
/// conflict keeps existing progress. The export ID is the content hash, so a
/// repeated read adds nothing.
Future<WebviewMigrationOutcome> importWebviewValues(
  LocalRepository repo,
  Map<String, String> raw,
) async {
  final kept = <String, String>{};
  var skipped = 0;
  for (final e in raw.entries) {
    if (!safeLegacyKey(e.key)) {
      skipped++;
      continue;
    }
    try {
      validateLegacyValue(e.key, e.value);
      kept[e.key] = e.value;
    } on FormatException {
      skipped++;
    }
  }
  Future<void> markDone() => repo.transaction(
    (d) => (d['prefs'] as Map)[webviewMigrationFlag] = 'done',
  );
  if (kept.isEmpty) {
    await markDone();
    return WebviewMigrationOutcome(
      WebviewMigrationResult.nothing,
      skipped: skipped,
    );
  }
  final keys = kept.keys.toList()..sort();
  final hash = sha256
      .convert(utf8.encode(jsonEncode({for (final k in keys) k: kept[k]})))
      .toString()
      .substring(0, 24);
  try {
    final inserted = await importTransfer(
      repo,
      createTransfer(kept, exportId: 'tauri-webview-$hash'),
    );
    await markDone();
    return WebviewMigrationOutcome(
      inserted
          ? WebviewMigrationResult.imported
          : WebviewMigrationResult.alreadyImported,
      kept: kept.length,
      skipped: skipped,
    );
  } on FormatException {
    // Existing progress differs: nothing replaced; do not retry every launch.
    await markDone();
    return WebviewMigrationOutcome(
      WebviewMigrationResult.conflict,
      kept: kept.length,
      skipped: skipped,
    );
  }
}

bool needsWebviewMigration(Map<String, dynamic> doc) =>
    (doc['prefs'] as Map)[webviewMigrationFlag] != 'done';
