import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../config/api_config.dart';

class AuthService {
  // Login
  Future<Map<String, dynamic>> login(String email, String password) async {
    try {
      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/auth/login'),
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'email': email,
          'password': password,
        }),
      );

      // print('Response status: ${response.statusCode}');
      // print('Response body: ${response.body}');

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);

        // Check if response has the expected structure
        if (responseData['success'] == true && responseData['data'] != null) {
          final data = responseData['data'];

          // Extract tokens from data object
          final accessToken = data['accessToken'];
          final refreshToken = data['refreshToken'];

          if (accessToken == null || refreshToken == null) {
            return {
              'success': false,
              'error': 'Invalid response: missing tokens',
            };
          }

          // Save tokens
          await _saveTokens(accessToken, refreshToken);

          // Save user data
          if (data['user'] != null) {
            await _saveUserData(data['user']);
          }

          return {
            'success': true,
            'data': data,
          };
        } else {
          return {
            'success': false,
            'error': responseData['error'] ?? 'Login failed',
          };
        }
      } else {
        final error = jsonDecode(response.body);
        return {
          'success': false,
          'error': error['error'] ?? error['message'] ?? 'Login failed',
        };
      }
    } catch (e) {
      // print('Login error: $e');
      return {
        'success': false,
        'error': 'Network error: ${e.toString()}',
      };
    }
  }

  // Save tokens to SharedPreferences
  Future<void> _saveTokens(String accessToken, String refreshToken) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('accessToken', accessToken);
    await prefs.setString('refreshToken', refreshToken);
  }

  // Save user data
  Future<void> _saveUserData(Map<String, dynamic> user) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('user', jsonEncode(user));

    // Build full name from firstName and lastName
    final firstName = user['firstName'] ?? '';
    final lastName = user['lastName'] ?? '';
    final fullName = '$firstName $lastName'.trim();

    await prefs.setString('userName', fullName.isNotEmpty ? fullName : 'User');
    await prefs.setString('userEmail', user['email'] ?? '');
    await prefs.setString('userId', user['id'] ?? '');
    await prefs.setString('userRole', user['role'] ?? '');
  }

  // Get access token
  Future<String?> getAccessToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('accessToken');
  }

  // Get refresh token
  Future<String?> getRefreshToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('refreshToken');
  }

  // Get user name
  Future<String> getUserName() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('userName') ?? 'User';
  }

  // Get user email
  Future<String> getUserEmail() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('userEmail') ?? '';
  }

  // Get user role
  Future<String> getUserRole() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('userRole') ?? '';
  }

  // Check if logged in
  Future<bool> isLoggedIn() async {
    final token = await getAccessToken();
    return token != null && token.isNotEmpty;
  }

  // Logout
  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    final biometricEnabled = prefs.getBool('biometric_enabled') ?? false;
    print('biometric enabled ${biometricEnabled}');
    if (!biometricEnabled) {
      await prefs.remove('accessToken');
      await prefs.remove('refreshToken');
    }
    await prefs.remove('user');
    await prefs.remove('userName');
    await prefs.remove('userEmail');
    await prefs.remove('userId');
    await prefs.remove('userRole');
  }

  // Get user data
  Future<Map<String, dynamic>?> getUserData() async {
    final prefs = await SharedPreferences.getInstance();
    final userJson = prefs.getString('user');
    if (userJson != null) {
      return jsonDecode(userJson);
    }
    return null;
  }

  Future<Map<String, dynamic>> refreshSession() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final refreshToken = prefs.getString('refreshToken');

      if (refreshToken == null || refreshToken.isEmpty) {
        return {'success': false, 'error': 'No refresh token available'};
      }

      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/auth/refresh'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'refreshToken': refreshToken}),
      );

      final responseData = jsonDecode(response.body);

      if (response.statusCode == 200 && responseData['success'] == true) {
        // ✅ Unwrap 'data' first — same structure as login
        final data = responseData['data'];

        await prefs.setString('accessToken', data['accessToken']);
        await prefs.setString('refreshToken', data['refreshToken']);

        // ✅ Restore user data so getUserName() works
        if (data['user'] != null) {
          await _saveUserData(data['user']); // reuse existing private method
        }

        return {'success': true};
      } else {
        await prefs.remove('refreshToken');
        await prefs.setBool('has_logged_in_before', false);
        return {
          'success': false,
          'error': responseData['error'] ?? 'Session expired'
        };
      }
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  // Refresh access token
  Future<Map<String, dynamic>> refreshAccessToken() async {
    try {
      final refreshToken = await getRefreshToken();

      if (refreshToken == null) {
        return {
          'success': false,
          'error': 'No refresh token available',
        };
      }

      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/auth/refresh'),
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'refreshToken': refreshToken,
        }),
      );

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);

        if (responseData['success'] == true && responseData['data'] != null) {
          final data = responseData['data'];
          final newAccessToken = data['accessToken'];

          if (newAccessToken != null) {
            final prefs = await SharedPreferences.getInstance();
            await prefs.setString('accessToken', newAccessToken);

            return {
              'success': true,
              'data': data,
            };
          }
        }
      }

      return {
        'success': false,
        'error': 'Failed to refresh token',
      };
    } catch (e) {
      return {
        'success': false,
        'error': 'Network error: ${e.toString()}',
      };
    }
  }

  // En lib/services/auth_service.dart, agregar estos métodos:

  Future<Map<String, dynamic>> requestPasswordReset(String email) async {
    try {
      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/auth/password-reset-request'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'email': email}),
      );

      final data = json.decode(response.body);

      if (response.statusCode == 200 && data['success']) {
        return {
          'success': true,
          'message': data['message'],
          'devToken': data['devToken'], // Para desarrollo
        };
      } else {
        return {
          'success': false,
          'error': data['error'] ?? 'Failed to send reset email',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'error': 'Network error. Please try again.',
      };
    }
  }

  Future<Map<String, dynamic>> resetPassword(
      String token, String newPassword) async {
    try {
      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/auth/password-reset'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'token': token,
          'newPassword': newPassword,
        }),
      );

      final data = json.decode(response.body);

      if (response.statusCode == 200 && data['success']) {
        return {
          'success': true,
          'message': data['message'],
        };
      } else {
        return {
          'success': false,
          'error': data['error'] ?? 'Failed to reset password',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'error': 'Network error. Please try again.',
      };
    }
  }
}
