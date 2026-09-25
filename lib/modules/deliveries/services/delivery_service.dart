import 'dart:convert';
import '../../../core/network/api_client.dart';
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
    } catch (e) {
      return [];
    }
  }

  /// Update order status (e.g., EN_COURS_DE_LIVRAISON, CLOTUREE)
  static Future<bool> updateOrderStatus(String orderId, String newStatus, {double? lat, double? lng}) async {
    try {
      final body = {
        'statut': newStatus,
        if (lat != null) 'latitude_livraison': lat,
        if (lng != null) 'longitude_livraison': lng,
      };
      final response = await ApiClient.post('/orders/$orderId/status', body);
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  /// Record a field sale (Vente à la Criée) directly from truck stock
  static Future<bool> recordFieldSale({
    required String clientNom,
    required String clientTel,
    required String articleId,
    required int quantite,
    required String modePaiement,
    String? precisionPaiement,
  }) async {
    try {
      final body = {
        'client_passage_nom': clientNom,
        'client_passage_telephone': clientTel,
        'origine_commande': 'VENTE_CRIEE_LIVREUR',
        'mode_paiement': modePaiement,
        'precision_paiement': precisionPaiement,
        'est_payee': true,
        'items': [
          {
            'article_id': articleId,
            'quantite_commandee': quantite,
            'quantite_offerte': 0,
          }
        ]
      };
      final response = await ApiClient.post('/orders/', body);
      return response.statusCode == 201 || response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  /// Declare a delivery dispute or broken goods
  static Future<bool> declareDispute({
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
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }
}
