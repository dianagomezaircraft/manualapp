import 'dart:convert';
import 'package:http/http.dart' as http;
import '../services/auth_service.dart';
import 'sections_service.dart';

class ChaptersService {
  static const String baseUrl = 'http://localhost:3001/api';

  final AuthService _auth = AuthService.instance;

  /// Get all chapters
  Future<Map<String, dynamic>> getChapters({
    bool includeInactive = false,
  }) async {
    try {
      final token = _auth.token;
      final airlineId = _auth.airlineId;

      if (token == null || airlineId == null) {
        return {
          'success': false,
          'error': 'Missing auth or airline context',
        };
      }

      final uri = Uri.parse('$baseUrl/chapters').replace(
        queryParameters: {
          'airlineId': airlineId,
          if (includeInactive) 'includeInactive': 'true',
        },
      );

      final response = await http.get(
        uri,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final body = jsonDecode(response.body);

        return {
          'success': true,
          'data': body['data'],
        };
      }

      if (response.statusCode == 401) {
        final refreshed = await _auth.refreshAccessToken();
        if (refreshed['success'] == true) {
          return await getChapters(includeInactive: includeInactive);
        }
      }

      final error = jsonDecode(response.body);
      return {
        'success': false,
        'error': error['error'] ?? error['message'],
      };
    } catch (e) {
      return {
        'success': false,
        'error': e.toString(),
      };
    }
  }

  /// Get chapter by ID
  Future<Map<String, dynamic>> getChapterById(String chapterId) async {
    try {
      final token = _auth.token;
      final airlineId = _auth.airlineId;

      if (token == null || airlineId == null) {
        return {
          'success': false,
          'error': 'Missing auth or airline context',
        };
      }

      final uri = Uri.parse('$baseUrl/chapters/$chapterId').replace(
        queryParameters: {
          'airlineId': airlineId,
        },
      );

      final response = await http.get(
        uri,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final body = jsonDecode(response.body);
        return {
          'success': true,
          'data': body['data'],
        };
      }

      if (response.statusCode == 401) {
        final refreshed = await _auth.refreshAccessToken();
        if (refreshed['success'] == true) {
          return await getChapterById(chapterId);
        }
      }

      final error = jsonDecode(response.body);
      return {
        'success': false,
        'error': error['error'] ?? error['message'],
      };
    } catch (e) {
      return {
        'success': false,
        'error': e.toString(),
      };
    }
  }
}

// Chapter model class for easier data handling
class Chapter {
  final String id;
  final String title;
  final String description;
  final int chapterNumber;
  final int order;
  final bool active;
  final String airlineId;
  final DateTime createdAt;
  final DateTime updatedAt;
  final ChapterAirline? airline;
  final int sectionsCount;
  final List<Section>? sections; // Add sections list

  Chapter({
    required this.id,
    required this.title,
    required this.description,
    required this.chapterNumber,
    required this.order,
    required this.active,
    required this.airlineId,
    required this.createdAt,
    required this.updatedAt,
    this.airline,
    this.sectionsCount = 0,
    this.sections,
  });

  factory Chapter.fromJson(Map<String, dynamic> json) {
    // Parse sections if available
    List<Section>? sectionsList;
    if (json['sections'] != null && json['sections'] is List) {
      sectionsList = (json['sections'] as List)
          .map((sectionJson) => Section.fromJson(sectionJson))
          .toList()
        ..sort((a, b) => a.order.compareTo(b.order));
    }

    return Chapter(
      id: json['id'] ?? json['_id'] ?? '',
      title: json['title'] ?? '',
      description: json['description'] ?? '',
      chapterNumber: json['chapterNumber'] ?? 0,
      order: json['order'] ?? 0,
      active: json['active'] ?? true,
      airlineId: json['airlineId'] ?? '',
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'])
          : DateTime.now(),
      updatedAt: json['updatedAt'] != null
          ? DateTime.parse(json['updatedAt'])
          : DateTime.now(),
      airline: json['airline'] != null
          ? ChapterAirline.fromJson(json['airline'])
          : null,
      sectionsCount: json['_count'] != null && json['_count']['sections'] != null
          ? json['_count']['sections'] as int
          : (sectionsList?.length ?? 0),
      sections: sectionsList,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'chapterNumber': chapterNumber,
      'order': order,
      'active': active,
      'airlineId': airlineId,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'airline': airline?.toJson(),
      '_count': {'sections': sectionsCount},
      'sections': sections?.map((s) => s.toJson()).toList(),
    };
  }
}

// Airline model for chapter
class ChapterAirline {
  final String id;
  final String name;
  final String code;

  ChapterAirline({
    required this.id,
    required this.name,
    required this.code,
  });

  factory ChapterAirline.fromJson(Map<String, dynamic> json) {
    return ChapterAirline(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      code: json['code'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'code': code,
    };
  }
}