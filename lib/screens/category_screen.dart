import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../services/chapters_service.dart';
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

    try {
      // Obtener los datos del usuario para extraer el airlineId
      final userData = await _authService.getUserData();

      if (userData == null) {
        throw Exception('User not authenticated');
      }

      // Obtener el airlineId del usuario
      final airlineId = userData['airlineId'];
      if (airlineId == null) {
        throw Exception('User has no airline assigned');
      }

      // Llamar al servicio solo con el airlineId
      // El servicio maneja el token internamente
      final result = await _chaptersService.getChapters(
        airlineId: airlineId,
      );

      if (!mounted) return;

      if (result['success'] == true) {
        final chaptersData = result['data'] as List<dynamic>;
        setState(() {
          chapters = chaptersData.map((json) => Chapter.fromJson(json)).toList()
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
    } catch (e) {
      if (!mounted) return;

      setState(() {
        errorMessage = e.toString();
        isLoading = false;
      });

      // Si hay error de autenticación, redirigir al login
      if (e.toString().contains('not authenticated') ||
          e.toString().contains('no airline assigned')) {
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
      String chapterId, String title, String chapterNumber) async {
    // Mostrar un indicador de carga
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
      // Obtener los detalles del capítulo
      final result = await _chaptersService.getChapterById(chapterId);

      if (!mounted) return;

      // Cerrar el indicador de carga
      Navigator.pop(context);

      if (result['success'] == true) {
        final chapterData = Chapter.fromJson(result['data']);

        // Verificar si sections no es nulo y tiene solo 1 sección
        if (chapterData.sections != null &&
            chapterData.sections!.isNotEmpty &&
            chapterData.sections!.length == 1) {
          // Ir directamente al detalle de la sección
          final section = chapterData.sections!.first;
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => SectionDetailScreen(
                sectionId: section.id,
                title: section.title,
                subtitle: section.subtitle,
                chapterTitle: chapterData.title,
              ),
            ),
          );
        } else {
          // Ir a la pantalla de capítulo (comportamiento normal)
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
        // Manejar error
        if (result['needsLogin'] == true) {
          _handleLogout();
        } else {
          // Mostrar mensaje de error
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

      // Cerrar el indicador de carga si sigue abierto
      Navigator.pop(context);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          image: DecorationImage(
            image: const AssetImage('assets/background_1.png'),
            alignment: Alignment.topCenter,
            fit: BoxFit.cover,
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Header Section
              const SizedBox(height: 30),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 20.0),
                child: Column(
                  children: [
                    // Greeting
                    Align(
                      alignment: Alignment.centerLeft,
                      child:Text(
                      'Hi ${widget.userName}!',
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
                        padding: const EdgeInsets.symmetric(horizontal: 8.0), // Ajusta el valor de padding
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween, // Esto separa los elementos
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
            'CHAPTER ${chapter.order}',
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
                color: isSelected ? Color(0xFFAD8042) : Colors.grey,
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
    String subtitle,
    String chapterNumber,
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
          onTap: () => _handleChapterTap(chapterId, title, chapterNumber),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'Inter',
                          color: Colors.black87,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    chapterNumber,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      fontFamily: 'Inter',
                      color: Colors.black87,
                    ),
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
