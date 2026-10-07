class ApiConfig {
  // TODO: ใส่ URL ngrok/tunnel ปัจจุบันของคุณตรงนี้ (ที่ใช้อยู่ล่าสุด อย่าใช้ตัวเก่า)
  static const String baseUrl = 'https://4d3b-58-11-85-15.ngrok-free.app';

  // ---- Auth ----
  static const String loginEndpoint = '/auth/login';
  static const String setPasswordEndpoint = '/auth/set-password';

  // ---- Attendance ----
  static const String attendanceHistoryEndpoint = '/attendance/me';

  // ---- Payroll ----
  static const String payrollEndpoint = '/payroll/me';
  static const String payrollEstimateEndpoint = '/payroll/me/estimate';

  // ---- Profile ----
  static const String profileEndpoint = '/employee/me';
  static const String updateProfileEndpoint = '/employee/me';
  static const String uploadAvatarEndpoint = '/employee/me/avatar';
  // POST { current_password, new_password } -> self-service password change
  static const String changePasswordEndpoint = '/employee/me/change-password';
}

class AppConfig {
  static const double standardWorkHoursPerDay = 8.0;
}