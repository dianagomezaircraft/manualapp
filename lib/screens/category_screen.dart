import 'package:flutter/material.dart';
import '../services/auth_service.dart';

// Import the new screens
import 'search_screen.dart';
import 'chapter_detail_screen.dart';
import 'section_detail_screen.dart';
import 'contact_details_screen.dart';
import 'login_screen.dart';

class CategoryScreen extends StatefulWidget {
  final String userName;

  const CategoryScreen({
    super.key,
    this.userName = 'User',
  });

  @override
  State<CategoryScreen> createState() => _CategoryScreenState();
}

class _CategoryScreenState extends State<CategoryScreen> {
  int selectedRating = 0;
  int selectedBottomIndex = 2; // ARTS logo selected by default

  final AuthService _authService = AuthService();

  Future<void> _handleLogout() async {
    await _authService.logout();

    if (!mounted) return;

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => const LoginScreen(),
      ),
    );
  }

  final List<Map<String, String>> categories = [
    {
      'title': 'Introduction',
      'subtitle': 'Overview of roles, responsibilities, and how to use this manual.',
      'chapterNumber': 'CHAPTER 1',
    },
    {
      'title': 'Notification of Loss',
      'subtitle': 'When and how to notify, plus the minimum information required.',
      'chapterNumber': 'CHAPTER 2',
    },
    {
      'title': 'Major Loss',
      'subtitle': 'Critical actions and escalation steps for catastrophic events.',
      'chapterNumber': 'CHAPTER 3',
    },
    {
      'title': 'Provision of Information',
      'subtitle': 'What documents and evidence to gather, and when to submit them.',
      'chapterNumber': 'CHAPTER 4',
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFFB8956A), // Tan/Brown color from mockup
              Color(0xFF8B7355),
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Header Section
              Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  children: [
                    // Greeting
                    Text(
                      'Hi ${widget.userName}!',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'Inter',
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Description
                    const Text(
                      'Access the key steps and contacts you need for your situation.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontFamily: 'Inter',
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 20),
                    // Description2
                    const Text(
                      'Choose the category that best describes what happened.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontFamily: 'Inter',
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Star Rating Section
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          _buildStarRating(1, 'Incident'),
                          _buildStarRating(2, 'Major Loss'),
                          _buildStarRating(3, 'Injuries'),
                          _buildStarRating(4, 'Liability'),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // Categories List Section
              Expanded(
                child: Container(
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(30),
                      topRight: Radius.circular(30),
                    ),
                  ),
                  child: Column(
                    children: [
                      const SizedBox(height: 24),
                      Expanded(
                        child: ListView.builder(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          itemCount: categories.length,
                          itemBuilder: (context, index) {
                            return _buildCategoryCard(
                              categories[index]['title']!,
                              categories[index]['subtitle']!,
                              categories[index]['chapterNumber']!,
                              index,
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: _buildBottomNavigationBar(),
    );
  }

  Widget _buildStarRating(int stars, String label) {
    final isSelected = selectedRating == stars;

    return GestureDetector(
      onTap: () {
        setState(() {
          selectedRating = stars;
        });
      },
      child: Column(
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: List.generate(stars, (index) {
              return Icon(
                isSelected ? Icons.star : Icons.star_border,
                color: isSelected ? Colors.orange : Colors.white,
                size: 20,
              );
            }),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              color: Colors.white,
              fontSize: 10,
              fontFamily: 'Inter',
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryCard(String title, String subtitle, String chapterNumber, int index) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.grey.shade300,
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () {
            // Navigate to chapter detail screen
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => ChapterDetailScreen(
                  chapterTitle: title,
                  chapterNumber: chapterNumber,
                ),
              ),
            );
          },
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'Inter',
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 13,
                    fontFamily: 'Inter',
                    color: Colors.grey[600],
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBottomNavigationBar() {
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
              _buildBottomNavItem(Icons.home_outlined, 0, () {
                // Home action - already on home
              }),
              _buildBottomNavItem(Icons.search, 1, () {
                // Navigate to Search Screen
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const SearchScreen(),
                  ),
                );
              }),
              _buildBottomNavItemARTS(2, () {
                // ARTS action - already on ARTS screen
              }),
              _buildBottomNavItem(Icons.phone_outlined, 3, () {
                // Navigate to Contact Details Screen
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const ContactDetailsScreen(),
                  ),
                );
              }),
              _buildBottomNavItem(Icons.more_horiz, 4, () {
                // More options action
                showDialog(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('Logout'),
                    content: const Text('Are you sure you want to logout?'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Cancel'),
                      ),
                      TextButton(
                        onPressed: () {
                          Navigator.pop(context);
                          _handleLogout();
                        },
                        child: const Text('Logout'),
                      ),
                    ],
                  ),
                );
              }),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBottomNavItem(IconData icon, int index, VoidCallback onTap) {
    final isSelected = selectedBottomIndex == index;

    return InkWell(
      onTap: () {
        setState(() {
          selectedBottomIndex = index;
        });
        onTap();
      },
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Icon(
          icon,
          color: isSelected ? const Color(0xFF123157) : Colors.grey,
          size: 26,
        ),
      ),
    );
  }

  Widget _buildBottomNavItemARTS(int index, VoidCallback onTap) {
    final isSelected = selectedBottomIndex == index;

    return InkWell(
      onTap: () {
        setState(() {
          selectedBottomIndex = index;
        });
        onTap();
      },
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.flight,
              color: isSelected ? const Color(0xFF123157) : Colors.grey,
              size: 24,
            ),
            const SizedBox(height: 2),
            Text(
              'ARTS',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                fontFamily: 'Inter',
                color: isSelected ? const Color(0xFF123157) : Colors.grey,
              ),
            ),
          ],
        ),
      ),
    );
  }
}