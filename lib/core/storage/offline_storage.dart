import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../../modules/deliveries/models/delivery_model.dart';

/// Représente une action offline en attente de synchronisation avec l'API.
class PendingAction {
  final String id; // UUID unique de l'action locale
  final String orderId;
  final String type; // 'UPDATE_STATUS' | 'DECLARE_DISPUTE'
  final Map<String, dynamic> payload;
  final DateTime createdAt;

  PendingAction({
    required this.id,
    required this.orderId,
    required this.type,
    required this.payload,
    required this.createdAt,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'orderId': orderId,
        'type': type,
        'payload': payload,
        'createdAt': createdAt.toIso8601String(),
      };

  factory PendingAction.fromJson(Map<String, dynamic> json) => PendingAction(
        id: json['id'] as String,
        orderId: json['orderId'] as String,
        type: json['type'] as String,
        payload: Map<String, dynamic>.from(json['payload'] as Map),
        createdAt: DateTime.parse(json['createdAt'] as String),
      );
}

/// Stockage local des commandes et des actions en attente pour le mode offline.
class OfflineStorage {
  static const String _keyOrders = 'offline_delivery_orders';
  static const String _keyPendingActions = 'offline_pending_actions';
  static const String _keyLastSync = 'offline_last_sync';

  // ─── COMMANDES ────────────────────────────────────────────────────────────

  /// Sauvegarde la liste des commandes affiliées au chauffeur en cache local.
  static Future<void> saveOrders(List<DeliveryOrder> orders) async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = orders.map((o) => jsonEncode(o.toJson())).toList();
    await prefs.setStringList(_keyOrders, encoded);
    await prefs.setString(_keyLastSync, DateTime.now().toIso8601String());
  }

  /// Récupère les commandes depuis le cache local (mode offline).
  static Future<List<DeliveryOrder>> loadOrders() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_keyOrders) ?? [];
    return raw.map((s) => DeliveryOrder.fromJson(jsonDecode(s) as Map<String, dynamic>)).toList();
  }

  /// Retourne la date/heure de la dernière synchronisation avec l'API.
  static Future<DateTime?> getLastSync() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_keyLastSync);
    return raw != null ? DateTime.tryParse(raw) : null;
  }

  /// Efface le cache des commandes.
  static Future<void> clearOrders() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyOrders);
    await prefs.remove(_keyLastSync);
  }

  // ─── ACTIONS EN ATTENTE ───────────────────────────────────────────────────

  /// Ajoute une action offline dans la file d'attente de synchronisation.
  static Future<void> enqueuePendingAction(PendingAction action) async {
    final prefs = await SharedPreferences.getInstance();
    final existing = await loadPendingActions();
    existing.add(action);
    await _savePendingActions(prefs, existing);
  }

  /// Charge toutes les actions en attente.
  static Future<List<PendingAction>> loadPendingActions() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_keyPendingActions) ?? [];
    return raw.map((s) => PendingAction.fromJson(jsonDecode(s) as Map<String, dynamic>)).toList();
  }

  /// Supprime une action par son id (après synchronisation réussie).
  static Future<void> removePendingAction(String actionId) async {
    final prefs = await SharedPreferences.getInstance();
    final existing = await loadPendingActions();
    existing.removeWhere((a) => a.id == actionId);
    await _savePendingActions(prefs, existing);
  }

  /// Vide toutes les actions en attente (après une synchronisation complète).
  static Future<void> clearPendingActions() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyPendingActions);
  }

  static Future<void> _savePendingActions(SharedPreferences prefs, List<PendingAction> actions) async {
    final encoded = actions.map((a) => jsonEncode(a.toJson())).toList();
    await prefs.setStringList(_keyPendingActions, encoded);
  }

  // ─── UTILITAIRES ─────────────────────────────────────────────────────────

  /// Retourne true si le cache local contient des commandes.
  static Future<bool> hasCachedOrders() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_keyOrders) ?? [];
    return raw.isNotEmpty;
  }

  /// Applique une mise à jour de statut directement sur le cache local.
  static Future<void> applyLocalStatusUpdate(String orderId, String newStatus) async {
    final orders = await loadOrders();
    final updated = orders.map((o) {
      if (o.id == orderId) {
        return DeliveryOrder(
          id: o.id,
          code: o.code,
          clientNom: o.clientNom,
          clientTel: o.clientTel,
          clientEmail: o.clientEmail,
          adresseLivraison: o.adresseLivraison,
          modePaiement: o.modePaiement,
          precisionPaiement: o.precisionPaiement,
          montantTotal: o.montantTotal,
          statut: newStatus,
          dateCreation: o.dateCreation,
          items: o.items,
          latitude: o.latitude,
          longitude: o.longitude,
        );
      }
      return o;
    }).toList();
    await saveOrders(updated);
  }
}
