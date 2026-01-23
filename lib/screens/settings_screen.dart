import 'package:flutter/material.dart';

import '../models/airline.dart';
import '../services/auth_service.dart';
import '../services/airline_service.dart';
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

    return _SettingsData(
      email: email,
      airline: airline,
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
                child: CircularProgressIndicator(
                  color: Color(0xFF123157),
                ),
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

                const Spacer(),

                SizedBox(
                  width: double.infinity,
                  child:ElevatedButton(
  style: ElevatedButton.styleFrom(
    backgroundColor: const Color(0xFF123157),
    foregroundColor: Colors.white, // 🔥 clave
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
            child: Text(
              label,
              style: const TextStyle(color: Colors.grey),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
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

/// Helper class to bundle screen data
class _SettingsData {
  final String email;
  final Airline airline;

  _SettingsData({
    required this.email,
    required this.airline,
  });
}
