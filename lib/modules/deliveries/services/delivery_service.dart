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
      final body = {
        'statut': newStatus,
        'latitude_livraison': lat,
        'longitude_livraison': lng,
      }..removeWhere((_, v) => v == null);
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

  /// Declare a delivery dispute or broken goods
  static Future<({bool success, String? errorMessage})> declareDispute({
    required String orderId,
    required String motif,
    required String actionCode,
  }) async {
    try {
      final body = {
        'statut': 'EN_ATTENTE_DE_RELIVRAISON',
        'notes_paiement': 'LITIGE TERRAIN: $motif (Action: $actionCode)',
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
