/// Teacher cabinet in TypeFree (contract ecosystem.coach/2, packages
/// `ecosystem_account` + `ecosystem_coach`, app_id [coachAppId]).
///
/// Off unless built with `--dart-define=TF_COACH=true` (and never on the web:
/// the sign-in return and invites are app links `pro.typefree.app://…`).
/// Server: Supabase project of the ecosystem, RPC `ecosystem_coach_v2`.
///
/// What the bridge does:
///   · after a finished training, turns the saved history row into the cabinet
///     event ([coachProjection]) and sends it — fire-and-forget; nothing leaves
///     the device without sign-in and a teacher the student consented to for
///     TypeFree, and a failure never touches the saved session;
///   · opens the package screens in TypeFree's own sub-page frame;
///   · accepts `pro.typefree.app://auth/callback` and
///     `pro.typefree.app://coach/invite?code=<48 hex>` links.
library;

import 'dart:async';

import 'package:ecosystem_account/ecosystem_account.dart';
import 'package:ecosystem_coach/ecosystem_coach.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import 'coach_projection.dart';
import 'key_statistics_store.dart';

/// What the student allowed for TypeFree: union of scopes over their teachers,
/// and the earliest consent time (ms) — older sessions never leave (no backfill).
typedef CoachConsent = ({Set<String> scopes, int since});

class TypeFreeCoach {
  TypeFreeCoach(this.client, {this.auth}) {
    auth?.addListener(forgetConsent);
  }

  static const enabled = bool.fromEnvironment('TF_COACH') && !kIsWeb;
  static const scheme = 'pro.typefree.app';
  static const callback = '$scheme://auth/callback';
  static const _url = String.fromEnvironment(
    'TF_SUPABASE_URL',
    defaultValue: 'https://iuvvheeocobhiothfgei.supabase.co',
  );
  // A publishable key is public by Supabase design (database rights decide
  // access) — the same one the other ecosystem apps ship. Not a secret.
  static const _key = String.fromEnvironment(
    'TF_SUPABASE_PUBLISHABLE_KEY',
    defaultValue: 'sb_publishable_A2vJ5DjemTZIKrKX6XGqvQ_WaiuAkk1',
  );
  static const signedInKey = 'typefree.coach.signedIn';

  /// The app's cabinet; null — off by the build flag.
  static TypeFreeCoach? instance;

  /// Navigator of the app, for screens opened from a link.
  static final navigatorKey = GlobalKey<NavigatorState>();

  /// Build the cabinet from the build flags; null when off.
  static Future<TypeFreeCoach?> fromEnvironment() async {
    if (!enabled) return null;
    final prefs = SharedPreferencesAsync();
    final account = EcosystemAccount(
      appId: coachAppId,
      url: _url,
      publishableKey: _key,
      callback: Uri.parse(callback),
      vault: const _Vault(),
    );
    final auth = AccountCoachAuth(
      account,
      openUrl: (u) => launchUrl(u, mode: LaunchMode.externalApplication),
      // Google is hidden on iOS until Sign in with Apple (App Store 4.8):
      // the e-mail link stays.
      googleAvailable: defaultTargetPlatform != TargetPlatform.iOS,
      onSignedIn: () => prefs.setBool(signedInKey, true),
      onSignedOut: () => prefs.remove(signedInKey),
    );
    // Before the first sign-in the cabinet makes no network calls at all.
    try {
      if (await prefs.getBool(signedInKey) == true) {
        unawaited(auth.restore());
      }
    } on Object {
      // No preferences — stay signed out.
    }
    return TypeFreeCoach(
      CoachClient(AccountCoachTransport(account), appId: coachAppId),
      auth: auth,
    )..observe();
  }

  final CoachClient client;
  final AccountCoachAuth? auth;
  Future<CoachConsent?>? _consent;

  /// Subscribe to finished trainings. One subscriber — the last one set.
  void observe() => KeyStatisticsStore.onSessionSaved = submitSession;

  void dispose() {
    if (KeyStatisticsStore.onSessionSaved == submitSession) {
      KeyStatisticsStore.onSessionSaved = null;
    }
    auth?.removeListener(forgetConsent);
  }

  /// Consent can change: after sign-in/out and after the cabinet screens.
  void forgetConsent() => _consent = null;

  Future<CoachConsent?> _currentConsent() => _consent ??= () async {
    try {
      final board = await client.dashboard();
      final scopes = <String>{};
      int? since;
      for (final coach in board.coaches) {
        for (final app in coach.apps) {
          if (app.appId != coachAppId) continue;
          scopes.addAll(app.scopes);
          final t = app.grantedAt?.millisecondsSinceEpoch;
          if (t != null && (since == null || t < since)) since = t;
        }
      }
      return (scopes: scopes, since: since ?? 0);
    } on Object {
      _consent = null; // retry with the next training
      return null;
    }
  }();

  /// A saved history row → cabinet event. Errors are swallowed: the cabinet
  /// must never break a training, the session is already saved locally.
  Future<void> submitSession(Map<String, dynamic> row) async {
    try {
      final consent = await _currentConsent();
      if (consent == null || consent.scopes.isEmpty) return;
      final json = coachProjection(
        row,
        scopes: consent.scopes,
        consentSince: consent.since,
      );
      if (json == null) return;
      await client.submit(coachEventFromProjection(json));
    } on Object {
      // no sign-in / no network / no consent — nothing to do
    }
  }

  CoachStrings strings(String language) =>
      language == 'ru' ? CoachStrings.ru : CoachStrings.en;

  Future<void> openTeacher(BuildContext context, String language) => _open(
    context,
    (s) => TeacherCabinetScreen(
      client: client,
      auth: auth,
      strings: s,
      frame: typeFreeCoachFrame(language),
    ),
    language,
  );

  Future<void> openMyCoaches(BuildContext context, String language) => _open(
    context,
    (s) => MyCoachesScreen(
      client: client,
      auth: auth,
      strings: s,
      frame: typeFreeCoachFrame(language),
    ),
    language,
  );

  Future<void> _open(
    BuildContext context,
    Widget Function(CoachStrings) screen,
    String language,
  ) async {
    await Navigator.of(
      context,
    ).push<void>(MaterialPageRoute(builder: (_) => screen(strings(language))));
    forgetConsent();
  }

  /// Incoming link: sign-in return (`auth/callback`) or invite (`coach/invite`).
  /// Not ours → false.
  Future<bool> handleLink(Uri uri, {required String language}) async {
    if (uri.scheme != scheme) return false;
    if (uri.host == 'auth') {
      try {
        return await auth?.complete(uri) ?? false;
      } on Object {
        return false;
      }
    }
    final link = CoachInviteLink.parse(uri, appId: coachAppId);
    if (link == null) return false;
    // A cold start delivers the link before the first frame.
    for (var i = 0; i < 50 && navigatorKey.currentState == null; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 100));
    }
    final navigator = navigatorKey.currentState;
    if (navigator == null) return false;
    unawaited(
      navigator
          .push<void>(
            MaterialPageRoute(
              builder: (_) => AcceptInviteScreen(
                client: client,
                code: link.code,
                auth: auth,
                strings: strings(language),
                frame: typeFreeCoachFrame(language),
              ),
            ),
          )
          .then((_) => forgetConsent()),
    );
    return true;
  }

  /// Listen to the app's links (app_links stream). Errors are ignored.
  StreamSubscription<Uri> listen(
    Stream<Uri> links, {
    required String Function() language,
  }) => links.listen(
    (u) => unawaited(handleLink(u, language: language())),
    onError: (Object _) {},
  );
}

/// Subtitles of the two settings rows (the titles come from [CoachStrings]).
String coachSettingsSubtitle(String language, String key) =>
    switch ((language == 'ru', key)) {
      (true, 'teacher') => 'Ученики, приглашения и их тренировки',
      (true, _) => 'Кто видит ваши тренировки и что именно',
      (false, 'teacher') => 'Students, invites and their trainings',
      (false, _) => 'Who sees your trainings and what exactly',
    };

/// The projection JSON ([coachProjection]) as the package event.
CoachEvent coachEventFromProjection(Map<String, Object?> json) => CoachEvent(
  eventId: json['event_id']! as String,
  kind: json['kind']! as String,
  mode: json['mode'] as String?,
  exerciseRef: json['exercise_ref'] as String?,
  assignmentId: json['assignment_id'] as String?,
  step: json['step'] as int?,
  occurredAt: DateTime.tryParse('${json['occurred_at']}'),
  metrics: Map<String, Object?>.from(json['metrics'] as Map? ?? const {}),
  errors: Map<String, Object?>.from(json['errors'] as Map? ?? const {}),
);

/// TypeFree's sub-page frame (as «Settings → Input/Sound»): bold title, the
/// arrow back, content up to 720 px wide; screen buttons in the bottom row.
CoachFrame typeFreeCoachFrame(String language) =>
    (context, title, body, actions) => Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: language == 'ru' ? 'Назад' : 'Back',
          onPressed: () => Navigator.of(context).maybePop(),
          icon: const Icon(Icons.arrow_back),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: body,
          ),
        ),
      ),
      bottomNavigationBar: actions.isEmpty
          ? null
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                child: Row(
                  children: [
                    for (final a in actions)
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: FilledButton.icon(
                            key: a.key,
                            onPressed: a.onPressed,
                            icon: Icon(a.icon),
                            label: Text(a.label),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
    );

/// Session storage: the system keychain (macOS — the legacy keychain, which a
/// sandboxed app reaches without a keychain-sharing entitlement).
class _Vault implements AccountVault {
  const _Vault();
  static const _storage = FlutterSecureStorage(
    iOptions: IOSOptions(
      accessibility: KeychainAccessibility.first_unlock_this_device,
    ),
    mOptions: MacOsOptions(usesDataProtectionKeychain: false),
  );
  @override
  Future<String?> read(String key) => _storage.read(key: key);
  @override
  Future<void> write(String key, String value) =>
      _storage.write(key: key, value: value);
  @override
  Future<void> remove(String key) => _storage.delete(key: key);
}
