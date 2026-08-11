class AppConfig {
  static const String appName = "JL Green Aquafresh";
  static const String appVersion = "1.0.0";
  
  // =========================================================================
  // 🔘 BASCULEMENT ULTRA-SIMPLE : Mettre à `true` pour PROD, `false` pour LOCAL
  // =========================================================================
  static bool isProduction = true;

  // URLs d'API configurées automatiquement
  static const String _prodUrl  = "https://jlgapi.jlgpowerservicessupplies.com/api/v1";
  static const String _localUrl = "http://10.0.2.2:8000/api/v1"; // Émulateur Android local

  static String get activeBaseUrl => isProduction ? _prodUrl : _localUrl;
}
