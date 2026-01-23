// services/search_service.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'auth_service.dart';
import '../config/api_config.dart';

class SearchService {
  final AuthService _authService = AuthService();

  // Global search
  Future<Map<String, dynamic>> globalSearch({
    required String query,
    int limit = 50,
    bool includeInactive = false,
  }) async {
    try {
      final token = await _authService.getAccessToken();
      
      if (token == null) {
        return {
          'success': false,
          'error': 'Not authenticated',
          'needsLogin': true,
        };
      }

      final url = Uri.parse(
        '${ApiConfig.baseUrl}/search?q=${Uri.encodeComponent(query)}&limit=$limit&includeInactive=$includeInactive'
      );

      final response = await http.get(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return {
          'success': true,
          'data': data['data'],
          'count': data['count'],
          'query': data['query'],
        };
      } else if (response.statusCode == 401) {
        return {
          'success': false,
          'error': 'Authentication failed',
          'needsLogin': true,
        };
      } else {
        final error = json.decode(response.body);
        return {
          'success': false,
          'error': error['error'] ?? 'Failed to search',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'error': 'Network error: ${e.toString()}',
      };
    }
  }

  // Search within a specific chapter
  Future<Map<String, dynamic>> searchInChapter({
    required String chapterId,
    required String query,
  }) async {
    try {
      final token = await _authService.getAccessToken();
      
      if (token == null) {
        return {
          'success': false,
          'error': 'Not authenticated',
          'needsLogin': true,
        };
      }

      final url = Uri.parse(
        '${ApiConfig.baseUrl}/search/chapter/$chapterId?q=${Uri.encodeComponent(query)}'
      );

      final response = await http.get(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return {
          'success': true,
          'data': data['data'],
          'count': data['count'],
          'query': data['query'],
          'chapterId': data['chapterId'],
        };
      } else if (response.statusCode == 401) {
        return {
          'success': false,
          'error': 'Authentication failed',
          'needsLogin': true,
        };
      } else {
        final error = json.decode(response.body);
        return {
          'success': false,
          'error': error['error'] ?? 'Failed to search',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'error': 'Network error: ${e.toString()}',
      };
    }
  }
}

// Search Result Model
class SearchResult {
  final String type; // 'chapter', 'section', or 'content'
  final String id;
  final String title;
  final String? description;
  final String? content;
  final String chapterId;
  final String chapterTitle;
  final String? sectionId;
  final String? sectionTitle;
  final int order;
  final int relevance;

  SearchResult({
    required this.type,
    required this.id,
    required this.title,
    this.description,
    this.content,
    required this.chapterId,
    required this.chapterTitle,
    this.sectionId,
    this.sectionTitle,
    required this.order,
    required this.relevance,
  });

  factory SearchResult.fromJson(Map<String, dynamic> json) {
    return SearchResult(
      type: json['type'] as String,
      id: json['id'] as String,
      title: json['title'] as String,
      description: json['description'] as String?,
      content: json['content'] as String?,
      chapterId: json['chapterId'] as String,
      chapterTitle: json['chapterTitle'] as String,
      sectionId: json['sectionId'] as String?,
      sectionTitle: json['sectionTitle'] as String?,
      order: json['order'] as int,
      relevance: json['relevance'] as int,
    );
  }

  // Get display text for the result
  String get displayText {
    if (content != null && content!.isNotEmpty) {
      return content!;
    }
    if (description != null && description!.isNotEmpty) {
      return description!;
    }
    return title;
  }

  // Get the chapter display text
  String get chapterDisplayText {
    return chapterTitle;
  }

  // Get type icon
  String get typeDisplay {
    switch (type) {
      case 'chapter':
        return 'Chapter';
      case 'section':
        return 'Section';
      case 'content':
        return 'Content';
      default:
        return type;
    }
  }
}