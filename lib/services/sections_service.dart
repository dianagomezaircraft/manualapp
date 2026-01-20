import 'dart:convert';
import 'package:http/http.dart' as http;
import 'auth_service.dart';

class SectionsService {
  static const String baseUrl = 'http://localhost:3001/api';
  // static const String baseUrl = 'https://admin-webapp-backend.onrender.com/api';

  final AuthService _authService = AuthService();

  // Get section by ID
  Future<Map<String, dynamic>> getSectionById(String sectionId) async {
    try {
      final accessToken = await _authService.getAccessToken();

      if (accessToken == null) {
        return {
          'success': false,
          'error': 'No access token available',
        };
      }

      final response = await http.get(
        Uri.parse('$baseUrl/sections/$sectionId'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $accessToken',
        },
      );

      print('Get section by ID status: ${response.statusCode}');
      print('Get section by ID body: ${response.body}');

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);

        if (responseData['success'] == true && responseData['data'] != null) {
          return {
            'success': true,
            'data': responseData['data'],
          };
        } else {
          return {
            'success': false,
            'error': responseData['error'] ?? 'Failed to fetch section',
          };
        }
      } else if (response.statusCode == 401) {
        // Token might be expired, try to refresh
        final refreshResult = await _authService.refreshAccessToken();

        if (refreshResult['success'] == true) {
          // Retry the request with new token
          return await getSectionById(sectionId);
        } else {
          return {
            'success': false,
            'error': 'Authentication failed',
            'needsLogin': true,
          };
        }
      } else {
        final error = jsonDecode(response.body);
        return {
          'success': false,
          'error': error['error'] ?? error['message'] ?? 'Failed to fetch section',
        };
      }
    } catch (e) {
      print('Get section by ID error: $e');
      return {
        'success': false,
        'error': 'Network error: ${e.toString()}',
      };
    }
  }
}

// Section model class
class Section {
  final String id;
  final String title;
  final String subtitle;
  final String content;
  final String? imageUrl;
  final int order;
  final bool active;
  final String chapterId;
  final DateTime createdAt;
  final DateTime updatedAt;

  Section({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.content,
    this.imageUrl,
    required this.order,
    required this.active,
    required this.chapterId,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Section.fromJson(Map<String, dynamic> json) {
    return Section(
      id: json['id'] ?? '',
      title: json['title'] ?? '',
      subtitle: json['subtitle'] ?? '',
      content: json['content'] ?? '',
      imageUrl: json['imageUrl'],
      order: json['order'] ?? 0,
      active: json['active'] ?? true,
      chapterId: json['chapterId'] ?? '',
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'])
          : DateTime.now(),
      updatedAt: json['updatedAt'] != null
          ? DateTime.parse(json['updatedAt'])
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'subtitle': subtitle,
      'content': content,
      'imageUrl': imageUrl,
      'order': order,
      'active': active,
      'chapterId': chapterId,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }
}