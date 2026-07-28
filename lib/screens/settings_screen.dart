import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/airline.dart';
import '../services/auth_service.dart';
import '../services/airline_service.dart';
import '../services/chapters_service.dart';
import '../widgets/app_bottom_navigation.dart';
import 'login_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final AuthService _authService = AuthService();
  final AirlineService _airlineService = AirlineService();
  final ChaptersService _chaptersService = ChaptersService();

  late Future<_SettingsData> _dataFuture;

  @override
  void initState() {
    super.initState();
    _dataFuture = _loadData();
  }

  Future<_SettingsData> _loadData() async {
    final token = await _authService.getAccessToken();
    final userData = await _authService.getUserData();
    final email = await _authService.getUserEmail();

    final prefs = await SharedPreferences.getInstance();
    final biometricEnabled = prefs.getBool('biometric_enabled') ?? false;

    if (token == null || userData == null) {
      throw Exception('User not authenticated');
    }

    final airlineId = userData['airlineId'];
    if (airlineId == null) {
      throw Exception('User has no airline assigned');
    }

    final airline = await _airlineService.getAirlineById(
      airlineId: airlineId,
      token: token,
    );

    // Fetch chapters to get the latest updatedAt
    DateTime? lastChapterUpdate;
    final chaptersResult =
        await _chaptersService.getChapters(airlineId: airlineId);
    if (chaptersResult['success'] == true && chaptersResult['data'] != null) {
      final chapters = (chaptersResult['data'] as List)
          .map((json) => Chapter.fromJson(json as Map<String, dynamic>))
          .toList();

      if (chapters.isNotEmpty) {
        lastChapterUpdate = chapters
            .map((c) => c.updatedAt)
            .reduce((a, b) => a.isAfter(b) ? a : b);
      }
    }

    return _SettingsData(
      email: email,
      airline: airline,
      lastChapterUpdate: lastChapterUpdate,
      biometricEnabled: biometricEnabled,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF123157),
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text(
          'Settings',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: FutureBuilder<_SettingsData>(
          future: _dataFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(
                child: CircularProgressIndicator(color: Color(0xFF123157)),
              );
            }

            if (snapshot.hasError) {
              return Center(
                child: Text(
                  snapshot.error.toString(),
                  textAlign: TextAlign.center,
                ),
              );
            }

            final data = snapshot.data!;
            final airline = data.airline;

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _sectionTitle('User'),
                _infoTile('Email', data.email),
                const SizedBox(height: 24),
                _sectionTitle('Airline'),
                _infoTile('Name', airline.name),
                _infoTile('Code', airline.code),
                _infoTile(
                  'Status',
                  airline.active ? 'Active' : 'Inactive',
                ),
                const SizedBox(height: 24),
                _sectionTitle('Manual'),
                _infoTile(
                  'Last Updated',
                  data.lastChapterUpdate != null
                      ? DateFormat('MMM dd, yyyy')
                          .format(data.lastChapterUpdate!.toLocal())
                      : 'N/A',
                ),
                const SizedBox(height: 24),
                _sectionTitle('Security'),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Biometric Unlock'),
                  subtitle: const Text('Use fingerprint or Face ID to unlock'),
                  activeColor: const Color(0xFF123157),
                  value: data.biometricEnabled,
                  onChanged: (val) async {
                    final prefs = await SharedPreferences.getInstance();
                    await prefs.setBool('biometric_enabled', val);
                    if (!mounted) return;
                    setState(() {
                      _dataFuture = _loadData();
                    });
                  },
                ),
                const Spacer(),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF123157),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      textStyle: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    onPressed: _logout,
                    child: const Text('Logout'),
                  ),
                ),
              ],
            );
          },
        ),
      ),
      bottomNavigationBar: const AppBottomNavigation(selectedIndex: 4),
    );
  }

  Widget _sectionTitle(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: Color(0xFF123157),
        ),
      ),
    );
  }

  Widget _infoTile(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: Text(label, style: const TextStyle(color: Colors.grey)),
          ),
          Expanded(
            flex: 3,
            child: Text(value,
                style: const TextStyle(fontWeight: FontWeight.w500)),
          ),
        ],
      ),
    );
  }

  Future<void> _logout() async {
    await _authService.logout();
    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (_) => false,
    );
  }
}

class _SettingsData {
  final String email;
  final Airline airline;
  final DateTime? lastChapterUpdate;
  final bool biometricEnabled;

  _SettingsData({
    required this.email,
    required this.airline,
    this.lastChapterUpdate,
    required this.biometricEnabled,
  });
}