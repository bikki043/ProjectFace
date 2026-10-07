import '../config/api_config.dart';
import '../models/attendance_record.dart';
import '../models/attendance_stats.dart';

class TimeUtils {
  TimeUtils._();

  static const List<String> thaiWeekdaysShort = ['อา', 'จ', 'อ', 'พ', 'พฤ', 'ศ', 'ส'];

  static const List<String> thaiMonths = [
    'มกราคม', 'กุมภาพันธ์', 'มีนาคม', 'เมษายน', 'พฤษภาคม', 'มิถุนายน',
    'กรกฎาคม', 'สิงหาคม', 'กันยายน', 'ตุลาคม', 'พฤศจิกายน', 'ธันวาคม',
  ];

  static String monthLabel(DateTime date) =>
      '${thaiMonths[date.month - 1]} ${date.year + 543}';

  /// HH:mm น. — returns a dash if the time is missing (no scan recorded).
  static String formatClock(DateTime? time) {
    if (time == null) return '--:--';
    final hh = time.hour.toString().padLeft(2, '0');
    final mm = time.minute.toString().padLeft(2, '0');
    return '$hh:$mm น.';
  }

  /// "8 ชั่วโมง 30 นาที" style duration label from a decimal hour value.
  static String formatHoursLabel(double hours) {
    final totalMinutes = (hours * 60).round();
    final h = totalMinutes ~/ 60;
    final m = totalMinutes % 60;
    if (m == 0) return '$h ชั่วโมง';
    return '$h ชั่วโมง $m นาที';
  }

  /// Fallback for when a record has check-in/check-out timestamps but the
  /// backend did NOT already compute work_hours/ot_hours for it. Only used
  /// when both those fields come back as 0 — the backend's own numbers
  /// always win when present, so client and server never disagree.
  ///
  /// TESTING/DEMO ONLY: the OT threshold below is set to 5 minutes instead
  /// of a real workday length, so OT can be triggered quickly while testing
  /// the flow (scan in, wait a few minutes, scan out) without needing to
  /// wait a full 8-hour shift. Before going to production, replace the
  /// 5-minute threshold with AppConfig.standardWorkHoursPerDay.
  static ({double workHours, double otHours}) deriveHoursFromTimes(
    DateTime? checkIn,
    DateTime? checkOut,
  ) {
    if (checkIn == null || checkOut == null) return (workHours: 0.0, otHours: 0.0);
    final minutes = checkOut.difference(checkIn).inMinutes;
    if (minutes <= 0) return (workHours: 0.0, otHours: 0.0);
    final hours = minutes / 60.0;

    const double standardMinutes = 5.0; // <-- demo threshold, see note above
    const double standard = standardMinutes / 60.0;

    if (minutes <= standardMinutes) return (workHours: hours, otHours: 0.0);
    return (workHours: standard, otHours: hours - standard);
  }

  static AttendanceStats calculateStats(List<AttendanceRecord> history) {
    double totalWork = 0.0;
    double totalOt = 0.0;
    int lateCount = 0;

    for (final record in history) {
      double work = record.workHours;
      double ot = record.otHours;
      if (work == 0.0 && ot == 0.0 && record.hasScan) {
        final derived = deriveHoursFromTimes(record.checkIn, record.checkOut);
        work = derived.workHours;
        ot = derived.otHours;
      }
      totalWork += work;
      totalOt += ot;

      final status = record.status.toLowerCase();
      if (status.contains('late') || record.status.contains('สาย')) {
        lateCount++;
      }
    }

    return AttendanceStats(
      totalRecords: history.length,
      totalWorkHours: totalWork,
      totalOtHours: totalOt,
      lateCount: lateCount,
    );
  }

  /// Finds the record (if any) for a given calendar day.
  static AttendanceRecord? recordForDay(List<AttendanceRecord> history, DateTime day) {
    for (final r in history) {
      if (r.isSameDay(day)) return r;
    }
    return null;
  }
}
