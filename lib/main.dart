import 'package:flutter/material.dart';
import 'screens/category_screen.dart';
import 'screens/login_screen.dart';
import 'screens/reset_password_screen.dart';
import 'services/auth_service.dart';
import 'package:app_links/app_links.dart';

import 'dart:async';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  runApp(const ARTSClaimsApp());
}

class ARTSClaimsApp extends StatefulWidget {
  const ARTSClaimsApp({super.key});

  @override
  State<ARTSClaimsApp> createState() => _ARTSClaimsAppState();
}

class _ARTSClaimsAppState extends State<ARTSClaimsApp> {
  // GlobalKey para navegación desde cualquier lugar
  final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

  StreamSubscription? _linkSubscription;

  @override
  void initState() {
    super.initState();
    //Solo inicializar deep links si NO es web
    if (!kIsWeb) {
      _initDeepLinks();
    } else {
      debugPrint('🌐 Running on Web - Deep links disabled');
    }
  }

  final _appLinks = AppLinks();

  Future<void> _initDeepLinks() async {
    // Handle deep link when app is opened from closed
    final uri = await _appLinks.getInitialLink();
    if (uri != null) _handleDeepLink(uri);

    // Handle deep links while app is running
    _linkSubscription = _appLinks.uriLinkStream.listen((uri) {
      _handleDeepLink(uri);
    }, onError: (err) {
      debugPrint('❌ Error handling deep link: $err');
    });
  }

  // ✅ Procesar deep link
  void _handleDeepLink(Uri uri) {
    debugPrint('📱 Deep link recibido: $uri');

    // artsclaims://reset-password?token=abc123
    if (uri.host == 'reset-password') {
      final token = uri.queryParameters['token'];

      if (token != null && token.isNotEmpty) {
        debugPrint('✅ Token de reset encontrado: ${token.substring(0, 10)}...');

        // Navegar a ResetPasswordScreen
        navigatorKey.currentState?.push(
          MaterialPageRoute(
            builder: (context) => ResetPasswordScreen(token: token),
          ),
        );
      } else {
        debugPrint('❌ No se encontró token en el deep link');
      }
    }
  }

  @override
  void dispose() {
    _linkSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ARTS Claims',
      navigatorKey: navigatorKey, // ✅ Key para navegación global
      theme: ThemeData(
        primarySwatch: Colors.blue,
        useMaterial3: true,
        fontFamily: 'Inter',
      ),
      home: const SplashScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}

// Splash Screen to check authentication
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  final AuthService _authService = AuthService();

  @override
  void initState() {
    super.initState();
    _checkAuth();
  }

  Future<void> _checkAuth() async {
    await Future.delayed(const Duration(seconds: 1));

    final isLoggedIn = await _authService.isLoggedIn();

    if (!mounted) return;

    if (isLoggedIn) {
      final prefs = await SharedPreferences.getInstance();
      final biometricEnabled = prefs.getBool('biometric_enabled') ?? false;

      // If biometrics enabled, go to LoginScreen — it will auto-prompt biometrics
      // If not, go straight to CategoryScreen
      if (biometricEnabled) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const LoginScreen()),
        );
      } else {
        final userName = await _authService.getUserName();
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => CategoryScreen(userName: userName),
          ),
        );
      }
    } else {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const LoginScreen()),
      );
    }
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
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Image.asset(
                'assets/logoWhite.png',
                width: 160,
                height: 195,
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}
