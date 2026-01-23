import 'package:flutter/material.dart';
import '../services/search_service.dart';
import '../services/auth_service.dart';
import 'chapter_detail_screen.dart';
import 'login_screen.dart';
import '../widgets/app_bottom_navigation.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  final SearchService _searchService = SearchService();
  final AuthService _authService = AuthService();
  
  int selectedBottomIndex = 1; // Search icon selected
  
  List<SearchResult> searchResults = [];
  bool isSearching = false;
  bool hasSearched = false;
  String? errorMessage;
  String currentQuery = '';

  @override
  void initState() {
    super.initState();
    // Add debounce to search
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    // Debounce search - wait for user to stop typing
    if (_searchController.text.isEmpty) {
      setState(() {
        searchResults = [];
        hasSearched = false;
        errorMessage = null;
      });
    }
  }

  Future<void> _performSearch() async {
    final query = _searchController.text.trim();
    
    if (query.isEmpty) {
      setState(() {
        searchResults = [];
        hasSearched = false;
        errorMessage = null;
      });
      return;
    }

    setState(() {
      isSearching = true;
      hasSearched = true;
      errorMessage = null;
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
        errorMessage = result['error'] ?? 'Failed to search';
        searchResults = [];
        isSearching = false;
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
      backgroundColor: const Color(0xFF123157),
      body: SafeArea(
        child: Column(
          children: [
            // Header with search bar
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Container(
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
                                errorMessage = null;
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
            ),

            // Filters
            if (hasSearched && searchResults.isNotEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Row(
                  children: [
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
              ),

            const SizedBox(height: 16),

            // Search Results
            Expanded(
              child: Container(
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(30),
                    topRight: Radius.circular(30),
                  ),
                ),
                child: _buildSearchResults(),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: const AppBottomNavigation(selectedIndex: 1),
    );
  }

  Widget _buildSearchResults() {
    // Loading state
    if (isSearching) {
      return const Center(
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
      );
    }

    // Error state
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
      );
    }

    // No search performed yet
    if (!hasSearched) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.search,
                size: 64,
                color: Colors.grey[300],
              ),
              const SizedBox(height: 16),
              Text(
                'Enter a search term to find\nchapters, sections, and content',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey[500],
                  fontFamily: 'Inter',
                ),
              ),
            ],
          ),
        ),
      );
    }

    // No results found
    if (searchResults.isEmpty) {
      return Center(
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
      );
    }

    // Results list
    return Column(
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
    );
  }

  Widget _buildSearchResultItem(SearchResult result) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: InkWell(
        onTap: () {
          // Navigate to chapter detail with the chapter ID
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
                  // Chapter title
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
                  // Result title
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
                  // Result description/content
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
                  // Type badge
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

}