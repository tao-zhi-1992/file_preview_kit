import 'dart:typed_data';

/// In-memory file content and metadata used to select a preview parser.
class PreviewSource {
  /// Raw file content.
  final Uint8List bytes;

  /// Optional file name used for extension-based format detection.
  final String? fileName;

  /// Optional MIME type used when [fileName] is unavailable.
  final String? mimeType;

  /// Creates a preview source from in-memory [bytes].
  const PreviewSource.bytes(this.bytes, {this.fileName, this.mimeType});
}
