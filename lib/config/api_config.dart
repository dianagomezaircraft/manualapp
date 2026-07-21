class ApiConfig {
  // Cambia esto según el entorno
  static const bool isProduction = true; // Cambiar a true para producción

  // URLs de backend
  static const String productionUrl =
      'https://admin-webapp-backend.onrender.com/api';
  static const String developmentUrl = 'http://localhost:3001/api';

  // URL base que se usará
  static String get baseUrl => isProduction ? productionUrl : developmentUrl;

  /// Sofema reverse proxy (Render) — same URL as the web Client Portal proxy.
  ///
  /// Replace with your Render service URL, e.g.
  /// `https://arts-sofema-proxy.onrender.com`
  ///
  /// Or pass at build time:
  /// `flutter build web --dart-define=SOFEMA_PROXY=https://....onrender.com`
  static const String sofemaProxyProduction = String.fromEnvironment(
    'SOFEMA_PROXY',
    defaultValue: 'https://REPLACE_WITH_RENDER_URL.onrender.com',
  );

  static const String sofemaProxyLocal = 'http://localhost:8081';

  /// Configured production proxy if set; otherwise local default.
  static String get sofemaProxyOrigin {
    final configured =
        sofemaProxyProduction.trim().replaceAll(RegExp(r'/$'), '');
    if (configured.isNotEmpty &&
        !configured.contains('REPLACE_WITH_RENDER_URL')) {
      return configured;
    }
    return sofemaProxyLocal;
  }
}
