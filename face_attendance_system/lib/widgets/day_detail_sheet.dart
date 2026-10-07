import 'package:flutter/material.dart';
import '../models/attendance_record.dart';
import '../theme/app_colors.dart';
import '../utils/time_utils.dart';
import 'time_detail_row.dart';

/// Shows the check-in / check-out / total-hours / OT detail for [record].
/// Pass a null [record] when the day has no scan at all (holiday/leave).
void showDayDetailBottomSheet({
  required BuildContext context,
  required DateTime day,
  required AttendanceRecord? record,
}) {
  showModalBottomSheet(
    context: context,
    backgroundColor: AppColors.panel,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
    builder: (context) {
      final hasScanned = record?.hasScan ?? false;

      double workHours = record?.workHours ?? 0.0;
      double otHours = record?.otHours ?? 0.0;
      if (record != null && workHours == 0.0 && otHours == 0.0 && hasScanned) {
        final derived = TimeUtils.deriveHoursFromTimes(record.checkIn, record.checkOut);
        workHours = derived.workHours;
        otHours = derived.otHours;
      }

      return Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'ประวัติการลงเวลาวันที่ ${day.day}/${day.month}/${day.year + 543}',
                  style: TextStyle(color: AppColors.accent, fontWeight: FontWeight.bold, fontSize: 15),
                ),
                IconButton(
                  icon: Icon(Icons.close, color: AppColors.inkDim),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            Divider(color: AppColors.panelLine),
            const SizedBox(height: 10),
            if (!hasScanned)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 20),
                child: Center(
                  child: Text(
                    record == null
                        ? 'ไม่มีบันทึกการสแกนหน้าในวันนี้ (วันหยุด/ลา)'
                        : 'สถานะ: ${record.status}',
                    style: TextStyle(color: AppColors.inkDim),
                  ),
                ),
              )
            else ...[
              TimeDetailRow(
                label: 'เวลาเข้างาน (Check-In)',
                value: TimeUtils.formatClock(record!.checkIn),
                icon: Icons.login_rounded,
                color: AppColors.accent,
              ),
              const SizedBox(height: 10),
              TimeDetailRow(
                label: 'เวลาออกงาน (Check-Out)',
                value: TimeUtils.formatClock(record.checkOut),
                icon: Icons.logout_rounded,
                color: Colors.orange,
              ),
              const SizedBox(height: 10),
              TimeDetailRow(
                label: 'รวมเวลาทำงานจริง',
                value: TimeUtils.formatHoursLabel(workHours),
                icon: Icons.access_time,
                color: AppColors.ink,
              ),
              const SizedBox(height: 10),
              TimeDetailRow(
                label: 'โอที (OT)',
                value: otHours > 0 ? '+${TimeUtils.formatHoursLabel(otHours)}' : 'ไม่มี OT',
                icon: Icons.star_rounded,
                color: Colors.purpleAccent,
              ),
            ],
            const SizedBox(height: 16),
          ],
        ),
      );
    },
  );
}
