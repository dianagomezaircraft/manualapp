import 'package:flutter/material.dart';
import '../services/chapters_service.dart';
import '../services/sections_service.dart';
import '../services/auth_service.dart';
import '../services/search_service.dart';
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
  final SearchService _searchService = SearchService();
  final TextEditingController _searchController = TextEditingController();

  Chapter? chapterDetails;
  bool isLoading = false;
  String? errorMessage;
  
  // Search-related state
  List<SearchResult> searchResults = [];
  bool isSearching = false;
  bool hasSearched = false;
  String? searchErrorMessage;
  String currentQuery = '';

  @override
  void initState() {
    super.initState();
    if (widget.chapterId != null) {
      _loadChapterDetails();
    }
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    if (_searchController.text.isEmpty) {
      setState(() {
        searchResults = [];
        hasSearched = false;
        searchErrorMessage = null;
      });
    }
  }

  Future<void> _performSearch() async {
    final query = _searchController.text.trim();
    
    if (query.isEmpty) {
      setState(() {
        searchResults = [];
        hasSearched = false;
        searchErrorMessage = null;
      });
      return;
    }

    setState(() {
      isSearching = true;
      hasSearched = true;
      searchErrorMessage = null;
      currentQuery = query;
    });

    final result = await _searchService.globalSearch(query: query);

    if (!mounted) return;

    if (result['success'] == true) {
      final resultsData = result['data'] as List<dynamic>;
      setState(() {
        searchResults = resultsData
            .map((json) => SearchResult.fromJson(json as Map<String, dynamic>))
            .toList();
        isSearching = false;
      });
    } else {
      setState(() {
        searchErrorMessage = result['error'] ?? 'Failed to search';
        searchResults = [];
        isSearching = false;
      });

      if (result['needsLogin'] == true) {
        _handleLogout();
      }
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
            end: Alignment(0.0, 0.0),
            colors: [
              Color(0xFF123157),
              Color(0xFF1e518f),
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              _buildCustomAppBar(),
              Expanded(
                child: hasSearched ? _buildSearchResults() : _buildBody(),
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
          // Back button row
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

          // Search bar
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
            ),
            child: TextField(
              controller: _searchController,
              onSubmitted: (_) => _performSearch(),
              decoration: InputDecoration(
                hintText: 'Search chapters, sections, content...',
                hintStyle: TextStyle(
                  color: Colors.grey[400],
                  fontSize: 14,
                ),
                prefixIcon: const Icon(
                  Icons.search,
                  color: Color(0xFF123157),
                ),
                suffixIcon: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_searchController.text.isNotEmpty)
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.grey),
                        onPressed: () {
                          _searchController.clear();
                          setState(() {
                            searchResults = [];
                            hasSearched = false;
                            searchErrorMessage = null;
                          });
                        },
                      ),
                    IconButton(
                      icon: const Icon(
                        Icons.search,
                        color: Color(0xFF123157),
                      ),
                      onPressed: _performSearch,
                    ),
                  ],
                ),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Chapter title (only show when not searching)
          if (!hasSearched) ...[
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

          // Search results count
          if (hasSearched && searchResults.isNotEmpty)
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 6,
              ),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.filter_list,
                    size: 16,
                    color: Color(0xFF123157),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '${searchResults.length} results',
                    style: const TextStyle(
                      color: Color(0xFF123157),
                      fontSize: 12,
                      fontFamily: 'Inter',
                    ),
                  ),
                ],
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

  Widget _buildSearchResults() {
    // Loading state
    if (isSearching) {
      return Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(30),
            topRight: Radius.circular(30),
          ),
        ),
        child: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(
                color: Color(0xFF123157),
              ),
              SizedBox(height: 16),
              Text(
                'Searching...',
                style: TextStyle(
                  color: Colors.grey,
                  fontFamily: 'Inter',
                ),
              ),
            ],
          ),
        ),
      );
    }

    // Error state
    if (searchErrorMessage != null) {
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
                  searchErrorMessage!,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey[600],
                    fontFamily: 'Inter',
                  ),
                ),
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  onPressed: _performSearch,
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
      );
    }

    // No results found
    if (searchResults.isEmpty) {
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
                  Icons.search_off,
                  size: 64,
                  color: Colors.grey[400],
                ),
                const SizedBox(height: 16),
                Text(
                  'No results found for "$currentQuery"',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                    fontFamily: 'Inter',
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Try different keywords or check your spelling',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[600],
                    fontFamily: 'Inter',
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    // Results list
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(30),
          topRight: Radius.circular(30),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(20.0),
            child: Text(
              'Search results for "$currentQuery"',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                fontFamily: 'Inter',
                color: Colors.black87,
              ),
            ),
          ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: searchResults.length,
              itemBuilder: (context, index) {
                return _buildSearchResultItem(searchResults[index]);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchResultItem(SearchResult result) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ChapterDetailScreen(
                chapterTitle: result.chapterTitle,
                chapterNumber: 'CHAPTER',
                chapterId: result.chapterId,
              ),
            ),
          );
        },
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              margin: const EdgeInsets.only(top: 4),
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: _getTypeColor(result.type).withOpacity(0.1),
                border: Border.all(
                  color: _getTypeColor(result.type).withOpacity(0.3),
                ),
                shape: BoxShape.circle,
              ),
              child: Icon(
                _getTypeIcon(result.type),
                size: 20,
                color: _getTypeColor(result.type),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    result.chapterTitle,
                    style: TextStyle(
                      fontSize: 12,
                      fontFamily: 'Inter',
                      color: Colors.grey[500],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    result.title,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      fontFamily: 'Inter',
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 4),
                  RichText(
                    text: TextSpan(
                      style: TextStyle(
                        fontSize: 12,
                        fontFamily: 'Inter',
                        color: Colors.grey[600],
                        height: 1.4,
                      ),
                      children: _highlightKeyword(
                        result.displayText,
                        currentQuery,
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: _getTypeColor(result.type).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      result.typeDisplay,
                      style: TextStyle(
                        fontSize: 10,
                        fontFamily: 'Inter',
                        color: _getTypeColor(result.type),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  IconData _getTypeIcon(String type) {
    switch (type) {
      case 'chapter':
        return Icons.book;
      case 'section':
        return Icons.bookmark;
      case 'content':
        return Icons.description;
      default:
        return Icons.article;
    }
  }

  Color _getTypeColor(String type) {
    switch (type) {
      case 'chapter':
        return const Color(0xFF123157);
      case 'section':
        return Colors.blue;
      case 'content':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  List<TextSpan> _highlightKeyword(String text, String keyword) {
    final List<TextSpan> spans = [];
    final lowerText = text.toLowerCase();
    final lowerKeyword = keyword.toLowerCase();

    int start = 0;
    int index = lowerText.indexOf(lowerKeyword);

    while (index != -1) {
      if (index > start) {
        spans.add(TextSpan(text: text.substring(start, index)));
      }

      spans.add(TextSpan(
        text: text.substring(index, index + keyword.length),
        style: const TextStyle(
          fontWeight: FontWeight.bold,
          color: Colors.black87,
          backgroundColor: Color(0xFFFFEB3B),
        ),
      ));

      start = index + keyword.length;
      index = lowerText.indexOf(lowerKeyword, start);
    }

    if (start < text.length) {
      spans.add(TextSpan(text: text.substring(start)));
    }

    return spans;
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
    IconData sectionIcon = Icons.description;

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
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment(0.0, 0.1),
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
                  chapterTitle: chapterDetails!.title,
                ),
              ),
            );
          },
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    sectionIcon,
                    size: 40,
                    color: const Color(0xFFAD8042),
                  ),
                ),
                const SizedBox(height: 16),
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