// lib/utils/ethiopian_calendar.dart

/// ====================
/// Ethiopic (EC) <-> Gregorian (GC) helpers
/// ====================
/// Fix: Correct Ethiopic epoch JDN so EC year is correct around New Year.
/// Using JDN for 1 መስከረም 1 EC == 1724221.
const int _EC_EPOCH_JDN = 1724221;

/// Amharic month names (EC 1..13)
const List<String> _EC_MONTHS = [
  'መስከረም', 'ጥቅምት', 'ህዳር', 'ታህሳስ', 'ጥር', 'የካቲት',
  'መጋቢት', 'ሚያዚያ', 'ግንቦት', 'ሰኔ', 'ሐምሌ', 'ነሃሴ', 'ጳጉሜ',
];

/// Amharic weekdays, 1=Mon..7=Sun
const List<String> _AMH_WEEKDAYS = [
  '', 'ሰኞ', 'ማክሰኞ', 'ረቡዕ', 'ሐሙስ', 'ዓርብ', 'ቅዳሜ', 'እሁድ'
];

class EcDate {
  final int year;
  final int month; // 1..13
  final int day;   // 1..30 (1..5/6 for 13)
  final int weekday; // 1=Mon..7=Sun (copied from GC day)
  const EcDate(this.year, this.month, this.day, this.weekday);
}

/// ---------- JDN helpers ----------
int _gcToJdn(DateTime d) {
  final y = d.year;
  final m = d.month;
  final day = d.day;
  final a = (14 - m) ~/ 12;
  final y2 = y + 4800 - a;
  final m2 = m + 12 * a - 3;
  return day +
      ((153 * m2 + 2) ~/ 5) +
      365 * y2 +
      y2 ~/ 4 -
      y2 ~/ 100 +
      y2 ~/ 400 -
      32045;
}

DateTime _jdnToGc(int jdn) {
  final a = jdn + 32044;
  final b = (4 * a + 3) ~/ 146097;
  final c = a - (146097 * b) ~/ 4;
  final d = (4 * c + 3) ~/ 1461;
  final e = c - (1461 * d) ~/ 4;
  final m = (5 * e + 2) ~/ 153;
  final day = e - (153 * m + 2) ~/ 5 + 1;
  final month = m + 3 - 12 * (m ~/ 10);
  final year = 100 * b + d - 4800 + (m ~/ 10);
  return DateTime(year, month, day);
}

/// ---------- EC <-> GC ----------
bool ecIsLeap(int ecYear) => ecYear % 4 == 3;

/// Days in an EC month
int ecMonthLength(int ecYear, int ecMonth) {
  if (ecMonth >= 1 && ecMonth <= 12) return 30;
  return ecIsLeap(ecYear) ? 6 : 5; // 13th (ጳጉሜ)
}

int _ecToJdn(int y, int m, int d) {
  // 30-day months + year/4 leap rule
  return _EC_EPOCH_JDN - 1 + 365 * (y - 1) + ((y - 1) ~/ 4) + 30 * (m - 1) + d;
}

EcDate ecFromGc(DateTime g) {
  final j = _gcToJdn(DateTime(g.year, g.month, g.day));
  final r = j - _EC_EPOCH_JDN;
  final quad = r ~/ 1461;
  final rem = r % 1461;

  final y = quad * 4 + rem ~/ 365 + 1;
  final doy = rem % 365;
  final m = doy ~/ 30 + 1;
  final d = doy % 30 + 1;

  final weekday = g.weekday; // 1..7 (Mon..Sun)
  return EcDate(y, m, d, weekday);
}

DateTime gcFromEc(int y, int m, int d) {
  final jdn = _ecToJdn(y, m, d);
  return _jdnToGc(jdn);
}

/// Parse ISO "YYYY-MM-DD" into local midnight DateTime
DateTime gcFromIsoLocal(String iso) {
  final p = iso.split('-').map(int.parse).toList();
  return DateTime(p[0], p[1], p[2]); // local 00:00
}

/// Week start Monday for a GC date (local)
DateTime gcWeekStartMonday(DateTime d) {
  final day = d.weekday; // 1=Mon..7=Sun
  return DateTime(d.year, d.month, d.day).subtract(Duration(days: day - 1));
}

/// End of day (23:59:59.999)
DateTime gcEndOfDay(DateTime d) => DateTime(d.year, d.month, d.day, 23, 59, 59, 999);

/// EC first-of-month GC Date for the GC day given
DateTime gcEcMonthStartFor(DateTime g) {
  final ec = ecFromGc(g);
  return gcFromEc(ec.year, ec.month, 1);
}

/// Add months on the EC scale (1..12 only; 13th is not a regular month)
/// Returns (year, month), day is assumed 1 outside.
List<int> ecAddMonths(int y, int m, int add) {
  // We roll only in 1..12, pagume is appended to month 12 implicitly by month-end rule.
  final idxZero = (m - 1) + add;
  final ny = y + (idxZero ~/ 12);
  final nm = (idxZero % 12) + 1;
  return [ny, nm];
}

/// Does a sequence of EC months (count = n) starting at (y,m) include a Nehase (12)?
bool ecRangeIncludesNehase(int y, int m, int n) {
  for (int k = 0; k < n; k++) {
    final curM = ((m - 1 + k) % 12) + 1;
    if (curM == 12) return true;
  }
  return false;
}

/// ---------- Formatting ----------
String _two(int n) => n.toString();

String ecFormatFull(EcDate e) {
  final wd = _AMH_WEEKDAYS[e.weekday];
  final monthName = _EC_MONTHS[e.month - 1];
  return '$wd, ${_two(e.day)} $monthName ${e.year}';
}

String ecFormatFullFromGc(DateTime g) => ecFormatFull(ecFromGc(g));

/// Convenience for ISO "YYYY-MM-DD" → EC pretty
String ecFromIsoShort(String iso) => ecFormatFullFromGc(gcFromIsoLocal(iso));
