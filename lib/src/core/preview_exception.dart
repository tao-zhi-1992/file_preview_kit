sealed class PreviewException implements Exception {
  final String message;

  const PreviewException(this.message);

  @override
  String toString() => message;
}

class UnsupportedFileTypeException extends PreviewException {
  const UnsupportedFileTypeException() : super('Unsupported file type');
}

class InvalidXlsxException extends PreviewException {
  const InvalidXlsxException() : super('Invalid or corrupted xlsx file');
}

class InvalidCsvException extends PreviewException {
  const InvalidCsvException() : super('Invalid or corrupted csv file');
}

class EmptyFileException extends PreviewException {
  const EmptyFileException() : super('File is empty');
}

class PasswordProtectedFileException extends PreviewException {
  const PasswordProtectedFileException()
    : super('Password protected xlsx files are not supported');
}
