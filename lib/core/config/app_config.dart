class AppConfig {
  static const String appName = "JL Green Aquafresh";
  static const String appVersion = "1.0.0";
  
  // =========================================================================
  // 🔘 BASCULEMENT ULTRA-SIMPLE : Mettre à `true` pour PROD, `false` pour LOCAL
  // =========================================================================
  static bool isProduction = false;

  // URLs d'API configurées automatiquement
  static const String _prodUrl  = "https://jlgapi.jlgpowerservicessupplies.com/api/v1";
  static const String _localUrl = "http://10.0.2.2:8085/api/v1"; // Émulateur Android (10.0.2.2:8085) ou http://localhost:8085/api/v1 pour iOS/Web

  static String get activeBaseUrl => isProduction ? _prodUrl : _localUrl;
}
