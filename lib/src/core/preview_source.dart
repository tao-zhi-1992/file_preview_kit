import 'dart:typed_data';

class PreviewSource {
  final Uint8List bytes;
  final String? fileName;
  final String? mimeType;

  const PreviewSource.bytes(this.bytes, {this.fileName, this.mimeType});
}
