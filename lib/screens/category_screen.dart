import 'package:arts_claims_app/screens/coming_soon_features.dart';
import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../services/chapters_service.dart';
import '../services/airline_service.dart';
import '../models/airline.dart';
import '../widgets/app_bottom_navigation.dart';

// Import the screens
import 'search_screen.dart';
import 'chapter_detail_screen.dart';
import 'contact_details_screen.dart';
import 'login_screen.dart';
import 'section_detail_screen.dart';

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
  final AirlineService _airlineService = AirlineService();

  List<Chapter> chapters = [];
  List<Airline> airlines = [];
  bool isLoading = true;
  bool isLoadingAirlines = false;
  String? errorMessage;
  String userName = 'User';
  bool isSuperAdmin = false;
  String? selectedAirlineId; // For dropdown filter
  String? userAirlineId; // User's assigned airline

  @override
  void initState() {
    super.initState();
    _loadUserName();
    _initializeScreen();
  }

  Future<void> _initializeScreen() async {
    await _checkUserRole();
    if (isSuperAdmin) {
      await _loadAirlines();
    }
    await _loadChapters();
  }

  // Check if user is SUPER_ADMIN
  Future<void> _checkUserRole() async {
    final userData = await _authService.getUserData();
    if (userData != null) {
      setState(() {
        isSuperAdmin = userData['role'] == 'SUPER_ADMIN';
        if (!isSuperAdmin) {
          userAirlineId = userData['airlineId'];
        }
      });
    }
  }

  // Load airlines for dropdown (only for SUPER_ADMIN)
  Future<void> _loadAirlines() async {
    setState(() {
      isLoadingAirlines = true;
    });

    try {
      final token = await _authService.getAccessToken();
      
      if (token == null) {
        throw Exception('No access token available');
      }

      final airlinesData = await _airlineService.getAllAirlines(token: token);
      
      if (mounted) {
        setState(() {
          airlines = airlinesData;
          isLoadingAirlines = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          isLoadingAirlines = false;
        });
      }
      print('Error loading airlines: $e');
    }
  }

  // Load user name
  Future<void> _loadUserName() async {
    final name = await _authService.getUserName();
    if (mounted) {
      setState(() {
        userName = name;
      });
    }
  }

  Future<void> _loadChapters() async {
    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    try {
      final userData = await _authService.getUserData();

      if (userData == null) {
        throw Exception('User not authenticated');
      }

      final userRole = userData['role'];
      print('User role: $userRole');

      String? airlineId;

      if (userRole == 'SUPER_ADMIN') {
        // Use selected airline from dropdown, or null to show all
        airlineId = selectedAirlineId;
        // print('Loading chapters for SUPER_ADMIN${airlineId != null ? " - Airline: $airlineId" : " - All airlines"}');
      } else {
        // Regular users use their assigned airline
        airlineId = userData['airlineId'];
        if (airlineId == null || airlineId.isEmpty) {
          throw Exception('User has no airline assigned');
        }
        // print('Loading chapters for airline: $airlineId');
      }

      final result = await _chaptersService.getChapters(
        airlineId: airlineId,
      );

      if (!mounted) return;

      if (result['success'] == true) {
        final chaptersData = result['data'] as List<dynamic>;
        setState(() {
          chapters = chaptersData.map((json) => Chapter.fromJson(json)).toList()
            ..sort((a, b) => a.order.compareTo(b.order));
          isLoading = false;
        });
        // print('Loaded ${chapters.length} chapters');
      } else {
        setState(() {
          errorMessage = result['error'] ?? 'Failed to load chapters';
          isLoading = false;
        });

        if (result['needsLogin'] == true) {
          _handleLogout();
        }
      }
    } catch (e) {
      if (!mounted) return;

      print('Error loading chapters: $e');

      setState(() {
        errorMessage = e.toString();
        isLoading = false;
      });

      if (e.toString().contains('not authenticated')) {
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

  Future<void> _handleChapterTap(
      String chapterId, String title, String? description, String chapterNumber) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CircularProgressIndicator(
          color: Color(0xFF123157),
        ),
      ),
    );

    try {
      final result = await _chaptersService.getChapterById(chapterId);

      if (!mounted) return;

      Navigator.pop(context);

      if (result['success'] == true) {
        final chapterData = Chapter.fromJson(result['data']);

        if (chapterData.sections != null &&
            chapterData.sections!.isNotEmpty &&
            chapterData.sections!.length == 1) {
          final section = chapterData.sections!.first;
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => SectionDetailScreen(
                sectionId: section.id,
                title: section.title,
                description: section.description,
                chapterTitle: chapterData.title,
              ),
            ),
          );
        } else if (chapterData.sections!.isEmpty) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const ComingSoonFeatures(),
            ),
          );
        } else {
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
        }
      } else {
        if (result['needsLogin'] == true) {
          _handleLogout();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(result['error'] ?? 'Error loading chapter'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (!mounted) return;

      Navigator.pop(context);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _navigateToSearch(String searchTerm) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => SearchScreen(
          initialSearchTerm: searchTerm,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          image: DecorationImage(
            image: AssetImage('assets/background_1.png'),
            alignment: Alignment.topCenter,
            fit: BoxFit.cover,
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              const SizedBox(height: 30),
              Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: 20.0, vertical: 20.0),
                child: Column(
                  children: [
                    // Greeting
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Hi $userName!',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'Inter',
                        ),
                      ),
                    ),

                    const SizedBox(height: 12),

                    // Description
                    const Text(
                      'Access the loss prevention measures and the key steps and contacts you would need in the event of a  loss.',
                      textAlign: TextAlign.left,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontFamily: 'Inter',
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Airline Filter Dropdown (only for SUPER_ADMIN)
                    if (isSuperAdmin && !isLoadingAirlines)
                      Container(
                        margin: const EdgeInsets.only(bottom: 16),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.1),
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            isExpanded: true,
                            value: selectedAirlineId,
                            hint: const Row(
                              children: [
                                Icon(
                                  Icons.filter_list,
                                  size: 18,
                                  color: Color(0xFF123157),
                                ),
                                SizedBox(width: 8),
                                Text(
                                  'All Airlines',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontFamily: 'Inter',
                                    color: Color(0xFF123157),
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                            icon: const Icon(
                              Icons.arrow_drop_down,
                              color: Color(0xFF123157),
                            ),
                            style: const TextStyle(
                              fontSize: 14,
                              fontFamily: 'Inter',
                              color: Color(0xFF123157),
                            ),
                            items: [
                              const DropdownMenuItem<String>(
                                value: null,
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.flight,
                                      size: 18,
                                      color: Color(0xFF123157),
                                    ),
                                    SizedBox(width: 8),
                                    Text(
                                      'All Airlines',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w600,
                                        color: Color(0xFF123157),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              ...airlines.map((airline) {
                                return DropdownMenuItem<String>(
                                  value: airline.id,
                                  child: Row(
                                    children: [
                                      const Icon(
                                        Icons.flight,
                                        size: 18,
                                        color: Color(0xFF123157),
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          '${airline.name} (${airline.code})',
                                          style: const TextStyle(
                                            color: Color(0xFF123157),
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              }).toList(),
                            ],
                            onChanged: (String? newValue) {
                              setState(() {
                                selectedAirlineId = newValue;
                              });
                              _loadChapters();
                            },
                          ),
                        ),
                      ),

                    // Loading airlines indicator
                    if (isSuperAdmin && isLoadingAirlines)
                      Container(
                        margin: const EdgeInsets.only(bottom: 16),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Color(0xFF123157),
                              ),
                            ),
                            SizedBox(width: 12),
                            Text(
                              'Loading airlines...',
                              style: TextStyle(
                                fontSize: 14,
                                fontFamily: 'Inter',
                                color: Color(0xFF123157),
                              ),
                            ),
                          ],
                        ),
                      ),

                    // Star Rating Section
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 15,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8.0),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            _buildStarRating(1, 'Incident'),
                            _buildStarRating(1, 'Major Loss'),
                            _buildStarRating(1, 'Injuries'),
                            _buildStarRating(1, 'Liability'),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Categories List Section
              Expanded(
                child: Container(
                  decoration: const BoxDecoration(
                    color: Color(0xFFeeeff0),
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(20),
                      topRight: Radius.circular(20),
                    ),
                  ),
                  child: Column(
                    children: [
                      const SizedBox(height: 29),
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
      bottomNavigationBar: const AppBottomNavigation(selectedIndex: 0),
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
                isSuperAdmin && selectedAirlineId != null
                    ? 'No chapters available for selected airline'
                    : 'No chapters available',
                textAlign: TextAlign.center,
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
            'CHAPTER ${chapter.order - 1}',
            chapter.description,
            chapter.imageUrl,
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
        _navigateToSearch(label);
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
                color: isSelected ? const Color(0xFFAD8042) : Colors.grey,
                size: 30,
              );
            }),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              color: Colors.grey,
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
    String chapterNumber,
    String? description,
    String? imageUrl,
    String chapterId,
    int index,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.grey.shade300,
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.5),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => _handleChapterTap(chapterId, title, description, chapterNumber),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                // Text content
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'Inter',
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        description != null && description != 'Coming soon'
                            ? chapterNumber
                            : description ?? chapterNumber,
                        style: TextStyle(
                          fontSize: 13,
                          fontFamily: 'Inter',
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
                // Chapter image
                if (imageUrl != null && imageUrl.isNotEmpty)
                  Container(
                    width: 80,
                    height: 80,
                    margin: const EdgeInsets.only(right: 16),
                    decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        color: Colors.transparent),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.network(
                        imageUrl,
                        fit: BoxFit.cover,
                        loadingBuilder: (context, child, loadingProgress) {
                          if (loadingProgress == null) return child;
                          return Center(
                            child: CircularProgressIndicator(
                              value: loadingProgress.expectedTotalBytes != null
                                  ? loadingProgress.cumulativeBytesLoaded /
                                      loadingProgress.expectedTotalBytes!
                                  : null,
                              strokeWidth: 2,
                              color: const Color(0xFF123157),
                            ),
                          );
                        },
                        errorBuilder: (context, error, stackTrace) {
                          return Container(
                            color: Colors.grey[300],
                            child: const Icon(
                              Icons.image_not_supported,
                              color: Colors.transparent,
                              size: 32,
                            ),
                          );
                        },
                      ),
                    ),
                  )
                else
                  Container(
                    width: 80,
                    height: 80,
                    margin: const EdgeInsets.only(right: 16),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      color: Colors.grey[200],
                    ),
                    child: Icon(
                      Icons.book,
                      color: Colors.grey[400],
                      size: 40,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}