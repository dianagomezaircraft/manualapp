class ApiConfig {
  // Cambia esto según el entorno
  static const bool isProduction = true; // Cambiar a true para producción
  
  // URLs de backend
  static const String productionUrl = 'https://admin-webapp-backend.onrender.com/api';
  static const String developmentUrl = 'http://localhost:3001/api';
  
  // URL base que se usará
  static String get baseUrl => isProduction ? productionUrl : developmentUrl;
}