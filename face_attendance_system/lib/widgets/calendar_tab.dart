import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../models/attendance_model.dart';
import '../utils/time_utils.dart';

class CalendarTab extends StatefulWidget {
  final List<AttendanceModel> history;

  const CalendarTab({super.key, required this.history});

  @override
  State<CalendarTab> createState() => _CalendarTabState();
}

class _CalendarTabState extends State<CalendarTab> {
  final DateTime _selectedMonth = DateTime.now();

  @override
  Widget build(BuildContext context) {
    int daysInMonth = DateTime(_selectedMonth.year, _selectedMonth.month + 1, 0).day;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'ปฏิทินลงเวลา (${_selectedMonth.month}/${_selectedMonth.year})',
              style: const TextStyle(color: AppColors.ink, fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const Text('กดที่วันเพื่อดูรายละเอียด', style: TextStyle(color: AppColors.accent, fontSize: 11)),
          ],
        ),
        const SizedBox(height: 16),

        GridView.count(
          crossAxisCount: 7,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          children: ['อา', 'จ', 'อ', 'พ', 'พฤ', 'ศ', 'ส']
              .map((day) => Center(child: Text(day, style: const TextStyle(color: AppColors.inkDim, fontWeight: FontWeight.bold, fontSize: 12))))
              .toList(),
        ),
        const Divider(color: AppColors.panelLine),

        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 7, childAspectRatio: 1),
          itemCount: daysInMonth,
          itemBuilder: (context, index) {
            int dayNumber = index + 1;

            AttendanceModel? record;
            try {
              record = widget.history.firstWhere(
                (item) => item.date.day == dayNumber && item.date.month == _selectedMonth.month && item.date.year == _selectedMonth.year,
              );
            } catch (_) {
              record = null;
            }

            bool hasScanned = record != null;

            return InkWell(
              onTap: () => _showDayDetailBottomSheet(context, dayNumber, record),
              child: Container(
                margin: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  color: AppColors.panel,
                  border: Border.all(color: hasScanned ? AppColors.accent.withOpacity(0.6) : AppColors.panelLine),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text('$dayNumber', style: TextStyle(color: hasScanned ? AppColors.ink : AppColors.inkDim, fontWeight: FontWeight.bold, fontSize: 13)),
                    if (hasScanned)
                      Container(
                        margin: const EdgeInsets.only(top: 3),
                        width: 5,
                        height: 5,
                        decoration: const BoxDecoration(color: AppColors.accent, shape: BoxShape.circle),
                      ),
                  ],
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  void _showDayDetailBottomSheet(BuildContext context, int day, AttendanceModel? record) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.panel,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('ประวัติการลงเวลาวันที่ $day/${_selectedMonth.month}/${_selectedMonth.year}',
                      style: const TextStyle(color: AppColors.accent, fontWeight: FontWeight.bold, fontSize: 15)),
                  IconButton(icon: const Icon(Icons.close, color: AppColors.inkDim), onPressed: () => Navigator.pop(context)),
                ],
              ),
              const Divider(color: AppColors.panelLine),
              const SizedBox(height: 10),
              if (record == null)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 20),
                  child: Center(child: Text('ไม่มีบันทึกการสแกนหน้าในวันนี้', style: TextStyle(color: AppColors.inkDim))),
                )
              else ...[
                _buildTimeDetailRow('เวลาเข้างาน (Check-In)', TimeUtils.formatClock(record.checkIn), Icons.login_rounded, AppColors.accent),
                const SizedBox(height: 10),
                _buildTimeDetailRow('เวลาออกงาน (Check-Out)', TimeUtils.formatClock(record.checkOut), Icons.logout_rounded, Colors.orange),
                const SizedBox(height: 10),
                _buildTimeDetailRow('เวลารวมทำงานจริง', '${record.workHours} ชั่วโมง', Icons.access_time, AppColors.ink),
                const SizedBox(height: 10),
                _buildTimeDetailRow('โอที (OT)', '+${record.otHours} ชั่วโมง', Icons.star_rounded, Colors.purpleAccent),
              ],
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }

  Widget _buildTimeDetailRow(String label, String time, IconData icon, Color color) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Icon(icon, color: color, size: 18),
            const SizedBox(width: 8),
            Text(label, style: const TextStyle(color: AppColors.inkDim, fontSize: 13)),
          ],
        ),
        Text(time, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 13)),
      ],
    );
  }
}