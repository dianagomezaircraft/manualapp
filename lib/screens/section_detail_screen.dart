import 'package:flutter/material.dart';
import '../services/sections_service.dart';
import '../services/content_service.dart';
import '../services/auth_service.dart';
import 'login_screen.dart';

class SectionDetailScreen extends StatefulWidget {
  final String? sectionId;
  final String title;
  final String subtitle;

  const SectionDetailScreen({
    super.key,
    this.sectionId,
    required this.title,
    required this.subtitle,
  });

  @override
  State<SectionDetailScreen> createState() => _SectionDetailScreenState();
}

class _SectionDetailScreenState extends State<SectionDetailScreen> {
  int selectedBottomIndex = 2; // ARTS selected

  final SectionsService _sectionsService = SectionsService();
  final ContentService _contentService = ContentService();
  final AuthService _authService = AuthService();

  Section? sectionDetails;
  List<Content> contents = [];
  bool isLoading = false;
  bool isLoadingContents = false;
  String? errorMessage;
  int currentPage = 0;

  @override
  void initState() {
    super.initState();
    if (widget.sectionId != null) {
      _loadSectionDetails();
      _loadContents();
    }
  }

  Future<void> _loadSectionDetails() async {
    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    final result = await _sectionsService.getSectionById(widget.sectionId!);

    if (!mounted) return;

    if (result['success'] == true) {
      setState(() {
        sectionDetails = Section.fromJson(result['data']);
        isLoading = false;
      });
    } else {
      setState(() {
        errorMessage = result['error'] ?? 'Failed to load section details';
        isLoading = false;
      });

      // If authentication failed, redirect to login
      if (result['needsLogin'] == true) {
        _handleLogout();
      }
    }
  }

  Future<void> _loadContents() async {
    if (widget.sectionId == null) return;

    setState(() {
      isLoadingContents = true;
    });

    final result = await _contentService.getContentsBySectionId(widget.sectionId!);

    if (!mounted) return;

    if (result['success'] == true) {
      final contentsData = result['data'] as List<dynamic>;
      setState(() {
        contents = contentsData
            .map((json) => Content.fromJson(json))
            .toList()
          ..sort((a, b) => a.order.compareTo(b.order)); // Sort by order
        isLoadingContents = false;
      });
    } else {
      setState(() {
        isLoadingContents = false;
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
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black87),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.share, color: Colors.black87),
            onPressed: () {
              // Share functionality
            },
          ),
        ],
      ),
      body: _buildBody(),
      bottomNavigationBar: _buildBottomNavigationBar(),
    );
  }

  Widget _buildBody() {
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
                onPressed: () {
                  _loadSectionDetails();
                  _loadContents();
                },
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

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Image Header
          _buildImageHeader(),

          // Content
          Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Title
                Text(
                  sectionDetails?.title ?? widget.title,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'Inter',
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 8),

                // Subtitle
                Text(
                  sectionDetails?.subtitle ?? widget.subtitle,
                  style: TextStyle(
                    fontSize: 14,
                    fontFamily: 'Inter',
                    color: Colors.grey[600],
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 24),

                // Section content (if available)
                if (sectionDetails?.content != null && sectionDetails!.content.isNotEmpty) ...[
                  Text(
                    sectionDetails!.content,
                    style: TextStyle(
                      fontSize: 14,
                      fontFamily: 'Inter',
                      color: Colors.grey[800],
                      height: 1.6,
                    ),
                  ),
                  const SizedBox(height: 24),
                ],

                // Dynamic contents from API
                if (isLoadingContents)
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.all(20.0),
                      child: CircularProgressIndicator(
                        color: Color(0xFF123157),
                      ),
                    ),
                  )
                else if (contents.isNotEmpty)
                  _buildContentsList()
                else if (sectionDetails?.content == null || sectionDetails!.content.isEmpty)
                    Text(
                      'No additional content available for this section.',
                      style: TextStyle(
                        fontSize: 14,
                        fontFamily: 'Inter',
                        color: Colors.grey[600],
                        fontStyle: FontStyle.italic,
                      ),
                    ),

                const SizedBox(height: 24),

                // Navigation Dots
                if (contents.length > 1) _buildNavigationDots(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildImageHeader() {
    // Check if any content has an image
    final imageContent = contents.firstWhere(
          (c) => c.type == ContentType.IMAGE,
      orElse: () => Content(
        id: '',
        title: '',
        type: ContentType.TEXT,
        content: '',
        order: 0,
        active: true,
        sectionId: '',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),
    );

    if (imageContent.id.isNotEmpty) {
      return Container(
        width: double.infinity,
        height: 220,
        decoration: BoxDecoration(
          image: DecorationImage(
            image: NetworkImage(imageContent.content),
            fit: BoxFit.cover,
          ),
        ),
      );
    } else if (sectionDetails?.imageUrl != null) {
      return Container(
        width: double.infinity,
        height: 220,
        decoration: BoxDecoration(
          image: DecorationImage(
            image: NetworkImage(sectionDetails!.imageUrl!),
            fit: BoxFit.cover,
          ),
        ),
      );
    } else {
      return Container(
        width: double.infinity,
        height: 220,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              const Color(0xFF123157),
              const Color(0xFF1a4570),
            ],
          ),
        ),
        child: Center(
          child: Icon(
            Icons.flight,
            size: 80,
            color: Colors.white.withOpacity(0.3),
          ),
        ),
      );
    }
  }

  Widget _buildContentsList() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: contents.where((c) => c.type != ContentType.IMAGE).map((content) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 16.0),
          child: _buildContentItem(content),
        );
      }).toList(),
    );
  }

  Widget _buildContentItem(Content content) {
    switch (content.type) {
      case ContentType.TEXT:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (content.title.isNotEmpty) ...[
              Text(
                content.title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'Inter',
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 8),
            ],
            Text(
              content.content,
              style: TextStyle(
                fontSize: 14,
                fontFamily: 'Inter',
                color: Colors.grey[800],
                height: 1.6,
              ),
            ),
          ],
        );


      case ContentType.VIDEO:
        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.grey[100],
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF123157),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.play_arrow,
                  color: Colors.white,
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      content.title,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        fontFamily: 'Inter',
                        color: Colors.black87,
                      ),
                    ),
                    Text(
                      'Tap to play video',
                      style: TextStyle(
                        fontSize: 12,
                        fontFamily: 'Inter',
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );



      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildNavigationDots() {
    // Show dots based on number of contents or default to 3
    final dotCount = contents.isEmpty ? 3 : contents.length;

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(
        dotCount > 5 ? 5 : dotCount, // Max 5 dots
            (index) => Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: _buildDot(currentPage == index),
        ),
      ),
    );
  }

  Widget _buildDot(bool isActive) {
    return Container(
      width: 8,
      height: 8,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: isActive ? const Color(0xFF123157) : Colors.grey[300],
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
              _buildBottomNavItem(Icons.home_outlined, 0),
              _buildBottomNavItem(Icons.search, 1),
              _buildBottomNavItemARTS(2),
              _buildBottomNavItem(Icons.phone_outlined, 3),
              _buildBottomNavItem(Icons.more_horiz, 4),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBottomNavItem(IconData icon, int index) {
    final isSelected = selectedBottomIndex == index;

    return InkWell(
      onTap: () {
        setState(() {
          selectedBottomIndex = index;
        });
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

  Widget _buildBottomNavItemARTS(int index) {
    final isSelected = selectedBottomIndex == index;

    return InkWell(
      onTap: () {
        setState(() {
          selectedBottomIndex = index;
        });
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