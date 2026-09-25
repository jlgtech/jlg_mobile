import 'dart:async';
import 'package:flutter/material.dart';
import '../../modules/deliveries/models/delivery_model.dart';
import '../../modules/deliveries/services/delivery_service.dart';
import '../network/connectivity_service.dart';
import '../storage/offline_storage.dart';
import '../utils/error_sanitizer.dart';

/// Résultat d'une action offline/en ligne
class SyncResult {
  final int synced;
  final int failed;
  final List<String> errors;

  SyncResult({required this.synced, required this.failed, required this.errors});
}

/// Service de synchronisation offline/online pour les chauffeurs-livreurs.
///
/// Responsabilités :
/// - Charge les commandes : depuis l'API si en ligne, depuis le cache sinon.
/// - Enregistre les actions offline dans une file d'attente.
/// - Synchronise automatiquement les actions en attente dès le retour de la connectivité.
class OfflineSyncService extends ChangeNotifier {
  static final OfflineSyncService _instance = OfflineSyncService._internal();
  factory OfflineSyncService() => _instance;
  OfflineSyncService._internal();

  bool _isSyncing = false;
  bool _hasPendingActions = false;
  String? _syncError;
  DateTime? _lastSync;

  bool get isSyncing => _isSyncing;
  bool get hasPendingActions => _hasPendingActions;
  String? get syncError => _syncError;
  DateTime? get lastSync => _lastSync;

  final ConnectivityService _connectivity = ConnectivityService();

  /// Initialise le service. À appeler une seule fois au démarrage de l'app.
  Future<void> initialize() async {
    _lastSync = await OfflineStorage.getLastSync();
    _hasPendingActions = (await OfflineStorage.loadPendingActions()).isNotEmpty;

    // Écoute le retour de connectivité via ChangeNotifier
    _connectivity.addListener(_onConnectivityChanged);
  }

  void _onConnectivityChanged() {
    if (_connectivity.isOnline && _hasPendingActions) {
      syncPendingActions();
    }
  }

  // ─── CHARGEMENT DES COMMANDES ────────────────────────────────────────────

  /// Charge les commandes pour le chauffeur.
  /// Si en ligne : récupère depuis l'API et met à jour le cache.
  /// Si hors ligne : retourne les commandes du cache local.
  Future<List<DeliveryOrder>> loadOrders() async {
    if (_connectivity.isOnline) {
      try {
        final orders = await DeliveryService.getAssignedOrders();
        if (orders.isNotEmpty) {
          await OfflineStorage.saveOrders(orders);
          _lastSync = DateTime.now();
          notifyListeners();
        }
        return orders;
      } catch (_) {
        // Échec de l'API, on utilise le cache
      }
    }
    return OfflineStorage.loadOrders();
  }

  // ─── ACTIONS OFFLINE ─────────────────────────────────────────────────────

  /// Tente de mettre à jour le statut d'une commande.
  /// Si hors ligne : enregistre l'action localement et applique le changement au cache.
  /// Si en ligne : appelle directement l'API.
  Future<({bool success, String? errorMessage})> updateOrderStatus(
    String orderId,
    String newStatus, {
    double? lat,
    double? lng,
  }) async {
    if (_connectivity.isOffline) {
      // Application immédiate sur le cache offline (optimistic update)
      await OfflineStorage.applyLocalStatusUpdate(orderId, newStatus);

      final action = PendingAction(
        id: '${orderId}_${newStatus}_${DateTime.now().millisecondsSinceEpoch}',
        orderId: orderId,
        type: 'UPDATE_STATUS',
        payload: {
          'statut': newStatus,
          'latitude_livraison': lat,
          'longitude_livraison': lng,
        }..removeWhere((_, v) => v == null),
        createdAt: DateTime.now(),
      );
      await OfflineStorage.enqueuePendingAction(action);
      _hasPendingActions = true;
      notifyListeners();
      return (success: true, errorMessage: null);
    }

    return DeliveryService.updateOrderStatus(orderId, newStatus, lat: lat, lng: lng);
  }

  /// Tente de déclarer un litige.
  /// Si hors ligne : enregistre l'action dans la file d'attente.
  /// Si en ligne : appelle directement l'API.
  Future<({bool success, String? errorMessage})> declareDispute({
    required String orderId,
    required String motif,
    required String actionCode,
  }) async {
    if (_connectivity.isOffline) {
      await OfflineStorage.applyLocalStatusUpdate(orderId, 'EN_ATTENTE_DE_RELIVRAISON');

      final action = PendingAction(
        id: '${orderId}_LITIGE_${DateTime.now().millisecondsSinceEpoch}',
        orderId: orderId,
        type: 'DECLARE_DISPUTE',
        payload: {
          'motif': motif,
          'actionCode': actionCode,
        },
        createdAt: DateTime.now(),
      );
      await OfflineStorage.enqueuePendingAction(action);
      _hasPendingActions = true;
      notifyListeners();
      return (success: true, errorMessage: null);
    }

    return DeliveryService.declareDispute(
      orderId: orderId,
      motif: motif,
      actionCode: actionCode,
    );
  }

  // ─── SYNCHRONISATION ─────────────────────────────────────────────────────

  /// Synchronise toutes les actions en attente avec l'API.
  /// Appelé automatiquement au retour de la connectivité.
  Future<SyncResult> syncPendingActions() async {
    if (_isSyncing || _connectivity.isOffline) {
      return SyncResult(synced: 0, failed: 0, errors: []);
    }

    _isSyncing = true;
    _syncError = null;
    notifyListeners();

    final actions = await OfflineStorage.loadPendingActions();
    int synced = 0;
    int failed = 0;
    final List<String> errors = [];

    for (final action in actions) {
      try {
        bool ok = false;

        if (action.type == 'UPDATE_STATUS') {
          final result = await DeliveryService.updateOrderStatus(
            action.orderId,
            action.payload['statut'] as String,
            lat: action.payload['latitude_livraison'] != null
                ? (action.payload['latitude_livraison'] as num).toDouble()
                : null,
            lng: action.payload['longitude_livraison'] != null
                ? (action.payload['longitude_livraison'] as num).toDouble()
                : null,
          );
          ok = result.success;
          if (!ok && result.errorMessage != null) {
            errors.add('[${action.orderId}] ${result.errorMessage}');
          }
        } else if (action.type == 'DECLARE_DISPUTE') {
          final result = await DeliveryService.declareDispute(
            orderId: action.orderId,
            motif: action.payload['motif'] as String,
            actionCode: action.payload['actionCode'] as String,
          );
          ok = result.success;
          if (!ok && result.errorMessage != null) {
            errors.add('[${action.orderId}] ${result.errorMessage}');
          }
        }

        if (ok) {
          await OfflineStorage.removePendingAction(action.id);
          synced++;
        } else {
          failed++;
        }
      } catch (e) {
        failed++;
        errors.add(ErrorSanitizer.extractErrorMessage(e));
      }
    }

    final remaining = await OfflineStorage.loadPendingActions();
    _hasPendingActions = remaining.isNotEmpty;

    if (failed == 0 && synced > 0) {
      // Re-télécharge les commandes depuis l'API après une sync réussie
      try {
        final fresh = await DeliveryService.getAssignedOrders();
        if (fresh.isNotEmpty) await OfflineStorage.saveOrders(fresh);
      } catch (_) {}
    }

    if (errors.isNotEmpty) {
      _syncError = "Certaines actions n'ont pas pu être synchronisées.";
    }

    _isSyncing = false;
    _lastSync = DateTime.now();
    notifyListeners();

    return SyncResult(synced: synced, failed: failed, errors: errors);
  }

  /// Force le téléchargement des commandes pour mise en cache offline.
  Future<bool> downloadForOffline() async {
    if (_connectivity.isOffline) return false;
    try {
      final orders = await DeliveryService.getAssignedOrders();
      await OfflineStorage.saveOrders(orders);
      _lastSync = DateTime.now();
      notifyListeners();
      return true;
    } catch (_) {
      return false;
    }
  }

  @override
  void dispose() {
    _connectivity.removeListener(_onConnectivityChanged);
    super.dispose();
  }
}
