/// Philippine time (UTC+08:00, no daylight saving): the time the OSCA office
/// and its seniors use, whatever time zone the phone is set to.
const Duration _philippineOffset = Duration(hours: 8);

/// A time with an offset or "Z" at the end, e.g. "2026-10-20T21:15:00+08:00".
/// A plain date ("2026-10-20") or a naive time has none.
final RegExp _hasOffset = RegExp(
  r'\d{2}:\d{2}(:\d{2}([.,]\d+)?)?\s*(z|[+-]\d{2}(:?\d{2})?)$',
  caseSensitive: false,
);

/// The Philippine wall-clock time of the moment [instant]. The fields are
/// Philippine, but the value is not UTC, so DateFormat prints them as they are.
DateTime toPhilippineTime(DateTime instant) {
  final ph = instant.toUtc().add(_philippineOffset);
  return DateTime(
    ph.year,
    ph.month,
    ph.day,
    ph.hour,
    ph.minute,
    ph.second,
    ph.millisecond,
    ph.microsecond,
  );
}

/// Reads a timestamp from the server. When it has an offset (or "Z") it is
/// converted to Philippine wall-clock time, so 9:15 PM stays 9:15 PM. When it
/// has none (a plain date or a naive time) it is read as written. Null when
/// [text] is empty or not a date.
///
/// Why this exists: DateTime.tryParse("...T21:15:00+08:00") returns a UTC
/// DateTime, and DateFormat prints its UTC fields, so 9:15 PM showed as 1:15 PM.
DateTime? parseServerTime(String? text) {
  final value = text?.trim() ?? '';
  if (value.isEmpty) return null;
  final parsed = DateTime.tryParse(value);
  if (parsed == null) return null;
  return _hasOffset.hasMatch(value) ? toPhilippineTime(parsed) : parsed;
}
