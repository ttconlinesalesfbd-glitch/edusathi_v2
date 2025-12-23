import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class ApiService {
  static const String _baseUrl = 'https://schoolerp.edusathi.in/api';

  /// Send GET request with token
  static Future<http.Response> get(String endpoint) async {
    final token = await _getToken();
    final url = Uri.parse('$_baseUrl$endpoint');

    return http.get(
      url,
      headers: {'Authorization': 'Bearer $token', 'Accept': 'application/json'},
    );
  }

  /// Unified POST request
  static Future<http.Response> post(
    String endpoint, {
    Map<String, dynamic>? body,
  }) async {
    final token = await _getToken();
    final url = Uri.parse('$_baseUrl$endpoint');

    return http.post(
      url,
      headers: {
        'Authorization': 'Bearer $token',
        'Accept': 'application/json',
        'Content-Type': 'application/json',
      },
      body: jsonEncode(body ?? {}),
    );
  }

  static Future<String> _getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('auth_token') ?? '';
  }
}
