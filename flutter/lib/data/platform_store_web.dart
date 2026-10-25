import 'package:web/web.dart' as web;

import 'string_store.dart';

Future<StringStore> openPlatformStore() async => BrowserStore();

class BrowserStore implements StringStore {
  @override
  Future<String?> read(String key) async =>
      web.window.localStorage.getItem(key);
  @override
  Future<void> write(String key, String value) async {
    final old = web.window.localStorage.getItem(key);
    if (old != null) web.window.localStorage.setItem('$key.backup', old);
    // A single setItem replaces the document atomically or throws without changing it.
    web.window.localStorage.setItem(key, value);
  }
}
