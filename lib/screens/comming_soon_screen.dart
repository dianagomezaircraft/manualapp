import 'package:flutter/material.dart';
import '../widgets/app_bottom_navigation.dart';

class ComingSoonScreen extends StatelessWidget {
  const ComingSoonScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0),
                  child: Column(
                    children: [
                      const SizedBox(height: 40),
                      
                      // Logo and Title
                      Column(
                        children: [
                          // ARTS Logo
                          // Option 1: If you have a logo image file (e.g., assets/logo.png)
                          Image.asset(
                            'assets/logoBlue.png',
                            width: 100,
                            height: 100,
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
                          const SizedBox(height: 16),
                          
                          // ARTS Text
                          const Text(
                            'ARTS',
                            style: TextStyle(
                              color: Color(0xFF123157),
                              fontSize: 32,
                              fontWeight: FontWeight.bold,
                              fontFamily: 'Inter',
                              letterSpacing: 2,
                            ),
                          ),
                          const SizedBox(height: 4),
                          
                          // Subtitle
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
                          ),
                        ],
                      ),
                      
                      const SizedBox(height: 40),
                      
                      // Coming Soon Message
                      const Text(
                        'We are working on new\nfeatures to better protect you\ncoming soon.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Color(0xFF123157),
                          fontSize: 16,
                          fontStyle: FontStyle.italic,
                          fontFamily: 'Inter',
                          height: 1.5,
                        ),
                      ),
                      
                      const SizedBox(height: 60),
                      
                      // Building Image
                      Image.asset(
                        'assets/background-building.png',
                        width: double.infinity,
                        fit: BoxFit.contain,
                      ),
                      
                      const SizedBox(height: 20),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: const AppBottomNavigation(selectedIndex: 2),
    );
  }
}