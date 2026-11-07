import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

/// Représente une option d'itinéraire routier
class RouteOption {
  final List<LatLng> points;
  final double distanceMeters;
  final double durationSeconds;
  final bool isPrimary;

  const RouteOption({
    required this.points,
    required this.distanceMeters,
    required this.durationSeconds,
    this.isPrimary = false,
  });

  double get distanceKm => distanceMeters / 1000.0;
  int get durationMinutes => (durationSeconds / 60.0).round().clamp(1, 999);
}

/// Résultat complet du calcul de routage
class RoutingResult {
  final RouteOption primaryRoute;
  final List<RouteOption> alternativeRoutes;
  final bool isFromRoadNetwork;

  const RoutingResult({
    required this.primaryRoute,
    this.alternativeRoutes = const [],
    required this.isFromRoadNetwork,
  });
}

class RoutingService {
  static const String _osrmBaseUrl = "https://router.project-osrm.org/route/v1/driving";

  /// Calcule l'itinéraire routier réel et ses alternatives (Dijkstra / Contraction Hierarchies)
  /// entre la position du livreur et la destination client.
  static Future<RoutingResult> calculateRoutes({
    required LatLng origin,
    required LatLng destination,
  }) async {
    // Calcul de repli direct (à vol d'oiseau) en cas de panne réseau
    const distanceCalc = Distance();
    final directDistanceMeters = distanceCalc.as(LengthUnit.Meter, origin, destination);
    final directDurationSeconds = (directDistanceMeters / 6.94); // ~25 km/h en ville

    final fallbackPrimary = RouteOption(
      points: [origin, destination],
      distanceMeters: directDistanceMeters,
      durationSeconds: directDurationSeconds,
      isPrimary: true,
    );

    try {
      final url = Uri.parse(
        "$_osrmBaseUrl/${origin.longitude},${origin.latitude};${destination.longitude},${destination.latitude}"
        "?overview=full&geometries=geojson&alternatives=true",
      );

      final response = await http.get(url).timeout(const Duration(seconds: 4));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data is Map<String, dynamic> && data['code'] == 'Ok') {
          final routesList = data['routes'] as List<dynamic>?;
          if (routesList != null && routesList.isNotEmpty) {
            final List<RouteOption> parsedRoutes = [];

            for (int i = 0; i < routesList.length; i++) {
              final r = routesList[i] as Map<String, dynamic>;
              final distance = (r['distance'] as num?)?.toDouble() ?? directDistanceMeters;
              final duration = (r['duration'] as num?)?.toDouble() ?? directDurationSeconds;

              final geometry = r['geometry'] as Map<String, dynamic>?;
              final coordinates = geometry?['coordinates'] as List<dynamic>?;

              final List<LatLng> polyPoints = [];
              if (coordinates != null) {
                for (final coord in coordinates) {
                  if (coord is List && coord.length >= 2) {
                    final lng = (coord[0] as num).toDouble();
                    final lat = (coord[1] as num).toDouble();
                    polyPoints.add(LatLng(lat, lng));
                  }
                }
              }

              if (polyPoints.isEmpty) {
                polyPoints.addAll([origin, destination]);
              }

              parsedRoutes.add(
                RouteOption(
                  points: polyPoints,
                  distanceMeters: distance,
                  durationSeconds: duration,
                  isPrimary: i == 0,
                ),
              );
            }

            // Trier pour garantir que le plus court ou plus rapide est en tête
            parsedRoutes.sort((a, b) => a.distanceMeters.compareTo(b.distanceMeters));

            final primary = parsedRoutes.first;
            final alternatives = parsedRoutes.skip(1).toList();

            return RoutingResult(
              primaryRoute: RouteOption(
                points: primary.points,
                distanceMeters: primary.distanceMeters,
                durationSeconds: primary.durationSeconds,
                isPrimary: true,
              ),
              alternativeRoutes: alternatives,
              isFromRoadNetwork: true,
            );
          }
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print("[RoutingService] Erreur appel OSRM, basculement repli: $e");
      }
    }

    return RoutingResult(
      primaryRoute: fallbackPrimary,
      alternativeRoutes: const [],
      isFromRoadNetwork: false,
    );
  }

  /// Détecte si le livreur a dévié de l'itinéraire actif de plus de [thresholdMeters] (par défaut 40m)
  static bool hasDriverDeviated({
    required LatLng driverPosition,
    required List<LatLng> currentRoutePoints,
    double thresholdMeters = 40.0,
  }) {
    if (currentRoutePoints.isEmpty) return false;
    const distanceCalc = Distance();

    // Recherche de la distance minimale au point le plus proche du polyline
    double minDistance = double.infinity;
    for (final pt in currentRoutePoints) {
      final d = distanceCalc.as(LengthUnit.Meter, driverPosition, pt);
      if (d < minDistance) {
        minDistance = d;
      }
      if (minDistance <= thresholdMeters) {
        return false; // Encore sur la route
      }
    }

    return minDistance > thresholdMeters;
  }

  /// Ouvre la destination dans l'application Google Maps native (ou Waze/Web) en mode navigation virage par virage
  static Future<bool> openGoogleMapsNavigation({
    required double destLat,
    required double destLng,
    double? originLat,
    double? originLng,
    String? destinationLabel,
  }) async {
    final nativeNavUri = Uri.parse("google.navigation:q=$destLat,$destLng&mode=d");

    final String universalUrl = originLat != null && originLng != null
        ? "https://www.google.com/maps/dir/?api=1&origin=$originLat,$originLng&destination=$destLat,$destLng&travelmode=driving"
        : "https://www.google.com/maps/dir/?api=1&destination=$destLat,$destLng&travelmode=driving";

    final universalUri = Uri.parse(universalUrl);

    // 1. Essai avec le protocole natif Google Maps (Android)
    try {
      final canNative = await canLaunchUrl(nativeNavUri);
      if (canNative) {
        return await launchUrl(nativeNavUri, mode: LaunchMode.externalApplication);
      }
    } catch (_) {
      // Ignorer l'erreur spécifique pigeon/channel et tenter le protocole universel
    }

    // 2. Essai avec l'URI universelle Google Maps (app ou navigateur)
    try {
      final canUniversal = await canLaunchUrl(universalUri);
      if (canUniversal) {
        return await launchUrl(universalUri, mode: LaunchMode.externalApplication);
      }
    } catch (_) {
      // Si canLaunchUrl échoue en raison de restrictions Android, tenter le lancement direct
    }

    // 3. Fallback direct externe sans canLaunchUrl
    try {
      return await launchUrl(universalUri, mode: LaunchMode.externalApplication);
    } catch (e) {
      if (kDebugMode) {
        print("[RoutingService] Erreur lancement Google Maps: $e");
      }
      return false;
    }
  }
}

