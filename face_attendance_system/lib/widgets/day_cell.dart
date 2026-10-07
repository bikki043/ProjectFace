import 'package:flutter/material.dart';
import '../models/attendance_record.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';

class DayCell extends StatelessWidget {
  final int dayNumber;
  final AttendanceRecord? record;
  final bool isToday;
  final VoidCallback onTap;

  const DayCell({
    super.key,
    required this.dayNumber,
    required this.record,
    required this.isToday,
    required this.onTap,
  });

  Color? get _dotColor {
    if (record == null || !record!.hasScan) return null;
    final status = record!.status;
    if (status.contains('สาย')) return AppColors.coral;
    if (status.contains('ลา') || status.contains('ขาด')) return AppColors.inkDim;
    return AppColors.mint;
  }

  @override
  Widget build(BuildContext context) {
    final dot = _dotColor;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          color: isToday ? AppColors.primarySoft : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: isToday ? Border.all(color: AppColors.primary, width: 1.4) : null,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              '$dayNumber',
              style: AppText.body.copyWith(
                fontWeight: isToday ? FontWeight.w700 : FontWeight.w400,
                color: isToday ? AppColors.primary : AppColors.ink,
              ),
            ),
            const SizedBox(height: 3),
            Container(
              width: 5,
              height: 5,
              decoration: BoxDecoration(color: dot ?? Colors.transparent, shape: BoxShape.circle),
            ),
          ],
        ),
      ),
    );
  }
}
