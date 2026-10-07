/// One attendance record = one work day's face-scan summary.
///
/// IMPORTANT: this is the contract between the app and the backend.
/// Whatever key names the backend actually returns from
/// GET /attendance/me must be reflected in `fromJson` below — that is
/// the single place in the whole app where this mapping happens, so
/// if the backend field names change, this is the only file to edit.
class AttendanceRecord {
  final DateTime date; // the calendar day this record belongs to (no time part)
  final DateTime? checkIn; // full timestamp of check-in scan, if any
  final DateTime? checkOut; // full timestamp of check-out scan, if any
  final double workHours; // actual worked hours for this day
  final double otHours; // overtime hours for this day
  final String status; // e.g. "ปกติ", "สาย" (late), "ขาด" (absent), "ลา" (leave)

  const AttendanceRecord({
    required this.date,
    required this.checkIn,
    required this.checkOut,
    required this.workHours,
    required this.otHours,
    required this.status,
  });

  bool get hasScan => checkIn != null || checkOut != null;

  bool isSameDay(DateTime other) =>
      date.year == other.year && date.month == other.month && date.day == other.day;

  /// Backend (`to_thailand_time` in main.py) always sends timestamps as
  /// Thailand-local time WITH a +07:00 offset (e.g. "2026-09-09T14:30:00+07:00").
  /// Dart's DateTime.tryParse converts any offset value to UTC internally,
  /// so reading .hour/.minute straight off the parsed result gives UTC time,
  /// not the Thailand clock time the backend intended — a 7-hour drift.
  /// Adding the 7 hours back here (once, in the one place this parsing
  /// happens) makes .hour/.minute match the real Thai wall-clock time,
  /// with no dependency on the device's own timezone.
  static DateTime? _parseTime(dynamic value) {
    if (value == null) return null;
    if (value is String && value.isNotEmpty) {
      final parsed = DateTime.tryParse(value);
      if (parsed == null) return null;
      return parsed.isUtc ? parsed.add(const Duration(hours: 7)) : parsed;
    }
    return null;
  }

  static double _parseDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString()) ?? 0.0;
  }

  factory AttendanceRecord.fromJson(Map<String, dynamic> json) {
    // Accept a few likely backend key spellings so this survives small
    // API naming differences without breaking. Once the real backend
    // contract is fixed, trim this list down to just the real keys.
    final checkIn = _parseTime(
      json['check_in'] ?? json['check_in_time'] ?? json['clock_in'] ?? json['in_time'],
    );
    final checkOut = _parseTime(
      json['check_out'] ?? json['check_out_time'] ?? json['clock_out'] ?? json['out_time'],
    );

    final rawDate = json['date'] ?? json['timestamp'] ?? checkIn?.toIso8601String();
    final parsedDate = _parseTime(rawDate) ?? checkIn ?? checkOut ?? DateTime.now();

    return AttendanceRecord(
      date: DateTime(parsedDate.year, parsedDate.month, parsedDate.day),
      checkIn: checkIn,
      checkOut: checkOut,
      workHours: _parseDouble(json['work_hours'] ?? json['hours']),
      otHours: _parseDouble(json['ot_hours'] ?? json['ot']),
      status: (json['status'] ?? 'ปกติ').toString(),
    );
  }
}
