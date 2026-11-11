import 'dart:convert';

import 'package:crypto/crypto.dart';

import 'legacy_transfer.dart';
import 'legacy_values.dart';
import 'local_repository.dart';

/// Same-ID update from the Tauri app (pro.typefree.app 2.60.x): its progress
/// stays in the Android WebView storage of this origin — Tauri 2 serves
/// `http://tauri.localhost` while `useHttpsScheme` is unset (2.60.4 config).
const tauriAndroidOrigin = 'http://tauri.localhost/';

/// iOS and the desktop macOS app: WKWebView of the Tauri app serves its own
/// custom scheme.
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

/// Reject malformed messages rather than silently dropping values and
/// treating the resulting empty storage as a successfully completed read.
Map<String, String>? decodeWebviewMigrationMessage(String message) {
  try {
    final payload = jsonDecode(message);
    if (payload is! Map || payload['ok'] != true || payload['values'] is! Map) {
      return null;
    }
    final values = payload['values'] as Map;
    if (!values.entries.every((e) => e.key is String && e.value is String)) {
      return null;
    }
    return Map<String, String>.from(values);
  } on FormatException {
    return null;
  }
}

enum WebviewMigrationResult { nothing, imported, alreadyImported, conflict }

class WebviewMigrationOutcome {
  const WebviewMigrationOutcome(this.result, {this.kept = 0, this.skipped = 0});
  final WebviewMigrationResult result;
  final int kept, skipped;
}

/// Imports the old app's values through the same allowlist, validators and
/// transactional transfer as the I5 file import. Invalid or foreign keys are
/// skipped; invalid allowed keys and conflicting keys leave migration pending
/// while compatible keys can be imported. A content hash makes retries safe.
Future<WebviewMigrationOutcome> importWebviewValues(
  LocalRepository repo,
  Map<String, String> raw,
) async {
  final kept = <String, String>{};
  var skipped = 0;
  final invalidKnownKeys = <String>[];
  final legacyName = raw['tr_name'];
  var nameConflict = (repo.data['prefs'] as Map)['webviewNameConflict'] == true;
  if (legacyName != null && legacyName.isNotEmpty) {
    if (legacyName.length > 1000000) {
      // Leave the migration pending and the source untouched.
      nameConflict = true;
    } else {
      await repo.transaction((doc) {
        final prefs = doc['prefs'] as Map;
        final existing = prefs['legacyCertificateName'];
        if (existing != null && existing != legacyName) {
          nameConflict = true;
          // Names are personal: keep bounded local-only recovery copies, never
          // in the transferable history or WebView conflict export.
          final copies = List<String>.from(
            (prefs['webviewNameCopies'] as List?) ?? const <String>[],
          );
          final total = copies.fold<int>(0, (sum, value) => sum + value.length);
          if (!copies.contains(legacyName) &&
              copies.length < 20 && total + legacyName.length <= 1000000) {
            copies.add(legacyName);
            prefs['webviewNameCopies'] = copies;
          }
          prefs['webviewNameConflict'] = true;
          return;
        }
        prefs.putIfAbsent('legacyCertificateName', () => legacyName);
        final profile = raw['tr_profile'];
        if (legacyName.length <= 512 && ['m', 'f', 'kids'].contains(profile)) {
          prefs.putIfAbsent('certificateName_$profile', () => legacyName);
        }
      });
    }
  }
  if (nameConflict) {
    // A later empty read cannot prove that a conflicting name was resolved.
    // Persist only the issue marker; the original remains in the old WebView.
    await repo.transaction((doc) {
      (doc['prefs'] as Map)['webviewNameConflict'] = true;
    });
  }
  for (final e in raw.entries) {
    if (e.key == 'tr_name') {
      continue; // local-only personal data, never exported
    }
    if (!safeLegacyKey(e.key)) {
      skipped++;
      continue;
    }
    try {
      validateLegacyValue(e.key, e.value);
      kept[e.key] = e.value;
    } on FormatException {
      skipped++;
      invalidKnownKeys.add(e.key);
    }
  }
  final previousInvalidKeys = (repo.data['prefs'] as Map)['webviewInvalidKeys'];
  final outstandingInvalidKeys = <String>{
    ...invalidKnownKeys,
    if (previousInvalidKeys is List)
      for (final key in previousInvalidKeys)
        if (key is String && !raw.containsKey(key)) key,
  }.toList()..sort();
  if (outstandingInvalidKeys.isNotEmpty || previousInvalidKeys != null) {
    await repo.transaction((doc) {
      final prefs = doc['prefs'] as Map;
      if (outstandingInvalidKeys.isEmpty) {
        prefs.remove('webviewInvalidKeys');
      } else {
        // Record only allowlisted key names, never the rejected values.
        prefs['webviewInvalidKeys'] = outstandingInvalidKeys;
      }
    });
  }
  final invalidKnownValue = outstandingInvalidKeys.isNotEmpty;
  // A later empty or changed WebView read cannot resolve a previously saved
  // conflict. Keep retrying until that recovery data is explicitly resolved.
  final pending = repo.data['webviewPending'];
  final hasPending = pending is Map && pending.isNotEmpty;
  Future<void> markDone() => repo.transaction(
    (d) => (d['prefs'] as Map)[webviewMigrationFlag] = 'done',
  );
  if (kept.isEmpty) {
    if (!nameConflict && !invalidKnownValue && !hasPending) await markDone();
    return WebviewMigrationOutcome(
      nameConflict || invalidKnownValue || hasPending
          ? WebviewMigrationResult.conflict
          : WebviewMigrationResult.nothing,
      skipped: skipped,
    );
  }
  // A conflicting preference must not prevent unrelated history from being
  // recovered. Never replace an existing value; leave the migration pending
  // so the conflicting source remains eligible for an explicit resolution.
  final existing = repo.data['legacy'] as Map;
  final compatible = <String, String>{};
  final conflicts = <String, String>{};
  var hasConflict = nameConflict || invalidKnownValue || hasPending;
  for (final entry in kept.entries) {
    if (existing.containsKey(entry.key) && existing[entry.key] != entry.value) {
      hasConflict = true;
      conflicts[entry.key] = entry.value;
    } else {
      compatible[entry.key] = entry.value;
    }
  }
  // ProgressView already combines the immutable legacy history archive with
  // the current timeline. If the current mirror has diverged, preserve the
  // old history in an empty archive without replacing either existing copy.
  // Other conflicts still need explicit resolution and remain pending.
  if (conflicts.isNotEmpty) {
    final conflictKeys = conflicts.keys.toList()..sort();
    final conflictId = sha256
        .convert(
          utf8.encode(
            jsonEncode({for (final key in conflictKeys) key: conflicts[key]}),
          ),
        )
        .toString();
    await repo.transaction((doc) {
      // Preserve every distinct validated conflict without replacing a prior
      // snapshot. This is local recovery data, not a resolved import.
      final pending =
          doc.putIfAbsent('webviewPending', () => <String, dynamic>{}) as Map;
      pending.putIfAbsent(conflictId, () => conflicts);
      final archive =
          doc.putIfAbsent('legacyArchive', () => <String, dynamic>{}) as Map;
      if (conflicts.containsKey('tr_history')) {
        archive.putIfAbsent('tr_history', () => conflicts['tr_history']);
      }
      // Course stars are monotonic: preserving the larger earned value for
      // each level retains both progress sets without locking completed work.
      final legacy = doc['legacy'] as Map;
      void keepIfValid(String key, Object value) {
        final merged = jsonEncode(value);
        try {
          validateLegacyValue(key, merged);
          legacy[key] = merged;
        } on FormatException {
          // Preserve the current value and the incoming snapshot unchanged.
        }
      }

      if (conflicts.containsKey('tr_keystats')) {
        final current = Map<String, dynamic>.from(
          jsonDecode(legacy['tr_keystats'] as String) as Map,
        );
        final incoming = jsonDecode(conflicts['tr_keystats']!) as Map;
        for (final entry in incoming.entries) {
          // The same physical key may contain overlapping observations. Keep
          // the current record, and retain its old version in pending.
          current.putIfAbsent(entry.key as String, () => entry.value);
        }
        final merged = jsonEncode(current);
        try {
          validateLegacyValue('tr_keystats', merged);
          legacy['tr_keystats'] = merged;
        } on FormatException {
          // Both original versions are still retained if the union is too big.
        }
      }
      if (conflicts.containsKey('tr_compete')) {
        final current = Map<String, dynamic>.from(
          jsonDecode(legacy['tr_compete'] as String) as Map,
        );
        final incoming = jsonDecode(conflicts['tr_compete']!) as Map;
        for (final entry in incoming.entries) {
          final existing = current[entry.key];
          if (existing == null || (entry.value as num) > (existing as num)) {
            current[entry.key as String] = entry.value;
          }
        }
        keepIfValid('tr_compete', current);
      }
      if (conflicts.containsKey('tr_ach')) {
        final current = List<String>.from(
          jsonDecode(legacy['tr_ach'] as String) as List,
        );
        final incoming = List<String>.from(
          jsonDecode(conflicts['tr_ach']!) as List,
        );
        final combined = {...current, ...incoming}.toList();
        // Do not create a document the repository would reject on restart.
        if (combined.length <= 1000) legacy['tr_ach'] = jsonEncode(combined);
      }
      for (final entry in conflicts.entries) {
        if (entry.key.startsWith('tr_progress_')) {
          final current = jsonDecode(legacy[entry.key] as String) as Map;
          final incoming = jsonDecode(entry.value) as Map;
          num greater(String key) =>
              (current[key] as num) >= (incoming[key] as num)
              ? current[key] as num
              : incoming[key] as num;
          final merged = jsonEncode({
            'bestWpm': greater('bestWpm'),
            'bestAcc': greater('bestAcc'),
            'done': {
              ...(current['done'] as List),
              ...(incoming['done'] as List),
            }.toList(),
            // Keep the current place; the old position remains in the snapshot.
            'lastIdx': current['lastIdx'],
          });
          try {
            validateLegacyValue(entry.key, merged);
            legacy[entry.key] = merged;
          } on FormatException {
            // Keep both original values if their union exceeds limits.
          }
          continue;
        }
        if (entry.key != 'tr_kids' && !entry.key.startsWith('tr_course_')) {
          continue;
        }
        final current = jsonDecode(legacy[entry.key] as String) as Map;
        final incoming = jsonDecode(entry.value) as Map;
        final stars = Map<String, dynamic>.from(current['stars'] as Map);
        for (final star in (incoming['stars'] as Map).entries) {
          final oldValue = stars[star.key];
          if (oldValue == null || (star.value as int) > (oldValue as int)) {
            stars[star.key as String] = star.value;
          }
        }
        keepIfValid(entry.key, {'stars': stars});
      }
    });
  }
  if (compatible.isEmpty) {
    return WebviewMigrationOutcome(
      WebviewMigrationResult.conflict,
      kept: kept.length,
      skipped: skipped,
    );
  }
  final keys = compatible.keys.toList()..sort();
  final hash = sha256
      .convert(
        utf8.encode(jsonEncode({for (final k in keys) k: compatible[k]})),
      )
      .toString()
      .substring(0, 24);
  try {
    final inserted = await importTransfer(
      repo,
      createTransfer(compatible, exportId: 'tauri-webview-$hash'),
    );
    if (!hasConflict) await markDone();
    return WebviewMigrationOutcome(
      hasConflict
          ? WebviewMigrationResult.conflict
          : inserted
          ? WebviewMigrationResult.imported
          : WebviewMigrationResult.alreadyImported,
      kept: kept.length,
      skipped: skipped,
    );
  } on FormatException {
    // A concurrent change can introduce a conflict after the snapshot above.
    // Do not declare the migration complete; the source remains untouched.
    return WebviewMigrationOutcome(
      WebviewMigrationResult.conflict,
      kept: kept.length,
      skipped: skipped,
    );
  }
}

bool needsWebviewMigration(Map<String, dynamic> doc) =>
    (doc['prefs'] as Map)[webviewMigrationFlag] != 'done';
