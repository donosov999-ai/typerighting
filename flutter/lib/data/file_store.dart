import 'dart:io';

import 'string_store.dart';

/// App-owned candidate directory only. Also usable with disposable fixture paths.
class NativeStore implements StringStore {
  NativeStore(this.directory);
  final Directory directory;
  File file(String key) =>
      File('${directory.path}/${Uri.encodeComponent(key)}.json');
  @override
  Future<String?> read(String key) async {
    final f = file(key);
    if (await f.exists()) return f.readAsString();
    final backup = File('${f.path}.backup');
    return await backup.exists() ? backup.readAsString() : null;
  }

  @override
  Future<void> write(String key, String value) async {
    await directory.create(recursive: true);
    final f = file(key), temp = File('${file(key).path}.pending');
    await temp.writeAsString(value, flush: true);
    if (await f.exists()) await f.copy('${f.path}.backup');
    await temp.rename(f.path);
  }
}
