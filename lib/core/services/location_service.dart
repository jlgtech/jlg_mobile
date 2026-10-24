import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import '../config/app_config.dart';
import '../network/api_client.dart';

class ReverseGeocodeInfo {
  final String commune;
  final String codePostal;
  final String? quartier;
  final String adresseFormatee;
  final bool estZoneReconnue;
  final String source;

  ReverseGeocodeInfo({
    required this.commune,
    required this.codePostal,
    this.quartier,
    required this.adresseFormatee,
    required this.estZoneReconnue,
    required this.source,
  });

  factory ReverseGeocodeInfo.fromJson(Map<String, dynamic> json) {
    return ReverseGeocodeInfo(
      commune: json['commune'] as String? ?? 'Zone Métropolitaine',
      codePostal: json['code_postal'] as String? ?? 'HT6110',
      quartier: json['quartier'] as String?,
      adresseFormatee: json['adresse_formatee'] as String? ?? '',
      estZoneReconnue: json['est_zone_reconnue'] as bool? ?? false,
      source: json['source'] as String? ?? 'local',
    );
  }
}

class LocationResult {
  final LatLng position;
  final bool isFromGps;
  final double? accuracyMeters;
  final ReverseGeocodeInfo? reverseInfo;
  final String? errorMessage;

  LocationResult({
    required this.position,
    required this.isFromGps,
    this.accuracyMeters,
    this.reverseInfo,
    this.errorMessage,
  });
}

class LocationService {
  /// Limites géographiques strictes de la République d'Haïti
  static bool isWithinHaitiBounds(double lat, double lng) {
    return lat >= 18.0 && lat <= 20.2 && lng >= -74.6 && lng <= -71.5;
  }

  /// Cartographie locale de secours des codes postaux haitiens
  static ReverseGeocodeInfo fallbackHaitiDetection(double lat, double lng) {
    String commune = "Zone Métropolitaine";
    String codePostal = "HT1110";

    // Petion-Ville (HT6110)
    if (lat >= 18.4750 && lat <= 18.5450 && lng >= -72.3150 && lng <= -72.2350) {
      commune = "Pétion-Ville";
      codePostal = "HT6110";
    }
    // Delmas (HT6120)
    else if (lat >= 18.5280 && lat <= 18.5850 && lng >= -72.3250 && lng <= -72.2500) {
      commune = "Delmas";
      codePostal = "HT6120";
    }
    // Port-au-Prince (HT1110)
    else if (lat >= 18.5050 && lat <= 18.5680 && lng >= -72.3750 && lng <= -72.3050) {
      commune = "Port-au-Prince";
      codePostal = "HT1110";
    }
    // Tabarre (HT6141)
    else if (lat >= 18.5550 && lat <= 18.6150 && lng >= -72.2950 && lng <= -72.2200) {
      commune = "Tabarre";
      codePostal = "HT6141";
    }
    // Carrefour (HT6130)
    else if (lat >= 18.5000 && lat <= 18.5550 && lng >= -72.4300 && lng <= -72.3600) {
      commune = "Carrefour";
      codePostal = "HT6130";
    }
    // Kenscoff (HT6120)
    else if (lat >= 18.4100 && lat <= 18.4800 && lng >= -72.3100 && lng <= -72.2400) {
      commune = "Kenscoff";
      codePostal = "HT6120";
    }

    return ReverseGeocodeInfo(
      commune: commune,
      codePostal: codePostal,
      quartier: null,
      adresseFormatee: "$commune, $codePostal, Haïti",
      estZoneReconnue: true,
      source: "local_boundary",
    );
  }

  /// Resolution d'adresse inversee certifiee via le backend FastAPI
  static Future<ReverseGeocodeInfo> reverseGeocode(double lat, double lng) async {
    try {
      final res = await ApiClient.get('/reverse-geocode?lat=$lat&lng=$lng');
      if (res.statusCode == 200) {
        final data = jsonDecode(utf8.decode(res.bodyBytes));
        if (data is Map<String, dynamic>) {
          return ReverseGeocodeInfo.fromJson(data);
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print("[LocationService] Echec reverse geocoding API, repli local: $e");
      }
    }
    return fallbackHaitiDetection(lat, lng);
  }

  /// Geocodage d'une adresse textuelle vers des coordonnees reelles via l'API (/geocode)
  static Future<LatLng?> geocodeAddress(String rawAddress) async {
    final query = rawAddress.trim();
    if (query.isEmpty) return null;

    try {
      final res = await ApiClient.post(
        '/geocode',
        {'raw_address': query},
      );
      if (res.statusCode == 200) {
        final data = jsonDecode(utf8.decode(res.bodyBytes));
        if (data is Map<String, dynamic> && data['lat'] != null && data['lng'] != null) {
          final lat = (data['lat'] as num).toDouble();
          final lng = (data['lng'] as num).toDouble();
          if (isWithinHaitiBounds(lat, lng)) {
            return LatLng(lat, lng);
          }
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print("[LocationService] Echec geocodage de l'adresse: $e");
      }
    }
    return null;
  }

  /// Obtient la position GPS reelle du smartphone avec resolution d'adresse et code postal.
  static Future<LocationResult> getCurrentDeviceLocation() async {
    try {
      final bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        return LocationResult(
          position: LatLng(AppConfig.fallbackLatitude, AppConfig.fallbackLongitude),
          isFromGps: false,
          errorMessage: "Le service GPS est désactivé sur cet appareil. Veuillez l'activer pour localiser le client.",
        );
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          return LocationResult(
            position: LatLng(AppConfig.fallbackLatitude, AppConfig.fallbackLongitude),
            isFromGps: false,
            errorMessage: "L'autorisation d'accès à la localisation a été refusée.",
          );
        }
      }

      if (permission == LocationPermission.deniedForever) {
        return LocationResult(
          position: LatLng(AppConfig.fallbackLatitude, AppConfig.fallbackLongitude),
          isFromGps: false,
          errorMessage: "Les autorisations de localisation sont définitivement refusées. Activez-les dans les paramètres.",
        );
      }

      final Position pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.best,
          timeLimit: Duration(seconds: 12),
        ),
      );

      // Verifier que les coordonnees sont bien situees en Haiti
      if (!isWithinHaitiBounds(pos.latitude, pos.longitude)) {
        return LocationResult(
          position: LatLng(AppConfig.fallbackLatitude, AppConfig.fallbackLongitude),
          isFromGps: false,
          errorMessage: "Position GPS détectée en dehors d'Haïti (${pos.latitude.toStringAsFixed(4)}, ${pos.longitude.toStringAsFixed(4)}). Veuillez ajuster manuellement sur la carte.",
        );
      }

      final reverseInfo = await reverseGeocode(pos.latitude, pos.longitude);

      return LocationResult(
        position: LatLng(pos.latitude, pos.longitude),
        isFromGps: true,
        accuracyMeters: pos.accuracy,
        reverseInfo: reverseInfo,
      );
    } catch (e) {
      if (kDebugMode) {
        print("Erreur acquisition position GPS: $e");
      }
      return LocationResult(
        position: LatLng(AppConfig.fallbackLatitude, AppConfig.fallbackLongitude),
        isFromGps: false,
        errorMessage: "Impossible d'acquérir le signal GPS immédiat. Vérifiez votre visibilité satellite.",
      );
    }
  }
}
