class ApiConfig {
  // Cambia esto según el entorno
  static const bool isProduction = true; // Cambiar a true para producción

  /// Shared Render host (claims API + Sofema reverse proxy).
  static const String productionHost =
      'https://admin-webapp-backend.onrender.com';

  // URLs de backend
  static const String productionUrl = '$productionHost/api';
  static const String developmentUrl = 'http://localhost:3001/api';

  // URL base que se usará
  static String get baseUrl => isProduction ? productionUrl : developmentUrl;

  /// Sofema reverse proxy on the same Render service as the claims API.
  /// Paths (from backend root JSON):
  ///   health      → /healthz
  ///   api         → /__api
  ///   authBridge  → /__auth_bridge
  ///   sessionBoot → /__session_boot
  ///
  /// Override: `--dart-define=SOFEMA_PROXY=https://....onrender.com`
  static const String sofemaProxyProduction = String.fromEnvironment(
    'SOFEMA_PROXY',
    defaultValue: productionHost,
  );

  static const String sofemaProxyLocal = 'http://localhost:8081';

  /// Prefer the Render proxy whenever it is configured.
  static String get sofemaProxyOrigin {
    final configured =
        sofemaProxyProduction.trim().replaceAll(RegExp(r'/$'), '');
    if (configured.isNotEmpty &&
        !configured.contains('REPLACE_WITH_RENDER_URL') &&
        !configured.contains('localhost')) {
      return configured;
    }
    return sofemaProxyLocal;
  }
}
