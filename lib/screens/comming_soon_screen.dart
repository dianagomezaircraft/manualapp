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
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 25),
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
                  const SizedBox(height: 30),

                  // const Spacer(flex: 0,5),

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

                  const Spacer(flex: 2),
                ],
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: const AppBottomNavigation(selectedIndex: 4),
    );
  }
}