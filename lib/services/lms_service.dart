import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/api_config.dart';
import 'auth_service.dart';

class LmsService {
  final AuthService _authService = AuthService();

  Future<Map<String, dynamic>> getLoginUrl() async {
    try {
      final accessToken = await _authService.getAccessToken();

      if (accessToken == null || accessToken.isEmpty) {
        return {
          'success': false,
          'error': 'No access token available',
          'needsLogin': true,
        };
      }

      // Only this request is allowed. Never GET the returned loginUrl —
      // that hits Moodle /auth/userkey/login.php and burns the one-time key.
      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/moodle/login-url'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $accessToken',
        },
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        final loginUrl = _extractLoginUrl(responseData);

        if (loginUrl == null || loginUrl.isEmpty) {
          return {
            'success': false,
            'error': 'No Moodle access URL was returned.',
          };
        }

        return {
          'success': true,
          'loginUrl': loginUrl,
        };
      }

      if (response.statusCode == 401) {
        final refreshResult = await _authService.refreshAccessToken();

        if (refreshResult['success'] == true) {
          return await getLoginUrl();
        }

        return {
          'success': false,
          'error': 'Authentication failed',
          'needsLogin': true,
        };
      }

      return {
        'success': false,
        'error': _errorFromBody(response.body, response.statusCode),
      };
    } catch (e) {
      return {
        'success': false,
        'error': 'Network error: ${e.toString()}',
      };
    }
  }

  String? _extractLoginUrl(dynamic body) {
    if (body is! Map) return null;

    final direct = body['loginUrl'];
    if (direct is String && direct.isNotEmpty) return direct;

    final data = body['data'];
    if (data is String && data.isNotEmpty) return data;
    if (data is Map) {
      final nested = data['loginUrl'];
      if (nested is String && nested.isNotEmpty) return nested;
    }

    return null;
  }

  String _errorFromBody(String body, int statusCode) {
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map) {
        final message = decoded['error'] ?? decoded['message'];
        if (message is String && message.isNotEmpty) return message;
      }
    } catch (_) {}
    return 'The server responded with error $statusCode';
  }
}
