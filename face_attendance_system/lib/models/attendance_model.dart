class AttendanceModel {
  final String id;
  final DateTime date;
  final String? checkIn;
  final String? checkOut;
  final double workHours;
  final double otHours;
  final String status;

  AttendanceModel({
    required this.id,
    required this.date,
    this.checkIn,
    this.checkOut,
    required this.workHours,
    required this.otHours,
    required this.status,
  });

  factory AttendanceModel.fromJson(Map<String, dynamic> json) {
    return AttendanceModel(
      id: (json['id'] ?? json['emp_id'] ?? '').toString(),
      date: DateTime.tryParse((json['date'] ?? json['created_at'] ?? '').toString()) ?? DateTime.now(),
      checkIn: json['check_in'] ?? json['checkIn'] ?? json['timestamp'],
      checkOut: json['check_out'] ?? json['checkOut'],
      workHours: double.tryParse((json['work_hours'] ?? json['hours'] ?? '0').toString()) ?? 0.0,
      otHours: double.tryParse((json['ot_hours'] ?? json['ot'] ?? '0').toString()) ?? 0.0,
      status: json['status'] ?? 'ปกติ',
    );
  }
}