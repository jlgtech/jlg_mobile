import 'package:flutter/material.dart';
import '../models/delivery_model.dart';
import '../../../core/config/app_config.dart';
import '../../../core/network/connectivity_service.dart';
import '../../../core/network/offline_sync_service.dart';

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

  List<DeliveryOrder> get filteredOrders {
    if (_activeTab == 'LIVREES') {
      return _orders.where((o) => o.statut == 'CLOTUREE' || o.statut == 'LIVREE_EN_ATTENTE').toList();
    } else if (_activeTab == 'LITIGES') {
      return _orders.where((o) => o.statut == 'EN_ATTENTE_DE_RELIVRAISON' || o.statut == 'ANNULEE').toList();
    } else {
      return _orders.where((o) =>
        o.statut != 'CLOTUREE' &&
        o.statut != 'EN_ATTENTE_DE_RELIVRAISON' &&
        o.statut != 'ANNULEE'
      ).toList();
    }
  }

  void setActiveTab(String tab) {
    _activeTab = tab;
    notifyListeners();
  }

  /// Charge les commandes — API si en ligne, cache local si hors ligne.
  Future<void> fetchOrders() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _orders = await _syncService.loadOrders();
      if (_orders.isEmpty && _connectivity.isOffline) {
        _errorMessage = "Aucune commande en cache. Connectez-vous pour télécharger vos livraisons.";
      }
    } catch (_) {
      _errorMessage = "Erreur lors du chargement des livraisons. Veuillez réessayer.";
    } finally {
      _isLoading = false;
      notifyListeners();
    }
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
    final result = await _syncService.updateOrderStatus(orderId, 'EN_COURS_DE_LIVRAISON');
    if (result.success) {
      await fetchOrders();
      return true;
    }
    _errorMessage = result.errorMessage;
    notifyListeners();
    return false;
  }

  Future<bool> completeDelivery(String orderId, {double? lat, double? lng}) async {
    _errorMessage = null;
    final double targetLat = lat ?? AppConfig.fallbackLatitude;
    final double targetLng = lng ?? AppConfig.fallbackLongitude;

    final result = await _syncService.updateOrderStatus(
      orderId,
      'CLOTUREE',
      lat: targetLat,
      lng: targetLng,
    );

    if (result.success) {
      await fetchOrders();
      return true;
    }
    _errorMessage = result.errorMessage;
    notifyListeners();
    return false;
  }

  Future<bool> submitDispute(String orderId, String motif) async {
    _errorMessage = null;
    final result = await _syncService.declareDispute(
      orderId: orderId,
      motif: motif,
      actionCode: 'RELIVRAISON_DEMANDEE',
    );
    if (result.success) {
      await fetchOrders();
      return true;
    }
    _errorMessage = result.errorMessage;
    notifyListeners();
    return false;
  }

  @override
  void dispose() {
    _connectivity.removeListener(_onConnectivityChanged);
    _syncService.removeListener(_onSyncChanged);
    super.dispose();
  }
}
