import 'package:flutter/material.dart';
import '../models/delivery_model.dart';
import '../services/delivery_service.dart';

class DeliveryProvider extends ChangeNotifier {
  List<DeliveryOrder> _orders = [];
  bool _isLoading = false;
  String? _errorMessage;
  String _activeTab = 'A_LIVRER'; // 'A_LIVRER' | 'LIVREES' | 'LITIGES'

  List<DeliveryOrder> get orders => _orders;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  String get activeTab => _activeTab;

  List<DeliveryOrder> get filteredOrders {
    if (_activeTab == 'LIVREES') {
      return _orders.where((o) => o.statut == 'CLOTUREE' || o.statut == 'LIVREE_EN_ATTENTE').toList();
    } else if (_activeTab == 'LITIGES') {
      return _orders.where((o) => o.statut == 'EN_ATTENTE_DE_RELIVRAISON' || o.statut == 'ANNULEE').toList();
    } else {
      return _orders.where((o) => o.statut != 'CLOTUREE' && o.statut != 'EN_ATTENTE_DE_RELIVRAISON' && o.statut != 'ANNULEE').toList();
    }
  }

  void setActiveTab(String tab) {
    _activeTab = tab;
    notifyListeners();
  }

  Future<void> fetchOrders() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _orders = await DeliveryService.getAssignedOrders();
    } catch (e) {
      _errorMessage = "Erreur lors du chargement des livraisons ($e).";
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> startDelivery(String orderId) async {
    final success = await DeliveryService.updateOrderStatus(orderId, 'EN_COURS_DE_LIVRAISON');
    if (success) {
      await fetchOrders();
    }
    return success;
  }

  Future<bool> completeDelivery(String orderId, {double? lat, double? lng}) async {
    // Simulated GPS coords for Port-au-Prince if null
    final double targetLat = lat ?? 18.5392;
    final double targetLng = lng ?? -72.3364;

    final success = await DeliveryService.updateOrderStatus(
      orderId,
      'CLOTUREE',
      lat: targetLat,
      lng: targetLng,
    );

    if (success) {
      await fetchOrders();
    }
    return success;
  }

  Future<bool> submitDispute(String orderId, String motif) async {
    final success = await DeliveryService.declareDispute(
      orderId: orderId,
      motif: motif,
      actionCode: 'RELIVRAISON_DEMANDEE',
    );
    if (success) {
      await fetchOrders();
    }
    return success;
  }
}
