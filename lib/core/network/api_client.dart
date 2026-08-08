import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/app_config.dart';
import '../storage/auth_storage.dart';

class ApiClient {
  static void Function()? onSessionExpired;

  static Future<Map<String, String>> _getHeaders() async {
    final token = await AuthStorage.getToken();
    final headers = {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };
    if (token != null && token.isNotEmpty) {
      headers['Authorization'] = 'Bearer $token';
    }
    return headers;
  }

  static Future<http.Response> _processResponse(http.Response response) async {
    if (response.statusCode == 401) {
      // Auto-revoke local session if server responds 401 Unauthorized / Token Expired
      await AuthStorage.clearSession();
      if (onSessionExpired != null) {
        onSessionExpired!();
      }
    }
    return response;
  }

  static Future<http.Response> get(String endpoint) async {
    final url = Uri.parse('${AppConfig.activeBaseUrl}$endpoint');
    final headers = await _getHeaders();
    final response = await http.get(url, headers: headers);
    return await _processResponse(response);
  }

  static Future<http.Response> post(String endpoint, Map<String, dynamic> body) async {
    final url = Uri.parse('${AppConfig.activeBaseUrl}$endpoint');
    final headers = await _getHeaders();
    final response = await http.post(url, headers: headers, body: jsonEncode(body));
    return await _processResponse(response);
  }

  static Future<http.Response> put(String endpoint, Map<String, dynamic> body) async {
    final url = Uri.parse('${AppConfig.activeBaseUrl}$endpoint');
    final headers = await _getHeaders();
    final response = await http.put(url, headers: headers, body: jsonEncode(body));
    return await _processResponse(response);
  }

  static Future<http.Response> delete(String endpoint) async {
    final url = Uri.parse('${AppConfig.activeBaseUrl}$endpoint');
    final headers = await _getHeaders();
    final response = await http.delete(url, headers: headers);
    return await _processResponse(response);
  }
}
