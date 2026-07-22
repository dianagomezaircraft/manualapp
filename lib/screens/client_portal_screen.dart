import 'dart:convert';

import 'package:flutter/foundation.dart' show kDebugMode, kIsWeb;
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../config/api_config.dart';
import '../widgets/app_bottom_navigation.dart';
import '../widgets/sofema_iframe.dart';

/// Client Portal — Sofema credentials gate + dashboard embed (mirrors web portal).
class ClientPortalScreen extends StatefulWidget {
  const ClientPortalScreen({super.key});

  static const String sofemaOrigin = 'https://sofemaaviation.com';

  @override
  State<ClientPortalScreen> createState() => _ClientPortalScreenState();
}

class _ClientPortalScreenState extends State<ClientPortalScreen> {
  static const _navy = Color(0xFF123157);
  static const _gold = Color(0xFFAD8042);
  static const _goldLight = Color(0xFFB8956A);
  static const _goldDark = Color(0xFF8B7355);
  static const _grayBg = Color(0xFFEEEFF0);

  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  bool _checkingProxy = true;
  bool _embedReady = false;
  bool _unlocked = false;
  bool _signingIn = false;
  bool _isLoading = false;
  bool _webViewFailed = false;
  bool _obscurePassword = true;

  String? _proxyOrigin;
  String? _gateError;
  String? _embedHint;
  String? _loadError;
  String? _accessToken;
  String? _refreshToken;

  WebViewController? _webController;

  @override
  void initState() {
    super.initState();
    _bootstrapProxy();
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _bootstrapProxy() async {
    final origin = _resolveProxyOrigin();
    if (origin == null) {
      if (!mounted) return;
      setState(() {
        _proxyOrigin = null;
        _embedReady = false;
        _checkingProxy = false;
        _gateError =
            'Sofema proxy URL is not configured. Set SOFEMA_PROXY or ApiConfig.sofemaProxyProduction.';
      });
      return;
    }

    final ready = await _proxyReady(origin);
    if (!mounted) return;
    setState(() {
      _proxyOrigin = ready ? origin : null;
      _embedReady = ready;
      _checkingProxy = false;
      if (!ready) {
        _gateError =
            'Sofema proxy is offline. Start serve_portal.py (or check your Render service), then try again.';
      }
    });
  }

  String? _resolveProxyOrigin() {
    final configured = ApiConfig.sofemaProxyOrigin.trim().replaceAll(
      RegExp(r'/$'),
      '',
    );
    if (configured.isNotEmpty &&
        !configured.contains('REPLACE_WITH_RENDER_URL')) {
      return configured;
    }

    if (kIsWeb) {
      final host = Uri.base.host;
      if (host == 'localhost' || host == '127.0.0.1') {
        return ApiConfig.sofemaProxyLocal;
      }
    }

    if (kDebugMode) {
      return ApiConfig.sofemaProxyLocal;
    }

    return null;
  }

  Future<bool> _proxyReady(String origin) async {
    try {
      final res = await http
          .get(Uri.parse('$origin/healthz'))
          .timeout(const Duration(seconds: 4));
      return res.statusCode == 200;
    } catch (_) {
      if (kIsWeb) {
        final host = Uri.base.host;
        return host == 'localhost' || host == '127.0.0.1';
      }
      return false;
    }
  }

  Future<void> _handleLogin() async {
    setState(() => _gateError = null);

    final email = _emailController.text.trim();
    final password = _passwordController.text;
    if (email.isEmpty || password.isEmpty) {
      setState(() => _gateError = 'Please enter your email and password.');
      return;
    }

    var ready = _embedReady;
    if (!ready) {
      setState(() => _checkingProxy = true);
      await _bootstrapProxy();
      ready = _embedReady;
      if (!mounted) return;
    }
    if (!ready || _proxyOrigin == null) {
      setState(() {
        _gateError =
            'Sofema proxy is offline. Start serve_portal.py, then try again.';
      });
      return;
    }

    setState(() => _signingIn = true);

    try {
      final auth = await _authenticateSofema(email, password);
      final access = (auth['accessToken'] ??
              auth['access_token'] ??
              auth['token'] ??
              '')
          .toString();
      final refresh =
          (auth['refreshToken'] ?? auth['refresh_token'] ?? '').toString();

      if (access.isEmpty) {
        throw Exception('Sign-in succeeded but no access token was returned.');
      }

      if (!mounted) return;
      setState(() {
        _accessToken = access;
        _refreshToken = refresh;
        _unlocked = true;
        _signingIn = false;
        _isLoading = true;
        _embedHint = 'Embedded via Sofema proxy';
      });

      await _bootSession(access, refresh);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _signingIn = false;
        _gateError = e is Exception
            ? e.toString().replaceFirst('Exception: ', '')
            : 'Could not sign in. Please check your credentials.';
      });
    }
  }

  Future<Map<String, dynamic>> _authenticateSofema(
    String login,
    String password,
  ) async {
    final res = await http
        .post(
          Uri.parse('$_proxyOrigin/__api/api/v1/auth'),
          headers: {
            'Content-Type': 'application/json',
            'Accept': 'application/json',
          },
          body: jsonEncode({'login': login, 'password': password}),
        )
        .timeout(const Duration(seconds: 30));

    Map<String, dynamic>? data;
    try {
      final decoded = jsonDecode(res.body);
      if (decoded is Map<String, dynamic>) data = decoded;
    } catch (_) {
      data = null;
    }

    if (res.statusCode < 200 || res.statusCode >= 300) {
      final msg = data?['message'] ??
          data?['error'] ??
          data?['title'] ??
          'Invalid email or password. Please try again.';
      throw Exception(msg.toString());
    }

    return data ?? <String, dynamic>{};
  }

  Future<void> _bootSession(String accessToken, String refreshToken) async {
    final proxy = _proxyOrigin!;
    final bootUrl = '$proxy/__session_boot';
    final fields = {
      'accessToken': accessToken,
      'refreshToken': refreshToken,
      'next': '/dashboard',
    };

    if (kIsWeb) {
      // Iframe receives the POST via SofemaIFrame.sessionBoot.
      if (mounted) setState(() => _isLoading = false);
      return;
    }

    final body = utf8.encode(
      fields.entries
          .map((e) =>
              '${Uri.encodeQueryComponent(e.key)}=${Uri.encodeQueryComponent(e.value)}')
          .join('&'),
    );

    final controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.white)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (_) {
            if (mounted) {
              setState(() {
                _isLoading = true;
                _loadError = null;
              });
            }
          },
          onPageFinished: (_) {
            if (mounted) setState(() => _isLoading = false);
          },
          onWebResourceError: (error) {
            if (mounted) {
              setState(() {
                _isLoading = false;
                _webViewFailed = true;
                _loadError = error.description;
              });
            }
          },
        ),
      );

    _webController = controller;
    if (mounted) setState(() {});

    await controller.loadRequest(
      Uri.parse(bootUrl),
      method: LoadRequestMethod.post,
      headers: const {'Content-Type': 'application/x-www-form-urlencoded'},
      body: body,
    );
  }

  Future<void> _openDashboardExternal() async {
    final uri = Uri.parse('${ClientPortalScreen.sofemaOrigin}/dashboard');
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  Future<void> _reloadDashboard() async {
    if (_accessToken == null) return;
    setState(() {
      _webViewFailed = false;
      _loadError = null;
      _isLoading = true;
    });
    await _bootSession(_accessToken!, _refreshToken ?? '');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      bottomNavigationBar: const AppBottomNavigation(selectedIndex: 4),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [_goldLight, _goldDark],
          ),
        ),
        child: SafeArea(
          bottom: false,
          child: Column(
            children: [
              _buildIntro(),
              Expanded(
                child: Container(
                  margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.12),
                        blurRadius: 16,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: _unlocked ? _buildWorkspace() : _buildGate(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildIntro() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
      child: Column(
        children: [
          Image.asset(
            'assets/logoWhite.png',
            width: 56,
            height: 68,
            fit: BoxFit.contain,
          ),
          const SizedBox(height: 6),
          const Text(
            'CLIENT PORTAL',
            style: TextStyle(
              color: Colors.white,
              fontSize: 11,
              letterSpacing: 1.6,
              fontWeight: FontWeight.w600,
              fontFamily: 'Inter',
            ),
          ),
          const SizedBox(height: 2),
          const Text.rich(
            TextSpan(
              children: [
                TextSpan(
                  text: 'ARTS Claims App ',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'Inter',
                  ),
                ),
                TextSpan(
                  text: 'Coming Soon',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontStyle: FontStyle.italic,
                    fontWeight: FontWeight.w500,
                    fontFamily: 'Inter',
                  ),
                ),
              ],
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Container(
            width: 48,
            height: 2,
            color: Colors.white.withValues(alpha: 0.55),
          ),
          const SizedBox(height: 8),
          Text(
            'Sign in with your Sofema credentials to access courses and your dashboard. The full claims app — procedures manual and more — is coming soon.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.9),
              fontSize: 12,
              fontFamily: 'Inter',
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGate() {
    if (_checkingProxy) {
      return const Center(child: CircularProgressIndicator(color: _navy));
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 28, 24, 28),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Sofema Aviation',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: _gold,
                    fontSize: 12,
                    letterSpacing: 1.2,
                    fontWeight: FontWeight.w600,
                    fontFamily: 'Inter',
                  ),
                ),
                const SizedBox(height: 10),
                const Text(
                  'Enter your Sofema credentials to access the courses',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: _navy,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'Inter',
                    height: 1.25,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  'Use the login provided for the AI² Safety Summit in Türkiye.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 13,
                    fontFamily: 'Inter',
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 28),
                TextField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  autofillHints: const [AutofillHints.username],
                  enabled: !_signingIn,
                  decoration: InputDecoration(
                    labelText: 'Email',
                    hintText: 'you@company.com',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    filled: true,
                    fillColor: Colors.grey[100],
                  ),
                  onSubmitted: (_) => _handleLogin(),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: _passwordController,
                  obscureText: _obscurePassword,
                  autofillHints: const [AutofillHints.password],
                  enabled: !_signingIn,
                  decoration: InputDecoration(
                    labelText: 'Password',
                    hintText: '••••••••',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    filled: true,
                    fillColor: Colors.grey[100],
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscurePassword
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined,
                        color: _navy,
                      ),
                      onPressed: () => setState(
                        () => _obscurePassword = !_obscurePassword,
                      ),
                    ),
                  ),
                  onSubmitted: (_) => _handleLogin(),
                ),
                if (_gateError != null) ...[
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.red[50],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.red[200]!),
                    ),
                    child: Text(
                      _gateError!,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.red[700],
                        fontSize: 13,
                        fontFamily: 'Inter',
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 22),
                ElevatedButton(
                  onPressed: _signingIn ? null : _handleLogin,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _gold,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    disabledBackgroundColor: Colors.grey[400],
                  ),
                  child: _signingIn
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor:
                                AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              'Login',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                fontFamily: 'Inter',
                              ),
                            ),
                            SizedBox(width: 8),
                            Icon(Icons.arrow_forward, size: 16),
                          ],
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildWorkspace() {
    final wide = MediaQuery.sizeOf(context).width >= 720;
    return wide
        ? Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(width: 240, child: _buildSidebar()),
              Container(width: 1, color: _grayBg),
              Expanded(child: _buildMainPanel()),
            ],
          )
        : Column(
            children: [
              _buildSidebar(horizontal: true),
              const Divider(height: 1),
              Expanded(child: _buildMainPanel()),
            ],
          );
  }

  Widget _buildSidebar({bool horizontal = false}) {
    final dashBtn = _ActionButton(
      title: 'Dashboard',
      active: true,
      onTap: _reloadDashboard,
    );

    if (horizontal) {
      return ColoredBox(
        color: Colors.white,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 10, 16, 6),
              child: Text(
                'ACCESS',
                style: TextStyle(
                  color: _gold,
                  fontSize: 11,
                  letterSpacing: 1.4,
                  fontWeight: FontWeight.w700,
                  fontFamily: 'Inter',
                ),
              ),
            ),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              child: dashBtn,
            ),
          ],
        ),
      );
    }

    return ColoredBox(
      color: Colors.white,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
        children: [
          const Text(
            'ACCESS',
            style: TextStyle(
              color: _gold,
              fontSize: 11,
              letterSpacing: 1.4,
              fontWeight: FontWeight.w700,
              fontFamily: 'Inter',
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'You are signed in. Your Sofema dashboard is open below.',
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: 12,
              fontFamily: 'Inter',
              height: 1.35,
            ),
          ),
          const SizedBox(height: 16),
          dashBtn,
        ],
      ),
    );
  }

  Widget _buildMainPanel() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 8, 8),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Dashboard',
                      style: TextStyle(
                        color: _navy,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'Inter',
                      ),
                    ),
                    const SizedBox(height: 2),
                    // Text(
                    //   _embedHint ?? 'Sofema Aviation',
                    //   style: TextStyle(
                    //     color: Colors.grey[600],
                    //     fontSize: 12,
                    //     fontFamily: 'Inter',
                    //   ),
                    // ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(child: _buildEmbed()),
      ],
    );
  }

  Widget _buildEmbed() {
    if (!_embedReady || _proxyOrigin == null) {
      return _buildLaunchFallback(
        'The login proxy is unavailable. Open Sofema directly to view your dashboard.',
      );
    }

    if (_webViewFailed) {
      return _buildLaunchFallback(
        _loadError ??
            'Could not load Sofema inside the app. Open it in your browser instead.',
        showRetry: true,
      );
    }

    if (kIsWeb) {
      return SofemaIFrame(
        key: ValueKey('boot-$_accessToken'),
        title: 'Sofema dashboard',
        sessionBootUrl: '$_proxyOrigin/__session_boot',
        sessionBoot: {
          'accessToken': _accessToken ?? '',
          'refreshToken': _refreshToken ?? '',
          'next': '/dashboard',
        },
      );
    }

    return Stack(
      children: [
        if (_webController != null)
          WebViewWidget(controller: _webController!),
        if (_isLoading)
          const Center(child: CircularProgressIndicator(color: _navy)),
      ],
    );
  }

  Widget _buildLaunchFallback(String message, {bool showRetry = false}) {
    return Padding(
      padding: const EdgeInsets.all(28),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.school_outlined, size: 48, color: _gold),
          const SizedBox(height: 16),
          const Text(
            'Sofema Aviation',
            style: TextStyle(
              color: _gold,
              fontSize: 12,
              letterSpacing: 1.2,
              fontWeight: FontWeight.w600,
              fontFamily: 'Inter',
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Dashboard',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: _navy,
              fontSize: 22,
              fontWeight: FontWeight.bold,
              fontFamily: 'Inter',
            ),
          ),
          const SizedBox(height: 12),
          Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: 14,
              fontFamily: 'Inter',
              height: 1.4,
            ),
          ),
          const SizedBox(height: 28),
          ElevatedButton(
            onPressed: _openDashboardExternal,
            style: ElevatedButton.styleFrom(
              backgroundColor: _gold,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: const Text(
              'Open on Sofema',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                fontFamily: 'Inter',
              ),
            ),
          ),
          if (showRetry) ...[
            const SizedBox(height: 12),
            TextButton(
              onPressed: _reloadDashboard,
              child: const Text(
                'Retry embed',
                style: TextStyle(color: _navy, fontFamily: 'Inter'),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final String title;
  final bool active;
  final VoidCallback onTap;

  const _ActionButton({
    required this.title,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: active ? const Color(0xFF123157) : Colors.white,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: active
                  ? const Color(0xFF123157)
                  : const Color(0xFF123157).withValues(alpha: 0.2),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                title,
                style: TextStyle(
                  color: active ? Colors.white : const Color(0xFF123157),
                  fontSize: 13,
                  height: 1.25,
                  fontWeight: FontWeight.w600,
                  fontFamily: 'Inter',
                ),
              ),
              const SizedBox(width: 8),
              const Icon(
                Icons.arrow_forward,
                size: 14,
                color: Color(0xFFAD8042),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
