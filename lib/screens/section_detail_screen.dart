import 'package:flutter/material.dart';
import 'package:flutter_html/flutter_html.dart';
import '../services/auth_service.dart';
import '../services/content_service.dart' as cs;
import 'login_screen.dart';
import 'contact_details_screen.dart';
import '../widgets/app_bottom_navigation.dart';

class SectionDetailScreen extends StatefulWidget {
  final String sectionId;
  final String title;
  final String? description;
  final String chapterTitle;

  const SectionDetailScreen({
    super.key,
    required this.sectionId,
    required this.title,
    this.description,
    required this.chapterTitle,
  });

  @override
  State<SectionDetailScreen> createState() => _SectionDetailScreenState();
}

class _SectionDetailScreenState extends State<SectionDetailScreen> {
  final cs.ContentService _contentService = cs.ContentService();
  final AuthService _authService = AuthService();

  List<cs.Content> contents = [];
  bool isLoading = true;
  String? errorMessage;

  @override
  void initState() {
    super.initState();
    _loadSectionContents();
  }

  Future<void> _loadSectionContents() async {
    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    try {
      final result =
          await _contentService.getContentsBySectionId(widget.sectionId);

      if (!mounted) return;

      if (result['success'] == true) {
        final contentsData = result['data'] as List<dynamic>;
        setState(() {
          contents = contentsData
              .map((json) => cs.Content.fromJson(json as Map<String, dynamic>))
              .toList()
            ..sort((a, b) => a.order.compareTo(b.order));
          isLoading = false;
        });
      } else {
        setState(() {
          errorMessage = result['error'] ?? 'Failed to load content';
          isLoading = false;
        });

        if (result['needsLogin'] == true) {
          _handleLogout();
        }
      }
    } catch (e) {
      if (!mounted) return;

      setState(() {
        errorMessage = e.toString();
        isLoading = false;
      });
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

  // Check if content has contact button marker
  bool _hasContactButton(String content) {
    return content.contains('{{CONTACT_BUTTON}}');
  }

  // Build content with contact button
  Widget _buildContentWithContactButton(String htmlContent) {
  final parts = htmlContent.split('{{CONTACT_BUTTON}}');

  if (parts.length == 1) {
    return Html(
      data: htmlContent,
      style: {
        "body": Style(
          margin: Margins.zero,
          padding: HtmlPaddings.zero,
          fontSize: FontSize(16),
          lineHeight: const LineHeight(1.5),
          fontFamily: 'Inter',
        ),
      },
    );
  }

  // Replace the marker with an inline HTML element
  final modifiedHtml = htmlContent.replaceAll(
    '{{CONTACT_BUTTON}}',
    '<span id="contact-button-placeholder">📞</span>',
  );

  return Html(
    data: modifiedHtml,
    style: {
      "body": Style(
        margin: Margins.zero,
        padding: HtmlPaddings.zero,
        fontSize: FontSize(16),
        lineHeight: const LineHeight(1.5),
        fontFamily: 'Inter',
      ),
      "p": Style(
        margin: Margins.only(bottom: 12),
      ),
      "ul": Style(
        margin: Margins.only(bottom: 12, left: 20),
      ),
      "li": Style(
        margin: Margins.only(bottom: 8),
      ),
    },
    extensions: [
      TagExtension(
        tagsToExtend: {"span"},
        builder: (extensionContext) {
          if (extensionContext.attributes['id'] == 'contact-button-placeholder') {
            return InkWell(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const ContactDetailsScreen(),
                  ),
                );
              },
              child: Container(
                padding: const EdgeInsets.all(4),
                margin: const EdgeInsets.symmetric(horizontal: 4),
                decoration: const BoxDecoration(
                  color: Color(0xFF123157),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.phone_outlined,
                  size: 16,
                  color: Colors.white,
                ),
              ),
            );
          }
          return const SizedBox.shrink();
        },
      ),
    ],
  );
}

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Column(
        children: [
          // Header with image background
          Container(
            height: 200,
            decoration: const BoxDecoration(
              color: Color(0xFF123157),
              image: DecorationImage(
                image: AssetImage('assets/background_1.png'),
                fit: BoxFit.cover,
                opacity: 0.3,
              ),
            ),
            child: SafeArea(
              child: Column(
                children: [
                  // Back button
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Align(
                      alignment: Alignment.topLeft,
                      child: IconButton(
                        icon: const Icon(Icons.arrow_back, color: Colors.white),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ),
                  ),
                  // Airplane icon
                  const Expanded(
                    child: Center(
                      child: Icon(
                        Icons.flight,
                        size: 80,
                        color: Colors.white54,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Content area
          Expanded(
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Chapter title
                    Text(
                      widget.chapterTitle,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[600],
                        fontFamily: 'Inter',
                      ),
                    ),
                    const SizedBox(height: 8),

                    // Section title
                    Text(
                      widget.title,
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'Inter',
                        color: Colors.black87,
                      ),
                    ),

                    // Description
                    if (widget.description != null &&
                        widget.description!.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 8.0),
                        child: Text(
                          widget.description!,
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[600],
                            fontFamily: 'Inter',
                          ),
                        ),
                      ),

                    const SizedBox(height: 24),

                    // Loading state
                    if (isLoading)
                      const Center(
                        child: Padding(
                          padding: EdgeInsets.all(40.0),
                          child: CircularProgressIndicator(
                            color: Color(0xFF123157),
                          ),
                        ),
                      ),

                    // Error state
                    if (errorMessage != null)
                      Center(
                        child: Padding(
                          padding: const EdgeInsets.all(20.0),
                          child: Column(
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
                                onPressed: _loadSectionContents,
                                icon: const Icon(Icons.refresh),
                                label: const Text('Retry'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF123157),
                                  foregroundColor: Colors.white,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                    // Content
                    if (!isLoading && errorMessage == null)
                      ...contents.map((cs.Content content) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 20.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Content title
                              if (content.title.isNotEmpty)
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 12.0),
                                  child: Text(
                                    content.title,
                                    style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      fontFamily: 'Inter',
                                      color: Colors.black87,
                                    ),
                                  ),
                                ),

                              // Content body - check for contact button
                              if (_hasContactButton(content.content))
                                _buildContentWithContactButton(content.content)
                              else
                                Html(
                                  data: content.content,
                                  style: {
                                    "body": Style(
                                      margin: Margins.zero,
                                      padding: HtmlPaddings.zero,
                                      fontSize: FontSize(16),
                                      lineHeight: const LineHeight(1.5),
                                      fontFamily: 'Inter',
                                    ),
                                    "p": Style(
                                      margin: Margins.only(bottom: 12),
                                    ),
                                    "ul": Style(
                                      margin:
                                          Margins.only(bottom: 12, left: 20),
                                    ),
                                    "li": Style(
                                      margin: Margins.only(bottom: 8),
                                    ),
                                  },
                                ),
                            ],
                          ),
                        );
                      }).toList(),

                    // Empty state
                    if (!isLoading && errorMessage == null && contents.isEmpty)
                      Center(
                        child: Padding(
                          padding: const EdgeInsets.all(40.0),
                          child: Column(
                            children: [
                              Icon(
                                Icons.description_outlined,
                                size: 64,
                                color: Colors.grey[400],
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'No content available',
                                style: TextStyle(
                                  fontSize: 16,
                                  color: Colors.grey[600],
                                  fontFamily: 'Inter',
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
          ),
        ],
      ),
      bottomNavigationBar: const AppBottomNavigation(selectedIndex: 5),
    );
  }
}
