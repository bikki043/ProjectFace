import 'package:flutter_test/flutter_test.dart';
import 'package:face_attendance_system/models/payslip.dart';
import 'package:face_attendance_system/models/payroll_estimate.dart';

void main() {
  test('parses payroll amounts returned as numbers or strings', () {
    final payslip = Payslip.fromJson({
      'id': 14,
      'year': 2026,
      'month': 10,
      'pay_basis': 'monthly',
      'base_salary': 15000,
      'overtime_pay': '1250.50',
      'other_additions': 200,
      'tax_deduction': '100.25',
      'social_security_deduction': 750,
      'other_deductions': null,
      'net_salary': '15500.25',
      'pdf_path': null,
    });

    expect(payslip.id, 14);
    expect(payslip.payBasis, 'monthly');
    expect(payslip.baseSalary, 15000);
    expect(payslip.overtimePay, 1250.50);
    expect(payslip.taxDeduction, 100.25);
    expect(payslip.otherDeductions, 0);
    expect(payslip.netSalary, 15500.25);
    expect(payslip.pdfPath, isNull);
  });

  test('parses a live daily-pay estimate separately from issued slips', () {
    final estimate = PayrollEstimate.fromJson({
      'year': 2026,
      'month': 10,
      'pay_basis': 'daily',
      'monthly_salary': 0,
      'daily_wage': 800,
      'overtime_rate': 60,
      'completed_days': 2,
      'scheduled_workdays': 22,
      'elapsed_scheduled_days': 10,
      'attended_workdays': 2,
      'absence_days': 8,
      'work_minutes': 30,
      'overtime_minutes': 26,
      'overtime_hours': 0.4333,
      'base_pay': 1600,
      'overtime_pay': 26,
      'other_additions': 0,
      'tax_deduction': 0,
      'social_security_deduction': 0,
      'other_deductions': 0,
      'net_pay': 1626,
      'is_finalized': false,
      'attendance_days': [
        {
          'date': '2026-10-06',
          'worked_minutes': 12,
          'completed_sessions': 1,
          'is_qualifying_day': true,
          'is_scheduled_workday': true,
          'is_absent': false,
          'overtime_minutes': 10,
          'overtime_pay': 10,
          'sessions': [
            {
              'check_in': '2026-10-06T09:00:00+07:00',
              'check_out': '2026-10-06T09:12:00+07:00',
              'duration_minutes': 12,
              'is_complete': true,
            },
          ],
        },
      ],
    });

    expect(estimate.payBasis, 'daily');
    expect(estimate.completedDays, 2);
    expect(estimate.scheduledWorkdays, 22);
    expect(estimate.elapsedScheduledDays, 10);
    expect(estimate.attendedWorkdays, 2);
    expect(estimate.absenceDays, 8);
    expect(estimate.basePay, 1600);
    expect(estimate.overtimePay, 26);
    expect(estimate.netPay, 1626);
    expect(estimate.isFinalized, isFalse);
    expect(estimate.attendanceDays, hasLength(1));
    expect(estimate.attendanceDays.single.sessions.single.checkIn.hour, 9);
    expect(estimate.attendanceDays.single.sessions.single.checkOut?.minute, 12);
    expect(estimate.attendanceDays.single.overtimeMinutes, 10);
  });
}