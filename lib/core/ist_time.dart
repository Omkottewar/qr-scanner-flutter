// All users of this app are in India. Instead of relying on `.toLocal()`
// (which depends on the device timezone and gives wrong values when the
// phone or emulator is set to UTC / some other zone), we always convert
// to IST explicitly. Dart's DateTime has no built-in timezone table, so
// we do the +5:30 offset by hand — enough for a single fixed-zone app.
class IstTime {
  static const Duration offset = Duration(hours: 5, minutes: 30);

  // Parse an ISO 8601 string from the backend as UTC. Timestamps missing
  // an explicit offset are assumed UTC (matches what PostgreSQL /
  // pg-node emit when JSON-serialising a `timestamp` column).
  static DateTime? parseUtc(String? s) {
    if (s == null || s.isEmpty) return null;
    var str = s;
    final hasOffset =
        str.endsWith('Z') || RegExp(r'[+\-]\d{2}:?\d{2}$').hasMatch(str);
    if (!hasOffset) str = '${str}Z';
    return DateTime.tryParse(str)?.toUtc();
  }

  // Given a UTC DateTime, return a DateTime whose day/hour/minute fields
  // read out as the IST clock time. The returned DateTime is a plain
  // Dart DateTime — do not call `.toLocal()` on it.
  static DateTime toIst(DateTime utc) => utc.toUtc().add(offset);

  // Elapsed duration from `thenUtc` to now, timezone-agnostic.
  static Duration since(DateTime thenUtc) =>
      DateTime.now().toUtc().difference(thenUtc.toUtc());

  static const List<String> monthsShort = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];
}
