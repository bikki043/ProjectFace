class PayrollAttendanceSession {
  final DateTime checkIn;
  final DateTime? checkOut;
  final double durationMinutes;
  final bool isComplete;

  const PayrollAttendanceSession({
    required this.checkIn,
    required this.checkOut,
    required this.durationMinutes,
    required this.isComplete,
  });

  factory PayrollAttendanceSession.fromJson(Map<String, dynamic> json) {
    return PayrollAttendanceSession(
      checkIn: DateTime.parse(json['check_in'].toString()).toLocal(),
      checkOut: json['check_out'] == null
          ? null
          : DateTime.parse(json['check_out'].toString()).toLocal(),
      durationMinutes: double.tryParse('${json['duration_minutes'] ?? 0}') ?? 0,
      isComplete: json['is_complete'] == true,
    );
  }
}

class PayrollAttendanceDay {
  final DateTime date;
  final List<PayrollAttendanceSession> sessions;
  final double workedMinutes;
  final int completedSessions;
  final bool isQualifyingDay;
  final bool isScheduledWorkday;
  final bool isAbsent;
  final double overtimeMinutes;
  final double overtimePay;

  const PayrollAttendanceDay({
    required this.date,
    required this.sessions,
    required this.workedMinutes,
    required this.completedSessions,
    required this.isQualifyingDay,
    required this.isScheduledWorkday,
    required this.isAbsent,
    required this.overtimeMinutes,
    required this.overtimePay,
  });

  factory PayrollAttendanceDay.fromJson(Map<String, dynamic> json) {
    double amount(String key) => double.tryParse('${json[key] ?? 0}') ?? 0;
    int count(String key) => int.tryParse('${json[key] ?? 0}') ?? 0;
    final sessions = (json['sessions'] as List<dynamic>? ?? const [])
        .whereType<Map<String, dynamic>>()
        .map(PayrollAttendanceSession.fromJson)
        .toList();

    return PayrollAttendanceDay(
      date: DateTime.parse(json['date'].toString()),
      sessions: sessions,
      workedMinutes: amount('worked_minutes'),
      completedSessions: count('completed_sessions'),
      isQualifyingDay: json['is_qualifying_day'] == true,
      isScheduledWorkday: json['is_scheduled_workday'] == true,
      isAbsent: json['is_absent'] == true,
      overtimeMinutes: amount('overtime_minutes'),
      overtimePay: amount('overtime_pay'),
    );
  }
}

class PayrollEstimate {
  final int year;
  final int month;
  final String payBasis;
  final double monthlySalary;
  final double dailyWage;
  final double overtimeRate;
  final int completedDays;
  final int scheduledWorkdays;
  final int elapsedScheduledDays;
  final int attendedWorkdays;
  final int absenceDays;
  final double workMinutes;
  final double overtimeMinutes;
  final double overtimeHours;
  final double basePay;
  final double overtimePay;
  final double otherAdditions;
  final double taxDeduction;
  final double socialSecurityDeduction;
  final double otherDeductions;
  final double netPay;
  final bool isFinalized;
  final List<PayrollAttendanceDay> attendanceDays;

  const PayrollEstimate({
    required this.year,
    required this.month,
    required this.payBasis,
    required this.monthlySalary,
    required this.dailyWage,
    required this.overtimeRate,
    required this.completedDays,
    required this.scheduledWorkdays,
    required this.elapsedScheduledDays,
    required this.attendedWorkdays,
    required this.absenceDays,
    required this.workMinutes,
    required this.overtimeMinutes,
    required this.overtimeHours,
    required this.basePay,
    required this.overtimePay,
    required this.otherAdditions,
    required this.taxDeduction,
    required this.socialSecurityDeduction,
    required this.otherDeductions,
    required this.netPay,
    required this.isFinalized,
    required this.attendanceDays,
  });

  factory PayrollEstimate.fromJson(Map<String, dynamic> json) {
    double amount(String key) => double.tryParse('${json[key] ?? 0}') ?? 0;
    int count(String key) => int.tryParse('${json[key] ?? 0}') ?? 0;
    final attendanceDays = (json['attendance_days'] as List<dynamic>? ?? const [])
      .whereType<Map<String, dynamic>>()
      .map(PayrollAttendanceDay.fromJson)
      .toList();

    return PayrollEstimate(
      year: count('year'),
      month: count('month'),
      payBasis: (json['pay_basis'] ?? 'daily').toString(),
      monthlySalary: amount('monthly_salary'),
      dailyWage: amount('daily_wage'),
      overtimeRate: amount('overtime_rate'),
      completedDays: count('completed_days'),
      scheduledWorkdays: count('scheduled_workdays'),
      elapsedScheduledDays: count('elapsed_scheduled_days'),
      attendedWorkdays: count('attended_workdays'),
      absenceDays: count('absence_days'),
      workMinutes: amount('work_minutes'),
      overtimeMinutes: amount('overtime_minutes'),
      overtimeHours: amount('overtime_hours'),
      basePay: amount('base_pay'),
      overtimePay: amount('overtime_pay'),
      otherAdditions: amount('other_additions'),
      taxDeduction: amount('tax_deduction'),
      socialSecurityDeduction: amount('social_security_deduction'),
      otherDeductions: amount('other_deductions'),
      netPay: amount('net_pay'),
      isFinalized: json['is_finalized'] == true,
      attendanceDays: attendanceDays,
    );
  }
}