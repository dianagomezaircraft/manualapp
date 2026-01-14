import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../services/chapters_service.dart';

// Import the screens
import 'search_screen.dart';
import 'chapter_detail_screen.dart';
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
  final ChaptersService _chaptersService = ChaptersService();

  List<Chapter> chapters = [];
  bool isLoading = true;
  String? errorMessage;

  @override
  void initState() {
    super.initState();
    _loadChapters();
  }

  Future<void> _loadChapters() async {
    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    final result = await _chaptersService.getChapters();

    if (!mounted) return;

    if (result['success'] == true) {
      final chaptersData = result['data'] as List<dynamic>;
      setState(() {
        chapters = chaptersData
            .map((json) => Chapter.fromJson(json))
            .toList()
          ..sort((a, b) => a.order.compareTo(b.order)); // Sort by order
        isLoading = false;
      });
    } else {
      setState(() {
        errorMessage = result['error'] ?? 'Failed to load chapters';
        isLoading = false;
      });

      // If authentication failed, redirect to login
      if (result['needsLogin'] == true) {
        _handleLogout();
      }
    }
  }

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
                      'Access the loss prevention measures and the key steps and contacts you would need in the event of a  loss.',
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
                          _buildStarRating(1, 'Major Loss'),
                          _buildStarRating(1, 'Injuries'),
                          _buildStarRating(1, 'Liability'),
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
                        child: _buildChaptersList(),
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

  Widget _buildChaptersList() {
    if (isLoading) {
      return const Center(
        child: CircularProgressIndicator(
          color: Color(0xFF123157),
        ),
      );
    }

    if (errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.error_outline,
                size: 64,
                color: Colors.grey[400],
              ),
              const SizedBox(height: 16),
              Text(
                errorMessage!,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey[600],
                  fontFamily: 'Inter',
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: _loadChapters,
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF123157),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 12,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (chapters.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.folder_open,
                size: 64,
                color: Colors.grey[400],
              ),
              const SizedBox(height: 16),
              Text(
                'No chapters available',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey[600],
                  fontFamily: 'Inter',
                ),
              ),
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadChapters,
      color: const Color(0xFF123157),
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 8,
        ),
        itemCount: chapters.length,
        itemBuilder: (context, index) {
          final chapter = chapters[index];
          return _buildCategoryCard(
            chapter.title,
            chapter.description,
            'CHAPTER ${chapter.chapterNumber+1}',
            chapter.id,
            index,
          );
        },
      ),
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

  Widget _buildCategoryCard(
      String title,
      String subtitle,
      String chapterNumber,
      String chapterId,
      int index,
      ) {
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
            // Navigate to chapter detail screen with chapter ID
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => ChapterDetailScreen(
                  chapterTitle: title,
                  chapterNumber: chapterNumber,
                  chapterId: chapterId,
                ),
              ),
            );
          },
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'Inter',
                          color: Colors.black87,
                        ),
                      ),
                    ),
                    Text(
                      chapterNumber,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        fontFamily: 'Inter',
                        color: Colors.grey[500],
                      ),
                    ),
                  ],
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
            const SizedBox(height: 2),
            Image.asset(
              'assets/logoBlue.png',
              width: 73,
              height: 72,
            ),
          ],
        ),
      ),
    );
  }
}