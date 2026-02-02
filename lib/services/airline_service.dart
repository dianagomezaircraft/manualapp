import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';
import '../models/airline.dart';

class AirlineService {
  
  // Get all airlines
  Future<List<Airline>> getAllAirlines({required String token}) async {
    final response = await http.get(
      Uri.parse('${ApiConfig.baseUrl}/airlines'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to load airlines');
    }

    final decoded = jsonDecode(response.body);

    if (decoded['success'] != true || decoded['data'] == null) {
      throw Exception('Invalid airlines response');
    }

    final List<dynamic> airlinesData = decoded['data'];
    return airlinesData.map((json) => Airline.fromJson(json)).toList();
  }

  // Get airline by ID
  Future<Airline> getAirlineById({
    required String airlineId,
    required String token,
  }) async {
    final response = await http.get(
      Uri.parse('${ApiConfig.baseUrl}/airlines/$airlineId'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to load airline');
    }

    final decoded = jsonDecode(response.body);

    if (decoded['success'] != true || decoded['data'] == null) {
      throw Exception('Invalid airline response');
    }

    return Airline.fromJson(decoded['data']);
  }
}