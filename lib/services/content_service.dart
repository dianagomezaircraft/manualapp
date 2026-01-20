import 'dart:convert';
import 'package:http/http.dart' as http;
import 'auth_service.dart';

class ContentService {
  static const String baseUrl = 'http://localhost:3001/api';
  // static const String baseUrl = 'https://admin-webapp-backend.onrender.com/api';

  final AuthService _authService = AuthService();

  // Get all contents for a section
  Future<Map<String, dynamic>> getContentsBySectionId(String sectionId) async {
    try {
      final accessToken = await _authService.getAccessToken();

      if (accessToken == null) {
        return {
          'success': false,
          'error': 'No access token available',
        };
      }

      // Fixed endpoint - removed duplicate 'contents'
      final response = await http.get(
        Uri.parse('$baseUrl/contents/sections/$sectionId'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $accessToken',
        },
      );

      print('Get contents status: ${response.statusCode}');
      print('Get contents body: ${response.body}');

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
            'error': responseData['error'] ?? 'Failed to fetch contents',
          };
        }
      } else if (response.statusCode == 401) {
        // Token might be expired, try to refresh
        final refreshResult = await _authService.refreshAccessToken();

        if (refreshResult['success'] == true) {
          // Retry the request with new token
          return await getContentsBySectionId(sectionId);
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
          'error': error['error'] ?? error['message'] ?? 'Failed to fetch contents',
        };
      }
    } catch (e) {
      print('Get contents error: $e');
      return {
        'success': false,
        'error': 'Network error: ${e.toString()}',
      };
    }
  }

  // Get content by ID
  Future<Map<String, dynamic>> getContentById(String contentId) async {
    try {
      final accessToken = await _authService.getAccessToken();

      if (accessToken == null) {
        return {
          'success': false,
          'error': 'No access token available',
        };
      }

      final response = await http.get(
        Uri.parse('$baseUrl/contents/$contentId'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $accessToken',
        },
      );

      print('Get content by ID status: ${response.statusCode}');
      print('Get content by ID body: ${response.body}');

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
            'error': responseData['error'] ?? 'Failed to fetch content',
          };
        }
      } else if (response.statusCode == 401) {
        // Token might be expired, try to refresh
        final refreshResult = await _authService.refreshAccessToken();

        if (refreshResult['success'] == true) {
          // Retry the request with new token
          return await getContentById(contentId);
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
          'error': error['error'] ?? error['message'] ?? 'Failed to fetch content',
        };
      }
    } catch (e) {
      print('Get content by ID error: $e');
      return {
        'success': false,
        'error': 'Network error: ${e.toString()}',
      };
    }
  }
}

// Content Type Enum - FIXED to match Prisma schema
enum ContentType {
  TEXT,
  IMAGE,
  VIDEO,
  PDF,    // Changed from LINK
  AUDIO,  // Changed from FILE
}

// Content model class
class Content {
  final String id;
  final String title;
  final ContentType type;
  final String content;
  final int order;
  final bool active;
  final String sectionId;
  final Map<String, dynamic>? metadata;
  final DateTime createdAt;
  final DateTime updatedAt;

  Content({
    required this.id,
    required this.title,
    required this.type,
    required this.content,
    required this.order,
    required this.active,
    required this.sectionId,
    this.metadata,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Content.fromJson(Map<String, dynamic> json) {
    return Content(
      id: json['id'] ?? '',
      title: json['title'] ?? '',
      type: _parseContentType(json['type']),
      content: json['content'] ?? '',
      order: json['order'] ?? 0,
      active: json['active'] ?? true,
      sectionId: json['sectionId'] ?? '',
      metadata: json['metadata'] as Map<String, dynamic>?,
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'])
          : DateTime.now(),
      updatedAt: json['updatedAt'] != null
          ? DateTime.parse(json['updatedAt'])
          : DateTime.now(),
    );
  }

  static ContentType _parseContentType(String? type) {
    switch (type?.toUpperCase()) {
      case 'TEXT':
        return ContentType.TEXT;
      case 'IMAGE':
        return ContentType.IMAGE;
      case 'VIDEO':
        return ContentType.VIDEO;
      case 'PDF':        // Fixed
        return ContentType.PDF;
      case 'AUDIO':      // Fixed
        return ContentType.AUDIO;
      default:
        return ContentType.TEXT;
    }
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'type': type.toString().split('.').last,
      'content': content,
      'order': order,
      'active': active,
      'sectionId': sectionId,
      'metadata': metadata,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }
}