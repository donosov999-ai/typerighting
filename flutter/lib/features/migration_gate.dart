import 'dart:async';

import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../data/local_repository.dart';
import '../data/webview_migration.dart';

/// First launch after the same-ID update from the Tauri app (Android): an
/// invisible WebView opens the old origin, reads its localStorage and hands
/// the values to [importWebviewValues]. On a timeout before import or a
/// WebView error, the app starts and retries on the next launch. Once a write
/// begins it is awaited; a stalled native write can still block startup.
class TauriMigrationGate extends StatefulWidget {
  const TauriMigrationGate({
    super.key,
    required this.repository,
    required this.onDone,
    this.origin = tauriAndroidOrigin,
    this.timeout = const Duration(seconds: 8),
    this.slowWriteAfter = const Duration(seconds: 8),
  });
  final LocalRepository repository;
  final VoidCallback onDone;

  /// Old app origin: [tauriAndroidOrigin] or [tauriIosOrigin].
  final String origin;
  final Duration timeout;
  final Duration slowWriteAfter;
  @override
  State<TauriMigrationGate> createState() => _TauriMigrationGateState();
}

class _TauriMigrationGateState extends State<TauriMigrationGate> {
  late final WebViewController controller;
  Timer? timer, slowTimer;
  bool finished = false, importing = false, slowWrite = false;

  void finish() {
    if (finished) return;
    finished = true;
    timer?.cancel();
    slowTimer?.cancel();
    widget.onDone();
  }

  Future<void> onMessage(JavaScriptMessage m) async {
    if (!mounted || finished || importing) return;
    try {
      final raw = decodeWebviewMigrationMessage(m.message);
      if (raw != null) {
        // Once a write has started it cannot be cancelled safely. Do not let
        // the read timeout start the app against an unfinished transaction.
        importing = true;
        timer?.cancel();
        slowTimer = Timer(widget.slowWriteAfter, () {
          if (mounted && importing && !finished)
            setState(() => slowWrite = true);
        });
        await importWebviewValues(widget.repository, raw);
      }
    } catch (_) {
      // Unreadable payload: start anyway, retry next launch.
    }
    if (mounted) finish();
  }

  @override
  void initState() {
    super.initState();
    timer = Timer(widget.timeout, finish);
    controller = WebViewController();
    unawaited(initialize());
  }

  Future<void> initialize() async {
    try {
      // Register the channel before the page executes its startup script.
      await controller.setJavaScriptMode(JavaScriptMode.unrestricted);
      await controller.setNavigationDelegate(NavigationDelegate());
      await controller.addJavaScriptChannel(
        'TypeFreeMigration',
        onMessageReceived: onMessage,
      );
      if (!mounted || finished) return;
      await controller.loadHtmlString(
        webviewMigrationPage,
        baseUrl: widget.origin,
      );
    } catch (_) {
      if (mounted) finish();
    }
  }

  @override
  void dispose() {
    timer?.cancel();
    slowTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner: false,
    home: Scaffold(
      body: Stack(
        children: [
          // The WebView must be laid out to run; 1×1 and invisible.
          SizedBox(
            width: 1,
            height: 1,
            child: Opacity(
              opacity: 0,
              child: WebViewWidget(controller: controller),
            ),
          ),
          Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const CircularProgressIndicator(),
                  if (slowWrite) ...[
                    const SizedBox(height: 20),
                    Text(
                      migrationSlowCopy(
                        WidgetsBinding
                            .instance
                            .platformDispatcher
                            .locale
                            .languageCode,
                      ),
                      key: const ValueKey('migration-slow-write'),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

String migrationSlowCopy(String language) =>
    const {
      'ru': 'Сохранение занимает больше времени. Пожалуйста, подождите: прежние данные не удалены.',
      'en': 'Saving is taking longer than usual. Please wait; your previous data has not been deleted.',
      'es': 'El guardado tarda más de lo habitual. Espera; tus datos anteriores no se han eliminado.',
      'de': 'Das Speichern dauert länger als üblich. Bitte warten; deine bisherigen Daten wurden nicht gelöscht.',
      'fr': 'L’enregistrement prend plus de temps que prévu. Patientez ; vos anciennes données n’ont pas été supprimées.',
      'it': 'Il salvataggio richiede più tempo del previsto. Attendi; i dati precedenti non sono stati eliminati.',
      'pt': 'O salvamento está demorando mais que o normal. Aguarde; seus dados anteriores não foram excluídos.',
    }[language] ??
    'Saving is taking longer than usual. Please wait; your previous data has not been deleted.';
