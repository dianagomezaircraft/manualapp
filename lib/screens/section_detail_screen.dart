import 'package:flutter/material.dart';
import 'package:flutter_html/flutter_html.dart';
import '../services/sections_service.dart';
import '../services/content_service.dart' as content_service;
import '../services/auth_service.dart';
import 'login_screen.dart';
import '../widgets/app_bottom_navigation.dart';

class SectionDetailScreen extends StatefulWidget {
  final String? sectionId;
  final String title;
  final String subtitle;
  final String chapterTitle;

  const SectionDetailScreen({
    super.key,
    this.sectionId,
    required this.title,
    required this.subtitle,
    required this.chapterTitle,
  });

  @override
  State<SectionDetailScreen> createState() => _SectionDetailScreenState();
}

class _SectionDetailScreenState extends State<SectionDetailScreen> {
  int selectedBottomIndex = 2; // ARTS selected

  final SectionsService _sectionsService = SectionsService();
  final content_service.ContentService _contentService = content_service.ContentService();
  final AuthService _authService = AuthService();

  Section? sectionDetails;
  List<content_service.Content> contents = [];
  bool isLoading = false;
  bool isLoadingContents = false;
  String? errorMessage;
  int currentPage = 0;
  
  // PageView controller
  late PageController _pageController;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    if (widget.sectionId != null) {
      _loadSectionDetails();
      _loadContents();
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
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
            .map((json) => content_service.Content.fromJson(json))
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

  void _goToPreviousPage() {
    if (currentPage > 0) {
      _pageController.animateToPage(
        currentPage - 1,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  void _goToNextPage() {
    final nonImageContents = contents
        .where((c) => c.type != content_service.ContentType.IMAGE)
        .toList();
    
    if (currentPage < nonImageContents.length - 1) {
      _pageController.animateToPage(
        currentPage + 1,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
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
      ),
      body: _buildBody(),
      bottomNavigationBar: const AppBottomNavigation(selectedIndex: 0),
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

    return Column(
      children: [
        // Image Header
        _buildImageHeader(),

        // Content (Scrollable)
        Expanded(
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title
                  Text(
                    widget.chapterTitle,
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
                    sectionDetails?.title ?? widget.title,
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
                    Html(
                      data: sectionDetails!.content,
                      style: {
                        "body": Style(
                          margin: Margins.zero,
                          padding: HtmlPaddings.zero,
                          fontSize: FontSize(14),
                          fontFamily: 'Inter',
                          color: Colors.grey[800],
                          lineHeight: LineHeight(1.6),
                        ),
                        "p": Style(
                          margin: Margins.only(bottom: 12),
                          fontSize: FontSize(14),
                          fontFamily: 'Inter',
                          color: Colors.grey[800],
                        ),
                        "ul": Style(
                          margin: Margins.only(bottom: 12, left: 8),
                          padding: HtmlPaddings.only(left: 16),
                        ),
                        "ol": Style(
                          margin: Margins.only(bottom: 12, left: 8),
                          padding: HtmlPaddings.only(left: 16),
                        ),
                        "li": Style(
                          margin: Margins.only(bottom: 6),
                          fontSize: FontSize(14),
                          fontFamily: 'Inter',
                          color: Colors.grey[800],
                        ),
                        "h1": Style(
                          fontSize: FontSize(20),
                          fontWeight: FontWeight.bold,
                          margin: Margins.only(bottom: 12, top: 8),
                          color: Colors.black87,
                        ),
                        "h2": Style(
                          fontSize: FontSize(18),
                          fontWeight: FontWeight.bold,
                          margin: Margins.only(bottom: 10, top: 8),
                          color: Colors.black87,
                        ),
                        "h3": Style(
                          fontSize: FontSize(16),
                          fontWeight: FontWeight.bold,
                          margin: Margins.only(bottom: 8, top: 6),
                          color: Colors.black87,
                        ),
                        "strong": Style(
                          fontWeight: FontWeight.bold,
                        ),
                        "em": Style(
                          fontStyle: FontStyle.italic,
                        ),
                        "a": Style(
                          color: const Color(0xFF123157),
                          textDecoration: TextDecoration.underline,
                        ),
                      },
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
                    _buildContentsWithNavigation()
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
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildImageHeader() {
    // Check if any content has an image
    final imageContent = contents.firstWhere(
      (c) => c.type == content_service.ContentType.IMAGE,
      orElse: () => content_service.Content(
        id: '',
        title: '',
        type: content_service.ContentType.TEXT,
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

  Widget _buildContentsWithNavigation() {
    // Filter out images as they're shown in the header
    final nonImageContents = contents
        .where((c) => c.type != content_service.ContentType.IMAGE)
        .toList();

    if (nonImageContents.isEmpty) {
      return const SizedBox.shrink();
    }

    // If there's only one content, show it without navigation
    if (nonImageContents.length == 1) {
      return _buildContentItem(nonImageContents[0]);
    }

    // Multiple contents - show with navigation arrows beside content
    return Column(
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Left arrow
            Padding(
              padding: const EdgeInsets.only(top: 60, right: 8),
              child: GestureDetector(
                onTap: currentPage > 0 ? _goToPreviousPage : null,
                child: Opacity(
                  opacity: currentPage > 0 ? 1.0 : 0.3,
                  child: Image.asset(
                    'assets/iconLeft.png',
                    width: 32,
                    height: 32,
                    errorBuilder: (context, error, stackTrace) {
                      return Icon(
                        Icons.arrow_back_ios,
                        size: 32,
                        color: currentPage > 0 
                            ? const Color(0xFF123157) 
                            : Colors.grey[300],
                      );
                    },
                  ),
                ),
              ),
            ),

            // Content PageView with fixed height
            Expanded(
              child: SizedBox(
                height: MediaQuery.of(context).size.height * 0.45,
                child: PageView.builder(
                  controller: _pageController,
                  physics: const NeverScrollableScrollPhysics(), // Disable swipe, use arrows only
                  onPageChanged: (index) {
                    setState(() {
                      currentPage = index;
                    });
                  },
                  itemCount: nonImageContents.length,
                  itemBuilder: (context, index) {
                    return SingleChildScrollView(
                      child: _buildContentItem(nonImageContents[index]),
                    );
                  },
                ),
              ),
            ),

            // Right arrow
            Padding(
              padding: const EdgeInsets.only(top: 60, left: 8),
              child: GestureDetector(
                onTap: currentPage < nonImageContents.length - 1 ? _goToNextPage : null,
                child: Opacity(
                  opacity: currentPage < nonImageContents.length - 1 ? 1.0 : 0.3,
                  child: Image.asset(
                    'assets/iconRight.png',
                    width: 32,
                    height: 32,
                    errorBuilder: (context, error, stackTrace) {
                      return Icon(
                        Icons.arrow_forward_ios,
                        size: 32,
                        color: currentPage < nonImageContents.length - 1
                            ? const Color(0xFF123157)
                            : Colors.grey[300],
                      );
                    },
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildContentItem(content_service.Content content) {
    switch (content.type) {
      case content_service.ContentType.TEXT:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (content.title.isNotEmpty) ...[
              Text(
                content.title,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'Inter',
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 12),
            ],
            // Render HTML content
            Html(
              data: content.content,
              style: {
                "body": Style(
                  margin: Margins.zero,
                  padding: HtmlPaddings.zero,
                  fontSize: FontSize(14),
                  fontFamily: 'Inter',
                  color: Colors.grey[800],
                  lineHeight: LineHeight(1.6),
                ),
                "p": Style(
                  margin: Margins.only(bottom: 12),
                  fontSize: FontSize(14),
                  fontFamily: 'Inter',
                  color: Colors.grey[800],
                ),
                "ul": Style(
                  margin: Margins.only(bottom: 12, left: 8),
                  padding: HtmlPaddings.only(left: 16),
                ),
                "ol": Style(
                  margin: Margins.only(bottom: 12, left: 8),
                  padding: HtmlPaddings.only(left: 16),
                ),
                "li": Style(
                  margin: Margins.only(bottom: 6),
                  fontSize: FontSize(14),
                  fontFamily: 'Inter',
                  color: Colors.grey[800],
                ),
                "h1": Style(
                  fontSize: FontSize(20),
                  fontWeight: FontWeight.bold,
                  margin: Margins.only(bottom: 12, top: 8),
                  color: Colors.black87,
                ),
                "h2": Style(
                  fontSize: FontSize(18),
                  fontWeight: FontWeight.bold,
                  margin: Margins.only(bottom: 10, top: 8),
                  color: Colors.black87,
                ),
                "h3": Style(
                  fontSize: FontSize(16),
                  fontWeight: FontWeight.bold,
                  margin: Margins.only(bottom: 8, top: 6),
                  color: Colors.black87,
                ),
                "strong": Style(
                  fontWeight: FontWeight.bold,
                ),
                "em": Style(
                  fontStyle: FontStyle.italic,
                ),
                "a": Style(
                  color: const Color(0xFF123157),
                  textDecoration: TextDecoration.underline,
                ),
              },
            ),
          ],
        );

      case content_service.ContentType.VIDEO:
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
}