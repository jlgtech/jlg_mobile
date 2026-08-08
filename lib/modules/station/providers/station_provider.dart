import 'dart:convert';
import 'package:flutter/material.dart';
import '../../../core/network/api_client.dart';
import '../models/station_models.dart';

class StationProvider extends ChangeNotifier {
  List<TransactionStationModel> _transactions = [];
  bool _isLoading = false;
  String? _errorMessage;

  List<TransactionStationModel> get transactions => _transactions;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  List<TransactionStationModel> get pendingTransactions =>
      _transactions.where((t) => t.statut == 'EN_ATTENTE' || t.statut == 'EN_COURS').toList();

  Future<List<CamionStationModel>> searchMatchingTrucks(String query) async {
    final cleanQuery = query.toUpperCase().trim();
    if (cleanQuery.isEmpty) return [];

    final List<CamionStationModel> matches = [];
    final Set<String> seenIds = {};

    for (var tx in _transactions) {
      final truck = tx.camion;
      if (truck != null && !seenIds.contains(truck.id)) {
        final plaque = truck.plaqueImmatriculation.toUpperCase();
        final nom = (truck.nomProprietaire ?? '').toUpperCase();
        if (plaque.contains(cleanQuery) || nom.contains(cleanQuery)) {
          seenIds.add(truck.id);
          matches.add(truck);
        }
      }
    }

    try {
      final response = await ApiClient.get('/station/trucks/search?plaque=$cleanQuery');
      if (response.statusCode == 200 && response.body.isNotEmpty && response.body != "null") {
        final Map<String, dynamic> data = jsonDecode(response.body);
        final truck = CamionStationModel.fromJson(data);
        if (!seenIds.contains(truck.id)) {
          matches.insert(0, truck);
        }
      }
    } catch (_) {}

    return matches;
  }

  Future<CamionStationModel?> searchTruck(String plaque) async {
    final cleanPlaque = plaque.toUpperCase().trim();
    if (cleanPlaque.isEmpty) return null;

    try {
      final response = await ApiClient.get('/station/trucks/search?plaque=$cleanPlaque');
      if (response.statusCode == 200 && response.body.isNotEmpty && response.body != "null") {
        final Map<String, dynamic> data = jsonDecode(response.body);
        return CamionStationModel.fromJson(data);
      }
    } catch (_) {}

    for (var tx in _transactions) {
      if (tx.camion?.plaqueImmatriculation.toUpperCase() == cleanPlaque) {
        return tx.camion;
      }
    }
    return null;
  }

  Future<void> fetchQueue() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final response = await ApiClient.get('/station/transactions');
      debugPrint('FETCH QUEUE STATUS: ${response.statusCode}');
      debugPrint('FETCH QUEUE BODY: ${response.body}');

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        _transactions = data.map((item) => TransactionStationModel.fromJson(item)).toList();
        debugPrint('PARSED TRANSACTIONS COUNT: ${_transactions.length}');
      } else {
        _errorMessage = "Erreur serveur: HTTP ${response.statusCode}";
      }
    } catch (e) {
      _errorMessage = "Erreur réseau: $e";
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> createTicket({
    required String plaqueImmatriculation,
    required double montantHtg,
    required String modePaiement,
    String? nomProprietaire,
    String? telephone,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    final cleanPlaque = plaqueImmatriculation.toUpperCase().trim();

    // 1. Double-entry validation check: Is truck already in active queue?
    final activeTx = _transactions.where((t) =>
      t.camion?.plaqueImmatriculation.toUpperCase() == cleanPlaque &&
      (t.statut == 'EN_ATTENTE' || t.statut == 'EN_COURS')
    ).toList();

    if (activeTx.isNotEmpty) {
      _errorMessage = "Le camion $cleanPlaque est déjà enregistré dans la file d'attente (Ticket #${activeTx.first.codeTicket}) ! Un camion ne peut pas avoir plusieurs remplissages simultanés.";
      _isLoading = false;
      notifyListeners();
      return false;
    }

    try {
      // 2. Register/fetch truck
      final truckResp = await ApiClient.post('/station/trucks', {
        'plaque_immatriculation': cleanPlaque,
        'nom_proprietaire': nomProprietaire?.trim(),
        'telephone': telephone?.trim(),
      });

      if (truckResp.statusCode != 200 && truckResp.statusCode != 201) {
        final err = jsonDecode(truckResp.body);
        _errorMessage = err['detail'] ?? "Impossible d'enregistrer le camion.";
        _isLoading = false;
        notifyListeners();
        return false;
      }

      final truckData = jsonDecode(truckResp.body);
      final camionId = truckData['id'];

      // 3. Create station filling transaction
      final txResp = await ApiClient.post('/station/transactions', {
        'camion_id': camionId,
        'montant_htg': montantHtg,
      });

      if (txResp.statusCode == 200 || txResp.statusCode == 201) {
        await fetchQueue();
        return true;
      } else {
        final err = jsonDecode(txResp.body);
        _errorMessage = err['detail'] ?? "Erreur lors de la création du ticket.";
        _isLoading = false;
        notifyListeners();
        return false;
      }
    } catch (e) {
      _errorMessage = "Erreur d'enregistrement: $e";
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> updateStatus(String transactionId, String nouveauStatut) async {
    try {
      String path = '/station/transactions/$transactionId/start';
      if (nouveauStatut == 'TERMINEE') {
        path = '/station/transactions/$transactionId/complete';
      } else if (nouveauStatut == 'ANNULEE') {
        path = '/station/transactions/$transactionId/cancel';
      }

      final response = await ApiClient.post(path, {});
      if (response.statusCode == 200) {
        await fetchQueue();
        return true;
      }
      return false;
    } catch (e) {
      return false;
    }
  }
}
