import 'package:shared_preferences/shared_preferences.dart';

class SessionManager {
  static Future<void> saveSession(Map<String, dynamic> employee) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('emp_id', employee['emp_id']);
    await prefs.setString('first_name', employee['first_name']);
    await prefs.setString('last_name', employee['last_name']);
    await prefs.setString('email', employee['email']);
    await prefs.setString('designation', employee['designation'] ?? '');
    await prefs.setString('image_url', employee['image_url'] ?? '');
  }

  static Future<int?> getEmpId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt('emp_id');
  }

  static Future<void> clearSession() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
  }
}
