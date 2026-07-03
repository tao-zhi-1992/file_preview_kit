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

  static const _monthNames = [
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

    if (_isDateTimeFormat(formatCode)) {
      return _formatDateTime(value, formatCode);
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

  static bool _isDateTimeFormat(String formatCode) {
    final lower = formatCode.toLowerCase();
    return lower.contains('y') ||
        lower.contains('d') ||
        lower.contains('h') ||
        lower.contains('s') ||
        lower.contains('am/pm') ||
        _containsMinuteToken(lower);
  }

  static bool _containsMinuteToken(String lower) {
    return lower.contains('mm') || lower.contains('m:');
  }

  static bool _isIntegerFormat(String formatCode) {
    return !formatCode.contains('.') &&
        !formatCode.contains('%') &&
        (formatCode.contains('0') || formatCode.contains('#'));
  }

  static DateTime _excelDateTime(double serial) {
    const millisecondsPerDay = 24 * 60 * 60 * 1000;
    final totalMilliseconds = (serial * millisecondsPerDay).round();
    return DateTime(1899, 12, 30).add(
      Duration(milliseconds: totalMilliseconds),
    );
  }

  static String _formatDateTime(double serial, String formatCode) {
    final normalized = formatCode.trim();
    final lower = normalized.toLowerCase();
    final dateTime = _excelDateTime(serial);

    if (lower == 'mm:ss') {
      return _formatDurationMmSs(serial);
    }

    if (lower == '[h]:mm:ss') {
      return _formatElapsedHms(serial);
    }

    final spaceIndex = normalized.indexOf(' ');
    if (spaceIndex > 0) {
      final dateFormat = normalized.substring(0, spaceIndex);
      final timeFormat = normalized.substring(spaceIndex + 1);
      if (_hasDateTokens(dateFormat) &&
          _hasTimeTokens(timeFormat) &&
          !_isAmPmSuffix(timeFormat)) {
        return '${_formatDatePart(dateTime, dateFormat)} '
            '${_formatTimePart(dateTime, timeFormat)}';
      }
    }

    if (_isTimeOnlyFormat(lower)) {
      return _formatTimePart(dateTime, normalized);
    }

    if (_hasTimeTokens(normalized)) {
      return _formatDateTimeTokens(dateTime, normalized);
    }

    return _formatDatePart(dateTime, normalized);
  }

  static bool _hasTimeTokens(String format) {
    final lower = format.toLowerCase();
    return lower.contains('h') ||
        lower.contains('s') ||
        lower.contains('am/pm') ||
        _containsMinuteToken(lower);
  }

  static bool _isTimeOnlyFormat(String lower) {
    return (lower.contains('h') || lower.contains('am/pm')) &&
        !lower.contains('y') &&
        !lower.contains('d');
  }

  static bool _hasDateTokens(String format) {
    final lower = format.toLowerCase();
    return lower.contains('y') ||
        lower.contains('d') ||
        lower.contains('m/d') ||
        lower.contains('mmm');
  }

  static bool _isAmPmSuffix(String format) {
    return format.toLowerCase().trim() == 'am/pm';
  }

  static String _formatDateTimeTokens(DateTime dateTime, String format) {
    final lower = format.toLowerCase();
    final buffer = StringBuffer();
    var index = 0;

    while (index < format.length) {
      final remaining = format.substring(index);
      final lowerRemaining = lower.substring(index);

      if (lowerRemaining.startsWith('yyyy')) {
        buffer.write(dateTime.year.toString().padLeft(4, '0'));
        index += 4;
        continue;
      }

      if (lowerRemaining.startsWith('yy')) {
        buffer.write((dateTime.year % 100).toString().padLeft(2, '0'));
        index += 2;
        continue;
      }

      if (lowerRemaining.startsWith('mmm')) {
        buffer.write(_monthNames[dateTime.month - 1]);
        index += 3;
        continue;
      }

      if (lowerRemaining.startsWith('mm')) {
        buffer.write(dateTime.month.toString().padLeft(2, '0'));
        index += 2;
        continue;
      }

      if (lowerRemaining.startsWith('dd')) {
        buffer.write(dateTime.day.toString().padLeft(2, '0'));
        index += 2;
        continue;
      }

      if (lowerRemaining.startsWith('hh')) {
        buffer.write(dateTime.hour.toString().padLeft(2, '0'));
        index += 2;
        continue;
      }

      if (lowerRemaining.startsWith('h')) {
        buffer.write(dateTime.hour.toString());
        index += 1;
        continue;
      }

      if (lowerRemaining.startsWith('ss')) {
        buffer.write(dateTime.second.toString().padLeft(2, '0'));
        index += 2;
        continue;
      }

      if (lowerRemaining.startsWith('am/pm')) {
        buffer.write(dateTime.hour >= 12 ? 'PM' : 'AM');
        index += 5;
        continue;
      }

      if (lowerRemaining.startsWith('m')) {
        buffer.write(dateTime.minute.toString());
        index += 1;
        continue;
      }

      if (lowerRemaining.startsWith('d')) {
        buffer.write(dateTime.day.toString());
        index += 1;
        continue;
      }

      buffer.write(format[index]);
      index += 1;
    }

    return buffer.toString();
  }

  static String _formatDatePart(DateTime dateTime, String format) {
    final lower = format.toLowerCase();

    if (lower == 'm/d/yy') {
      final year = dateTime.year % 100;
      return '${dateTime.month}/${dateTime.day}/$year';
    }

    if (lower == 'yyyy-mm-dd' || lower == 'yyyy/m/d') {
      final month = dateTime.month.toString().padLeft(2, '0');
      final day = dateTime.day.toString().padLeft(2, '0');
      return '${dateTime.year}-$month-$day';
    }

    if (lower.contains('yyyy') &&
        lower.contains('mm') &&
        lower.contains('dd')) {
      final month = dateTime.month.toString().padLeft(2, '0');
      final day = dateTime.day.toString().padLeft(2, '0');
      return '${dateTime.year}-$month-$day';
    }

    if (lower == 'd-mmm-yy' || lower == 'd-mmm') {
      final monthName = _monthNames[dateTime.month - 1];
      if (lower == 'd-mmm') {
        return '${dateTime.day}-$monthName';
      }
      final year = dateTime.year % 100;
      return '${dateTime.day}-$monthName-$year';
    }

    if (_hasTimeTokens(format)) {
      return _formatDateTimeTokens(dateTime, format);
    }

    final month = dateTime.month.toString().padLeft(2, '0');
    final day = dateTime.day.toString().padLeft(2, '0');
    return '${dateTime.year}-$month-$day';
  }

  static String _formatTimePart(DateTime dateTime, String format) {
    final lower = format.toLowerCase();
    final useAmPm = lower.contains('am/pm');
    final showSeconds = lower.contains('ss');
    final padHour = lower.contains('hh');

    var hour = dateTime.hour;
    var suffix = '';

    if (useAmPm) {
      suffix = hour >= 12 ? ' PM' : ' AM';
      hour = hour % 12;
      if (hour == 0) {
        hour = 12;
      }
    }

    final hourText = padHour ? hour.toString().padLeft(2, '0') : '$hour';
    final minute = dateTime.minute.toString().padLeft(2, '0');

    if (!showSeconds) {
      return '$hourText:$minute$suffix';
    }

    final second = dateTime.second.toString().padLeft(2, '0');
    return '$hourText:$minute:$second$suffix';
  }

  static String _formatDurationMmSs(double serial) {
    final fraction = serial - serial.floor();
    final totalSeconds = (fraction * 24 * 60 * 60).round();
    final minutes = (totalSeconds ~/ 60) % 60;
    final seconds = totalSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:'
        '${seconds.toString().padLeft(2, '0')}';
  }

  static String _formatElapsedHms(double serial) {
    final fraction = serial - serial.floor();
    final totalSeconds = (fraction * 24 * 60 * 60).round();
    final hours = totalSeconds ~/ 3600;
    final minutes = (totalSeconds % 3600) ~/ 60;
    final seconds = totalSeconds % 60;
    return '$hours:${minutes.toString().padLeft(2, '0')}:'
        '${seconds.toString().padLeft(2, '0')}';
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
