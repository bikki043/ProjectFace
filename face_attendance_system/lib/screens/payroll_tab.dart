import 'dart:async';
import 'package:flutter/material.dart';
import '../models/payslip.dart';
import '../models/payroll_estimate.dart';
import '../services/api_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';

class PayrollTab extends StatefulWidget {
  final ApiService apiService;

  const PayrollTab({super.key, required this.apiService});

  @override
  State<PayrollTab> createState() => PayrollTabState();
}

class _PayrollData {
  final List<Payslip> payslips;
  final PayrollEstimate estimate;

  const _PayrollData({required this.payslips, required this.estimate});
}

class PayrollTabState extends State<PayrollTab> with WidgetsBindingObserver {
  late Future<_PayrollData> _dataFuture;
  Timer? _refreshTimer;
  bool _isRefreshing = false;
  DateTime _selectedMonth = DateTime(DateTime.now().year, DateTime.now().month);
  int _selectedView = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _dataFuture = _fetchAll();
    _refreshTimer = Timer.periodic(const Duration(seconds: 30), (_) => refresh());
  }

  Future<_PayrollData> _fetchAll() async {
    final payslipsFuture = widget.apiService.getPayroll();
    final estimateFuture = widget.apiService.getPayrollEstimate(
      year: _selectedMonth.year,
      month: _selectedMonth.month,
    );
    return _PayrollData(
      payslips: await payslipsFuture,
      estimate: await estimateFuture,
    );
  }

  Future<void> refresh() async {
    if (_isRefreshing) return;
    _isRefreshing = true;
    final future = _fetchAll();
    if (mounted) setState(() => _dataFuture = future);
    try {
      await future;
    } catch (_) {
      // The FutureBuilder renders the request error with a retry action.
    } finally {
      _isRefreshing = false;
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) refresh();
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  String _period(Payslip payslip) {
    const months = [
      'มกราคม', 'กุมภาพันธ์', 'มีนาคม', 'เมษายน', 'พฤษภาคม', 'มิถุนายน',
      'กรกฎาคม', 'สิงหาคม', 'กันยายน', 'ตุลาคม', 'พฤศจิกายน', 'ธันวาคม',
    ];
    final monthName = payslip.month >= 1 && payslip.month <= 12
        ? months[payslip.month - 1]
        : 'งวดที่ ${payslip.month}';
    return '$monthName ${payslip.year + 543}';
  }

  String _selectedPeriodLabel() {
    const months = [
      'มกราคม', 'กุมภาพันธ์', 'มีนาคม', 'เมษายน', 'พฤษภาคม', 'มิถุนายน',
      'กรกฎาคม', 'สิงหาคม', 'กันยายน', 'ตุลาคม', 'พฤศจิกายน', 'ธันวาคม',
    ];
    return '${months[_selectedMonth.month - 1]} ${_selectedMonth.year + 543}';
  }

  Future<void> _changeMonth(int delta) async {
    final changed = DateTime(_selectedMonth.year, _selectedMonth.month + delta);
    final now = DateTime.now();
    if (changed.isAfter(DateTime(now.year, now.month))) return;
    setState(() {
      _selectedMonth = changed;
      _dataFuture = _fetchAll();
    });
    try {
      await _dataFuture;
    } catch (_) {
      // The FutureBuilder renders the fetch error and retry action.
    }
  }

  String _money(double value) => value.toStringAsFixed(2);

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.bg,
      child: RefreshIndicator(
        color: AppColors.primary,
        onRefresh: refresh,
        child: FutureBuilder<_PayrollData>(
          future: _dataFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
              return ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: [
                  SizedBox(
                    height: MediaQuery.sizeOf(context).height * 0.65,
                    child: Center(child: CircularProgressIndicator(color: AppColors.primary)),
                  ),
                ],
              );
            }

            if (snapshot.hasError) {
              return ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(24),
                children: [
                  const SizedBox(height: 100),
                  Icon(Icons.cloud_off_rounded, size: 42, color: AppColors.coral),
                  const SizedBox(height: 12),
                  Text('โหลดข้อมูลเงินเดือนไม่สำเร็จ', textAlign: TextAlign.center, style: AppText.displayMd),
                  const SizedBox(height: 6),
                  Text('${snapshot.error}', textAlign: TextAlign.center, style: AppText.bodyDim),
                  const SizedBox(height: 16),
                  Center(
                    child: OutlinedButton.icon(
                      onPressed: refresh,
                      icon: const Icon(Icons.refresh_rounded),
                      label: const Text('ลองอีกครั้ง'),
                    ),
                  ),
                ],
              );
            }

            final data = snapshot.data!;
            final payslips = [...data.payslips]
              ..sort((a, b) {
                final byYear = b.year.compareTo(a.year);
                return byYear != 0 ? byYear : b.month.compareTo(a.month);
              });

            final selectedPayslip = payslips.where((payslip) =>
              payslip.year == _selectedMonth.year && payslip.month == _selectedMonth.month
            ).firstOrNull;
            return ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
              children: [
                SegmentedButton<int>(
                  segments: const [
                    ButtonSegment(value: 0, label: Text('สรุปงวดนี้'), icon: Icon(Icons.payments_outlined)),
                    ButtonSegment(value: 1, label: Text('ประวัติสลิป'), icon: Icon(Icons.receipt_long_outlined)),
                  ],
                  selected: {_selectedView},
                  onSelectionChanged: (selection) => setState(() => _selectedView = selection.first),
                  showSelectedIcon: false,
                ),
                const SizedBox(height: 20),
                if (_selectedView == 0) ...[
                  _buildPeriodSelector(),
                  const SizedBox(height: 14),
                  _buildEstimateCard(data.estimate, selectedPayslip),
                ] else ...[
                  Text('สลิปเงินเดือนที่ออกแล้ว', style: AppText.displayMd),
                  const SizedBox(height: 6),
                  Text('รายการยืนยันจากฝ่ายบุคคลเรียงจากงวดล่าสุด', style: AppText.bodyDim),
                  const SizedBox(height: 14),
                  if (payslips.isEmpty) _buildEmptySlips(),
                  ...payslips.map(_buildPayslipCard),
                ],
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildPeriodSelector() {
    final now = DateTime.now();
    final canAdvance = _selectedMonth.year < now.year ||
        (_selectedMonth.year == now.year && _selectedMonth.month < now.month);
    return Row(
      children: [
        IconButton(
          tooltip: 'เดือนก่อนหน้า',
          onPressed: () => _changeMonth(-1),
          icon: const Icon(Icons.chevron_left_rounded),
          style: IconButton.styleFrom(foregroundColor: AppColors.ink),
        ),
        Expanded(
          child: Column(
            children: [
              Text(_selectedPeriodLabel(), style: AppText.displayMd),
              Text('งวดเงินเดือน', style: AppText.label),
            ],
          ),
        ),
        IconButton(
          tooltip: 'เดือนถัดไป',
          onPressed: canAdvance ? () => _changeMonth(1) : null,
          icon: const Icon(Icons.chevron_right_rounded),
          style: IconButton.styleFrom(foregroundColor: AppColors.ink),
        ),
      ],
    );
  }

  Widget _buildEmptySlips() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 30),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        children: [
          Icon(Icons.receipt_long_outlined, size: 36, color: AppColors.inkDim),
          const SizedBox(height: 10),
          Text('ยังไม่มีสลิปเงินเดือน', style: AppText.body.copyWith(fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          Text('เมื่อฝ่ายบุคคลออกสลิปแล้ว รายการจะแสดงที่นี่', textAlign: TextAlign.center, style: AppText.bodyDim),
        ],
      ),
    );
  }

  Widget _buildEstimateCard(PayrollEstimate estimate, Payslip? payslip) {
    final isDaily = estimate.payBasis == 'daily';
    final isFinalized = payslip != null || estimate.isFinalized;
    final basePay = payslip?.baseSalary ?? estimate.basePay;
    final overtimePay = payslip?.overtimePay ?? estimate.overtimePay;
    final otherAdditions = payslip?.otherAdditions ?? estimate.otherAdditions;
    final taxDeduction = payslip?.taxDeduction ?? estimate.taxDeduction;
    final socialDeduction = payslip?.socialSecurityDeduction ?? estimate.socialSecurityDeduction;
    final otherDeductions = payslip?.otherDeductions ?? estimate.otherDeductions;
    final deductions = taxDeduction + socialDeduction + otherDeductions;
    final netPay = payslip?.netSalary ?? estimate.netPay;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text(isFinalized ? 'ยอดเงินสุทธิ' : 'ยอดเงินประมาณการ', style: AppText.bodyDim)),
              _statusPill(isFinalized ? 'ออกสลิปแล้ว' : 'ยังไม่สรุป', isFinalized),
            ],
          ),
          const SizedBox(height: 5),
          Text('฿${_money(netPay)}', style: AppText.statNumber.copyWith(fontSize: 34)),
          const SizedBox(height: 5),
          Text(
            isDaily
                ? 'รายวัน · ${estimate.completedDays} วันที่ผ่านเกณฑ์'
                : 'รายเดือน · มาทำงาน ${estimate.attendedWorkdays}/${estimate.scheduledWorkdays} วัน · ขาด ${estimate.absenceDays} วัน',
            style: AppText.bodyDim,
          ),
          if (!isFinalized) ...[
            const SizedBox(height: 5),
            Text('อัปเดตจากเวลาสแกน · ตัวเลขอาจเปลี่ยนก่อนออกสลิป', style: AppText.label.copyWith(color: AppColors.primary)),
          ],
          if (!isDaily) ...[
            const SizedBox(height: 4),
            Text('คิดวันทำงาน จันทร์-ศุกร์ · ยังไม่รวมปฏิทินวันหยุดบริษัท', style: AppText.label),
          ],
          const SizedBox(height: 18),
          Divider(color: AppColors.divider, height: 1),
          const SizedBox(height: 12),
          Text('รายรับ', style: AppText.body.copyWith(fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          _amountRow(
            isDaily ? 'ค่าจ้างรายวัน (${estimate.completedDays} วัน)' : 'เงินเดือนตามวันที่มาทำงาน',
            basePay,
          ),
          _amountRow('ค่าล่วงเวลา (${estimate.overtimeMinutes.toStringAsFixed(1)} นาที)', overtimePay),
          _amountRow('รายได้อื่น', otherAdditions),
          const SizedBox(height: 12),
          Text('รายการหัก', style: AppText.body.copyWith(fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          _amountRow('ภาษีหัก ณ ที่จ่าย', taxDeduction, isDeduction: true),
          _amountRow('ประกันสังคม', socialDeduction, isDeduction: true),
          _amountRow('รายการหักอื่น', otherDeductions, isDeduction: true),
          Divider(color: AppColors.divider, height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('รวมรายการหัก', style: AppText.bodyDim),
              Text('-฿${_money(deductions)}', style: AppText.body.copyWith(color: AppColors.coral)),
            ],
          ),
          const SizedBox(height: 12),
          _buildWorkSummary(estimate),
          const SizedBox(height: 18),
          Divider(color: AppColors.divider, height: 1),
          const SizedBox(height: 14),
          Text('เวลาเข้า-ออกและ OT รายวัน', style: AppText.body.copyWith(fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          Text('แสดงเวลาสแกนที่ใช้คำนวณค่าจ้างและ OT ของงวดนี้', style: AppText.label),
          const SizedBox(height: 10),
          _buildAttendanceBreakdown(estimate),
          if (payslip?.pdfPath != null && payslip!.pdfPath!.isNotEmpty) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(Icons.picture_as_pdf_outlined, size: 17, color: AppColors.primary),
                const SizedBox(width: 6),
                Text('มีไฟล์สลิปแนบ', style: AppText.label.copyWith(color: AppColors.primary)),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _statusPill(String label, bool finalized) {
    final foreground = finalized ? AppColors.mint : AppColors.amber;
    final background = finalized ? AppColors.mintSoft : AppColors.amberSoft;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(label, style: AppText.label.copyWith(color: foreground, fontWeight: FontWeight.w600)),
    );
  }

  Widget _buildWorkSummary(PayrollEstimate estimate) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
      decoration: BoxDecoration(
        color: AppColors.surfaceAlt,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          _workMetric(
            estimate.payBasis == 'monthly' ? 'มา / กำหนด' : 'วันทำงาน',
            estimate.payBasis == 'monthly'
                ? '${estimate.attendedWorkdays}/${estimate.scheduledWorkdays}'
                : '${estimate.completedDays}',
            Icons.event_available_outlined,
          ),
          _metricDivider(),
          _workMetric('เวลารวม', '${(estimate.workMinutes / 60).toStringAsFixed(1)} ชม.', Icons.schedule_rounded),
          _metricDivider(),
          _workMetric('OT', '${estimate.overtimeHours.toStringAsFixed(1)} ชม.', Icons.more_time_rounded),
        ],
      ),
    );
  }

  Widget _workMetric(String label, String value, IconData icon) {
    return Expanded(
      child: Column(
        children: [
          Icon(icon, size: 17, color: AppColors.primary),
          const SizedBox(height: 5),
          Text(value, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppText.body.copyWith(fontWeight: FontWeight.w600)),
          Text(label, style: AppText.label),
        ],
      ),
    );
  }

  Widget _metricDivider() => Container(width: 1, height: 38, color: AppColors.divider);

  Widget _buildAttendanceBreakdown(PayrollEstimate estimate) {
    if (estimate.attendanceDays.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Text('ยังไม่มีรายการสแกนในงวดนี้', style: AppText.bodyDim),
      );
    }

    return Column(
      children: estimate.attendanceDays.map((day) {
        return Container(
          width: double.infinity,
          margin: const EdgeInsets.only(bottom: 9),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.surfaceAlt,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(_formatThaiDate(day.date), style: AppText.body.copyWith(fontWeight: FontWeight.w600)),
                  ),
                  _statusPill(
                    estimate.payBasis == 'monthly' && !day.isScheduledWorkday
                        ? 'วันหยุดตามตาราง'
                        : day.isAbsent
                            ? 'ขาด · หักฐานเงิน'
                            : day.isQualifyingDay
                                ? 'มาทำงาน · ผ่านเกณฑ์'
                                : 'ยังไม่ครบ 2 นาที',
                    day.isQualifyingDay && !day.isAbsent,
                  ),
                ],
              ),
              const SizedBox(height: 8),
              ...day.sessions.map(_buildScanSession),
              const SizedBox(height: 7),
              Divider(color: AppColors.divider, height: 1),
              const SizedBox(height: 7),
              Row(
                children: [
                  Expanded(child: Text('เวลาที่จับคู่ได้ ${_formatDuration(day.workedMinutes)}', style: AppText.label)),
                  Text('OT ${_formatDuration(day.overtimeMinutes)} · ฿${_money(day.overtimePay)}',
                      style: AppText.label.copyWith(color: day.overtimeMinutes > 0 ? AppColors.primary : AppColors.inkDim,
                        fontWeight: day.overtimeMinutes > 0 ? FontWeight.w600 : FontWeight.w400)),
                ],
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildScanSession(PayrollAttendanceSession session) {
    final clockedIn = _clock(session.checkIn);
    final clockedOut = session.checkOut == null ? null : _clock(session.checkOut!);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(Icons.login_rounded, size: 16, color: AppColors.mint),
          const SizedBox(width: 5),
          Text(clockedIn, style: AppText.body.copyWith(fontWeight: FontWeight.w600)),
          const SizedBox(width: 8),
          Icon(Icons.logout_rounded, size: 16, color: session.isComplete ? AppColors.coral : AppColors.inkDim),
          const SizedBox(width: 5),
          if (clockedOut != null)
            Text(clockedOut, style: AppText.body.copyWith(fontWeight: FontWeight.w600))
          else
            Text('ยังไม่สแกนออก', style: AppText.label.copyWith(color: AppColors.amber)),
          const Spacer(),
          Text(
            session.isComplete
                ? _formatDuration(session.durationMinutes)
                : 'กำลังทำงาน ${_formatDuration(session.durationMinutes)}',
            style: AppText.label.copyWith(color: session.isComplete ? AppColors.inkDim : AppColors.amber),
          ),
        ],
      ),
    );
  }

  String _clock(DateTime value) =>
      '${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')} น.';

  String _formatDuration(double minutes) {
    final roundedMinutes = minutes.round();
    final hours = roundedMinutes ~/ 60;
    final remainingMinutes = roundedMinutes % 60;
    if (hours == 0) return '$remainingMinutes นาที';
    if (remainingMinutes == 0) return '$hours ชม.';
    return '$hours ชม. $remainingMinutes นาที';
  }

  String _formatThaiDate(DateTime date) {
    const weekdays = ['จ.', 'อ.', 'พ.', 'พฤ.', 'ศ.', 'ส.', 'อา.'];
    const months = [
      'ม.ค.', 'ก.พ.', 'มี.ค.', 'เม.ย.', 'พ.ค.', 'มิ.ย.',
      'ก.ค.', 'ส.ค.', 'ก.ย.', 'ต.ค.', 'พ.ย.', 'ธ.ค.',
    ];
    return '${weekdays[date.weekday - 1]} ${date.day} ${months[date.month - 1]} ${date.year + 543}';
  }

  Widget _buildPayslipCard(Payslip payslip) {
    final deductions = payslip.taxDeduction + payslip.socialSecurityDeduction + payslip.otherDeductions;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(_period(payslip), style: AppText.body.copyWith(fontWeight: FontWeight.w600)),
                    Text(payslip.payBasis == 'monthly' ? 'พนักงานรายเดือน' : 'พนักงานรายวัน', style: AppText.label),
                  ],
                ),
              ),
              Text('฿${_money(payslip.netSalary)}', style: AppText.body.copyWith(color: AppColors.mint, fontWeight: FontWeight.w700)),
            ],
          ),
          const SizedBox(height: 12),
          _amountRow('เงินเดือนพื้นฐาน', payslip.baseSalary),
          _amountRow('ค่าล่วงเวลา (OT)', payslip.overtimePay),
          _amountRow('รายได้อื่น', payslip.otherAdditions),
          Divider(color: AppColors.divider, height: 18),
          _amountRow('รายการหักรวม', deductions, isDeduction: true),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('รับสุทธิ', style: AppText.body.copyWith(fontWeight: FontWeight.w700)),
              Text('฿${_money(payslip.netSalary)}', style: AppText.body.copyWith(fontWeight: FontWeight.w700)),
            ],
          ),
          if (payslip.pdfPath != null && payslip.pdfPath!.isNotEmpty) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                Icon(Icons.picture_as_pdf_outlined, size: 17, color: AppColors.primary),
                const SizedBox(width: 6),
                Text('มีไฟล์สลิปแนบ', style: AppText.label.copyWith(color: AppColors.primary)),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _amountRow(String label, double amount, {bool isDeduction = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: AppText.bodyDim),
          Text(
            '${isDeduction ? '-' : ''}฿${_money(amount)}',
            style: AppText.body.copyWith(color: isDeduction ? AppColors.coral : AppColors.ink),
          ),
        ],
      ),
    );
  }
}