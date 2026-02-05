import 'package:flutter/material.dart';

// Screens
import '../screens/category_screen.dart';
import '../screens/search_screen.dart';
import '../screens/contact_details_screen.dart';
import '../screens/about_us_screen.dart';
import '../screens/settings_screen.dart';
import '../screens/comming_soon_screen.dart';

class AppBottomNavigation extends StatelessWidget {
  final int selectedIndex;

  const AppBottomNavigation({
    super.key,
    required this.selectedIndex,
  });

  void _onTap(BuildContext context, int index) {
    if (index == selectedIndex) return;

    switch (index) {
      case 0:
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const CategoryScreen()),
          (route) => false,
        );
        break;

      case 1:
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const SearchScreen()),
        );
        break;

      case 2:
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const AboutUsScreen()),
        );
        break;

      case 3:
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const ContactDetailsScreen()),
        );
        break;

      case 4:
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const SettingsScreen()),
        );
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _navIcon(context, Icons.home_outlined, 0),
              _navIcon(context, Icons.search, 1),
              _artsLogo(context, 2),
              _navIcon(context, Icons.phone_outlined, 3),
              _settings(context, Icons.settings,4),
            ],
          ),
        ),
      ),
    );
  }

  Widget _navIcon(BuildContext context, IconData icon, int index) {
    final isSelected = selectedIndex == index;

    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: () => _onTap(context, index),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Icon(
          icon,
          size: 26,
          color: isSelected ? const Color(0xFF123157) : Colors.grey,
        ),
      ),
    );
  }

  Widget _artsLogo(BuildContext context, int index) {
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: () => _onTap(context, index),
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Image.asset(
          'assets/logoBlue.png',
          width: 73,
          height: 72,
        ),
      ),
    );
  }

  Widget _artsClaims(BuildContext context, int index) {
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: () => _onTap(context, index),
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Image.asset(
          'assets/claimIcon.png',
          width: 32,
          //height: 22,
        ),
      ),
    );
  }
  Widget _settings(BuildContext context, IconData icon, int index) {
    final isSelected = selectedIndex == index;

    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: () => _onTap(context, index),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Icon(
          icon,
          size: 26,
          color: isSelected ? const Color(0xFF123157) : Colors.grey,
        ),
      ),
    );
  }
}
