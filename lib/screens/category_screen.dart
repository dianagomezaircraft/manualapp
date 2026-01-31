import 'package:arts_claims_app/screens/coming_soon_features.dart';
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
    // Obtener los datos del usuario
    final userData = await _authService.getUserData();

    if (userData == null) {
      throw Exception('User not authenticated');
    }

    // Obtener el rol del usuario
    final userRole = userData['role'];
    print('User role: $userRole');

    String? airlineId;

    // Si NO es SUPER_ADMIN, necesita tener un airlineId
    if (userRole != 'SUPER_ADMIN') {
      airlineId = userData['airlineId'];
      if (airlineId == null || airlineId.isEmpty) {
        throw Exception('User has no airline assigned');
      }
      print('Loading chapters for airline: $airlineId');
    } else {
      print('Loading all chapters for SUPER_ADMIN');
    }

    // Llamar al servicio
    // Para SUPER_ADMIN: airlineId será null, así que obtendrá todos los capítulos
    // Para otros usuarios: airlineId tendrá valor, así que filtrará por aerolínea
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
      print('Loaded ${chapters.length} chapters');
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

    print('Error loading chapters: $e');

    setState(() {
      errorMessage = e.toString();
      isLoading = false;
    });

    // Solo redirigir al login si el error es de autenticación
    // NO redirigir por falta de airlineId si es SUPER_ADMIN
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
        } else if (chapterData.sections!.isEmpty) {
          // Ir a la pantalla de capítulo (comportamiento normal)
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ComingSoonFeatures(),
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

  // NUEVO: Navegar a la pantalla de búsqueda con el término
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
              // Header Section
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
            'CHAPTER ${chapter.order}',
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
        // CAMBIO: Navegar a búsqueda en lugar de solo cambiar estado
        _navigateToSearch(label);

        // Opcional: Mantener selección visual
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
          onTap: () => _handleChapterTap(chapterId, title, chapterNumber),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                // Contenido del texto (lado derecho)
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Título del capítulo
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
                      // Número de capítulo (sin descripción)
                      Text(
                        description! != 'Coming soon'
                            ? chapterNumber
                            : description,
                        style: TextStyle(
                          fontSize: 13,
                          fontFamily: 'Inter',
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
                // Imagen del capítulo (lado izquierdo)
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
                            child: Icon(
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
                  // Placeholder si no hay imagen
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
