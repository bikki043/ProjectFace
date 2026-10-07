import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../config/api_config.dart';
import '../models/attendance_record.dart';
import '../models/payslip.dart';
import '../models/payroll_estimate.dart';
import '../models/user_profile.dart';

class ApiException implements Exception {
  final String message;
  final int? statusCode;
  ApiException(this.message, [this.statusCode]);
  @override
  String toString() => message;
}

/// Every network call the app makes lives in this one file. Screens never
/// call `http` directly — they only ever talk to ApiService, and ApiService
/// only ever talks to the models in lib/models/*.dart for parsing. That
/// keeps "what shape does the backend return" defined in exactly one place.
class ApiService {
  final _storage = const FlutterSecureStorage();
  static const _tokenKey = 'jwt_token';

  Future<String?> get _token => _storage.read(key: _tokenKey);

  Future<void> _saveToken(String token) =>
      _storage.write(key: _tokenKey, value: token);

  Future<void> logout() => _storage.delete(key: _tokenKey);

  Future<bool> isLoggedIn() async => (await _token) != null;

  Map<String, String> _headers([String? token]) => {
        'Content-Type': 'application/json',
        // Bypasses the ngrok free-tier interstitial warning page, which
        // otherwise intercepts every request from a new browser/client and
        // has no CORS headers (shows up as "Failed to fetch"). Harmless to
        // leave in even if you move off ngrok later — other hosts just
        // ignore an unknown header.
        'ngrok-skip-browser-warning': 'true',
        if (token != null) 'Authorization': 'Bearer $token',
      };

  Future<String> _requireToken() async {
    final token = await _token;
    if (token == null) throw ApiException('Not logged in');
    return token;
  }

  String _extractError(String body) {
    try {
      final data = jsonDecode(body);
      return data['message'] ?? data['error'] ?? 'Request failed';
    } catch (_) {
      return 'Request failed';
    }
  }

  // ---------------------------------------------------------------------
  // Auth
  // ---------------------------------------------------------------------
  Future<Map<String, dynamic>> login(String employeeId, String password) async {
    final res = await http.post(
      Uri.parse('${ApiConfig.baseUrl}${ApiConfig.loginEndpoint}'),
      headers: _headers(),
      body: jsonEncode({'employee_id': employeeId, 'password': password}),
    );

    if (res.statusCode != 200) {
      throw ApiException(_extractError(res.body), res.statusCode);
    }

    final data = jsonDecode(res.body) as Map<String, dynamic>;
    final token = data['token'] ?? data['access_token'];
    if (token == null) {
      throw ApiException('No token returned from server');
    }
    await _saveToken(token as String);
    return data;
  }

  // ---------------------------------------------------------------------
  // Attendance
  // ---------------------------------------------------------------------
  /// Pass [month]/[year] to scope the request to one calendar month
  /// (used by the calendar tab). Omit both to get the backend's default
  /// range (used by the dashboard tab's "recent scans" list).
  Future<List<AttendanceRecord>> getAttendanceHistory({int? month, int? year}) async {
    final token = await _requireToken();
    final query = <String, String>{};
    if (month != null) query['month'] = month.toString();
    if (year != null) query['year'] = year.toString();

    final uri = Uri.parse('${ApiConfig.baseUrl}${ApiConfig.attendanceHistoryEndpoint}')
        .replace(queryParameters: query.isEmpty ? null : query);

    final res = await http.get(uri, headers: _headers(token));

    if (res.statusCode != 200) {
      throw ApiException(_extractError(res.body), res.statusCode);
    }
    final decoded = jsonDecode(res.body) as List<dynamic>;
    final logs = decoded.whereType<Map<String, dynamic>>().toList();
    return _groupLogsIntoRecords(logs);
  }

  /// The backend's `/attendance/me` returns one row PER SCAN — each row
  /// has just `timestamp` + `log_type` ("check-in" / "check-out"), not a
  /// paired check_in/check_out. AttendanceRecord.fromJson, on the other
  /// hand, expects one JSON object PER DAY with both keys already present.
  /// This function bridges that gap: it buckets the raw scan logs by
  /// calendar day (using the same +07:00 correction as
  /// AttendanceRecord._parseTime, so a scan just after local midnight
  /// never lands in the previous day's bucket), picks the LATEST
  /// check-in and the LATEST check-out for each day, and hands the
  /// result to AttendanceRecord.fromJson exactly like a single-day
  /// backend response would look.
  List<AttendanceRecord> _groupLogsIntoRecords(List<Map<String, dynamic>> logs) {
    final byDay = <String, Map<String, dynamic>>{};

    DateTime? parseThaiTime(dynamic value) {
      if (value is! String || value.isEmpty) return null;
      final parsed = DateTime.tryParse(value);
      if (parsed == null) return null;
      // Same correction as AttendanceRecord._parseTime: the backend sends
      // a +07:00 offset, which Dart normalizes to UTC on parse, so add
      // the 7 hours back to get the real Thai wall-clock time.
      return parsed.isUtc ? parsed.add(const Duration(hours: 7)) : parsed;
    }

    for (final log in logs) {
      final timestampRaw = log['timestamp'];
      final timestamp = parseThaiTime(timestampRaw);
      if (timestamp == null) continue;

      final dayKey = '${timestamp.year}-${timestamp.month}-${timestamp.day}';
      final logType = (log['log_type'] ?? '').toString();

      final entry = byDay.putIfAbsent(
        dayKey,
        () => <String, dynamic>{
          'date': timestampRaw,
          'check_in': null,
          'check_out': null,
        },
      );

      if (logType == 'check-in') {
        final existing = parseThaiTime(entry['check_in']);
        if (existing == null || timestamp.isAfter(existing)) {
          entry['check_in'] = timestampRaw;
        }
      } else if (logType == 'check-out') {
        final existing = parseThaiTime(entry['check_out']);
        if (existing == null || timestamp.isAfter(existing)) {
          entry['check_out'] = timestampRaw;
        }
      }
    }

    for (final entry in byDay.values) {
      final checkIn = parseThaiTime(entry['check_in']);
      final checkOut = parseThaiTime(entry['check_out']);
      if (checkIn != null && checkOut != null && checkOut.isBefore(checkIn)) {
        entry['check_out'] = null;
      }
    }

    return byDay.values.map(AttendanceRecord.fromJson).toList();
  }

  // ---------------------------------------------------------------------
  // Payroll
  // ---------------------------------------------------------------------
  Future<List<Payslip>> getPayroll() async {
    final token = await _requireToken();
    final res = await http.get(
      Uri.parse('${ApiConfig.baseUrl}${ApiConfig.payrollEndpoint}'),
      headers: _headers(token),
    );

    if (res.statusCode != 200) {
      throw ApiException(_extractError(res.body), res.statusCode);
    }
    final decoded = jsonDecode(res.body) as List<dynamic>;
    return decoded
      .whereType<Map<String, dynamic>>()
      .map(Payslip.fromJson)
      .toList();
  }

  Future<PayrollEstimate> getPayrollEstimate({int? year, int? month}) async {
    final token = await _requireToken();
    final query = <String, String>{};
    if (year != null) query['year'] = year.toString();
    if (month != null) query['month'] = month.toString();
    final uri = Uri.parse('${ApiConfig.baseUrl}${ApiConfig.payrollEstimateEndpoint}')
        .replace(queryParameters: query.isEmpty ? null : query);
    final response = await http.get(uri, headers: _headers(token));
    if (response.statusCode != 200) {
      throw ApiException(_extractError(response.body), response.statusCode);
    }
    return PayrollEstimate.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
  }

  // ---------------------------------------------------------------------
  // Profile
  // ---------------------------------------------------------------------
  Future<UserProfile> getProfile() async {
    final token = await _requireToken();
    final res = await http.get(
      Uri.parse('${ApiConfig.baseUrl}${ApiConfig.profileEndpoint}'),
      headers: _headers(token),
    );

    if (res.statusCode != 200) {
      throw ApiException(_extractError(res.body), res.statusCode);
    }
    return UserProfile.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
  }

  Future<UserProfile> updateProfile(UserProfile updated) async {
    final token = await _requireToken();
    final res = await http.patch(
      Uri.parse('${ApiConfig.baseUrl}${ApiConfig.updateProfileEndpoint}'),
      headers: _headers(token),
      body: jsonEncode(updated.toUpdateJson()),
    );

    if (res.statusCode != 200) {
      throw ApiException(_extractError(res.body), res.statusCode);
    }
    return UserProfile.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
  }

  /// Self-service password change. The backend verifies [currentPassword]
  /// against the stored hash before accepting [newPassword] — this is a
  /// different endpoint from /auth/set-password, which is admin-only and
  /// requires an admin_secret (used to reset someone else's password).
  Future<void> changePassword(String currentPassword, String newPassword) async {
    final token = await _requireToken();
    final res = await http.post(
      Uri.parse('${ApiConfig.baseUrl}${ApiConfig.changePasswordEndpoint}'),
      headers: _headers(token),
      body: jsonEncode({
        'current_password': currentPassword,
        'new_password': newPassword,
      }),
    );

    if (res.statusCode != 200) {
      throw ApiException(_extractError(res.body), res.statusCode);
    }
  }

  /// Uploads a new profile photo and returns the new avatar URL.
  /// Requires the `image_picker` package on the caller side to obtain [imageFile].
  Future<String> uploadAvatar(File imageFile) async {
    final token = await _requireToken();
    final uri = Uri.parse('${ApiConfig.baseUrl}${ApiConfig.uploadAvatarEndpoint}');

    final request = http.MultipartRequest('POST', uri)
      ..headers['Authorization'] = 'Bearer $token'
      ..headers['ngrok-skip-browser-warning'] = 'true'
      ..files.add(await http.MultipartFile.fromPath('avatar', imageFile.path));

    final streamedRes = await request.send();
    final res = await http.Response.fromStream(streamedRes);

    if (res.statusCode != 200) {
      throw ApiException(_extractError(res.body), res.statusCode);
    }
    final data = jsonDecode(res.body) as Map<String, dynamic>;
    final url = data['avatar_url'] ?? data['photo_url'];
    if (url == null) {
      throw ApiException('No avatar_url returned from server');
    }
    return url as String;
  }
}