import 'package:flutter/material.dart';
import '../widgets/app_bottom_navigation.dart';

class ComingSoonFeatures extends StatelessWidget {
  const ComingSoonFeatures({super.key});

  @override
  Widget build(BuildContext context) {
    // Obtener el ancho de la pantalla
    final screenWidth = MediaQuery.of(context).size.width;
    // Usar el MISMO padding que ComingSoonScreen - solo 25 en todos los dispositivos
    final horizontalPadding = 25.0;
    
    return Scaffold(
      extendBodyBehindAppBar: true,
      body: Stack(
        children: [
          // Background image
          Positioned.fill(
            child: Image.asset(
              'assets/background_1.png',
              fit: BoxFit.cover,
            ),
          ),

          // White overlay
          Positioned.fill(
            child: Container(
              color: Colors.white.withOpacity(0.75),
            ),
          ),

          // Building image at the bottom (behind content)
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Image.asset(
              'assets/background_building.png',
              fit: BoxFit.contain,
              alignment: Alignment.bottomCenter,
            ),
          ),

          // Content on top - Centrado con ancho máximo
          Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: screenWidth > 600 ? 600 : screenWidth, // Ancho máximo en tablets
              ),
              child: SafeArea(
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
                  child: Column(
                    children: [
                      const SizedBox(height: 60),
                      
                      // Logo
                      Image.asset(
                        'assets/logoBlue.png',
                        width: 120,
                        errorBuilder: (context, error, stackTrace) {
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
                      
                      const SizedBox(height: 30),

                      // Message
                      const Text(
                        'We are working on new features to better protect you',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Color(0xFF123157),
                          fontSize: 16,
                          fontStyle: FontStyle.italic,
                          fontWeight: FontWeight.w600,
                          fontFamily: 'Inter',
                          height: 1.5,
                        ),
                      ),
                      
                      const SizedBox(height: 30),

                      // Coming soon text
                      const Text(
                        'Coming soon...',
                        style: TextStyle(
                          color: Color(0xFF123157),
                          fontSize: 16,
                          fontStyle: FontStyle.italic,
                          fontWeight: FontWeight.w600,
                          fontFamily: 'Inter',
                          letterSpacing: 2,
                        ),
                      ),
                      
                      const Spacer(flex: 2),
                    ],
                  ),
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