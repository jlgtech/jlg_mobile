class AppConfig {
  static const String appName = "JL Green Aquafresh";
  static const String appVersion = "1.0.0";

  // =========================================================================
  // BASCULEMENT ULTRA-SIMPLE : Mettre a `true` pour PROD, `false` pour LOCAL
  // =========================================================================
  static bool isProduction = true;

  // URLs d'API configurées automatiquement
  static const String _prodUrl  = "https://jlgapi.jlgpowerservicessupplies.com/api/v1";
  static const String _localUrl = "http://10.0.2.2:8085/api/v1"; // Emulateur Android ou http://localhost:8085/api/v1 pour iOS/Web

  static String get activeBaseUrl => isProduction ? _prodUrl : _localUrl;

  // =========================================================================
  // Coordonnées géographiques du centre opérationnel (Port-au-Prince, Haïti)
  // Utilisées UNIQUEMENT comme coordonnées de repli si :
  //   - La commande n'a pas encore de position GPS enregistrée
  //   - La géolocalisation de l'appareil est indisponible
  // Ces valeurs ne remplacent JAMAIS les coordonnées réelles de l'API ou du GPS.
  // =========================================================================
  static const double fallbackLatitude  = 18.5392;
  static const double fallbackLongitude = -72.3364;

  // =========================================================================
  // Tarif de remplissage par défaut (HTG)
  // Utilisé UNIQUEMENT si l'API /station/tarif est indisponible au démarrage.
  // La valeur officielle est toujours lue depuis l'API.
  // =========================================================================
  static const double fallbackTarifRemplissageHtg = 0.0;
}
