class Payslip {
  final int id;
  final int year;
  final int month;
  final String payBasis;
  final double baseSalary;
  final double overtimePay;
  final double otherAdditions;
  final double taxDeduction;
  final double socialSecurityDeduction;
  final double otherDeductions;
  final double netSalary;
  final String? pdfPath;

  const Payslip({
    required this.id,
    required this.year,
    required this.month,
    required this.payBasis,
    required this.baseSalary,
    required this.overtimePay,
    required this.otherAdditions,
    required this.taxDeduction,
    required this.socialSecurityDeduction,
    required this.otherDeductions,
    required this.netSalary,
    required this.pdfPath,
  });

  factory Payslip.fromJson(Map<String, dynamic> json) {
    double amount(String key) => double.tryParse('${json[key] ?? 0}') ?? 0;

    return Payslip(
      id: int.tryParse('${json['id'] ?? 0}') ?? 0,
      year: int.tryParse('${json['year'] ?? 0}') ?? 0,
      month: int.tryParse('${json['month'] ?? 0}') ?? 0,
      payBasis: (json['pay_basis'] ?? 'daily').toString(),
      baseSalary: amount('base_salary'),
      overtimePay: amount('overtime_pay'),
      otherAdditions: amount('other_additions'),
      taxDeduction: amount('tax_deduction'),
      socialSecurityDeduction: amount('social_security_deduction'),
      otherDeductions: amount('other_deductions'),
      netSalary: amount('net_salary'),
      pdfPath: json['pdf_path']?.toString(),
    );
  }
}