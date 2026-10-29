import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../data/local_repository.dart';
import '../data/webview_migration.dart';

/// First launch after the same-ID update from the Tauri app (Android): an
/// invisible WebView opens the old origin, reads its localStorage and hands
/// the values to [importWebviewValues]. Practice is never blocked: on a
/// timeout or a WebView error the app starts and the read is retried on the
/// next launch (the flag is set only after a finished read).
class TauriMigrationGate extends StatefulWidget {
  const TauriMigrationGate({
    super.key,
    required this.repository,
    required this.onDone,
    this.timeout = const Duration(seconds: 8),
  });
  final LocalRepository repository;
  final VoidCallback onDone;
  final Duration timeout;
  @override
  State<TauriMigrationGate> createState() => _TauriMigrationGateState();
}

class _TauriMigrationGateState extends State<TauriMigrationGate> {
  late final WebViewController controller;
  Timer? timer;
  bool finished = false;

  void finish() {
    if (finished) return;
    finished = true;
    timer?.cancel();
    widget.onDone();
  }

  Future<void> onMessage(JavaScriptMessage m) async {
    try {
      final payload = jsonDecode(m.message);
      if (payload is Map && payload['ok'] == true && payload['values'] is Map) {
        final raw = <String, String>{
          for (final e in (payload['values'] as Map).entries)
            if (e.key is String && e.value is String)
              e.key as String: e.value as String,
        };
        await importWebviewValues(widget.repository, raw);
      }
    } catch (_) {
      // Unreadable payload: start anyway, retry next launch.
    }
    finish();
  }

  @override
  void initState() {
    super.initState();
    timer = Timer(widget.timeout, finish);
    controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..addJavaScriptChannel('TypeFreeMigration', onMessageReceived: onMessage)
      ..loadHtmlString(webviewMigrationPage, baseUrl: tauriAndroidOrigin);
  }

  @override
  void dispose() {
    timer?.cancel();
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
          const Center(child: CircularProgressIndicator()),
        ],
      ),
    ),
  );
}
