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

          // Content on top
          SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                // Detectar si es landscape (horizontal)
                final isLandscape = constraints.maxHeight < 500;
                
                // Ajustar espacios según orientación
                final topSpace = isLandscape ? 20.0 : 60.0;
                final logoToText = isLandscape ? 15.0 : 30.0;
                final textSpacing = isLandscape ? 15.0 : 30.0;
                
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 25),
                  child: Column(
                    children: [
                      SizedBox(height: topSpace),

                      // Logo
                      Image.asset(
                        'assets/logoBlue.png',
                        width: isLandscape ? 80 : 120, // Logo más pequeño en landscape
                        errorBuilder: (context, error, stackTrace) {
                          return Container(
                            width: isLandscape ? 60 : 80,
                            height: isLandscape ? 60 : 80,
                            decoration: const BoxDecoration(
                              color: Color(0xFF123157),
                              shape: BoxShape.circle,
                            ),
                            child: Center(
                              child: Text(
                                'A',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: isLandscape ? 36 : 48,
                                  fontWeight: FontWeight.bold,
                                  fontFamily: 'Inter',
                                ),
                              ),
                            ),
                          );
                        },
                      ),

                      SizedBox(height: logoToText),

                      // Coming soon text
                      const Text(
                        'Coming soon.',
                        style: TextStyle(
                          color: Color(0xFF123157),
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          fontStyle: FontStyle.italic,
                          fontFamily: 'Inter',
                          letterSpacing: 2,
                        ),
                      ),
                      
                      SizedBox(height: textSpacing),

                      // Coming Soon Message
                      Flexible(
                        child: Text(
                          'In the future you will be able to notify any type of claim through the app. This will immediately notify all parties involved in your policies to allow for a swift and efficient handling of your claim',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: const Color(0xFF123157),
                            fontSize: isLandscape ? 14 : 16, // Texto más pequeño en landscape
                            fontStyle: FontStyle.italic,
                            fontWeight: FontWeight.w600,
                            fontFamily: 'Inter',
                            height: 1.5,
                          ),
                        ),
                      ),

                      const Spacer(flex: 2),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
      bottomNavigationBar: const AppBottomNavigation(selectedIndex: 4),
    );
  }
}