const int _ecEpochJdn = 1724221;

const List<String> _ecMonths = [
  'መስከረም',
  'ጥቅምት',
  'ህዳር',
  'ታህሳስ',
  'ጥር',
  'የካቲት',
  'መጋቢት',
  'ሚያዚያ',
  'ግንቦት',
  'ሰኔ',
  'ሐምሌ',
  'ነሃሴ',
  'ጳጉሜ',
];

const List<String> _amhWeekdays = [
  '',
  'ሰኞ',
  'ማክሰኞ',
  'ረቡዕ',
  'ሐሙስ',
  'ዓርብ',
  'ቅዳሜ',
  'እሁድ',
];

const Map<int, String> monthNames = {
  1: "መስከረም",
  2: "ጥቅምት",
  3: "ኅዳር",
  4: "ታኅሣሥ",
  5: "ጥር",
  6: "የካቲት",
  7: "መጋቢት",
  8: "ሚያዝያ",
  9: "ግንቦት",
  10: "ሰኔ",
  11: "ሐምሌ",
  12: "ነሐሴ",
  13: "ጳጉሜ",
};

class EcDate {
  final int year;
  final int month;
  final int day;
  final int weekday;
  final String monthName;

  EcDate(this.year, this.month, this.day, this.weekday)
    : monthName = monthNames[month] ?? '';
}

DateTime _jdnToGc(int jdn) {
  final f = jdn + 1401 + ((((4 * jdn + 274277) ~/ 146097) * 3) ~/ 4) - 38;
  final e = 4 * f + 3;
  final g = (e % 1461) ~/ 4;
  final h = 5 * g + 2;
  final day = ((h % 153) ~/ 5) + 1;
  final month = (((h ~/ 153) + 2) % 12) + 1;
  final year = (e ~/ 1461) - 4716 + ((14 - month) ~/ 12);
  return DateTime(year, month, day);
}

bool ecIsLeap(int ecYear) => ecYear % 4 == 3;

int ecMonthLength(int ecYear, int ecMonth) {
  if (ecMonth >= 1 && ecMonth <= 12) return 30;
  return ecIsLeap(ecYear) ? 6 : 5;
}

int _ecToJdn(int year, int month, int day) {
  return _ecEpochJdn +
      (year - 1) * 365 +
      (year ~/ 4) +
      (month - 1) * 30 +
      (day - 1);
}

int _ethiopianNewYearDayInSeptember(int ethiopianYear) {
  int day = (ethiopianYear ~/ 100) - (ethiopianYear ~/ 400) - 4;
  if ((ethiopianYear - 1) % 4 == 3) {
    day += 1;
  }
  return day;
}

EcDate ecFromGc(DateTime date) {
  final y = date.year;
  final m = date.month;
  final d = date.day;

  if (y < 1900) {
    throw Exception("Gregorian year must be 1900 or later.");
  }

  int ethYear = y - 7;
  int newYearDay = _ethiopianNewYearDayInSeptember(ethYear);
  int newYearGregYear = ethYear + 7;
  final newYearDate = DateTime(newYearGregYear, 9, newYearDay);

  final currentDate = DateTime(y, m, d);

  if (currentDate.isBefore(newYearDate)) {
    ethYear--;
    newYearDay = _ethiopianNewYearDayInSeptember(ethYear);
    newYearGregYear = ethYear + 7;
    final updatedNewYearDate = DateTime(newYearGregYear, 9, newYearDay);
    final daysDiff = currentDate.difference(updatedNewYearDate).inDays;

    int month = (daysDiff ~/ 30) + 1;
    int day = (daysDiff % 30) + 1;

    if (month > 13) {
      month = 13;
      day = daysDiff - 360 + 1;
    }

    final weekday = date.weekday;
    return EcDate(ethYear, month, day, weekday);
  }

  final daysDiff = currentDate.difference(newYearDate).inDays;

  int month = (daysDiff ~/ 30) + 1;
  int day = (daysDiff % 30) + 1;

  if (month > 13) {
    month = 13;
    day = daysDiff - 360 + 1;
  }

  final weekday = date.weekday;
  return EcDate(ethYear, month, day, weekday);
}

DateTime gcFromEc(int year, int month, int day) {
  final jdn = _ecToJdn(year, month, day);
  return _jdnToGc(jdn);
}

DateTime gcFromIsoLocal(String iso) {
  final p = iso.split('-').map(int.parse).toList();
  return DateTime(p[0], p[1], p[2]);
}

DateTime gcWeekStartMonday(DateTime d) {
  final day = d.weekday;
  return DateTime(d.year, d.month, d.day).subtract(Duration(days: day - 1));
}

DateTime gcStartOfDay(DateTime d) => DateTime(d.year, d.month, d.day);

DateTime gcEndOfDay(DateTime d) =>
    DateTime(d.year, d.month, d.day, 23, 59, 59, 999);

DateTime gcEcMonthStartFor(DateTime g) {
  final ec = ecFromGc(g);
  return gcFromEc(ec.year, ec.month, 1);
}

List<int> ecAddMonths(int y, int m, int add) {
  final idxZero = (m - 1) + add;
  final ny = y + (idxZero ~/ 12);
  final nm = (idxZero % 12) + 1;
  return [ny, nm];
}

bool ecRangeIncludesNehase(int y, int m, int n) {
  for (int k = 0; k < n; k++) {
    final curM = ((m - 1 + k) % 12) + 1;
    if (curM == 12) return true;
  }
  return false;
}

String _two(int n) => n.toString().padLeft(2, '0');

String ecFormatFull(EcDate e) {
  final wd = _amhWeekdays[e.weekday];
  final monthName = _ecMonths[e.month - 1];
  return '$wd, ${_two(e.day)} $monthName ${e.year}';
}

String ecFormatFullFromGc(DateTime g) => ecFormatFull(ecFromGc(g));

String formatEthiopianDate(EcDate eth) {
  return '${_two(eth.day)}/${_two(eth.month)}/${eth.year}';
}

String ethiopianStringToGregorian(String ethStr) {
  if (ethStr.isEmpty) return '';
  final parts = ethStr.split('/');
  if (parts.length != 3) return '';
  final day = int.tryParse(parts[0]);
  final month = int.tryParse(parts[1]);
  final year = int.tryParse(parts[2]);
  if (year == null || month == null || day == null) return '';
  final gcDate = gcFromEc(year, month, day);
  return '${gcDate.year}-${_two(gcDate.month)}-${_two(gcDate.day)}';
}

String gregorianStringToEthiopian(String gcStr) {
  if (gcStr.isEmpty) return '';
  final parts = gcStr.split('-');
  if (parts.length != 3) return '';
  final year = int.tryParse(parts[0]);
  final month = int.tryParse(parts[1]);
  final day = int.tryParse(parts[2]);
  if (year == null || month == null || day == null) return '';
  final eth = ecFromGc(DateTime(year, month, day));
  return formatEthiopianDate(eth);
}

String ethiopianYMDToGregorian(String ethStr) {
  if (ethStr.isEmpty) return '';
  final parts = ethStr.split('-');
  if (parts.length != 3) return '';
  final year = int.tryParse(parts[0]);
  final month = int.tryParse(parts[1]);
  final day = int.tryParse(parts[2]);
  if (year == null || month == null || day == null) return '';
  final gcDate = gcFromEc(year, month, day);
  return '${gcDate.year}-${_two(gcDate.month)}-${_two(gcDate.day)}';
}

String gregorianToEthiopianYMD(String gcStr) {
  if (gcStr.isEmpty) return '';
  final parts = gcStr.split('-');
  if (parts.length != 3) return '';
  final year = int.tryParse(parts[0]);
  final month = int.tryParse(parts[1]);
  final day = int.tryParse(parts[2]);
  if (year == null || month == null || day == null) return '';
  final eth = ecFromGc(DateTime(year, month, day));
  return '${eth.year.toString().padLeft(4, '0')}-${_two(eth.month)}-${_two(eth.day)}';
}

String ethiopianDDMMYYYYToGregorian(String ethDateStr) {
  if (ethDateStr.isEmpty) return '';
  final parts = ethDateStr.split('/');
  if (parts.length != 3) return '';
  final day = int.tryParse(parts[0]);
  final month = int.tryParse(parts[1]);
  final year = int.tryParse(parts[2]);
  if (year == null || month == null || day == null) return '';
  final gcDate = gcFromEc(year, month, day);
  return '${gcDate.year}-${_two(gcDate.month)}-${_two(gcDate.day)}';
}

String ecFromIsoShort(String iso) => ecFormatFullFromGc(gcFromIsoLocal(iso));

int getFirstDayOfMonth(int month, int year) {
  final gregDate = gcFromEc(year, month, 1);
  final dayOfWeek = gregDate.weekday;
  return dayOfWeek == 7 ? 6 : dayOfWeek - 1;
}

int getDaysInMonth(int month, int year) {
  return ecMonthLength(year, month);
}

bool isLeapYear(int year) => ecIsLeap(year);
