import 'package:flutter/material.dart';
import '../widgets/app_bottom_navigation.dart';

class ComingSoonScreen extends StatelessWidget {
  const ComingSoonScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      body: Stack( 
        children: [   
          Positioned.fill(                 // Aqui pongo la imagen de fondo
            child: Image.asset(
              'assets/background_1.png',
              fit: BoxFit.cover,
            ),
          ),

          Positioned.fill(                 // Aqui pongo un velo blanco encima de la imagen
            child: Container(
              color: Colors.white.withOpacity(0.75),
            ),
          ),

          SafeArea(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 25),
                    child: Column(
                      children: [
                        const SizedBox(height: 80),
                        // Logo and Title
                        Column(
                          children: [
                            // ARTS Logo
                            // Option 1: If you have a logo image file (e.g., assets/logo.png)
                            Image.asset(
                              'assets/logoBlue.png',
                              width: 120,
                              // height: 100,
                              errorBuilder: (context, error, stackTrace) {
                                // Fallback to text logo if image not found
                                return Container(
                                  width: 80,
                                  height: 80,
                                  decoration: const BoxDecoration(
                                    color: Color(0xFF123157),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Center(
                                    child: Text(
                                      'A',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 48,
                                        fontWeight: FontWeight.bold,
                                        fontFamily: 'Inter',
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                            const SizedBox(height: 50),
                            
                            // ARTS Text
                            const Text(
                              'Comming soon...',
                              style: TextStyle(
                                color: Color(0xFF123157),
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                fontFamily: 'Inter',
                                letterSpacing: 2,
                              ),
                            ),
                            const SizedBox(height: 4),
                            
                            /* // Subtitle
                            const Text(
                              'Aerospace Risk\nTransfer Solutions',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Color(0xFF123157),
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                                fontFamily: 'Inter',
                                height: 1.4,
                              ),
                            ), */
                          ],
                        ),

                        const SizedBox(height: 40),
                        
                        // Coming Soon Message
                        const Text(
                          'In the future you will be able to notify any type of claim through the app. This will immediately notify all parties involved in your policies to allow for a swift and efficient handling of your claim',
                          textAlign: TextAlign.justify,
                          style: TextStyle(
                            color: Color(0xFF123157),
                            fontSize: 16,
                            fontStyle: FontStyle.italic,
                            fontWeight: FontWeight.w600,
                            fontFamily: 'Inter',
                            height: 1.5,
                          ),
                        ),
                        
                        const SizedBox(height: 70),
                      ],
                    ),
                  ),
                  
                  // Building Image - Sin padding para que cubra todo el ancho
                  Transform.scale(
                    scale: 1.1, // Escala al 150%
                    alignment: Alignment(1.2,1),
                    child: Image.asset(
                      'assets/background_building.png',
                      width: double.infinity,
                      fit: BoxFit.cover,
                    ),
                  )
                ],
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: const AppBottomNavigation(selectedIndex: 2),
    );
  }
}