/// Base exception for file parsing and preview failures.
sealed class PreviewException implements Exception {
  /// Human-readable failure reason.
  final String message;

  const PreviewException(this.message);

  @override
  String toString() => message;
}

/// Indicates that a file format cannot be previewed.
class UnsupportedFileTypeException extends PreviewException {
  const UnsupportedFileTypeException() : super('Unsupported file type');
}

/// Indicates that XLSX content is invalid or corrupted.
class InvalidXlsxException extends PreviewException {
  const InvalidXlsxException() : super('Invalid or corrupted xlsx file');
}

/// Indicates that CSV content is invalid or corrupted.
class InvalidCsvException extends PreviewException {
  const InvalidCsvException() : super('Invalid or corrupted csv file');
}

/// Indicates that DOCX content is invalid or corrupted.
class InvalidDocxException extends PreviewException {
  const InvalidDocxException() : super('Invalid or corrupted docx file');
}

/// Indicates that no file content was provided.
class EmptyFileException extends PreviewException {
  const EmptyFileException() : super('File is empty');
}

/// Indicates that encrypted XLSX content is unsupported.
class PasswordProtectedFileException extends PreviewException {
  const PasswordProtectedFileException()
    : super('Password protected xlsx files are not supported');
}
