import 'dart:convert';
import 'package:http/http.dart' as http;
import 'auth_service.dart';
import 'sections_service.dart';
import '../config/api_config.dart';

class ChaptersService {
  
  final AuthService _authService = AuthService();

  // Get all chapters
  Future<Map<String, dynamic>> getChapters({String? airlineId, bool includeInactive = false}) async {
    try {
      final accessToken = await _authService.getAccessToken();
      
      if (accessToken == null) {
        return {
          'success': false,
          'error': 'No access token available',
        };
      }

      // Build query parameters
      final queryParams = <String, String>{};
      if (airlineId != null) {
        queryParams['airlineId'] = airlineId;
      }
      if (includeInactive) {
        queryParams['includeInactive'] = 'true';
      }

      final uri = Uri.parse('${ApiConfig.baseUrl}/chapters').replace(queryParameters: queryParams);

      final response = await http.get(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $accessToken',
        },
      );

      print('Get chapters status: ${response.statusCode}');
      print('Get chapters body: ${response.body}');

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        
        if (responseData['success'] == true && responseData['data'] != null) {
          return {
            'success': true,
            'data': responseData['data'],
            'count': responseData['count'],
          };
        } else {
          return {
            'success': false,
            'error': responseData['error'] ?? 'Failed to fetch chapters',
          };
        }
      } else if (response.statusCode == 401) {
        // Token might be expired, try to refresh
        final refreshResult = await _authService.refreshAccessToken();
        
        if (refreshResult['success'] == true) {
          // Retry the request with new token
          return await getChapters(
            airlineId: airlineId,
            includeInactive: includeInactive,
          );
        } else {
          return {
            'success': false,
            'error': 'Authentication failed',
            'needsLogin': true,
          };
        }
      } else {
        try {
          final error = jsonDecode(response.body);
          return {
            'success': false,
            'error': error['error'] ?? error['message'] ?? 'Failed to fetch chapters',
          };
        } catch (e) {
          return {
            'success': false,
            'error': 'Server error: ${response.statusCode}',
          };
        }
      }
    } catch (e) {
      print('Get chapters error: $e');
      return {
        'success': false,
        'error': 'Network error: ${e.toString()}',
      };
    }
  }

  // Get chapter by ID
  Future<Map<String, dynamic>> getChapterById(String chapterId) async {
    try {
      final accessToken = await _authService.getAccessToken();
      
      if (accessToken == null) {
        return {
          'success': false,
          'error': 'No access token available',
        };
      }

      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/chapters/$chapterId'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $accessToken',
        },
      );

      print('Get chapter by ID status: ${response.statusCode}');
      print('Get chapter by ID body: ${response.body}');

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
            'error': responseData['error'] ?? 'Failed to fetch chapter',
          };
        }
      } else if (response.statusCode == 401) {
        // Token might be expired, try to refresh
        final refreshResult = await _authService.refreshAccessToken();
        
        if (refreshResult['success'] == true) {
          // Retry the request with new token
          return await getChapterById(chapterId);
        } else {
          return {
            'success': false,
            'error': 'Authentication failed',
            'needsLogin': true,
          };
        }
      } else {
        try {
          final error = jsonDecode(response.body);
          return {
            'success': false,
            'error': error['error'] ?? error['message'] ?? 'Failed to fetch chapter',
          };
        } catch (e) {
          return {
            'success': false,
            'error': 'Server error: ${response.statusCode}',
          };
        }
      }
    } catch (e) {
      print('Get chapter by ID error: $e');
      return {
        'success': false,
        'error': 'Network error: ${e.toString()}',
      };
    }
  }
}

// Chapter model class
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
  final List<Section>? sections;

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
      try {
        sectionsList = (json['sections'] as List)
            .map((sectionJson) => Section.fromJson(sectionJson as Map<String, dynamic>))
            .toList()
          ..sort((a, b) => a.order.compareTo(b.order));
      } catch (e) {
        print('Error parsing sections: $e');
        sectionsList = null;
      }
    }

    // Parse sectionsCount
    int count = 0;
    if (json['_count'] != null && json['_count']['sections'] != null) {
      count = json['_count']['sections'] as int;
    } else if (sectionsList != null) {
      count = sectionsList.length;
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
          ? ChapterAirline.fromJson(json['airline'] as Map<String, dynamic>)
          : null,
      sectionsCount: count,
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
      if (airline != null) 'airline': airline!.toJson(),
      '_count': {'sections': sectionsCount},
      if (sections != null) 'sections': sections!.map((s) => s.toJson()).toList(),
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