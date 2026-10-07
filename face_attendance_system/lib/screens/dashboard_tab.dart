import 'package:flutter/material.dart';
import '../models/attendance_record.dart';
import '../models/attendance_stats.dart';
import '../models/user_profile.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../utils/time_utils.dart';

class DashboardTab extends StatelessWidget {
  final UserProfile profile;
  final List<AttendanceRecord> history;

  const DashboardTab({super.key, required this.profile, required this.history});

  @override
  Widget build(BuildContext context) {
    final AttendanceStats stats = TimeUtils.calculateStats(history);
    final sorted = [...history]..sort((a, b) => b.date.compareTo(a.date));

    return Container(
      color: AppColors.bg,
      child: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        children: [
          // ส่วนหัวโปรไฟล์
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(profile.name, style: AppText.displayMd),
                  const SizedBox(height: 3),
                  Text('รหัสพนักงาน: ${profile.employeeId}', style: AppText.bodyDim),
                ],
              ),
              Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(color: AppColors.mint, shape: BoxShape.circle),
                  ),
                  const SizedBox(width: 6),
                  Text('ออนไลน์', style: AppText.body.copyWith(color: AppColors.mint, fontWeight: FontWeight.w500)),
                ],
              ),
            ],
          ),
          const SizedBox(height: 24),

          // การ์ดสรุปภาพรวม
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.divider),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('เดือนนี้คุณมาทำงาน', style: AppText.bodyDim.copyWith(fontWeight: FontWeight.w500)),
                const SizedBox(height: 14),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text('${stats.totalRecords}', style: AppText.statNumber.copyWith(fontSize: 34)),
                    const SizedBox(width: 6),
                    Text('วัน', style: AppText.bodyDim),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // ตารางสถิติย่อย 2x2
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
            childAspectRatio: 1.5,
            children: [
              _buildSimpleStatCard('เวลารวมทำงาน', '${stats.totalWorkHours.toStringAsFixed(1)} ชม.'),
              _buildSimpleStatCard('ชั่วโมงโอที (OT)', '${stats.totalOtHours.toStringAsFixed(1)} ชม.'),
              _buildSimpleStatCard('ตรงเวลา', '${stats.totalRecords - stats.lateCount} ครั้ง'),
              _buildSimpleStatCard('มาสาย', '${stats.lateCount} ครั้ง', isAlert: stats.lateCount > 0),
            ],
          ),
          const SizedBox(height: 24),

          // หัวข้อประวัติล่าสุด
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('ประวัติการลงเวลาล่าสุด', style: AppText.body.copyWith(fontWeight: FontWeight.w600)),
              Text('แสดง 5 รายการล่าสุด', style: AppText.label),
            ],
          ),
          const SizedBox(height: 12),

          // รายการประวัติ
          if (sorted.isEmpty)
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.divider),
              ),
              child: Center(
                child: Text('ไม่มีข้อมูลการลงเวลาในระบบ', style: AppText.bodyDim),
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: sorted.length > 5 ? 5 : sorted.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final item = sorted[index];
                final isLate = item.status.contains('สาย');
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.divider),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${item.date.day}/${item.date.month}/${item.date.year + 543}',
                            style: AppText.body.copyWith(fontWeight: FontWeight.w500),
                          ),
                          const SizedBox(height: 3),
                          Text('บันทึกเวลา: ${TimeUtils.formatClock(item.checkIn)} น.', style: AppText.bodyDim),
                        ],
                      ),
                      Text(
                        item.status,
                        style: AppText.body.copyWith(
                          color: isLate ? AppColors.amber : AppColors.mint,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _buildSimpleStatCard(String title, String value, {bool isAlert = false}) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(title, style: AppText.label),
          const SizedBox(height: 6),
          Text(
            value,
            style: AppText.body.copyWith(
              color: isAlert ? AppColors.amber : AppColors.ink,
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
