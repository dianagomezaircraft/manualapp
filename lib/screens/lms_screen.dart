import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';
import 'package:webview_flutter_wkwebview/webview_flutter_wkwebview.dart';

import '../services/lms_service.dart';
import '../widgets/app_bottom_navigation.dart';
import '../widgets/moodle_iframe.dart';
import 'login_screen.dart';

class LmsScreen extends StatefulWidget {
  const LmsScreen({super.key});

  @override
  State<LmsScreen> createState() => _LmsScreenState();
}

class _LmsScreenState extends State<LmsScreen> {
  static const _navy = Color(0xFF123157);

  final LmsService _lmsService = LmsService();

  var _opening = false;
  bool _isLoading = true;
  String? _errorMessage;
  String? _loginUrl;
  WebViewController? _controller;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _openMoodle();
    });
  }

  Future<void> _openMoodle() async {
    if (_opening) return;
    _opening = true;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _loginUrl = null;
      _controller = null;
    });

    try {
      final result = await _lmsService.getLoginUrl();
      if (!mounted) return;

      if (result['needsLogin'] == true) {
        _redirectToLogin();
        return;
      }

      if (result['success'] != true) {
        setState(() {
          _errorMessage = result['error'] ??
              'Could not connect to the courses platform.';
          _isLoading = false;
        });
        return;
      }

      final loginUrl = result['loginUrl'] as String;
      await _embedLoginUrlOnce(loginUrl);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Could not open Moodle.\n$e';
        _isLoading = false;
      });
    } finally {
      _opening = false;
    }
  }

  Future<void> _embedLoginUrlOnce(String loginUrl) async {
    if (kIsWeb) {
      if (!mounted) return;
      setState(() {
        _loginUrl = loginUrl;
        _isLoading = false;
      });
      return;
    }

    late final PlatformWebViewControllerCreationParams params;
    if (WebViewPlatform.instance is WebKitWebViewPlatform) {
      params = WebKitWebViewControllerCreationParams(
        allowsInlineMediaPlayback: true,
      );
    } else {
      params = const PlatformWebViewControllerCreationParams();
    }

    final controller = WebViewController.fromPlatformCreationParams(params)
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.white)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageFinished: (_) {
            if (mounted) setState(() => _isLoading = false);
          },
          onWebResourceError: (error) {
            if (!mounted) return;
            if (error.isForMainFrame == false) return;
            setState(() {
              _errorMessage =
                  'Could not load the courses platform. Please try again.';
              _isLoading = false;
            });
          },
        ),
      );

    if (controller.platform is AndroidWebViewController) {
      final android = controller.platform as AndroidWebViewController;
      final cookies = WebViewCookieManager();
      if (cookies.platform is AndroidWebViewCookieManager) {
        await (cookies.platform as AndroidWebViewCookieManager)
            .setAcceptThirdPartyCookies(android, true);
      }
    }

    await controller.loadRequest(Uri.parse(loginUrl));
    if (!mounted) return;

    setState(() {
      _loginUrl = loginUrl;
      _controller = controller;
      _isLoading = false;
    });
  }

  void _redirectToLogin() {
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (route) => false,
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
              _buildHeader(),
              Expanded(
                child: Container(
                  decoration: const BoxDecoration(
                    color: Color(0xFFeeeff0),
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(20),
                      topRight: Radius.circular(20),
                    ),
                  ),
                  clipBehavior: Clip.none,
                  child: _buildBody(),
                ),
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: const AppBottomNavigation(selectedIndex: -1),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 20, 12),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () => Navigator.pop(context),
          ),
          const SizedBox(width: 4),
          const Expanded(
            child: Text(
              'Moodle',
              style: TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.bold,
                fontFamily: 'Inter',
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_errorMessage != null) return _buildErrorState();
    if (_loginUrl == null) return _buildLoadingState();

    return Stack(
      children: [
        Positioned.fill(child: _buildEmbed()),
        if (_isLoading)
          const Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: IgnorePointer(
              child: LinearProgressIndicator(
                color: _navy,
                backgroundColor: Color(0xFFeeeff0),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildEmbed() {
    if (kIsWeb) {
      return MoodleIFrame(
        key: ValueKey(_loginUrl),
        url: _loginUrl!,
        title: 'Moodle',
        onBlocked: () {
          if (!mounted) return;
          setState(() {
            _errorMessage =
                'Moodle blocked this embed (CSP). Enable Allow frame embedding in Moodle: Site administration → Security → HTTP security. Then tap Retry.';
            _loginUrl = null;
            _isLoading = false;
          });
        },
      );
    }

    if (_controller == null) return const SizedBox.expand();
    return WebViewWidget(controller: _controller!);
  }

  Widget _buildLoadingState() {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircularProgressIndicator(color: _navy),
          SizedBox(height: 16),
          Text(
            'Opening Moodle...',
            style: TextStyle(
              color: _navy,
              fontSize: 16,
              fontWeight: FontWeight.w600,
              fontFamily: 'Inter',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            const Text(
              'Moodle unavailable',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: _navy,
                fontSize: 18,
                fontWeight: FontWeight.bold,
                fontFamily: 'Inter',
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _errorMessage ??
                  'Could not connect to the courses platform.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[600],
                fontFamily: 'Inter',
                height: 1.4,
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _openMoodle,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
              style: ElevatedButton.styleFrom(
                backgroundColor: _navy,
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
