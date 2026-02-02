// services/search_service.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:html/parser.dart' as html_parser;
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
          '${ApiConfig.baseUrl}/search?q=${Uri.encodeComponent(query)}&limit=$limit&includeInactive=$includeInactive');

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
          '${ApiConfig.baseUrl}/search/chapter/$chapterId?q=${Uri.encodeComponent(query)}');

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
      return _stripHtmlTags(content!);
    }
    if (description != null && description!.isNotEmpty) {
      return _stripHtmlTags(description!);
    }
    return title;
  }

  // Improved HTML stripping method
  String _stripHtmlTags(String htmlString) {
    try {
      // First, handle truncated tags at the beginning (like "...ill(s)" or "...aybill(s)")
      // Remove leading ellipsis and broken words
      String cleaned = htmlString;
      
      // Remove leading ellipsis and any partial text before the first complete word
      if (cleaned.startsWith('...')) {
        cleaned = cleaned.replaceFirst(RegExp(r'^\.{3}[^>\s]*'), '');
      }
      
      // Remove trailing ellipsis
      if (cleaned.endsWith('...')) {
        cleaned = cleaned.replaceFirst(RegExp(r'[^<\s]*\.{3}$'), '...');
      }
      
      // Parse HTML and extract text content
      final document = html_parser.parse(cleaned);
      String parsedString = document.body?.text ?? cleaned;
      
      // If html parser didn't work well, fall back to regex
      if (parsedString.contains('<') || parsedString.contains('>')) {
        // Remove all HTML tags
        parsedString = cleaned.replaceAll(RegExp(r'<[^>]*>'), ' ');
        
        // Decode HTML entities
        parsedString = _decodeHtmlEntities(parsedString);
      }
      
      // Clean up whitespace
      parsedString = parsedString
          .replaceAll(RegExp(r'\s+'), ' ') // Replace multiple spaces with single space
          .replaceAll(RegExp(r'\n\s*\n'), '\n') // Remove multiple newlines
          .trim();
      
      // Remove any remaining ellipsis at the start if followed by lowercase
      if (parsedString.startsWith('...')) {
        parsedString = parsedString.replaceFirst(RegExp(r'^\.{3}\s*[a-z]+\s*'), '');
      }
      
      // If the text is too short or doesn't make sense, try to clean it up more
      if (parsedString.length < 10 || parsedString.startsWith('...')) {
        parsedString = parsedString.replaceAll('...', '').trim();
        // Capitalize first letter if it's lowercase
        if (parsedString.isNotEmpty && parsedString[0] == parsedString[0].toLowerCase()) {
          parsedString = parsedString[0].toUpperCase() + parsedString.substring(1);
        }
      }
      
      return parsedString.isEmpty ? title : parsedString;
    } catch (e) {
      // If anything fails, return the title as fallback
      return title;
    }
  }
  
  // Helper method to decode HTML entities
  String _decodeHtmlEntities(String text) {
    return text
        .replaceAll('&nbsp;', ' ')
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&quot;', '"')
        .replaceAll('&#39;', "'")
        .replaceAll('&apos;', "'")
        .replaceAll('&ndash;', '–')
        .replaceAll('&mdash;', '—')
        .replaceAll('&hellip;', '…');
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
