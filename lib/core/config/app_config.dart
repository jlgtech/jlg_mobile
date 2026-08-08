class AppConfig {
  static const String appName = "JL Green Aquafresh";
  static const String appVersion = "1.0.0";
  
  // Base API URLs
  static const String defaultApiUrl = "https://jlgapi.jlgpowerservicessupplies.com/api/v1";
  static const String localApiUrl = "http://10.0.2.2:8000/api/v1"; // Android Emulator
  
  static String activeBaseUrl = defaultApiUrl;
}
