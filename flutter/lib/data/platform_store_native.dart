import 'package:path_provider/path_provider.dart';

import 'file_store.dart';
import 'string_store.dart';

Future<StringStore> openPlatformStore() async =>
    NativeStore(await getApplicationSupportDirectory());
