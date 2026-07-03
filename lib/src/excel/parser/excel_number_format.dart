/// Formats numeric cell values using Excel number format codes.
class ExcelNumberFormat {
  ExcelNumberFormat._();

  static const Map<int, String> builtInFormats = {
    0: 'General',
    1: '0',
    2: '0.00',
    3: '#,##0',
    4: '#,##0.00',
    9: '0%',
    10: '0.00%',
    14: 'm/d/yy',
    15: 'd-mmm-yy',
    16: 'd-mmm',
    17: 'mmm-yy',
    18: 'h:mm AM/PM',
    19: 'h:mm:ss AM/PM',
    20: 'h:mm',
    21: 'h:mm:ss',
    22: 'm/d/yy h:mm',
    37: '#,##0 ;(#,##0)',
    38: '#,##0 ;[Red](#,##0)',
    39: '#,##0.00;(#,##0.00)',
    40: '#,##0.00;[Red](#,##0.00)',
    45: 'mm:ss',
    46: '[h]:mm:ss',
    47: 'mmss.0',
    48: '##0.0E+0',
    49: '@',
  };

  /// Resolves a format code from [numFmtId] and custom [numFmts].
  static String? resolveFormatCode(
    int numFmtId,
    Map<int, String> numFmts,
  ) {
    return numFmts[numFmtId] ?? builtInFormats[numFmtId];
  }

  /// Formats [rawValue] using [formatCode], or returns [rawValue] on failure.
  static String format(String rawValue, String? formatCode) {
    if (rawValue.isEmpty) {
      return rawValue;
    }

    if (formatCode == null ||
        formatCode.isEmpty ||
        formatCode == 'General' ||
        formatCode == '@') {
      return rawValue;
    }

    final value = double.tryParse(rawValue);
    if (value == null) {
      return rawValue;
    }

    if (_isDateFormat(formatCode)) {
      return _formatDate(value, formatCode);
    }

    if (formatCode.contains('%')) {
      return _formatPercent(value, formatCode);
    }

    if (_isIntegerFormat(formatCode)) {
      return _formatInteger(value.round(), formatCode);
    }

    if (formatCode.contains('0') || formatCode.contains('#')) {
      return _formatDecimal(value, formatCode);
    }

    return rawValue;
  }

  static bool _isDateFormat(String formatCode) {
    final lower = formatCode.toLowerCase();
    return lower.contains('y') ||
        lower.contains('d') ||
        lower.contains('h') ||
        lower.contains('s') ||
        lower.contains('m');
  }

  static bool _isIntegerFormat(String formatCode) {
    return !formatCode.contains('.') &&
        !formatCode.contains('%') &&
        (formatCode.contains('0') || formatCode.contains('#'));
  }

  static DateTime _excelDate(double serial) {
    // Excel 1900 date system: serial 1 is 1900-01-01.
    return DateTime(1899, 12, 30).add(Duration(days: serial.round()));
  }

  static String _formatDate(double serial, String formatCode) {
    final date = _excelDate(serial);
    final lower = formatCode.toLowerCase();

    if (lower == 'm/d/yy') {
      final year = date.year % 100;
      return '${date.month}/${date.day}/$year';
    }

    if (lower == 'yyyy-mm-dd' || lower == 'yyyy/m/d') {
      final month = date.month.toString().padLeft(2, '0');
      final day = date.day.toString().padLeft(2, '0');
      return '${date.year}-$month-$day';
    }

    if (lower.contains('yyyy') && lower.contains('mm') && lower.contains('dd')) {
      final month = date.month.toString().padLeft(2, '0');
      final day = date.day.toString().padLeft(2, '0');
      return '${date.year}-$month-$day';
    }

    if (lower == 'd-mmm-yy' || lower == 'd-mmm') {
      const months = [
        'Jan',
        'Feb',
        'Mar',
        'Apr',
        'May',
        'Jun',
        'Jul',
        'Aug',
        'Sep',
        'Oct',
        'Nov',
        'Dec',
      ];
      final monthName = months[date.month - 1];
      if (lower == 'd-mmm') {
        return '${date.day}-$monthName';
      }
      final year = date.year % 100;
      return '${date.day}-$monthName-$year';
    }

    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '${date.year}-$month-$day';
  }

  static String _formatPercent(double value, String formatCode) {
    final scaled = value * 100;
    final decimalPlaces = _decimalPlaces(formatCode);
    if (decimalPlaces == 0) {
      return '${scaled.round()}%';
    }
    return '${scaled.toStringAsFixed(decimalPlaces)}%';
  }

  static String _formatInteger(int value, String formatCode) {
    final text = value.toString();
    if (!formatCode.contains(',')) {
      return text;
    }
    return _addThousandsSeparator(text);
  }

  static String _formatDecimal(double value, String formatCode) {
    final decimalPlaces = _decimalPlaces(formatCode);
    var text = value.toStringAsFixed(decimalPlaces);
    if (formatCode.contains(',')) {
      final parts = text.split('.');
      parts[0] = _addThousandsSeparator(parts[0]);
      text = parts.length > 1 ? '${parts[0]}.${parts[1]}' : parts[0];
    }
    return text;
  }

  static int _decimalPlaces(String formatCode) {
    final dotIndex = formatCode.indexOf('.');
    if (dotIndex < 0) {
      return 0;
    }

    var count = 0;
    for (var index = dotIndex + 1; index < formatCode.length; index++) {
      final char = formatCode[index];
      if (char == '0' || char == '#') {
        count++;
      } else {
        break;
      }
    }
    return count;
  }

  static String _addThousandsSeparator(String digits) {
    final negative = digits.startsWith('-');
    final unsigned = negative ? digits.substring(1) : digits;
    final buffer = StringBuffer();
    for (var index = 0; index < unsigned.length; index++) {
      if (index > 0 && (unsigned.length - index) % 3 == 0) {
        buffer.write(',');
      }
      buffer.write(unsigned[index]);
    }
    return negative ? '-$buffer' : buffer.toString();
  }
}
