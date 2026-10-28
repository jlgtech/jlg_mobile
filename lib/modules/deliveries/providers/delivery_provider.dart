import 'dart:async';
import 'package:flutter/material.dart';
import '../models/delivery_model.dart';
import '../services/delivery_service.dart';
import '../../../core/config/app_config.dart';
import '../../../core/network/connectivity_service.dart';
import '../../../core/network/offline_sync_service.dart';
import '../../../core/services/local_notification_service.dart';
import '../../../core/storage/offline_storage.dart';

/// Provider principal des livraisons — compatible mode offline.
///
/// Utilise [OfflineSyncService] pour :
/// - Charger les commandes depuis l'API (online) ou le cache local (offline).
/// - Enregistrer les actions (démarrage, clôture, litige) en offline.
/// - Synchroniser automatiquement dès le retour de la connexion.
class DeliveryProvider extends ChangeNotifier {
  List<DeliveryOrder> _orders = [];
  bool _isLoading = false;
  String? _errorMessage;
  String _activeTab = 'A_LIVRER'; // 'A_LIVRER' | 'LIVREES' | 'LITIGES'

  final OfflineSyncService _syncService = OfflineSyncService();
  final ConnectivityService _connectivity = ConnectivityService();
  final Set<String> _knownOrderIds = {};
  Timer? _pollingTimer;
  DateTime? _lastFetchTime;

  List<DeliveryOrder> get orders => _orders;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  String get activeTab => _activeTab;
  bool get isOffline => _connectivity.isOffline;
  bool get hasPendingSync => _syncService.hasPendingActions;
  bool get isSyncing => _syncService.isSyncing;
  DateTime? get lastSync => _syncService.lastSync;

  DeliveryProvider() {
    // Réagit aux changements de connectivité pour notifier l'UI
    _connectivity.addListener(_onConnectivityChanged);
    _syncService.addListener(_onSyncChanged);
  }

  void _onConnectivityChanged() {
    notifyListeners();
  }

  void _onSyncChanged() {
    // Recharge la liste après une synchronisation réussie
    if (!_syncService.isSyncing && !_syncService.hasPendingActions) {
      fetchOrders();
    } else {
      notifyListeners();
    }
  }

  int get availableOrdersCount => _orders.where((o) => !o.isPickupOrder && o.isUnassigned && o.statut != 'CLOTUREE' && o.statut != 'ANNULEE').length;

  List<DeliveryOrder> get filteredOrders {
    // Les commandes de retrait sur place (le client récupère lui-même) ne doivent JAMAIS apparaître pour les chauffeurs
    final deliveryOrders = _orders.where((o) => !o.isPickupOrder).toList();
    if (_activeTab == 'DISPONIBLES') {
      return deliveryOrders.where((o) => o.isUnassigned && o.statut != 'CLOTUREE' && o.statut != 'ANNULEE').toList();
    } else if (_activeTab == 'LIVREES') {
      return deliveryOrders.where((o) => !o.isUnassigned && (o.statut == 'CLOTUREE' || o.statut == 'LIVREE_EN_ATTENTE')).toList();
    } else if (_activeTab == 'LITIGES') {
      return deliveryOrders.where((o) => o.statut == 'EN_ATTENTE_DE_RELIVRAISON' || o.statut == 'ANNULEE').toList();
    } else {
      // A_LIVRER (Ma tournée de livraisons assignées)
      final list = deliveryOrders.where((o) =>
        !o.isUnassigned &&
        o.statut != 'CLOTUREE' &&
        o.statut != 'EN_ATTENTE_DE_RELIVRAISON' &&
        o.statut != 'ANNULEE'
      ).toList();

      // Trier : La course active (EN_COURS_DE_LIVRAISON) apparait TOUJOURS en première position (haut de liste)
      list.sort((a, b) {
        final aInProgress = a.statut == 'EN_COURS_DE_LIVRAISON';
        final bInProgress = b.statut == 'EN_COURS_DE_LIVRAISON';
        if (aInProgress && !bInProgress) return -1;
        if (!aInProgress && bInProgress) return 1;
        return 0;
      });

      return list;
    }
  }

  void setActiveTab(String tab) {
    _activeTab = tab;
    notifyListeners();
  }

  /// Charge les commandes — API si en ligne, cache local si hors ligne.
  Future<void> fetchOrders({bool silent = false, bool force = false}) async {
    // Évite de déclencher des requêtes doublons si le dernier appel date de moins de 10 secondes
    if (!force && _lastFetchTime != null && DateTime.now().difference(_lastFetchTime!) < const Duration(seconds: 10)) {
      return;
    }
    _lastFetchTime = DateTime.now();

    if (!silent) {
      _isLoading = true;
      _errorMessage = null;
      notifyListeners();
    }

    try {
      final loadedOrders = await _syncService.loadOrders();

      // Détection des nouvelles livraisons assignées en temps réel
      if (_knownOrderIds.isNotEmpty) {
        final newlyAssigned = loadedOrders.where((o) =>
          !_knownOrderIds.contains(o.id) &&
          !o.isPickupOrder &&
          o.statut != 'CLOTUREE' &&
          o.statut != 'ANNULEE'
        ).toList();

        for (final newOrder in newlyAssigned) {
          final client = newOrder.clientNom.isNotEmpty ? newOrder.clientNom : "Client";
          final address = newOrder.adresseLivraison.isNotEmpty ? newOrder.adresseLivraison : "Adresse à confirmer";
          LocalNotificationService.showDeliveryNotification(
            id: newOrder.id.hashCode,
            title: "Nouvelle Livraison Assignée",
            body: "Commande ${newOrder.code} pour $client ($address).",
            payload: newOrder.id,
          );
        }
      }

      _knownOrderIds.addAll(loadedOrders.map((o) => o.id));
      _orders = loadedOrders;

      if (_orders.isEmpty && _connectivity.isOffline) {
        _errorMessage = "Aucune commande en cache. Connectez-vous pour télécharger vos livraisons.";
      }
    } catch (_) {
      if (!silent) {
        _errorMessage = "Erreur lors du chargement des livraisons. Veuillez réessayer.";
      }
    } finally {
      if (!silent) {
        _isLoading = false;
      }
      notifyListeners();
    }
  }

  /// Démarrer la synchronisation périodique des tournées en avant-plan
  void startPolling({Duration interval = const Duration(seconds: 60)}) {
    _pollingTimer?.cancel();
    _pollingTimer = Timer.periodic(interval, (_) {
      if (!_connectivity.isOffline && !_syncService.isSyncing) {
        fetchOrders(silent: true);
      }
    });
    fetchOrders(silent: true);
  }

  /// Mettre en pause le polling périodique (lorsque l'application passe en arrière-plan)
  void pausePolling() {
    _pollingTimer?.cancel();
    _pollingTimer = null;
  }

  /// Reprendre le polling périodique (lorsque l'application revient au premier plan)
  void resumePolling({Duration interval = const Duration(seconds: 60)}) {
    if (_pollingTimer == null) {
      startPolling(interval: interval);
    }
  }

  /// Arrêter le polling
  void stopPolling() {
    _pollingTimer?.cancel();
    _pollingTimer = null;
  }

  /// Télécharge toutes les commandes pour usage offline.
  Future<bool> downloadForOffline() async {
    _isLoading = true;
    notifyListeners();
    final ok = await _syncService.downloadForOffline();
    if (ok) {
      _orders = await _syncService.loadOrders();
    }
    _isLoading = false;
    notifyListeners();
    return ok;
  }

  Future<bool> startDelivery(String orderId) async {
    _errorMessage = null;
    final existing = _orders.where((o) => o.id == orderId).firstOrNull;
    final orderCode = existing?.code ?? "CMD-${orderId.length >= 8 ? orderId.substring(0, 8).toUpperCase() : orderId}";

    // Mise a jour optimiste immediate en memoire pour reactivite sans latence
    final index = _orders.indexWhere((o) => o.id == orderId);
    if (index != -1) {
      _orders[index] = _orders[index].copyWith(statut: 'EN_COURS_DE_LIVRAISON');
      notifyListeners();
    }
    await OfflineStorage.applyLocalStatusUpdate(orderId, 'EN_COURS_DE_LIVRAISON');

    final result = await _syncService.updateOrderStatus(orderId, 'EN_COURS_DE_LIVRAISON');
    if (result.success) {
      _lastFetchTime = null;
      await fetchOrders(silent: true, force: true);
      LocalNotificationService.showDeliveryNotification(
        id: orderId.hashCode,
        title: "Tournée Démarrée",
        body: "Livraison $orderCode : En route vers ${existing?.clientNom ?? 'le client'}.",
      );
      return true;
    }
    // Restaurer l'etat precedent en cas d'erreur
    if (existing != null && index != -1) {
      _orders[index] = existing;
      await OfflineStorage.applyLocalStatusUpdate(orderId, existing.statut);
      notifyListeners();
    }
    _errorMessage = result.errorMessage;
    notifyListeners();
    return false;
  }

  Future<bool> completeDelivery(
    String orderId, {
    double? lat,
    double? lng,
    List<Map<String, dynamic>>? consignes,
  }) async {
    _errorMessage = null;
    final existing = _orders.where((o) => o.id == orderId).firstOrNull;
    final orderCode = existing?.code ?? "CMD-${orderId.length >= 8 ? orderId.substring(0, 8).toUpperCase() : orderId}";

    final double targetLat = lat ?? AppConfig.fallbackLatitude;
    final double targetLng = lng ?? AppConfig.fallbackLongitude;

    // Mise a jour optimiste immediate
    final index = _orders.indexWhere((o) => o.id == orderId);
    if (index != -1) {
      _orders[index] = _orders[index].copyWith(
        statut: 'CLOTUREE',
        estPayee: true,
        latitude: targetLat,
        longitude: targetLng,
      );
      notifyListeners();
    }
    await OfflineStorage.applyLocalStatusUpdate(orderId, 'CLOTUREE');

    final result = await _syncService.updateOrderStatus(
      orderId,
      'CLOTUREE',
      lat: targetLat,
      lng: targetLng,
      consignes: consignes,
    );

    if (result.success) {
      _lastFetchTime = null;
      await fetchOrders(silent: true, force: true);
      LocalNotificationService.showDeliveryNotification(
        id: orderId.hashCode,
        title: "Livraison Clôturée",
        body: "La commande $orderCode a été remise et validée avec succès.",
      );
      return true;
    }
    if (existing != null && index != -1) {
      _orders[index] = existing;
      await OfflineStorage.applyLocalStatusUpdate(orderId, existing.statut);
      notifyListeners();
    }
    _errorMessage = result.errorMessage;
    notifyListeners();
    return false;
  }

  Future<bool> confirmLocation(
    String orderId, {
    required double lat,
    required double lng,
    String? rawAddress,
    String? landmark,
  }) async {
    _errorMessage = null;
    final existing = _orders.where((o) => o.id == orderId).firstOrNull;
    final index = _orders.indexWhere((o) => o.id == orderId);
    if (index != -1) {
      _orders[index] = _orders[index].copyWith(
        latitude: lat,
        longitude: lng,
        confirmationGpsRequise: false,
      );
      notifyListeners();
    }

    final result = await DeliveryService.confirmOrderLocation(
      orderId,
      lat: lat,
      lng: lng,
      rawAddress: rawAddress,
      landmark: landmark,
    );
    if (result.success) {
      _lastFetchTime = null;
      await fetchOrders(silent: true, force: true);
      return true;
    }
    if (existing != null && index != -1) {
      _orders[index] = existing;
      notifyListeners();
    }
    _errorMessage = result.errorMessage;
    notifyListeners();
    return false;
  }

  Future<bool> recordPayment(
    String orderId, {
    required String modePaiement,
    String? notesPaiement,
  }) async {
    _errorMessage = null;

    final existing = _orders.where((o) => o.id == orderId).firstOrNull;
    if (existing != null &&
        existing.statut != 'EN_COURS_DE_LIVRAISON' &&
        existing.statut != 'PARTIELLEMENT_LIVREE') {
      _errorMessage = "Impossible d'encaisser le paiement : la livraison doit d'abord être lancée (statut En cours de livraison).";
      notifyListeners();
      return false;
    }

    final index = _orders.indexWhere((o) => o.id == orderId);
    if (index != -1) {
      _orders[index] = _orders[index].copyWith(
        estPayee: true,
        modePaiement: modePaiement,
      );
      notifyListeners();
    }

    final result = await DeliveryService.recordPayment(
      orderId,
      modePaiement: modePaiement,
      notesPaiement: notesPaiement,
    );
    if (result.success) {
      _lastFetchTime = null;
      await fetchOrders(silent: true, force: true);
      final orderCode = existing?.code ?? "CMD-${orderId.length >= 8 ? orderId.substring(0, 8).toUpperCase() : orderId}";
      LocalNotificationService.showPaymentNotification(
        id: "${orderId}pay".hashCode,
        title: "Encaissement Validé",
        body: "Paiement de ${existing?.montantTotal.toStringAsFixed(2) ?? ''} HTG enregistré pour $orderCode ($modePaiement).",
      );
      return true;
    }
    if (existing != null && index != -1) {
      _orders[index] = existing;
      notifyListeners();
    }
    _errorMessage = result.errorMessage;
    notifyListeners();
    return false;
  }

  Future<bool> submitDispute({
    required String orderId,
    String? articleId,
    int quantiteDefectueuse = 1,
    required String motif,
    String? description,
    bool doitEtreRelivree = true,
    String actionChoisie = 'RELIVRAISON_DEMANDEE',
  }) async {
    _errorMessage = null;
    final existing = _orders.where((o) => o.id == orderId).firstOrNull;
    final orderCode = existing?.code ?? "CMD-${orderId.length >= 8 ? orderId.substring(0, 8).toUpperCase() : orderId}";

    final result = await _syncService.declareDispute(
      orderId: orderId,
      articleId: articleId,
      quantiteDefectueuse: quantiteDefectueuse,
      motif: motif,
      description: description,
      doitEtreRelivree: doitEtreRelivree,
      actionChoisie: actionChoisie,
    );
    if (result.success) {
      _lastFetchTime = null;
      await fetchOrders(silent: true, force: true);
      LocalNotificationService.showAlertNotification(
        id: "${orderId}dispute".hashCode,
        title: "Litige Terrain Enregistré",
        body: "Signalement pour $orderCode : $quantiteDefectueuse unité(s) - $motif.",
      );
      return true;
    }
    _errorMessage = result.errorMessage;
    notifyListeners();
    return false;
  }

  /// Prendre en charge une course disponible de la bourse libre
  Future<({bool success, String? errorMessage})> claimOrder(
    String orderId, {
    required String driverId,
    String? vehicleId,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    try {
      final res = await DeliveryService.claimOrder(
        orderId,
        driverId: driverId,
        vehicleId: vehicleId,
      );
      if (res.success) {
        _lastFetchTime = null;
        await fetchOrders(silent: true, force: true);
        _activeTab = 'A_LIVRER';
      } else {
        _errorMessage = res.errorMessage;
      }
      return res;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Signaler un incident/panne sur la route et libérer la course
  Future<({bool success, String? errorMessage})> reportBreakdown(
    String orderId, {
    String? motif,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    try {
      final res = await DeliveryService.reportBreakdown(
        orderId,
        motif: motif,
      );
      if (res.success) {
        _lastFetchTime = null;
        await fetchOrders(silent: true, force: true);
        _activeTab = 'A_LIVRER';
      } else {
        _errorMessage = res.errorMessage;
      }
      return res;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    _connectivity.removeListener(_onConnectivityChanged);
    _syncService.removeListener(_onSyncChanged);
    super.dispose();
  }
}
