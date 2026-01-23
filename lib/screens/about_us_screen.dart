import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../widgets/app_bottom_navigation.dart';

class AboutUsScreen extends StatelessWidget {
  const AboutUsScreen({super.key});

  Future<void> _openWebsite() async {
    final uri = Uri.parse('https://arts-global.com/');
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFFB8956A),
              Color(0xFF8B7355),
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // HEADER
              Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: const [
                    Text(
                      'About Us',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'Inter',
                      ),
                    ),
                    SizedBox(height: 12),
                    Text(
                      'Risk Management is an ART',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontFamily: 'Inter',
                      ),
                    ),
                  ],
                ),
              ),

              // CONTENT
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(30),
                      topRight: Radius.circular(30),
                    ),
                  ),
                  child: ListView(
                    children: [
                      _section('Inspired', '''
We believe that Risk Management is an ART not just a science, creativity is at the core of everything we do.

True innovation has to have a commercial benefit & this has been proven by our track record in delivering group buying structures and power by the hour insurance for regional operators.
'''),
                      _section('Immersive', '''
Traditional Insurance Broking is just a fraction of what we can offer.

Our aim is to fully integrate into your business and become your de-facto risk manager.
'''),
                      _section('Initiative', '''
We have built a reputation for developing specific initiatives for our clients to suit their niche business needs.

We are agile and can provide solutions in difficult jurisdictions and areas of conflict.
'''),
                      const SizedBox(height: 24),
                      ElevatedButton(
                        onPressed: _openWebsite,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFAD8042),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        child: const Text(
                          'Visit ARTS Website',
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: const AppBottomNavigation(selectedIndex: 2),
    );
  }

  static Widget _section(String title, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontFamily: 'Inter',
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Color(0xFF123157),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            text.trim(),
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 14,
              height: 1.6,
              color: Colors.grey[700],
            ),
          ),
        ],
      ),
    );
  }
}
