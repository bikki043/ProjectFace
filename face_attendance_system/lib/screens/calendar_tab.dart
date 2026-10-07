import 'package:flutter/material.dart';
import '../models/attendance_record.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../utils/time_utils.dart';
import '../widgets/day_cell.dart';
import '../widgets/day_detail_sheet.dart';

class CalendarTab extends StatelessWidget {
  final List<AttendanceRecord> history;
  final DateTime selectedMonth;
  final ValueChanged<DateTime> onMonthChanged;

  const CalendarTab({
    super.key,
    required this.history,
    required this.selectedMonth,
    required this.onMonthChanged,
  });

  @override
  Widget build(BuildContext context) {
    final daysInMonth = DateTime(selectedMonth.year, selectedMonth.month + 1, 0).day;
    final firstDayOfMonth = DateTime(selectedMonth.year, selectedMonth.month, 1);
    final leadingBlanks = firstDayOfMonth.weekday % 7;
    final today = DateTime.now();

    // คำนวณสถิติคร่าวๆ ของเดือนนี้เพื่อให้ UI ดูมีข้อมูลเชิงลึกและไม่โล่งจนเกินไป
    final monthRecords = history.where((r) => r.date.year == selectedMonth.year && r.date.month == selectedMonth.month).toList();
    // เปลี่ยนจาก AttendanceStatus.present เป็นเช็คค่า String แบบนี้
    final presentCount = monthRecords.where((r) => r.status == 'present').length;

    return Container(
      color: AppColors.bg,
      child: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        children: [
          // 1. ส่วนหัวเปลี่ยนเดือน (Month Selector Card แบบพรีเมียม)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.ink.withOpacity(0.04)),
              boxShadow: [
                BoxShadow(
                  color: AppColors.ink.withOpacity(0.02),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Material(
                  color: Colors.transparent,
                  child: IconButton(
                    icon: Icon(Icons.chevron_left_rounded, color: AppColors.ink),
                    splashRadius: 20,
                    onPressed: () => onMonthChanged(DateTime(selectedMonth.year, selectedMonth.month - 1, 1)),
                  ),
                ),
                Row(
                  children: [
                    Icon(Icons.person_rounded, size: 52, color: AppColors.primary),
                    const SizedBox(width: 8),
                    Text(TimeUtils.monthLabel(selectedMonth), style: AppText.displayMd),
                  ],
                ),
                Material(
                  color: Colors.transparent,
                  child: IconButton(
                    icon: Icon(Icons.chevron_right_rounded, color: AppColors.ink),
                    splashRadius: 20,
                    onPressed: () => onMonthChanged(DateTime(selectedMonth.year, selectedMonth.month + 1, 1)),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // 2. การ์ดสรุปสถิติย่อประจำเดือน (เพิ่มความแอปใหญ่ให้ดูมีมิติ)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [AppColors.surface, AppColors.surface.withOpacity(0.8)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.primary.withOpacity(0.1)),
            ),
          ),
          const SizedBox(height: 16),

          // 3. ตารางปฏิทินหลัก
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: AppColors.ink.withOpacity(0.04),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              children: [
                // แถบแสดงวันในสัปดาห์ (อาทิตย์ - เสาร์)
                GridView.count(
                  crossAxisCount: 7,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  children: TimeUtils.thaiWeekdaysShort
                      .map((day) => Center(
                            child: Text(
                              day,
                              style: AppText.label.copyWith(fontWeight: FontWeight.w600),
                            ),
                          ))
                      .toList(),
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: Divider(height: 1, color: Colors.black12),
                ),
                // ช่องตารางวันในเดือน
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 7,
                    childAspectRatio: 0.95, // ปรับสัดส่วนให้ช่องดูสมส่วนขึ้น
                    mainAxisSpacing: 4,
                    crossAxisSpacing: 4,
                  ),
                  itemCount: leadingBlanks + daysInMonth,
                  itemBuilder: (context, index) {
                    if (index < leadingBlanks) return const SizedBox.shrink();

                    final dayNumber = index - leadingBlanks + 1;
                    final day = DateTime(selectedMonth.year, selectedMonth.month, dayNumber);
                    final record = TimeUtils.recordForDay(history, day);
                    final isToday = day.year == today.year && day.month == today.month && day.day == today.day;

                    return DayCell(
                      dayNumber: dayNumber,
                      record: record,
                      isToday: isToday,
                      onTap: () => showDayDetailBottomSheet(context: context, day: day, record: record),
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Widget ช่วยสร้างปุ่มสรุปข้อมูลเล็กๆ ด้านบน
  Widget _buildSummaryItem(String title, String value, IconData icon, Color color) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, size: 16, color: color),
        ),
        const SizedBox(width: 10),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: AppText.label),
            const SizedBox(height: 2),
            Text(value, style: AppText.body.copyWith(fontWeight: FontWeight.w600, fontSize: 13)),
          ],
        ),
      ],
    );
  }
}