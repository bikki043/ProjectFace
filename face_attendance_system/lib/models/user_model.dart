class UserModel {
  final String empId;
  final String name;
  final String phone;
  final String position;
  final String profileImage;

  UserModel({
    required this.empId,
    required this.name,
    required this.phone,
    required this.position,
    required this.profileImage,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      empId: json['emp_id'] ?? json['id'] ?? 'EMP-001',
      name: json['name'] ?? json['full_name'] ?? 'ผู้ใช้งาน',
      phone: json['phone'] ?? json['mobile'] ?? '-',
      position: json['position'] ?? json['department'] ?? 'พนักงาน',
      profileImage: json['profile_image'] ?? json['avatar'] ?? '',
    );
  }
}