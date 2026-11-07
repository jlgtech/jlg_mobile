import 'dart:async';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart' hide Path;
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/config/app_config.dart';
import '../../../core/services/location_service.dart';
import '../../../core/services/routing_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/error_sanitizer.dart';
import '../../auth/providers/auth_provider.dart';
import '../models/delivery_model.dart';
import '../providers/delivery_provider.dart';
import '../services/delivery_service.dart';
import '../widgets/address_map_modal.dart';
import '../widgets/dispute_dialog.dart';

/// Vue d'intervention pour Chauffeur / Livreur
/// Architecture moderne : Carte Plein Écran + Bottom Sheet Coulissant
/// Intègre un Stepper Séquentiel Guidé par étapes et une Barre d'Action Persistante (Sticky CTA)
/// Gère la prise en charge de course depuis la Bourse, la validation GPS sur site et la clôture BLP.
class DeliveryDetailView extends StatefulWidget {
  final DeliveryOrder order;

  const DeliveryDetailView({super.key, required this.order});

  @override
  State<DeliveryDetailView> createState() => _DeliveryDetailViewState();
}

class _DeliveryDetailViewState extends State<DeliveryDetailView> {
  final MapController _mapController = MapController();
  final DraggableScrollableController _sheetController = DraggableScrollableController();

  bool _isProcessing = false;
  DeliveryOrder? _overriddenOrder;
  final Map<String, int> _consignesRecuperees = {};
  final Map<String, TextEditingController> _consignesControllers = {};
  final TextEditingController _consignesNotesController = TextEditingController();

  // Suivi en temps réel de la position GPS du smartphone du livreur
  LatLng? _driverLocation;
  double? _driverAccuracyMeters;
  StreamSubscription<Position>? _positionSubscription;
  bool _isGpsActive = false;

  // Routage routier dynamique (Algorithme de Dijkstra / OSRM)
  RoutingResult? _routingResult;
  bool _isCalculatingRoute = false;
  LatLng? _lastCalculatedDriverPos;

  @override
  void initState() {
    super.initState();
    _initConsignes();
    _initDriverLocationTracking();
  }

  void _initConsignes() {
    for (final it in widget.order.items) {
      if (it.exigeRetourEmballage) {
        final initial = it.quantiteRecuperee ?? it.quantiteCommandee;
        _consignesRecuperees[it.articleId] = initial;
        _consignesControllers[it.articleId] = TextEditingController(text: initial.toString());
      }
    }
  }

  TextEditingController _getConsigneController(String articleId, int initialCount) {
    if (!_consignesControllers.containsKey(articleId)) {
      _consignesControllers[articleId] = TextEditingController(text: initialCount.toString());
    }
    return _consignesControllers[articleId]!;
  }

  Future<void> _initDriverLocationTracking() async {
    // Activer immédiatement l'écoute GPS dès l'ouverture de la commande
    _startPositionTracking();
  }

  /// Normalisation de la position pour compenser automatiquement les simulateurs situés en Californie
  LatLng _normalizePosition(double lat, double lng) {
    final bool isGoogleEmulator = (lat >= 37.41 && lat <= 37.43 && lng >= -122.09 && lng <= -122.07);
    final bool isAppleSimulator = (lat >= 37.32 && lat <= 37.34 && lng >= -122.02 && lng <= -121.99);

    if (isGoogleEmulator || isAppleSimulator) {
      // Positionnement automatique dans la zone de livraison (Port-au-Prince / Delmas)
      return const LatLng(18.5420, -72.3150);
    }
    return LatLng(lat, lng);
  }

  /// Démarre le flux d'écoute GPS en continu pour suivre le livreur en temps réel (instantané et réactif)
  void _startPositionTracking() async {
    await _positionSubscription?.cancel();
    try {
      final bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (mounted) setState(() => _isGpsActive = false);
        return;
      }
      LocationPermission perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.denied || perm == LocationPermission.deniedForever) {
        if (mounted) setState(() => _isGpsActive = false);
        return;
      }

      // 1. Lire instantanément la dernière position connue du smartphone (< 50ms)
      try {
        final lastPos = await Geolocator.getLastKnownPosition();
        if (lastPos != null && mounted) {
          final normPos = _normalizePosition(lastPos.latitude, lastPos.longitude);
          setState(() {
            _driverLocation = normPos;
            _driverAccuracyMeters = lastPos.accuracy;
            _isGpsActive = true;
          });
          _checkAndTriggerRouteUpdate(normPos);
        }
      } catch (_) {}

      // 2. Écouter le flux réactif des déplacements en temps réel (filtre de 5 mètres)
      _positionSubscription = Geolocator.getPositionStream(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.bestForNavigation,
          distanceFilter: 5,
        ),
      ).listen(
        (pos) {
          if (!mounted) return;
          final normPos = _normalizePosition(pos.latitude, pos.longitude);
          setState(() {
            _driverLocation = normPos;
            _driverAccuracyMeters = pos.accuracy;
            _isGpsActive = true;
          });
          _checkAndTriggerRouteUpdate(normPos);
        },
        onError: (_) {
          if (mounted) setState(() => _isGpsActive = false);
        },
      );

      // 3. Forcer un rafraîchissement actif en arrière-plan sans bloquer l'UI
      Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 5),
        ),
      ).then((pos) {
        if (mounted) {
          final normPos = _normalizePosition(pos.latitude, pos.longitude);
          setState(() {
            _driverLocation = normPos;
            _driverAccuracyMeters = pos.accuracy;
            _isGpsActive = true;
          });
          _checkAndTriggerRouteUpdate(normPos);
        }
      }).catchError((_) {});
    } catch (_) {
      if (mounted) setState(() => _isGpsActive = false);
    }
  }

  /// Calcul ou recalcul dynamique de l'itinéraire le plus court (Dijkstra)
  Future<void> _updateRouteIfNeeded(LatLng clientLatLng, {bool force = false}) async {
    if (_driverLocation == null) return;
    if (_isCalculatingRoute) return;

    const distanceCalc = Distance();
    final shouldRecalculate = force ||
        _lastCalculatedDriverPos == null ||
        distanceCalc.as(LengthUnit.Meter, _driverLocation!, _lastCalculatedDriverPos!) > 35.0 ||
        (_routingResult != null &&
            RoutingService.hasDriverDeviated(
              driverPosition: _driverLocation!,
              currentRoutePoints: _routingResult!.primaryRoute.points,
              thresholdMeters: 40.0,
            ));

    if (!shouldRecalculate) return;

    _isCalculatingRoute = true;
    final currentDriverPos = _driverLocation!;
    final res = await RoutingService.calculateRoutes(
      origin: currentDriverPos,
      destination: clientLatLng,
    );

    if (mounted) {
      setState(() {
        _routingResult = res;
        _lastCalculatedDriverPos = currentDriverPos;
        _isCalculatingRoute = false;
      });
    }
  }

  void _checkAndTriggerRouteUpdate(LatLng? currentDriverPos) {
    if (currentDriverPos == null) return;
    final currentOrder = _overriddenOrder ?? widget.order;
    if (currentOrder.latitude != null && currentOrder.longitude != null) {
      _updateRouteIfNeeded(LatLng(currentOrder.latitude!, currentOrder.longitude!));
    }
  }

  /// Recentrer la carte sur la position actuelle du livreur
  void _centerMapOnDriver() async {
    if (_driverLocation != null) {
      _mapController.move(_driverLocation!, 16.0);
    }
    await _refreshCurrentLocation();
  }

  /// Rafraîchissement ponctuel de la position GPS
  Future<void> _refreshCurrentLocation() async {
    setState(() => _isProcessing = true);
    final loc = await LocationService.getCurrentDeviceLocation();
    setState(() => _isProcessing = false);
    if (!mounted) return;
    if (loc.isFromGps) {
      setState(() {
        _driverLocation = loc.position;
        _driverAccuracyMeters = loc.accuracyMeters;
        _isGpsActive = true;
      });
      _mapController.move(loc.position, 16.0);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            "Position synchronisée : ${loc.reverseInfo?.commune ?? 'Signal GPS actif'} (Précision : ${loc.accuracyMeters?.toStringAsFixed(0) ?? '?'} m)",
          ),
          backgroundColor: const Color(0xFF0C4E55),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(loc.errorMessage ?? "Impossible d'acquérir le signal GPS."),
          backgroundColor: Colors.red.shade700,
        ),
      );
    }
  }

  @override
  void dispose() {
    _positionSubscription?.cancel();
    _consignesNotesController.dispose();
    for (final c in _consignesControllers.values) {
      c.dispose();
    }
    _sheetController.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // APPELS ET NAVIGATION EXTERNE
  // ---------------------------------------------------------------------------
  Future<void> _makePhoneCall(String phoneNumber) async {
    final cleaned = phoneNumber.replaceAll(RegExp(r'[^0-9+]'), '');
    if (cleaned.isEmpty) return;
    final Uri uri = Uri.parse('tel:$cleaned');
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
      } else {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Impossible de composer le numéro : $phoneNumber")),
        );
      }
    }
  }

  Future<void> _sendSms(String phoneNumber) async {
    final cleaned = phoneNumber.replaceAll(RegExp(r'[^0-9+]'), '');
    if (cleaned.isEmpty) return;
    final Uri uri = Uri.parse('sms:$cleaned');
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
      } else {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Impossible d'envoyer un message au : $phoneNumber")),
        );
      }
    }
  }

  Future<void> _openExternalGps(double lat, double lng) async {
    final currentOrder = _overriddenOrder ?? widget.order;
    await RoutingService.openGoogleMapsNavigation(
      destLat: lat,
      destLng: lng,
      originLat: _driverLocation?.latitude,
      originLng: _driverLocation?.longitude,
      destinationLabel: currentOrder.clientNom,
    );
  }

  // ---------------------------------------------------------------------------
  // ACTIONS MÉTIER DU WORKFLOW (ÉTAPES SÉQUENTIELLES)
  // ---------------------------------------------------------------------------

  /// Prise en charge d'une course disponible de la Bourse libre
  Future<void> _handleClaim(DeliveryOrder currentOrder) async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final currentDriverId = auth.currentUser?.id;
    if (currentDriverId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Chauffeur non identifié.")),
      );
      return;
    }
    setState(() => _isProcessing = true);
    final provider = Provider.of<DeliveryProvider>(context, listen: false);
    final res = await provider.claimOrder(
      currentOrder.id,
      driverId: currentDriverId,
    );
    setState(() => _isProcessing = false);

    if (!mounted) return;
    if (res.success) {
      provider.setActiveTab('A_LIVRER');
      setState(() {
        _overriddenOrder = currentOrder.copyWith(
          chauffeurId: currentDriverId,
          statut: 'ASSIGNEE',
        );
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Course ajoutée à votre tournée avec succès ! Vous pouvez débuter la livraison."),
          backgroundColor: Color(0xFF0C4E55),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(res.errorMessage ?? "Impossible de prendre la course."),
          backgroundColor: Colors.red.shade700,
        ),
      );
    }
  }

  /// Étape 1 : Démarrer la course vers le client (avec lecture et validation de la position GPS du livreur)
  Future<void> _handleStart(String orderId) async {
    // 1. Si la position GPS n'est pas encore acquise, la récupérer immédiatement
    if (_driverLocation == null) {
      setState(() => _isProcessing = true);
      final locResult = await LocationService.getCurrentDeviceLocation();
      setState(() => _isProcessing = false);

      if (locResult.isFromGps) {
        setState(() {
          _driverLocation = locResult.position;
          _driverAccuracyMeters = locResult.accuracyMeters;
          _isGpsActive = true;
        });
      }
    }

    // 2. Début effectif de la livraison
    setState(() => _isProcessing = true);
    final provider = Provider.of<DeliveryProvider>(context, listen: false);
    final success = await provider.startDelivery(orderId);
    setState(() => _isProcessing = false);

    if (!mounted) return;
    if (success) {
      // 3. Activer / rafraîchir le tracking temps réel sur la carte
      _startPositionTracking();

      final currentOrder = _overriddenOrder ?? widget.order;
      if (currentOrder.latitude != null && currentOrder.longitude != null && _driverLocation != null) {
        _updateRouteIfNeeded(LatLng(currentOrder.latitude!, currentOrder.longitude!), force: true);
      }

      final precisionText = _driverAccuracyMeters != null
          ? " (Précision : ${_driverAccuracyMeters!.toStringAsFixed(0)} m)"
          : "";

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _driverLocation != null
                ? "Course démarrée ! Position GPS synchronisée en temps réel$precisionText. En route vers le client."
                : "Course démarrée ! En route vers le client.",
          ),
          backgroundColor: AppTheme.primaryRoyal,
        ),
      );
    } else if (provider.errorMessage != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(provider.errorMessage!),
          backgroundColor: Colors.red.shade700,
        ),
      );
    }
  }

  /// Étape 2 : Encaissement sur place
  void _openPaymentModal(DeliveryOrder currentOrder) {
    String selectedMode = currentOrder.modePaiement;
    final notesController = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) {
          final isDark = AppTheme.isDark(ctx);
          return Container(
            decoration: BoxDecoration(
              color: AppTheme.surfaceColor(ctx),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            ),
            padding: EdgeInsets.only(
              top: 18,
              left: 20,
              right: 20,
              bottom: MediaQuery.of(ctx).viewInsets.bottom + MediaQuery.of(ctx).padding.bottom + 20,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 38,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade400,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryRoyal.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.point_of_sale, color: AppTheme.primaryRoyal, size: 22),
                    ),
                    const SizedBox(width: 12),
                    const Text(
                      "Étape 2 : Encaissement sur Place",
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: isDark ? AppTheme.cardDarkSubtle : Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text("Montant à encaisser :", style: TextStyle(fontWeight: FontWeight.w600)),
                      Text(
                        "${currentOrder.montantTotal.toStringAsFixed(2)} HTG",
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFF047857),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                DropdownButtonFormField<String>(
                  initialValue: ["ESPECES", "MONCASH", "NATCASH", "VIREMENT", "CHEQUE"].contains(selectedMode)
                      ? selectedMode
                      : "ESPECES",
                  decoration: InputDecoration(
                    labelText: "Mode d'encaissement",
                    prefixIcon: const Icon(Icons.payment),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  items: const [
                    DropdownMenuItem(value: "ESPECES", child: Text("Espèces (Cash)")),
                    DropdownMenuItem(value: "MONCASH", child: Text("MonCash")),
                    DropdownMenuItem(value: "NATCASH", child: Text("NatCash")),
                    DropdownMenuItem(value: "VIREMENT", child: Text("Virement bancaire")),
                    DropdownMenuItem(value: "CHEQUE", child: Text("Chèque")),
                  ],
                  onChanged: (val) {
                    if (val != null) setModalState(() => selectedMode = val);
                  },
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: notesController,
                  decoration: InputDecoration(
                    labelText: "Référence / Note de reçu",
                    hintText: "Optionnel (ex: No reçu, No transaction MonCash)",
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(height: 18),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF047857),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  icon: const Icon(Icons.check_circle, size: 20),
                  label: const Text(
                    "Valider le Paiement",
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                  ),
                  onPressed: () async {
                    Navigator.pop(ctx);
                    setState(() => _isProcessing = true);
                    final provider = Provider.of<DeliveryProvider>(context, listen: false);
                    final ok = await provider.recordPayment(
                      currentOrder.id,
                      modePaiement: selectedMode,
                      notesPaiement: notesController.text.trim().isNotEmpty ? notesController.text.trim() : null,
                    );
                    setState(() => _isProcessing = false);

                    if (!mounted) return;
                    if (ok) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text("Paiement validé avec succès ! Étape suivante débloquée."),
                          backgroundColor: Color(0xFF047857),
                        ),
                      );
                    }
                  },
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  /// Étape 3 : Validation GPS sur place
  Future<void> _captureGpsOnSite(DeliveryOrder currentOrder) async {
    setState(() => _isProcessing = true);
    final locResult = await LocationService.getCurrentDeviceLocation();
    setState(() => _isProcessing = false);

    if (!mounted) return;

    if (!locResult.isFromGps) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(locResult.errorMessage ?? "Signal GPS introuvable. Veuillez activer la localisation."),
          backgroundColor: Colors.red.shade700,
        ),
      );
      _openAddressValidationModal(currentOrder);
      return;
    }

    final lat = locResult.position.latitude;
    final lng = locResult.position.longitude;
    final rev = locResult.reverseInfo;
    final formattedAddr = currentOrder.adresseLivraison.isNotEmpty
        ? currentOrder.adresseLivraison
        : (rev?.adresseFormatee ?? "Coordonnées client certifiées");

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.gps_fixed, color: AppTheme.primaryRoyal, size: 22),
            SizedBox(width: 8),
            Text("Validation GPS Client", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Vous êtes actuellement chez le client. Confirmez-vous l'enregistrement de ces coordonnées GPS officielles ?",
              style: TextStyle(fontSize: 13),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.blue.shade100),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("Coordonnées : ${lat.toStringAsFixed(5)}, ${lng.toStringAsFixed(5)}",
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  if (rev != null) ...[
                    const SizedBox(height: 4),
                    Text("Zone : ${rev.commune} (${rev.codePostal})",
                        style: TextStyle(fontSize: 12, color: Colors.blue.shade900)),
                  ],
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text("Ajuster manuellement"),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryRoyal,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text("Enregistrer GPS"),
          ),
        ],
      ),
    );

    if (!mounted) return;

    if (confirmed == true) {
      setState(() => _isProcessing = true);
      final provider = Provider.of<DeliveryProvider>(context, listen: false);
      final success = await provider.confirmLocation(
        currentOrder.id,
        lat: lat,
        lng: lng,
        rawAddress: formattedAddr,
      );
      setState(() => _isProcessing = false);

      if (!mounted) return;
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Coordonnées GPS client validées avec succès ! La carte est désormais activée."),
            backgroundColor: Color(0xFF047857),
          ),
        );
      }
    } else if (confirmed == false) {
      _openAddressValidationModal(currentOrder);
    }
  }

  void _openAddressValidationModal(DeliveryOrder currentOrder, [bool isReadOnly = false]) async {
    final updated = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AddressMapModal(
        order: currentOrder,
        isReadOnly: isReadOnly,
      ),
    );

    if (updated == true && mounted) {
      Provider.of<DeliveryProvider>(context, listen: false).fetchOrders(force: true);
    }
  }

  /// Étape 4 (ou 3) : Clôture de la livraison & Bon de livraison (BLP) avec émargement
  Future<void> _handleComplete(DeliveryOrder currentOrder) async {
    // 1. Recueillir l'émargement physique et la signature tactile
    final proof = await showDialog<({
      String nomReceptionnaire,
      String? numeroRecuPapier,
      String? signatureSvg,
    })>(
      context: context,
      barrierDismissible: false,
      builder: (context) => _ProofOfDeliveryDialog(order: currentOrder),
    );

    if (proof == null) {
      // Clôture annulée par le livreur
      return;
    }

    setState(() => _isProcessing = true);
    final provider = Provider.of<DeliveryProvider>(context, listen: false);

    List<Map<String, dynamic>>? consigneItems;
    final hasConsignes = currentOrder.items.any((it) => it.exigeRetourEmballage);
    if (hasConsignes) {
      consigneItems = currentOrder.items
          .where((it) => it.exigeRetourEmballage)
          .map((it) => {
                'article_id': it.articleId,
                'nom_emballage': it.nomEmballageRecupere ?? 'Bonbonne vide 5G',
                'quantite_livree': it.quantiteCommandee,
                'quantite_recuperee': _consignesRecuperees[it.articleId] ?? it.quantiteCommandee,
                'observations': _consignesNotesController.text.trim().isNotEmpty
                    ? _consignesNotesController.text.trim()
                    : null,
              })
          .toList();

      if (consigneItems.isNotEmpty) {
        try {
          final res = await DeliveryService.declareConsignes(
            orderId: currentOrder.id,
            items: consigneItems,
          );
          if (!res.success) {
            setState(() => _isProcessing = false);
            if (!mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(res.errorMessage ?? "Déclaration des emballages consignés obligatoire."),
                backgroundColor: Colors.red.shade700,
              ),
            );
            return;
          }
        } catch (e) {
          setState(() => _isProcessing = false);
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text("Erreur déclaration consignes : ${ErrorSanitizer.extractErrorMessage(e)}"),
              backgroundColor: Colors.red.shade700,
            ),
          );
          return;
        }
      }
    }

    final success = await provider.completeDelivery(
      currentOrder.id,
      lat: currentOrder.latitude ?? AppConfig.fallbackLatitude,
      lng: currentOrder.longitude ?? AppConfig.fallbackLongitude,
      consignes: consigneItems,
      nomReceptionnaire: proof.nomReceptionnaire,
      signatureReception: proof.signatureSvg,
      numeroRecuPapier: proof.numeroRecuPapier,
    );

    setState(() => _isProcessing = false);

    if (!mounted) return;
    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Livraison clôturée avec succès. Émargement et bon enregistrés.'),
          backgroundColor: Color(0xFF047857),
        ),
      );
      Navigator.pop(context);
    } else if (provider.errorMessage != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(provider.errorMessage!),
          backgroundColor: Colors.red.shade700,
        ),
      );
    }
  }

  void _openDisputeModal(DeliveryOrder currentOrder) {
    showDialog(
      context: context,
      builder: (context) => DisputeDialog(
        order: currentOrder,
        onSubmit: ({
          required String articleId,
          required int quantiteDefectueuse,
          required String motif,
          String? description,
          required bool doitEtreRelivree,
          required String actionChoisie,
        }) async {
          final provider = Provider.of<DeliveryProvider>(context, listen: false);
          final success = await provider.submitDispute(
            orderId: currentOrder.id,
            articleId: articleId,
            quantiteDefectueuse: quantiteDefectueuse,
            motif: motif,
            description: description,
            doitEtreRelivree: doitEtreRelivree,
            actionChoisie: actionChoisie,
          );
          if (!context.mounted) return success;
          if (success) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text("Litige enregistré et transmis au superviseur."),
                backgroundColor: Colors.orange,
              ),
            );
            Navigator.pop(context);
          }
          return success;
        },
      ),
    );
  }

  void _openBreakdownDialog(DeliveryOrder currentOrder) {
    final reasonController = TextEditingController(text: "Panne mécanique / Incident véhicule");
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.car_crash_outlined, color: Colors.red, size: 22),
            SizedBox(width: 8),
            Text("Signaler Panne / Relais", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Cette action libère la course de votre tournée pour qu'un autre chauffeur prenne le relais.",
              style: TextStyle(fontSize: 12),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: reasonController,
              maxLines: 2,
              decoration: InputDecoration(
                hintText: "Ex: Crevaison, panne moteur...",
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Annuler")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () async {
              Navigator.pop(ctx);
              setState(() => _isProcessing = true);
              final provider = Provider.of<DeliveryProvider>(context, listen: false);
              final ok = await provider.submitDispute(
                orderId: currentOrder.id,
                articleId: currentOrder.items.isNotEmpty ? currentOrder.items.first.articleId : "VEHICULE",
                quantiteDefectueuse: 0,
                motif: "PANNE_VEHICULE",
                description: reasonController.text.trim(),
                doitEtreRelivree: true,
                actionChoisie: "RELIVRAISON_PRIORITAIRE",
              );
              setState(() => _isProcessing = false);
              if (!mounted) return;
              if (ok) Navigator.pop(context);
            },
            child: const Text("Confirmer"),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // ÉVALUATION DE L'ÉTAT DU WORKFLOW
  // ---------------------------------------------------------------------------
  _WorkflowProgress _computeWorkflow(DeliveryOrder order) {
    final statutNorm = order.statut.toUpperCase();

    // 1. Démarrée si en cours ou terminée
    final bool isDone = statutNorm == 'CLOTUREE' ||
        statutNorm == 'LIVREE_EN_ATTENTE' ||
        statutNorm == 'LIVREE' ||
        statutNorm == 'TERMINEE';

    final bool isStarted = isDone ||
        statutNorm == 'EN_COURS_DE_LIVRAISON' ||
        statutNorm == 'EN_COURS';

    // 2. Paiement
    final bool isPaymentDone = order.estPayee || order.isCreditOrder;

    // 3. GPS (validé si les coordonnées existent et qu'aucune vérification n'est imposée)
    final bool isGpsDone = !order.requiresGpsValidation || isDone;

    // Étape active
    int currentStep = 1;
    if (order.isUnassigned) {
      currentStep = 0; // Bourse libre
    } else if (!isStarted) {
      currentStep = 1;
    } else if (!isPaymentDone) {
      currentStep = 2;
    } else if (!isGpsDone) {
      currentStep = 3;
    } else if (!isDone) {
      currentStep = 4;
    } else {
      currentStep = 5; // Terminé
    }

    return _WorkflowProgress(
      isStarted: isStarted,
      isPaymentDone: isPaymentDone,
      isGpsDone: isGpsDone,
      isDone: isDone,
      currentStep: currentStep,
    );
  }

  // ---------------------------------------------------------------------------
  // CONSTRUCTION DE LA VUE PRINCIPALE
  // ---------------------------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<DeliveryProvider>(context);
    final currentOrder = _overriddenOrder ?? provider.orders.firstWhere(
      (o) => o.id == widget.order.id,
      orElse: () => widget.order,
    );

    final workflow = _computeWorkflow(currentOrder);

    // Règle métier : Lors de la première livraison ou si les coordonnées GPS
    // ne sont pas encore certifiées, la carte est masquée pour éviter les faux tracés.
    final bool requiresGpsValidation = currentOrder.requiresGpsValidation;

    return Scaffold(
      backgroundColor: const Color(0xFF071933),
      body: Stack(
        children: [
          // 1. Couche de Fond :
          // Si GPS validé -> Carte Plein Écran interactive
          // Si Première Livraison -> Écran de guidage textuel
          if (!requiresGpsValidation && currentOrder.latitude != null && currentOrder.longitude != null)
            _buildInteractiveMap(currentOrder)
          else
            _buildFirstDeliveryGuidanceView(currentOrder, workflow),

          // 2. Boutons d'en-tête flottants (Retour, Titre, GPS Externe)
          _buildFloatingHeader(currentOrder, requiresGpsValidation),

          // 2B. Boutons flottants : Recentrer GPS & Naviguer avec Google Maps
          if (!requiresGpsValidation && currentOrder.latitude != null && currentOrder.longitude != null)
            Positioned(
              right: 14,
              top: 76,
              child: SafeArea(
                child: Column(
                  children: [
                    // Bouton Recentrer
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 6, offset: Offset(0, 2))],
                      ),
                      child: IconButton(
                        icon: Icon(
                          _isGpsActive ? Icons.my_location : Icons.location_searching,
                          color: _isGpsActive ? const Color(0xFF0A5FCB) : Colors.grey.shade600,
                          size: 20,
                        ),
                        tooltip: "Recentrer sur ma position (Livreur)",
                        onPressed: _centerMapOnDriver,
                      ),
                    ),
                    const SizedBox(height: 8),
                    // Bouton Navigation Google Maps
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 6, offset: Offset(0, 2))],
                      ),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: () {
                            if (currentOrder.latitude != null && currentOrder.longitude != null) {
                              RoutingService.openGoogleMapsNavigation(
                                destLat: currentOrder.latitude!,
                                destLng: currentOrder.longitude!,
                                originLat: _driverLocation?.latitude,
                                originLng: _driverLocation?.longitude,
                                destinationLabel: currentOrder.clientNom,
                              );
                            }
                          },
                          borderRadius: BorderRadius.circular(20),
                          child: const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.directions, color: Color(0xFF0A5FCB), size: 18),
                                SizedBox(width: 4),
                                Text(
                                  "Maps",
                                  style: TextStyle(
                                    fontWeight: FontWeight.w900,
                                    fontSize: 11,
                                    color: Color(0xFF0F172A),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // 3. Volet Coulissant (Bottom Sheet) seulement si la carte est active
          if (!requiresGpsValidation && currentOrder.latitude != null && currentOrder.longitude != null)
            _buildDraggableBottomSheet(currentOrder, workflow),

          // Indicateur de chargement plein écran si opération en cours
          if (_isProcessing)
            Container(
              color: Colors.black45,
              child: const Center(
                child: CircularProgressIndicator(color: AppTheme.accentSky),
              ),
            ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // 1A. CARTE PLEIN ÉCRAN INTERACTIVE AVEC SUIVI GPS LIVREUR EN TEMPS RÉEL
  // ---------------------------------------------------------------------------
  Widget _buildInteractiveMap(DeliveryOrder currentOrder) {
    final clientLatLng = LatLng(currentOrder.latitude!, currentOrder.longitude!);
    final bool hasDriverGps = _driverLocation != null;

    // Déclencher le calcul du chemin le plus court dès que le GPS chauffeur est acquis
    if (hasDriverGps && _routingResult == null && !_isCalculatingRoute) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _updateRouteIfNeeded(clientLatLng);
      });
    }

    const distanceCalc = Distance();
    final double directDistanceKm = hasDriverGps
        ? distanceCalc.as(LengthUnit.Kilometer, _driverLocation!, clientLatLng)
        : 0.0;

    final double effectiveDistanceKm = _routingResult != null
        ? _routingResult!.primaryRoute.distanceKm
        : directDistanceKm;

    final int effectiveDurationMin = _routingResult != null
        ? _routingResult!.primaryRoute.durationMinutes
        : (directDistanceKm * 2.5).clamp(2, 60).round();

    // Positionnement du badge d'estimation sur l'itinéraire routier
    LatLng badgePoint = clientLatLng;
    if (hasDriverGps) {
      if (_routingResult != null && _routingResult!.primaryRoute.points.isNotEmpty) {
        final pts = _routingResult!.primaryRoute.points;
        badgePoint = pts[pts.length ~/ 2];
      } else {
        badgePoint = LatLng(
          (_driverLocation!.latitude + clientLatLng.latitude) / 2,
          (_driverLocation!.longitude + clientLatLng.longitude) / 2,
        );
      }
    }

    return FlutterMap(
      mapController: _mapController,
      options: MapOptions(
        initialCenter: hasDriverGps ? _driverLocation! : clientLatLng,
        initialZoom: 14.5,
      ),
      children: [
        TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'com.transportlogistic.transportlogistic',
        ),

        // Tracé des polylines routières
        PolylineLayer(
          polylines: [
            // 1. Chemins alternatifs secondaires (en gris-bleu discret)
            if (_routingResult != null)
              for (final alt in _routingResult!.alternativeRoutes)
                Polyline(
                  points: alt.points,
                  strokeWidth: 3.5,
                  color: const Color(0xFF64748B).withValues(alpha: 0.6),
                ),

            // 2. Chemin principal optimal (Dijkstra - le plus court en bleu éclatant)
            if (_routingResult != null)
              Polyline(
                points: _routingResult!.primaryRoute.points,
                strokeWidth: 5.5,
                color: const Color(0xFF0A5FCB),
              )
            else if (hasDriverGps)
              Polyline(
                points: [_driverLocation!, clientLatLng],
                strokeWidth: 4.0,
                color: const Color(0xFF0A5FCB).withValues(alpha: 0.35),
              ),
          ],
        ),

        MarkerLayer(
          markers: [
            // 1. Origine : Marqueur Livreur en temps réel (Bleu Royal) - AUCUN faux dépôt
            if (hasDriverGps)
              Marker(
                point: _driverLocation!,
                width: 52,
                height: 52,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    // Halo semi-transparent de précision GPS
                    Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        color: const Color(0xFF0A5FCB).withValues(alpha: 0.20),
                        shape: BoxShape.circle,
                      ),
                    ),
                    // Pointeur GPS dynamique du livreur
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: const Color(0xFF0A5FCB),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2.5),
                        boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 6, offset: Offset(0, 2))],
                      ),
                      child: const Icon(Icons.navigation, color: Colors.white, size: 20),
                    ),
                  ],
                ),
              ),

            // 2. Trajet & Temps Estimé au milieu du tracé routier
            if (hasDriverGps)
              Marker(
                point: badgePoint,
                width: 155,
                height: 44,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 6)],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(4),
                        decoration: const BoxDecoration(
                          color: Color(0xFF0A5FCB),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.local_shipping, color: Colors.white, size: 14),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        "$effectiveDurationMin min (${effectiveDistanceKm.toStringAsFixed(1)} km)",
                        style: const TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 11,
                          color: Colors.black87,
                        ),
                      ),
                      if (_routingResult != null && _routingResult!.alternativeRoutes.isNotEmpty) ...[
                        const SizedBox(width: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                          decoration: BoxDecoration(
                            color: const Color(0xFFDCFCE7),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text(
                            "Court",
                            style: TextStyle(fontWeight: FontWeight.w900, fontSize: 8, color: Color(0xFF166534)),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),

            // 3. Destination : Marqueur Vert Client
            Marker(
              point: clientLatLng,
              width: 48,
              height: 48,
              child: Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF047857),
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2.5),
                  boxShadow: const [BoxShadow(color: Colors.black38, blurRadius: 8)],
                ),
                child: const Icon(Icons.location_on, color: Colors.white, size: 26),
              ),
            ),
          ],
        ),

        // Message discret si en attente du GPS livreur
        if (!hasDriverGps)
          Positioned(
            top: 76,
            left: 20,
            right: 70,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFF0F172A).withValues(alpha: 0.88),
                borderRadius: BorderRadius.circular(12),
                boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 4)],
              ),
              child: const Row(
                children: [
                  SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  ),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      "Localisation chauffeur en cours...",
                      style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700),
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // 1B. ÉCRAN PREMIÈRE LIVRAISON (Pas de carte, guidage séquentiel explicite)
  // ---------------------------------------------------------------------------
  Widget _buildFirstDeliveryGuidanceView(DeliveryOrder currentOrder, _WorkflowProgress workflow) {
    return SafeArea(
      child: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.only(top: 72, left: 18, right: 18, bottom: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Bannière d'alerte Première Livraison
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFFB45309), Color(0xFFD97706)],
                      ),
                      borderRadius: BorderRadius.circular(18),
                      boxShadow: const [BoxShadow(color: Colors.black38, blurRadius: 10)],
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.20),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.explore_off, color: Colors.white, size: 28),
                        ),
                        const SizedBox(width: 14),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "Première Livraison Client",
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              SizedBox(height: 4),
                              Text(
                                "La carte est temporairement masquée. Utilisez les boutons d'étapes ci-dessous pour démarrer, valider le GPS sur site et clôturer.",
                                style: TextStyle(color: Colors.white, fontSize: 12),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Bannière Bourse si course non assignée
                  if (currentOrder.isUnassigned) ...[
                    const SizedBox(height: 14),
                    _buildUnassignedBanner(currentOrder),
                  ],

                  const SizedBox(height: 18),

                  // Fiche Client & Contact Direct
                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 8)],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            CircleAvatar(
                              radius: 26,
                              backgroundColor: const Color(0xFF071933),
                              child: Text(
                                currentOrder.clientNom.isNotEmpty
                                    ? currentOrder.clientNom[0].toUpperCase()
                                    : "C",
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    currentOrder.clientNom,
                                    style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w900,
                                      color: Color(0xFF0F172A),
                                    ),
                                  ),
                                  Text(
                                    currentOrder.clientTel.isNotEmpty
                                        ? currentOrder.clientTel
                                        : "Sans téléphone direct",
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: Colors.grey.shade600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (currentOrder.clientTel.isNotEmpty) ...[
                              _buildCircleIconButton(
                                icon: Icons.phone,
                                onTap: () => _makePhoneCall(currentOrder.clientTel),
                              ),
                              const SizedBox(width: 8),
                              _buildCircleIconButton(
                                icon: Icons.chat_bubble,
                                onTap: () => _sendSms(currentOrder.clientTel),
                              ),
                            ],
                          ],
                        ),

                        const Divider(height: 28),

                        const Text(
                          "ADRESSE DE LIVRAISON :",
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          currentOrder.adresseLivraison.isNotEmpty
                              ? currentOrder.adresseLivraison
                              : "Zone de livraison non précisée",
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF0F172A),
                          ),
                        ),

                        if (currentOrder.instructionsLivraison != null &&
                            currentOrder.instructionsLivraison!.trim().isNotEmpty) ...[
                          const SizedBox(height: 12),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Icon(Icons.info_outline, size: 16, color: Color(0xFF0284C7)),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    "Repères client : ${currentOrder.instructionsLivraison}",
                                    style: const TextStyle(fontSize: 12, color: Color(0xFF334155)),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),

                  const SizedBox(height: 18),

                  // Stepper séquentiel détaillé avec boutons d'actions d'étapes
                  _buildInteractiveStepsCard(currentOrder, workflow),

                  const SizedBox(height: 18),

                  _buildOrderSummaryCard(currentOrder, isDone: workflow.isDone),
                ],
              ),
            ),
          ),

          // Barre d'Action Persistante en bas
          _buildStickyBottomActionBar(currentOrder, workflow),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // 2. EN-TÊTE FLOTTANT
  // ---------------------------------------------------------------------------
  Widget _buildFloatingHeader(DeliveryOrder currentOrder, bool isFirstDelivery) {
    return Positioned(
      top: 12,
      left: 14,
      right: 14,
      child: SafeArea(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            CircleAvatar(
              backgroundColor: Colors.white,
              radius: 22,
              child: IconButton(
                icon: const Icon(Icons.arrow_back, color: Color(0xFF0F172A), size: 20),
                onPressed: () => Navigator.pop(context),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 6)],
              ),
              child: Text(
                isFirstDelivery ? "Vérification Première Livraison" : "Mission : ${currentOrder.code}",
                style: const TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 13,
                  color: Color(0xFF0F172A),
                ),
              ),
            ),
            CircleAvatar(
              backgroundColor: Colors.white,
              radius: 22,
              child: IconButton(
                icon: const Icon(Icons.navigation, color: Color(0xFF0A5FCB), size: 20),
                tooltip: "Ouvrir dans Google Maps / Waze",
                onPressed: () {
                  if (currentOrder.latitude != null && currentOrder.longitude != null) {
                    _openExternalGps(currentOrder.latitude!, currentOrder.longitude!);
                  } else {
                    _openAddressValidationModal(currentOrder);
                  }
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // 3. BOTTOM SHEET COULISSANT AVEC BOUTON D'ACTION PERSISTANT
  // ---------------------------------------------------------------------------
  Widget _buildDraggableBottomSheet(DeliveryOrder currentOrder, _WorkflowProgress workflow) {
    return DraggableScrollableSheet(
      controller: _sheetController,
      initialChildSize: 0.44,
      minChildSize: 0.32,
      maxChildSize: 0.88,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
            boxShadow: [
              BoxShadow(color: Colors.black26, blurRadius: 20, spreadRadius: 4),
            ],
          ),
          child: Column(
            children: [
              // Contenu défilable
              Expanded(
                child: SingleChildScrollView(
                  controller: scrollController,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Poignée
                      Center(
                        child: Container(
                          width: 44,
                          height: 5,
                          decoration: BoxDecoration(
                            color: Colors.grey.shade300,
                            borderRadius: BorderRadius.circular(3),
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),

                      // En-tête Contact : Avatar, Nom, Téléphone
                      Row(
                        children: [
                          CircleAvatar(
                            radius: 24,
                            backgroundColor: const Color(0xFF071933),
                            child: Text(
                              currentOrder.clientNom.isNotEmpty
                                  ? currentOrder.clientNom[0].toUpperCase()
                                  : "C",
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Text(
                                      "Client JLG",
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.grey.shade600,
                                      ),
                                    ),
                                    const SizedBox(width: 4),
                                    const Icon(Icons.verified, size: 14, color: Color(0xFF047857)),
                                  ],
                                ),
                                Text(
                                  currentOrder.clientNom,
                                  style: const TextStyle(
                                    fontSize: 17,
                                    fontWeight: FontWeight.w900,
                                    color: Color(0xFF0F172A),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (currentOrder.clientTel.isNotEmpty) ...[
                            _buildCircleIconButton(
                              icon: Icons.phone,
                              onTap: () => _makePhoneCall(currentOrder.clientTel),
                            ),
                            const SizedBox(width: 10),
                            _buildCircleIconButton(
                              icon: Icons.chat_bubble,
                              onTap: () => _sendSms(currentOrder.clientTel),
                            ),
                          ],
                        ],
                      ),

                      const SizedBox(height: 14),

                      // Pill de Statut Trajet
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                color: workflow.isStarted ? const Color(0xFF047857) : const Color(0xFFEA580C),
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                currentOrder.isUnassigned
                                    ? "Course Disponible · En attente de chauffeur"
                                    : (workflow.isDone
                                        ? "Livraison Clôturée"
                                        : (workflow.isStarted
                                            ? "En route · Arrivée estimée dans 8 min"
                                            : "Course prête au départ")),
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF0F172A),
                                ),
                              ),
                            ),
                            Text(
                              workflow.isDone ? "Terminé" : "5.0 km",
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: Colors.grey.shade600,
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Bannière Bourse si course non assignée
                      if (currentOrder.isUnassigned) ...[
                        const SizedBox(height: 14),
                        _buildUnassignedBanner(currentOrder),
                      ],

                      const SizedBox(height: 16),

                      // Carte de Mission avec Stepper
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: Colors.grey.shade200),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.grey.shade100,
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text("Commande", style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
                                    Text(
                                      currentOrder.code,
                                      style: const TextStyle(
                                        fontSize: 17,
                                        fontWeight: FontWeight.w900,
                                        color: Color(0xFF0F172A),
                                      ),
                                    ),
                                  ],
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                                  decoration: BoxDecoration(
                                    color: currentOrder.isUnassigned
                                        ? const Color(0xFF0C4E55)
                                        : (workflow.isDone
                                            ? const Color(0xFF047857)
                                            : (workflow.isStarted ? const Color(0xFFEA580C) : const Color(0xFF0F172A))),
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  child: Text(
                                    currentOrder.isUnassigned ? "DISPONIBLE" : currentOrder.statutLabel,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 11,
                                    ),
                                  ),
                                ),
                              ],
                            ),

                            const SizedBox(height: 16),

                            // Stepper avec petit camion
                            _buildStepperWithTruck(workflow),

                            const SizedBox(height: 16),

                            Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text("Départ", style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
                                      const Text(
                                        "Dépôt Central JLG",
                                        style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w700,
                                          color: Color(0xFF0F172A),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text("Destination", style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
                                      Text(
                                        currentOrder.adresseLivraison.isNotEmpty
                                            ? currentOrder.adresseLivraison
                                            : "Adresse client",
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w700,
                                          color: Color(0xFF0F172A),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),

                            const SizedBox(height: 14),

                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text("Montant", style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
                                    Text(
                                      "${currentOrder.montantTotal.toStringAsFixed(2)} HTG",
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w900,
                                        color: Color(0xFF047857),
                                      ),
                                    ),
                                  ],
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: currentOrder.estPayee
                                        ? const Color(0xFFDCFCE7)
                                        : const Color(0xFFFEF3C7),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    currentOrder.estPayee
                                        ? "PAYÉ"
                                        : (currentOrder.isCreditOrder ? "VENTE CRÉDIT" : "À ENCAISSER"),
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w900,
                                      color: currentOrder.estPayee
                                          ? const Color(0xFF166534)
                                          : const Color(0xFFB45309),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 16),

                      // Stepper séquentiel avec les boutons d'actions d'étapes
                      _buildInteractiveStepsCard(currentOrder, workflow),

                      if (workflow.isDone) ...[
                        const SizedBox(height: 16),
                        _buildDeliveryProofCard(currentOrder),
                      ],

                      const SizedBox(height: 16),

                      // Récapitulatif Articles & Consignes
                      _buildOrderSummaryCard(currentOrder, isDone: workflow.isDone),

                      if (!workflow.isDone) ...[
                        const SizedBox(height: 12),

                        // Bouton incident / panne
                        TextButton.icon(
                          onPressed: () => _openBreakdownDialog(currentOrder),
                          icon: const Icon(Icons.car_crash_outlined, size: 16, color: Colors.red),
                          label: const Text(
                            "Signaler une panne ou demander un relais",
                            style: TextStyle(color: Colors.red, fontSize: 12, fontWeight: FontWeight.w600),
                          ),
                        ),
                        // Bouton litige / anomalie
                        TextButton.icon(
                          onPressed: () => _openDisputeModal(currentOrder),
                          icon: const Icon(Icons.report_problem_outlined, size: 16, color: Colors.orange),
                          label: const Text(
                            "Signaler un litige / anomalie marchandise",
                            style: TextStyle(color: Colors.orange, fontSize: 12, fontWeight: FontWeight.w600),
                          ),
                        ),
                      ],
                      const SizedBox(height: 12),
                    ],
                  ),
                ),
              ),

              // Barre d'Action Persistante collée en bas du Bottom Sheet
              _buildStickyBottomActionBar(currentOrder, workflow),
            ],
          ),
        );
      },
    );
  }

  // ---------------------------------------------------------------------------
  // CARTE PREUVE DE LIVRAISON (ÉMARGEMENT & QUITTANCE)
  // ---------------------------------------------------------------------------
  Widget _buildDeliveryProofCard(DeliveryOrder currentOrder) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF0FDF4),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF86EFAC)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.verified_user_outlined, color: Color(0xFF166534), size: 20),
              SizedBox(width: 8),
              Text(
                "Preuve de Livraison Conforme",
                style: TextStyle(fontWeight: FontWeight.w900, fontSize: 14, color: Color(0xFF166534)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text("Réceptionné par :", style: TextStyle(fontSize: 12, color: Color(0xFF475569))),
              Text(
                currentOrder.nomReceptionnaire ?? currentOrder.clientNom,
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
              ),
            ],
          ),
          if (currentOrder.numeroRecuPapier != null && currentOrder.numeroRecuPapier!.isNotEmpty) ...[
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text("N° Reçu Papier / BL :", style: TextStyle(fontSize: 12, color: Color(0xFF475569))),
                Text(
                  currentOrder.numeroRecuPapier!,
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Color(0xFF0A5FCB)),
                ),
              ],
            ),
          ],
          if (currentOrder.signatureReception != null && currentOrder.signatureReception!.isNotEmpty) ...[
            const SizedBox(height: 6),
            const Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text("Signature :", style: TextStyle(fontSize: 12, color: Color(0xFF475569))),
                Row(
                  children: [
                    Icon(Icons.draw, size: 14, color: Color(0xFF166534)),
                    SizedBox(width: 4),
                    Text(
                      "Émargement tactile validé",
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF166534)),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // BANNIÈRE BOURSE LIBRE (Information de course disponible)
  // ---------------------------------------------------------------------------
  Widget _buildUnassignedBanner(DeliveryOrder currentOrder) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF0C4E55).withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF0C4E55).withValues(alpha: 0.25)),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.radar_outlined, color: Color(0xFF0C4E55), size: 22),
          SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Course Disponible (Bourse Libre)",
                  style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13, color: Color(0xFF0C4E55)),
                ),
                SizedBox(height: 3),
                Text(
                  "Cette livraison n'a pas encore de chauffeur attitré. Utilisez le bouton en bas d'écran pour la prendre en charge et l'ajouter à votre tournée.",
                  style: TextStyle(fontSize: 11, color: Colors.black87, height: 1.3),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // STEPPER INTERACTIF (INDICATEURS DE PROGRESSION SANS DOUBLON D'ACTION)
  // ---------------------------------------------------------------------------
  Widget _buildInteractiveStepsCard(DeliveryOrder currentOrder, _WorkflowProgress workflow) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Étapes du Workflow Chauffeur",
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: Color(0xFF0F172A)),
          ),
          const SizedBox(height: 14),

          // Étape 1 : Départ Course
          _buildStepRow(
            stepNumber: 1,
            title: "1. Départ de la Course",
            subtitle: workflow.isStarted
                ? "Course en cours vers le client"
                : (currentOrder.isUnassigned ? "Prenez la course avant de débuter" : "Signaler votre départ au système"),
            isCompleted: workflow.isStarted,
            isActive: workflow.currentStep == 1,
          ),

          const Divider(height: 24),

          // Étape 2 : Encaissement (si nécessaire)
          _buildStepRow(
            stepNumber: 2,
            title: "2. Règlement / Encaissement",
            subtitle: currentOrder.estPayee
                ? "Paiement déjà reçu (${currentOrder.modePaiement})"
                : (currentOrder.isCreditOrder
                    ? "Vente à crédit : encaissement non requis"
                    : "Encaissement sur place obligatoire"),
            isCompleted: workflow.isPaymentDone,
            isActive: workflow.currentStep == 2,
          ),

          // Étape 3 : Validation GPS (Visible uniquement si requise)
          if (currentOrder.requiresGpsValidation) ...[
            const Divider(height: 24),
            _buildStepRow(
              stepNumber: 3,
              title: "3. Validation GPS sur Place",
              subtitle: workflow.isGpsDone
                  ? "Coordonnées GPS certifiées"
                  : "À capturer une fois arrivé devant chez le client",
              isCompleted: workflow.isGpsDone,
              isActive: workflow.currentStep == 3,
            ),
          ],

          const Divider(height: 24),

          // Étape 4 (ou 3) : Remise & Clôture BLP
          _buildStepRow(
            stepNumber: currentOrder.requiresGpsValidation ? 4 : 3,
            title: "${currentOrder.requiresGpsValidation ? 4 : 3}. Remise & Clôture BLP",
            subtitle: workflow.isDone
                ? "Livraison terminée avec succès"
                : "Contrôle des emballages et confirmation",
            isCompleted: workflow.isDone,
            isActive: workflow.currentStep == 4,
          ),
        ],
      ),
    );
  }

  Widget _buildStepRow({
    required int stepNumber,
    required String title,
    required String subtitle,
    required bool isCompleted,
    required bool isActive,
  }) {
    String badgeText = "EN ATTENTE";
    Color badgeColor = Colors.grey.shade600;
    Color badgeBg = Colors.grey.shade100;

    if (isCompleted) {
      badgeText = "VALIDÉ";
      badgeColor = const Color(0xFF047857);
      badgeBg = const Color(0xFFDCFCE7);
    } else if (isActive) {
      badgeText = "EN COURS";
      badgeColor = const Color(0xFF0A5FCB);
      badgeBg = const Color(0xFFDBEAFE);
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: isCompleted
                ? const Color(0xFF047857)
                : (isActive ? const Color(0xFF0A5FCB) : Colors.grey.shade200),
            shape: BoxShape.circle,
          ),
          child: Center(
            child: isCompleted
                ? const Icon(Icons.check, size: 16, color: Colors.white)
                : Text(
                    "$stepNumber",
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: isActive ? Colors.white : Colors.grey.shade600,
                    ),
                  ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: isCompleted
                      ? const Color(0xFF047857)
                      : (isActive ? const Color(0xFF0A5FCB) : const Color(0xFF0F172A)),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: badgeBg,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            badgeText,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              color: badgeColor,
            ),
          ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // BARRE D'ACTION PERSISTANTE EN BAS (STICKY ACTION BAR)
  // ---------------------------------------------------------------------------
  Widget _buildStickyBottomActionBar(DeliveryOrder currentOrder, _WorkflowProgress workflow) {
    if (workflow.isDone) {
      return Container(
        color: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        child: SafeArea(
          top: false,
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFDCFCE7),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.check_circle, color: Color(0xFF166534)),
                SizedBox(width: 8),
                Text(
                  "Livraison clôturée et enregistrée",
                  style: TextStyle(fontWeight: FontWeight.w900, color: Color(0xFF166534)),
                ),
              ],
            ),
          ),
        ),
      );
    }

    String label;
    IconData icon;
    Color color;
    VoidCallback? onPressed;

    if (currentOrder.isUnassigned) {
      label = "PRENDRE LA COURSE (AJOUTER À MA TOURNÉE)";
      icon = Icons.add_task_rounded;
      color = const Color(0xFF0C4E55);
      onPressed = () => _handleClaim(currentOrder);
    } else if (!workflow.isStarted) {
      label = "Étape 1 : DÉBUTER LA COURSE";
      icon = Icons.play_arrow_rounded;
      color = const Color(0xFF0A5FCB);
      onPressed = () => _handleStart(currentOrder.id);
    } else if (!workflow.isPaymentDone) {
      label = "Étape 2 : ENCAISSER LE PAIEMENT (${currentOrder.montantTotal.toStringAsFixed(0)} HTG)";
      icon = Icons.payments_outlined;
      color = const Color(0xFFB45309);
      onPressed = () => _openPaymentModal(currentOrder);
    } else if (!workflow.isGpsDone && currentOrder.requiresGpsValidation) {
      label = "Étape 3 : VALIDER LE GPS SUR PLACE";
      icon = Icons.my_location;
      color = const Color(0xFF047857);
      onPressed = () => _captureGpsOnSite(currentOrder);
    } else {
      label = "Étape Finale : CONFIRMER LA LIVRAISON (BLP)";
      icon = Icons.check_circle_rounded;
      color = const Color(0xFF047857);
      onPressed = () => _handleComplete(currentOrder);
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 10,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: color,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                elevation: 3,
              ),
              onPressed: _isProcessing ? null : onPressed,
              icon: Icon(icon, size: 22),
              label: Text(
                label,
                style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14, letterSpacing: 0.5),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // STEPPER HORIZONTAL AVEC PETIT CAMION
  // ---------------------------------------------------------------------------
  Widget _buildStepperWithTruck(_WorkflowProgress workflow) {
    return Row(
      children: [
        _buildStepPoint(isActive: true, isPassed: workflow.isStarted),
        Expanded(child: _buildDottedLine(isActive: workflow.isStarted)),
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: workflow.isStarted ? const Color(0xFFEA580C) : const Color(0xFF0F172A),
            shape: BoxShape.circle,
            boxShadow: [
              if (workflow.isStarted)
                BoxShadow(
                  color: const Color(0xFFEA580C).withValues(alpha: 0.35),
                  blurRadius: 8,
                ),
            ],
          ),
          child: const Icon(Icons.local_shipping, size: 14, color: Colors.white),
        ),
        Expanded(child: _buildDottedLine(isActive: workflow.isPaymentDone && workflow.isGpsDone)),
        _buildStepPoint(
          isActive: workflow.isStarted,
          isPassed: workflow.isPaymentDone && workflow.isGpsDone,
        ),
        Expanded(child: _buildDottedLine(isActive: workflow.isDone)),
        _buildStepPoint(isActive: workflow.isDone, isPassed: workflow.isDone),
      ],
    );
  }

  Widget _buildStepPoint({required bool isActive, required bool isPassed}) {
    return Container(
      width: 14,
      height: 14,
      decoration: BoxDecoration(
        color: isActive ? const Color(0xFFEA580C) : Colors.grey.shade200,
        shape: BoxShape.circle,
      ),
      child: isPassed
          ? const Icon(Icons.check, size: 10, color: Colors.white)
          : null,
    );
  }

  Widget _buildDottedLine({required bool isActive}) {
    return Container(
      height: 2,
      margin: const EdgeInsets.symmetric(horizontal: 4),
      color: isActive ? const Color(0xFFEA580C) : Colors.grey.shade200,
    );
  }

  // ---------------------------------------------------------------------------
  // RÉCAPITULATIF MARCHANDISES & CONSIGNES
  // ---------------------------------------------------------------------------
  Widget _buildOrderSummaryCard(DeliveryOrder currentOrder, {bool isDone = false}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                "Articles à Livrer",
                style: TextStyle(fontWeight: FontWeight.w900, fontSize: 14, color: Color(0xFF0F172A)),
              ),
              Text(
                "${currentOrder.items.length} produit(s)",
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ...currentOrder.items.map((it) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: const Color(0xFF049DF7).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.water_drop, size: 14, color: Color(0xFF049DF7)),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        it.designation,
                        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                      ),
                    ),
                    Text(
                      "x${it.quantiteCommandee}",
                      style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14),
                    ),
                  ],
                ),
              )),
          if (currentOrder.items.any((it) => it.exigeRetourEmballage)) ...[
            const Divider(height: 22),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  "Emballages Vides à Récupérer :",
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF0F172A)),
                ),
                if (!isDone)
                  Text(
                    "Saisie manuelle ou +/-",
                    style: TextStyle(fontSize: 11, color: Colors.grey.shade500, fontStyle: FontStyle.italic),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            ...currentOrder.items.where((it) => it.exigeRetourEmballage).map((it) {
              final count = _consignesRecuperees[it.articleId] ?? it.quantiteCommandee;

              if (isDone) {
                // Mode Consultation / Livraison Clôturée : Verrouillé en lecture seule
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          it.nomEmballageRecupere ?? "Bonbonne vide 5G",
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: const Color(0xFF10B981).withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.3)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.check_circle_outline, size: 14, color: Color(0xFF059669)),
                            const SizedBox(width: 5),
                            Text(
                              "$count récupéré${count > 1 ? 's' : ''}",
                              style: const TextStyle(
                                color: Color(0xFF059669),
                                fontWeight: FontWeight.w700,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              }

              // Mode Saisie / En cours : Boutons +/- et champ de frappe directe au clavier
              final controller = _getConsigneController(it.articleId, count);

              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        it.nomEmballageRecupere ?? "Bonbonne vide 5G",
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Bouton Décrémenter (-1)
                        IconButton(
                          icon: const Icon(Icons.remove_circle_outline, size: 22, color: Color(0xFF475569)),
                          splashRadius: 20,
                          onPressed: count > 0
                              ? () {
                                  final newCount = count - 1;
                                  controller.text = newCount.toString();
                                  setState(() => _consignesRecuperees[it.articleId] = newCount);
                                }
                              : null,
                        ),
                        // Champ de saisie directe au clavier pour les gros volumes (ex: 300, 600...)
                        SizedBox(
                          width: 65,
                          height: 38,
                          child: TextFormField(
                            controller: controller,
                            keyboardType: TextInputType.number,
                            textAlign: TextAlign.center,
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF0F172A)),
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                              LengthLimitingTextInputFormatter(6),
                            ],
                            decoration: InputDecoration(
                              contentPadding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
                              filled: true,
                              fillColor: Colors.grey.shade50,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: BorderSide(color: Colors.grey.shade300),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: BorderSide(color: Colors.grey.shade300),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: const BorderSide(color: Color(0xFF049DF7), width: 1.5),
                              ),
                            ),
                            onChanged: (val) {
                              final parsed = int.tryParse(val.trim());
                              if (parsed != null && parsed >= 0) {
                                _consignesRecuperees[it.articleId] = parsed;
                              } else if (val.trim().isEmpty) {
                                _consignesRecuperees[it.articleId] = 0;
                              }
                            },
                          ),
                        ),
                        // Bouton Incrémenter (+1)
                        IconButton(
                          icon: const Icon(Icons.add_circle_outline, size: 22, color: Color(0xFF049DF7)),
                          splashRadius: 20,
                          onPressed: () {
                            final newCount = count + 1;
                            controller.text = newCount.toString();
                            setState(() => _consignesRecuperees[it.articleId] = newCount);
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              );
            }),
          ],
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // BOUTON CIRCULAIRE NOIR POUR APPEL / SMS
  // ---------------------------------------------------------------------------
  Widget _buildCircleIconButton({required IconData icon, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(22),
      child: Container(
        width: 44,
        height: 44,
        decoration: const BoxDecoration(
          color: Color(0xFF0F172A),
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(color: Colors.black26, blurRadius: 6, offset: Offset(0, 2)),
          ],
        ),
        child: Icon(icon, color: Colors.white, size: 20),
      ),
    );
  }
}

/// Classe interne représentant l'état consolidé du workflow
class _WorkflowProgress {
  final bool isStarted;
  final bool isPaymentDone;
  final bool isGpsDone;
  final bool isDone;
  final int currentStep;

  _WorkflowProgress({
    required this.isStarted,
    required this.isPaymentDone,
    required this.isGpsDone,
    required this.isDone,
    required this.currentStep,
  });
}

// ---------------------------------------------------------------------------
// DIALOGUE D'ÉMARGEMENT & PREUVE DE LIVRAISON (SIGNATURE TACTILE + BON PAPIER)
// ---------------------------------------------------------------------------
class _ProofOfDeliveryDialog extends StatefulWidget {
  final DeliveryOrder order;

  const _ProofOfDeliveryDialog({required this.order});

  @override
  State<_ProofOfDeliveryDialog> createState() => _ProofOfDeliveryDialogState();
}

class _ProofOfDeliveryDialogState extends State<_ProofOfDeliveryDialog> {
  late final TextEditingController _nomController;
  final TextEditingController _recuPapierController = TextEditingController();
  final GlobalKey<_TouchSignaturePadState> _sigKey = GlobalKey<_TouchSignaturePadState>();
  List<List<Offset>> _strokes = [];
  String? _validationError;

  @override
  void initState() {
    super.initState();
    final defaultNom = widget.order.clientNom.isNotEmpty && widget.order.clientNom != 'Client Particulier'
        ? widget.order.clientNom
        : '';
    _nomController = TextEditingController(text: defaultNom);
  }

  @override
  void dispose() {
    _nomController.dispose();
    _recuPapierController.dispose();
    super.dispose();
  }

  String _strokesToSvgPath(List<List<Offset>> strokes) {
    if (strokes.isEmpty) return '';
    final buffer = StringBuffer();
    for (final stroke in strokes) {
      if (stroke.isEmpty) continue;
      buffer.write('M ${stroke.first.dx.toStringAsFixed(1)} ${stroke.first.dy.toStringAsFixed(1)} ');
      for (int i = 1; i < stroke.length; i++) {
        buffer.write('L ${stroke[i].dx.toStringAsFixed(1)} ${stroke[i].dy.toStringAsFixed(1)} ');
      }
    }
    return buffer.toString().trim();
  }

  void _onConfirm() {
    final nom = _nomController.text.trim();
    if (nom.isEmpty) {
      setState(() {
        _validationError = "Veuillez renseigner le nom de la personne réceptionnant la livraison sur place.";
      });
      return;
    }

    final svgPath = _strokesToSvgPath(_strokes);
    final recu = _recuPapierController.text.trim();

    Navigator.pop(context, (
      nomReceptionnaire: nom,
      numeroRecuPapier: recu.isNotEmpty ? recu : null,
      signatureSvg: svgPath.isNotEmpty ? svgPath : null,
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Entête
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFF047857).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.assignment_turned_in_outlined, color: Color(0xFF047857), size: 24),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Émargement & Preuve",
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w900,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          "Attestation physique de réception sur place",
                          style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close, color: Color(0xFF64748B), size: 20),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const Divider(height: 1),
              const SizedBox(height: 16),

              // Rappel Commande & Client
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.order.code,
                          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: Color(0xFF0F172A)),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          widget.order.clientNom,
                          style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                        ),
                      ],
                    ),
                    Text(
                      "${widget.order.montantTotal.toStringAsFixed(0)} HTG",
                      style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14, color: Color(0xFF047857)),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // Champ 1 : Nom du réceptionnaire
              const Text(
                "Nom du Réceptionnaire sur place *",
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF334155)),
              ),
              const SizedBox(height: 6),
              TextField(
                controller: _nomController,
                textCapitalization: TextCapitalization.words,
                decoration: InputDecoration(
                  hintText: "Ex: M. Jean / Gardien Pierre / Secrétaire",
                  prefixIcon: const Icon(Icons.person_outline, size: 20, color: Color(0xFF64748B)),
                  filled: true,
                  fillColor: Colors.white,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: Color(0xFF047857), width: 1.5),
                  ),
                ),
                onChanged: (_) {
                  if (_validationError != null) setState(() => _validationError = null);
                },
              ),

              const SizedBox(height: 14),

              // Champ 2 : N° Bon Papier / Reçu à souche
              const Text(
                "N° Reçu Papier / Bon de Livraison Souche (optionnel)",
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF334155)),
              ),
              const SizedBox(height: 6),
              TextField(
                controller: _recuPapierController,
                textCapitalization: TextCapitalization.characters,
                decoration: InputDecoration(
                  hintText: "Ex: BL-48912 ou SOUCHE-042",
                  prefixIcon: const Icon(Icons.receipt_long_outlined, size: 20, color: Color(0xFF64748B)),
                  filled: true,
                  fillColor: Colors.white,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: Color(0xFF047857), width: 1.5),
                  ),
                ),
              ),

              const SizedBox(height: 14),

              // Champ 3 : Zone de signature tactile
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    "Signature Tactile Client / Réceptionnaire",
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF334155)),
                  ),
                  if (_strokes.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFFDCFCE7),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Text(
                        "Signé",
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFF166534)),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 6),
              _TouchSignaturePad(
                key: _sigKey,
                onSignatureChanged: (strokes) {
                  setState(() {
                    _strokes = strokes;
                  });
                },
              ),

              if (_validationError != null) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEF2F2),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFFCA5A5)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline, size: 18, color: Color(0xFFB91C1C)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _validationError!,
                          style: const TextStyle(fontSize: 12, color: Color(0xFFB91C1C), fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 20),

              // Boutons d'action
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        side: const BorderSide(color: Color(0xFFCBD5E1)),
                      ),
                      onPressed: () => Navigator.pop(context),
                      child: const Text(
                        "Annuler",
                        style: TextStyle(color: Color(0xFF475569), fontWeight: FontWeight.w700),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF047857),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        elevation: 2,
                      ),
                      onPressed: _onConfirm,
                      icon: const Icon(Icons.check_circle_outline, size: 20),
                      label: const Text(
                        "Valider & Clôturer",
                        style: TextStyle(fontWeight: FontWeight.w900, fontSize: 14),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// WIDGET DE CAPTURE TACTILE DE SIGNATURE SANS DÉPENDANCE EXTERNE
// ---------------------------------------------------------------------------
class _TouchSignaturePad extends StatefulWidget {
  final ValueChanged<List<List<Offset>>> onSignatureChanged;

  const _TouchSignaturePad({super.key, required this.onSignatureChanged});

  @override
  State<_TouchSignaturePad> createState() => _TouchSignaturePadState();
}

class _TouchSignaturePadState extends State<_TouchSignaturePad> {
  final List<List<Offset>> _strokes = [];
  List<Offset>? _currentStroke;

  void clear() {
    setState(() {
      _strokes.clear();
      _currentStroke = null;
    });
    widget.onSignatureChanged([]);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 160,
      width: double.infinity,
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFCBD5E1), width: 1.5),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: Stack(
          children: [
            Positioned.fill(
              child: GestureDetector(
                onPanStart: (details) {
                  setState(() {
                    _currentStroke = [details.localPosition];
                    _strokes.add(_currentStroke!);
                  });
                  widget.onSignatureChanged(_strokes);
                },
                onPanUpdate: (details) {
                  setState(() {
                    _currentStroke?.add(details.localPosition);
                  });
                  widget.onSignatureChanged(_strokes);
                },
                onPanEnd: (_) {
                  _currentStroke = null;
                },
                child: CustomPaint(
                  painter: _SignaturePainter(strokes: _strokes),
                  size: Size.infinite,
                ),
              ),
            ),
            if (_strokes.isEmpty)
              const Center(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.draw_outlined, color: Color(0xFF94A3B8), size: 18),
                    SizedBox(width: 8),
                    Text(
                      "Apposer la signature au doigt",
                      style: TextStyle(
                        color: Color(0xFF94A3B8),
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            Positioned(
              right: 8,
              top: 8,
              child: InkWell(
                onTap: clear,
                borderRadius: BorderRadius.circular(6),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.refresh, size: 14, color: Color(0xFF64748B)),
                      SizedBox(width: 4),
                      Text(
                        "Effacer",
                        style: TextStyle(
                          fontSize: 11,
                          color: Color(0xFF64748B),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SignaturePainter extends CustomPainter {
  final List<List<Offset>> strokes;

  _SignaturePainter({required this.strokes});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF0F172A)
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..strokeWidth = 2.8
      ..style = PaintingStyle.stroke;

    for (final stroke in strokes) {
      if (stroke.isEmpty) continue;
      if (stroke.length == 1) {
        canvas.drawCircle(stroke.first, 1.4, paint);
      } else {
        final path = ui.Path();
        path.moveTo(stroke.first.dx, stroke.first.dy);
        for (int i = 1; i < stroke.length; i++) {
          path.lineTo(stroke[i].dx, stroke[i].dy);
        }
        canvas.drawPath(path, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _SignaturePainter oldDelegate) => true;
}
