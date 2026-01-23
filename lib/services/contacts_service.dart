// services/contacts_service.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'auth_service.dart';
import '../config/api_config.dart';

class ContactsService {
  final AuthService _authService = AuthService();

  // Contact Group Model
  static ContactGroup contactGroupFromJson(Map<String, dynamic> json) {
    return ContactGroup(
      id: json['id'] as String,
      name: json['name'] as String,
      description: json['description'] as String?,
      order: json['order'] as int,
      active: json['active'] as bool,
      airlineId: json['airlineId'] as String,
      contacts: (json['contacts'] as List<dynamic>)
          .map((contactJson) => Contact.fromJson(contactJson as Map<String, dynamic>))
          .toList(),
    );
  }

  Future<Map<String, dynamic>> getContactGroups({bool includeInactive = false}) async {
    try {
      final token = await _authService.getAccessToken();
      
      if (token == null) {
        return {
          'success': false,
          'error': 'Not authenticated',
          'needsLogin': true,
        };
      }

      final url = includeInactive 
          ? '${ApiConfig.baseUrl}/contacts/groups?includeInactive=true'
          : '${ApiConfig.baseUrl}/contacts/groups';

      final response = await http.get(
        Uri.parse(url),
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
          'error': error['error'] ?? 'Failed to load contact groups',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'error': 'Network error: ${e.toString()}',
      };
    }
  }

  Future<Map<String, dynamic>> getContactById(String contactId) async {
    try {
      final token = await _authService.getAccessToken();
      
      if (token == null) {
        return {
          'success': false,
          'error': 'Not authenticated',
          'needsLogin': true,
        };
      }

      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/contacts/$contactId'),
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
          'error': error['error'] ?? 'Failed to load contact',
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

// Models
class ContactGroup {
  final String id;
  final String name;
  final String? description;
  final int order;
  final bool active;
  final String airlineId;
  final List<Contact> contacts;

  ContactGroup({
    required this.id,
    required this.name,
    this.description,
    required this.order,
    required this.active,
    required this.airlineId,
    required this.contacts,
  });

  factory ContactGroup.fromJson(Map<String, dynamic> json) {
    return ContactGroup(
      id: json['id'] as String,
      name: json['name'] as String,
      description: json['description'] as String?,
      order: json['order'] as int,
      active: json['active'] as bool,
      airlineId: json['airlineId'] as String,
      contacts: (json['contacts'] as List<dynamic>)
          .map((contactJson) => Contact.fromJson(contactJson as Map<String, dynamic>))
          .toList(),
    );
  }
}

class Contact {
  final String id;
  final String firstName;
  final String lastName;
  final String? title;
  final String? company;
  final String? phone;
  final String? email;
  final String? timezone;
  final String? avatar;
  final int order;
  final bool active;
  final String groupId;
  final Map<String, dynamic>? metadata;

  Contact({
    required this.id,
    required this.firstName,
    required this.lastName,
    this.title,
    this.company,
    this.phone,
    this.email,
    this.timezone,
    this.avatar,
    required this.order,
    required this.active,
    required this.groupId,
    this.metadata,
  });

  String get fullName => '$firstName $lastName';

  // Get office phone from metadata
  String? get officeTel {
    if (metadata == null) return null;
    return metadata!['office_tel'] as String? ?? metadata!['officeTel'] as String?;
  }

  // Get home phone from metadata
  String? get homeTel {
    if (metadata == null) return null;
    return metadata!['home_tel'] as String? ?? metadata!['homeTel'] as String?;
  }

  // Get alternate mobile from metadata
  String? get alternateMobile {
    if (metadata == null) return null;
    return metadata!['alternate_mobile'] as String? ?? metadata!['alternateMobile'] as String?;
  }

  // Get UK mobile from metadata
  String? get ukMobile {
    if (metadata == null) return null;
    return metadata!['uk_mobile'] as String? ?? metadata!['ukMobile'] as String?;
  }

  factory Contact.fromJson(Map<String, dynamic> json) {
    return Contact(
      id: json['id'] as String,
      firstName: json['firstName'] as String,
      lastName: json['lastName'] as String,
      title: json['title'] as String?,
      company: json['company'] as String?,
      phone: json['phone'] as String?,
      email: json['email'] as String?,
      timezone: json['timezone'] as String?,
      avatar: json['avatar'] as String?,
      order: json['order'] as int,
      active: json['active'] as bool,
      groupId: json['groupId'] as String,
      metadata: json['metadata'] as Map<String, dynamic>?,
    );
  }
}