class AttendanceStats {
  final int totalRecords;
  final double totalWorkHours;
  final double totalOtHours;
  final int lateCount;

  const AttendanceStats({
    required this.totalRecords,
    required this.totalWorkHours,
    required this.totalOtHours,
    required this.lateCount,
  });
}
