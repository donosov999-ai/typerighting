import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';

enum ArtifactExportOutcome { saved, requested, cancelled }

typedef ArtifactExporter = Future<ArtifactExportOutcome> Function(
  String name,
  Uint8List bytes,
  String mimeType,
);

Future<ArtifactExportOutcome> saveArtifact(
  String name,
  Uint8List bytes,
  String mimeType,
) async {
  final uri = await FilePicker.saveFile(
    fileName: name,
    bytes: bytes,
    mimeType: mimeType,
  );
  // The web implementation returns null after starting its download. That is
  // not a cancellation, nor proof that the user's browser saved the file.
  if (kIsWeb) return ArtifactExportOutcome.requested;
  return uri == null
      ? ArtifactExportOutcome.cancelled
      : ArtifactExportOutcome.saved;
}
