import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:jlg_mobile/core/services/routing_service.dart';

void main() {
  group('RoutingService Unit Tests', () {
    test('calculateRoutes returns fallback when network fails or with valid points', () async {
      final origin = LatLng(18.5392, -72.3364);
      final dest = LatLng(18.5420, -72.3150);

      final result = await RoutingService.calculateRoutes(origin: origin, destination: dest);

      expect(result.primaryRoute.points.isNotEmpty, isTrue);
      expect(result.primaryRoute.distanceMeters, greaterThan(0));
      expect(result.primaryRoute.durationSeconds, greaterThan(0));
      expect(result.primaryRoute.isPrimary, isTrue);
    });

    test('hasDriverDeviated correctly identifies when driver is on-route vs off-route', () {
      final routePoints = [
        LatLng(18.5300, -72.3300),
        LatLng(18.5350, -72.3300),
        LatLng(18.5400, -72.3300),
      ];

      // Point très proche du tracé (< 10 mètres) -> Ne doit pas être considéré comme dévié
      final onRoutePos = LatLng(18.53505, -72.33005);
      final isDeviatedClose = RoutingService.hasDriverDeviated(
        driverPosition: onRoutePos,
        currentRoutePoints: routePoints,
        thresholdMeters: 40.0,
      );
      expect(isDeviatedClose, isFalse);

      // Point distant (> 500 mètres) -> Doit être considéré comme dévié
      final farPos = LatLng(18.5500, -72.3200);
      final isDeviatedFar = RoutingService.hasDriverDeviated(
        driverPosition: farPos,
        currentRoutePoints: routePoints,
        thresholdMeters: 40.0,
      );
      expect(isDeviatedFar, isTrue);
    });

    test('RouteOption formats distance and duration correctly', () {
      final route = RouteOption(
        points: [LatLng(18.5, -72.3), LatLng(18.6, -72.4)],
        distanceMeters: 3500,
        durationSeconds: 480, // 8 minutes
        isPrimary: true,
      );

      expect(route.distanceKm, 3.5);
      expect(route.durationMinutes, 8);
    });
  });
}

