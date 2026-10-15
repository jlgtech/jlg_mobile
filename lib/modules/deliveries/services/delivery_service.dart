import 'dart:convert';
import '../../../core/network/api_client.dart';
import '../../../core/utils/error_sanitizer.dart';
import '../models/delivery_model.dart';

class DeliveryService {
  /// Fetch all delivery orders assigned to the current driver
  static Future<List<DeliveryOrder>> getAssignedOrders() async {
    try {
      final response = await ApiClient.get('/orders/');
      if (response.statusCode == 200) {
        final List data = jsonDecode(response.body);
        return data.map((item) => DeliveryOrder.fromJson(item)).toList();
      }
      return [];
    } catch (_) {
      return [];
    }
  }

  /// Update order status (e.g., EN_COURS_DE_LIVRAISON, CLOTUREE)
  static Future<({bool success, String? errorMessage})> updateOrderStatus(
    String orderId,
    String newStatus, {
    double? lat,
    double? lng,
  }) async {
    try {
      if (lat != null && lng != null) {
        await confirmOrderLocation(
          orderId,
          lat: lat,
          lng: lng,
          confirmedBy: "livreur",
        );
      }

      final body = {'statut': newStatus};
      final response = await ApiClient.post('/orders/$orderId/status', body);
      if (response.statusCode == 200) {
        return (success: true, errorMessage: null);
      }
      return (
        success: false,
        errorMessage: ErrorSanitizer.parseHttpResponseError(response),
      );
    } catch (e) {
      return (success: false, errorMessage: ErrorSanitizer.extractErrorMessage(e));
    }
  }

  /// Confirm delivery location and persist GPS coordinates in validated_addresses
  static Future<({bool success, String? errorMessage})> confirmOrderLocation(
    String orderId, {
    required double lat,
    required double lng,
    String? rawAddress,
    String? landmark,
    String confirmedBy = "livreur",
  }) async {
    try {
      final body = {
        'lat': lat,
        'lng': lng,
        'confirmed_by': confirmedBy,
        if (rawAddress != null && rawAddress.trim().isNotEmpty) 'raw_address': rawAddress.trim(),
        if (landmark != null && landmark.trim().isNotEmpty) 'landmark': landmark.trim(),
      };
      final response = await ApiClient.post('/orders/$orderId/confirm-location', body);
      if (response.statusCode == 200 || response.statusCode == 201) {
        return (success: true, errorMessage: null);
      }
      return (
        success: false,
        errorMessage: ErrorSanitizer.parseHttpResponseError(response),
      );
    } catch (e) {
      return (success: false, errorMessage: ErrorSanitizer.extractErrorMessage(e));
    }
  }

  /// Record payment upon delivery (e.g. CASH, MONCASH, etc.)
  static Future<({bool success, String? errorMessage})> recordPayment(
    String orderId, {
    required String modePaiement,
    String encaissePar = "LIVREUR",
    String? notesPaiement,
  }) async {
    try {
      final body = {
        'mode_paiement': modePaiement,
        'encaisse_par': encaissePar,
        'notes_paiement': notesPaiement ?? "Paiement encaissé par le livreur lors de la livraison.",
      };
      final response = await ApiClient.post('/orders/$orderId/pay', body);
      if (response.statusCode == 200 || response.statusCode == 201) {
        return (success: true, errorMessage: null);
      }
      return (
        success: false,
        errorMessage: ErrorSanitizer.parseHttpResponseError(response),
      );
    } catch (e) {
      return (success: false, errorMessage: ErrorSanitizer.extractErrorMessage(e));
    }
  }

  /// Declare a delivery dispute or broken goods
  static Future<({bool success, String? errorMessage})> declareDispute({
    required String orderId,
    required String motif,
    required String actionCode,
  }) async {
    try {
      final body = {
        'statut': 'EN_ATTENTE_DE_RELIVRAISON',
      };
      final response = await ApiClient.post('/orders/$orderId/status', body);
      if (response.statusCode == 200) {
        return (success: true, errorMessage: null);
      }
      return (
        success: false,
        errorMessage: ErrorSanitizer.parseHttpResponseError(response),
      );
    } catch (e) {
      return (success: false, errorMessage: ErrorSanitizer.extractErrorMessage(e));
    }
  }
}
