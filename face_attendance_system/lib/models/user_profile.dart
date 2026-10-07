/// Employee profile shown in the Profile tab.
///
/// Same rule as AttendanceRecord: this file is the ONLY place that
/// should know the backend's exact JSON key names for GET/PATCH
/// /employee/me. If the backend contract changes, edit here only.
class UserProfile {
  final String employeeId;
  final String name;
  final String phone;
  final String position;
  final String employmentStatus; // e.g. "Active", "พนักงานประจำ"
  final String avatarUrl;

  const UserProfile({
    required this.employeeId,
    required this.name,
    required this.phone,
    required this.position,
    required this.employmentStatus,
    required this.avatarUrl,
  });

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      employeeId: (json['employee_id'] ?? json['emp_id'] ?? '').toString(),
      name: (json['name'] ?? json['full_name'] ?? '').toString(),
      phone: (json['phone'] ?? json['phone_number'] ?? '').toString(),
      position: (json['position'] ?? json['department'] ?? '').toString(),
      employmentStatus: (json['employment_status'] ?? json['status'] ?? 'Active').toString(),
      avatarUrl: (json['avatar_url'] ?? json['photo_url'] ?? '').toString(),
    );
  }

  UserProfile copyWith({
    String? name,
    String? phone,
    String? avatarUrl,
  }) {
    return UserProfile(
      employeeId: employeeId,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      position: position,
      employmentStatus: employmentStatus,
      avatarUrl: avatarUrl ?? this.avatarUrl,
    );
  }

  /// Only the fields the user is actually allowed to self-edit.
  /// employee_id / position / employment_status stay server-controlled.
  Map<String, dynamic> toUpdateJson() {
    return {
      'name': name,
      'phone': phone,
    };
  }
}
