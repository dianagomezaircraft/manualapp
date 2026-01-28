import 'package:flutter/material.dart';
import '../services/chapters_service.dart';
import '../services/sections_service.dart';
import '../services/auth_service.dart';
import 'login_screen.dart';
import 'section_detail_screen.dart';
import '../widgets/app_bottom_navigation.dart';

class ChapterDetailScreen extends StatefulWidget {
  final String chapterTitle;
  final String chapterNumber;
  final String? chapterId;

  const ChapterDetailScreen({
    super.key,
    required this.chapterTitle,
    required this.chapterNumber,
    this.chapterId,
  });

  @override
  State<ChapterDetailScreen> createState() => _ChapterDetailScreenState();
}

class _ChapterDetailScreenState extends State<ChapterDetailScreen> {
  final ChaptersService _chaptersService = ChaptersService();
  final AuthService _authService = AuthService();

  Chapter? chapterDetails;
  bool isLoading = false;
  String? errorMessage;

  @override
  void initState() {
    super.initState();
    if (widget.chapterId != null) {
      _loadChapterDetails();
    }
  }

  Future<void> _loadChapterDetails() async {
    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    final result = await _chaptersService.getChapterById(widget.chapterId!);

    if (!mounted) return;

    if (result['success'] == true) {
      setState(() {
        chapterDetails = Chapter.fromJson(result['data']);
        isLoading = false;
      });
    } else {
      setState(() {
        errorMessage = result['error'] ?? 'Failed to load chapter details';
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

    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(
        builder: (context) => const LoginScreen(),
      ),
          (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end:  Alignment(0.0, 0.0),
            colors: [
                Color(0xFF123157),
                Color(0xFF1e518f),
              ],
          ),
        ),
      
        child: SafeArea(
          child: Column(
            children: [
              // Custom App Bar with Search
              _buildCustomAppBar(),

              // Main Content
              Expanded(
                child: _buildBody(),
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: const AppBottomNavigation(selectedIndex: 0),
    );
  }

  Widget _buildCustomAppBar() {
    return Container(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Back button and title row
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.white),
                onPressed: () => Navigator.pop(context),
              ),
              const Spacer(),
            ],
          ),
          const SizedBox(height: 8),

         
          const SizedBox(height: 16),

          // Chapter title
          Text(
            widget.chapterNumber,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontFamily: 'Inter',
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            chapterDetails?.title ?? widget.chapterTitle,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontFamily: 'Inter',
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (isLoading) {
      return Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(30),
            topRight: Radius.circular(30),
          ),
        ),
        child: const Center(
          child: CircularProgressIndicator(
            color: Color(0xFF123157),
          ),
        ),
      );
    }

    if (errorMessage != null) {
      return Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(30),
            topRight: Radius.circular(30),
          ),
        ),
        child: Center(
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
                  onPressed: _loadChapterDetails,
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
        ),
      );
    }

    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFFeeeff0),
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(30),
          topRight: Radius.circular(30),
        ),
      ),
      child: _buildSectionsGrid(),
    );
  }

  Widget _buildSectionsGrid() {
    final sections = chapterDetails?.sections ?? [];

    if (sections.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.list_alt,
                size: 64,
                color: Colors.grey[400],
              ),
              const SizedBox(height: 16),
              Text(
                'No sections available',
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

    return GridView.builder(
      padding: const EdgeInsets.all(20),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        childAspectRatio: 0.85,
      ),
      itemCount: sections.length,
      itemBuilder: (context, index) {
        final section = sections[index];
        return _buildSectionCard(section);
      },
    );
  }

  Widget _buildSectionCard(Section section) {
    // Define icons for different section types
    IconData sectionIcon = Icons.description;

    // You can customize icons based on section title or type
    if (section.title.toLowerCase().contains('hull')) {
      sectionIcon = Icons.flight;
    } else if (section.title.toLowerCase().contains('engine')) {
      sectionIcon = Icons.settings;
    } else if (section.title.toLowerCase().contains('spares') ||
        section.title.toLowerCase().contains('equipment')) {
      sectionIcon = Icons.build_circle;
    } else if (section.title.toLowerCase().contains('passenger')) {
      sectionIcon = Icons.person_outline;
    } else if (section.title.toLowerCase().contains('third parties')) {
      sectionIcon = Icons.groups;
    } else if (section.title.toLowerCase().contains('cargo')) {
      sectionIcon = Icons.inventory_2;
    }

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF123157),
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment(0.0,0.1),
          colors: [
            Color(0xFF1e518f),
            Color(0xFF123157),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.6),
            blurRadius: 5,
            offset: const Offset(3, 6),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => SectionDetailScreen(
                  sectionId: section.id,
                  title: section.title,
                  subtitle: section.subtitle,
                ),
              ),
            );
          },
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Icon
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    sectionIcon,
                    size: 40,
                    color: const Color(0xFFAD8042), // Gold color
                  ),
                ),
                const SizedBox(height: 16),

                // Title
                Text(
                  section.title,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'Inter',
                    height: 1.2,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}