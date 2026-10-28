import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import '../models/delivery_model.dart';
import '../providers/delivery_provider.dart';
import '../../../core/config/app_config.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/services/location_service.dart';

class AddressMapModal extends StatefulWidget {
  final DeliveryOrder order;
  final bool? isReadOnly;

  const AddressMapModal({
    super.key,
    required this.order,
    this.isReadOnly,
  });

  @override
  State<AddressMapModal> createState() => _AddressMapModalState();
}

class _AddressMapModalState extends State<AddressMapModal> {
  late MapController _mapController;
  late LatLng _currentPosition;
  late bool _isReadOnly;
  final TextEditingController _addressController = TextEditingController();
  final TextEditingController _postalCodeController = TextEditingController();
  final TextEditingController _communeController = TextEditingController();

  bool _isSaving = false;
  bool _isLocating = false;
  bool _isReverseGeocoding = false;
  bool _isSearchingAddress = false;
  bool _gpsCaptured = false;
  double? _accuracyMeters;
  ReverseGeocodeInfo? _currentReverseInfo;
  Timer? _debounceTimer;

  @override
  void initState() {
    super.initState();
    _mapController = MapController();

    // Priorite aux coordonnees certifiees de la commande si valides en Haiti
    final double? existingLat = widget.order.latitude;
    final double? existingLng = widget.order.longitude;
    final bool hasValidOrderGps = existingLat != null &&
        existingLng != null &&
        LocationService.isWithinHaitiBounds(existingLat, existingLng);

    // Par defaut, mode consultation si les coordonnees sont valides et ne requierent pas de capture obligatoire
    _isReadOnly = widget.isReadOnly ?? (hasValidOrderGps && !widget.order.requiresGpsValidation);

    final double initialLat = hasValidOrderGps ? existingLat : AppConfig.fallbackLatitude;
    final double initialLng = hasValidOrderGps ? existingLng : AppConfig.fallbackLongitude;
    _currentPosition = LatLng(initialLat, initialLng);
    _gpsCaptured = hasValidOrderGps;

    _addressController.text = widget.order.adresseLivraison;

    // Detection initiale de la commune et code postal a partir des coordonnees de base
    final initialReverse = LocationService.fallbackHaitiDetection(initialLat, initialLng);
    _communeController.text = initialReverse.commune;
    _postalCodeController.text = initialReverse.codePostal;
    _currentReverseInfo = initialReverse;

    // Si les coordonnees manquent, tenter d'abord de geocoder l'adresse textuelle pour centrer la carte au bon endroit
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!hasValidOrderGps) {
        if (widget.order.adresseLivraison.trim().isNotEmpty &&
            widget.order.adresseLivraison.trim() != "Adresse de livraison") {
          _geocodeOrderAddress(widget.order.adresseLivraison);
        } else {
          _acquireGpsLocation();
        }
      }
    });
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _addressController.dispose();
    _postalCodeController.dispose();
    _communeController.dispose();
    super.dispose();
  }

  /// Geocodage automatique de l'adresse de la commande a l'ouverture pour positionner la carte
  void _geocodeOrderAddress(String address) async {
    setState(() => _isSearchingAddress = true);
    final coords = await LocationService.geocodeAddress(address);
    if (!mounted) return;
    setState(() => _isSearchingAddress = false);

    if (coords != null) {
      setState(() {
        _currentPosition = coords;
      });
      try {
        _mapController.move(coords, 17.0);
      } catch (_) {}

      // Mettre a jour la commune et le code postal
      final rev = await LocationService.reverseGeocode(coords.latitude, coords.longitude);
      if (mounted) {
        setState(() {
          _currentReverseInfo = rev;
          _communeController.text = rev.commune;
          _postalCodeController.text = rev.codePostal;
        });
      }
    } else {
      _acquireGpsLocation();
    }
  }

  /// Recherche textuelle declenchee manuellement pour recentrer la carte sur une rue/adresse
  void _searchAddressOnMap() async {
    final raw = _addressController.text.trim();
    if (raw.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Veuillez saisir une adresse ou une rue à rechercher sur la carte."),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _isSearchingAddress = true);
    final coords = await LocationService.geocodeAddress(raw);
    if (!mounted) return;
    setState(() => _isSearchingAddress = false);

    if (coords != null) {
      setState(() {
        _currentPosition = coords;
        _gpsCaptured = false;
      });
      try {
        _mapController.move(coords, 17.5);
      } catch (_) {}

      final rev = await LocationService.reverseGeocode(coords.latitude, coords.longitude);
      if (mounted) {
        setState(() {
          _currentReverseInfo = rev;
          _communeController.text = rev.commune;
          _postalCodeController.text = rev.codePostal;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Carte recentrée sur : ${rev.commune} (${rev.codePostal})"),
            backgroundColor: const Color(0xFF047857),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Adresse introuvable avec précision. Pointez directement sur la carte pour l'ajuster."),
          backgroundColor: Colors.orange,
        ),
      );
    }
  }

  /// Pointeur interactif sur clic direct de la carte
  void _onMapTapped(TapPosition tapPosition, LatLng point) {
    if (_isReadOnly) return; // Mode consultation : le marqueur reste fixe sur le client
    if (!LocationService.isWithinHaitiBounds(point.latitude, point.longitude)) {
      return;
    }
    setState(() {
      _currentPosition = point;
      _gpsCaptured = false;
    });
    try {
      _mapController.move(point, _mapController.camera.zoom);
    } catch (_) {}

    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 300), () async {
      if (!mounted) return;
      setState(() => _isReverseGeocoding = true);
      final rev = await LocationService.reverseGeocode(point.latitude, point.longitude);
      if (!mounted) return;
      setState(() {
        _isReverseGeocoding = false;
        _currentReverseInfo = rev;
        _communeController.text = rev.commune;
        _postalCodeController.text = rev.codePostal;
      });
    });
  }

  void _acquireGpsLocation() async {
    setState(() => _isLocating = true);
    final locResult = await LocationService.getCurrentDeviceLocation();
    if (!mounted) return;

    setState(() {
      _isLocating = false;
      _currentPosition = locResult.position;
      _gpsCaptured = locResult.isFromGps;
      _accuracyMeters = locResult.accuracyMeters;
      if (locResult.reverseInfo != null) {
        _currentReverseInfo = locResult.reverseInfo;
        _communeController.text = locResult.reverseInfo!.commune;
        _postalCodeController.text = locResult.reverseInfo!.codePostal;

        // Si l'adresse etait vide ou basique, proposer l'adresse resolue
        if (_addressController.text.trim().isEmpty || _addressController.text.trim() == "Adresse de livraison") {
          _addressController.text = locResult.reverseInfo!.adresseFormatee;
        }
      }
    });

    try {
      _mapController.move(locResult.position, 17.5);
    } catch (_) {}

    if (locResult.isFromGps) {
      final commune = locResult.reverseInfo?.commune ?? "Zone";
      final codePostal = locResult.reverseInfo?.codePostal ?? "";
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Signal GPS haute précision acquis : $commune ($codePostal)."),
          backgroundColor: const Color(0xFF047857),
          duration: const Duration(seconds: 3),
        ),
      );
    } else if (locResult.errorMessage != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(locResult.errorMessage!),
          backgroundColor: Colors.orange.shade800,
          duration: const Duration(seconds: 4),
        ),
      );
    }
  }

  void _onPositionChanged(MapCamera camera, bool hasGesture) {
    if (_isReadOnly) return; // Mode consultation : déplacer la vue ne modifie pas la position du client
    if (!hasGesture) return;
    setState(() {
      _currentPosition = camera.center;
    });

    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 600), () async {
      if (!mounted) return;
      setState(() => _isReverseGeocoding = true);
      final rev = await LocationService.reverseGeocode(_currentPosition.latitude, _currentPosition.longitude);
      if (!mounted) return;
      setState(() {
        _isReverseGeocoding = false;
        _currentReverseInfo = rev;
        _communeController.text = rev.commune;
        _postalCodeController.text = rev.codePostal;
      });
    });
  }

  void _onSaveAddress() async {
    final rawAddress = _addressController.text.trim();
    final postalCode = _postalCodeController.text.trim();
    final commune = _communeController.text.trim();

    if (rawAddress.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Veuillez renseigner les détails de l'adresse de livraison."),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (postalCode.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Veuillez vérifier le code postal haïtien (ex: HT6110 pour Pétion-Ville)."),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (!LocationService.isWithinHaitiBounds(_currentPosition.latitude, _currentPosition.longitude)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Les coordonnées GPS sélectionnées sont situées en dehors d'Haïti. Veuillez recentrer la carte sur le lieu de livraison."),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Formatage propre avec la commune et le code postal verifie
    final fullValidatedAddress = rawAddress.contains(postalCode)
        ? rawAddress
        : "$rawAddress, $commune ($postalCode)";

    setState(() => _isSaving = true);

    final provider = Provider.of<DeliveryProvider>(context, listen: false);

    final success = await provider.confirmLocation(
      widget.order.id,
      lat: _currentPosition.latitude,
      lng: _currentPosition.longitude,
      rawAddress: fullValidatedAddress,
    );

    setState(() => _isSaving = false);

    if (mounted) {
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              "Coordonnées réelles et code postal ($postalCode) validés avec succès pour $commune !",
            ),
            backgroundColor: const Color(0xFF047857),
          ),
        );
        Navigator.pop(context, true);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Erreur lors de la confirmation des coordonnées sur le serveur."),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = AppTheme.isDark(context);
    final String currentCommune = _communeController.text.isNotEmpty ? _communeController.text : "Haïti";
    final String currentPostalCode = _postalCodeController.text.isNotEmpty ? _postalCodeController.text : "HT6110";

    return Dialog.fullscreen(
      child: Scaffold(
        appBar: AppBar(
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _isReadOnly ? "Position du Client sur la Carte" : "Localisation Réelle & Code Postal",
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
              ),
              Text(
                _isReadOnly
                    ? "${widget.order.clientNom} ($currentCommune — $currentPostalCode)"
                    : "Vérification certifiée pour Haïti ($currentCommune — $currentPostalCode)",
                style: TextStyle(fontSize: 11, color: isDark ? AppTheme.accentSky : Colors.white70),
              ),
            ],
          ),
          backgroundColor: isDark ? AppTheme.cardDark : AppTheme.primaryRoyal,
          foregroundColor: Colors.white,
          elevation: 0,
          actions: [
            IconButton(
              icon: const Icon(Icons.close),
              onPressed: () => Navigator.pop(context),
            ),
          ],
        ),
        body: Column(
          children: [
            // Bandeau indicateur de verification de code postal et precision
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: (_isReadOnly || _gpsCaptured)
                          ? const Color(0xFF047857).withValues(alpha: 0.15)
                          : Colors.orange.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      (_isReadOnly || _gpsCaptured) ? Icons.verified : Icons.warning_amber_rounded,
                      size: 16,
                      color: (_isReadOnly || _gpsCaptured) ? const Color(0xFF047857) : Colors.orange.shade800,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _isReadOnly
                              ? "Position GPS client certifiée : $currentCommune ($currentPostalCode)"
                              : (_gpsCaptured
                                  ? "GPS Téléphone certifié : $currentCommune ($currentPostalCode)"
                                  : "Position approximative — Cliquez sur 'Capturer GPS'"),
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: (_isReadOnly || _gpsCaptured) ? const Color(0xFF047857) : Colors.orange.shade900,
                          ),
                        ),
                        if (_isReadOnly)
                          Text(
                            "Adresse vérifiée et enregistrée pour la livraison",
                            style: TextStyle(fontSize: 11, color: AppTheme.mutedColor(context)),
                          )
                        else ...[
                          if (_currentReverseInfo?.quartier != null && _currentReverseInfo!.quartier!.isNotEmpty)
                            Text(
                              "Secteur : ${_currentReverseInfo!.quartier!}",
                              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: isDark ? AppTheme.accentSky : AppTheme.primaryRoyal),
                            ),
                          if (_accuracyMeters != null)
                            Text(
                              "Précision satellite : ± ${_accuracyMeters!.toStringAsFixed(1)} mètres",
                              style: TextStyle(fontSize: 10, color: AppTheme.mutedColor(context)),
                            ),
                        ],
                      ],
                    ),
                  ),
                  if (_isReverseGeocoding)
                    const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                ],
              ),
            ),

            // Carte Interactive OpenStreetMap
            Expanded(
              child: Stack(
                children: [
                  FlutterMap(
                    mapController: _mapController,
                    options: MapOptions(
                      initialCenter: _currentPosition,
                      initialZoom: 16.5,
                      onPositionChanged: _onPositionChanged,
                      onTap: _onMapTapped,
                    ),
                    children: [
                      TileLayer(
                        urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                        userAgentPackageName: 'com.transportlogistic.transportlogistic',
                      ),
                      MarkerLayer(
                        markers: [
                          Marker(
                            point: _currentPosition,
                            width: 54,
                            height: 54,
                            child: Container(
                              decoration: BoxDecoration(
                                color: (_isReadOnly || _gpsCaptured) ? const Color(0xFF047857) : AppTheme.primaryRoyal,
                                shape: BoxShape.circle,
                                boxShadow: const [
                                  BoxShadow(
                                    color: Colors.black38,
                                    blurRadius: 10,
                                    offset: Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: const Icon(
                                Icons.pin_drop,
                                color: Colors.white,
                                size: 32,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),

                  // Bouton flottant : Recentrer sur le client (mode consultation) OU Capturer GPS (mode edition)
                  Positioned(
                    top: 14,
                    left: 14,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _isReadOnly
                            ? AppTheme.primaryRoyal
                            : (_gpsCaptured ? const Color(0xFF047857) : AppTheme.primaryRoyal),
                        foregroundColor: Colors.white,
                        elevation: 4,
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                      ),
                      onPressed: _isReadOnly
                          ? () {
                              try {
                                _mapController.move(_currentPosition, 16.5);
                              } catch (_) {}
                            }
                          : (_isLocating ? null : _acquireGpsLocation),
                      icon: _isReadOnly
                          ? const Icon(Icons.center_focus_strong, size: 16)
                          : (_isLocating
                              ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                              : const Icon(Icons.gps_fixed, size: 16)),
                      label: Text(
                        _isReadOnly
                            ? "Recentrer sur le client"
                            : (_isLocating ? "Acquisition GPS..." : (_gpsCaptured ? "GPS Réel Actif" : "Capturer GPS")),
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),

                  // Badge coordonnees en direct
                  Positioned(
                    top: 14,
                    right: 14,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: AppTheme.surfaceColor(context),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: AppTheme.borderColor(context)),
                        boxShadow: const [
                          BoxShadow(color: Colors.black12, blurRadius: 6),
                        ],
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.my_location,
                            size: 14,
                            color: (_isReadOnly || _gpsCaptured) ? const Color(0xFF047857) : AppTheme.primaryRoyal,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            "${_currentPosition.latitude.toStringAsFixed(5)}, ${_currentPosition.longitude.toStringAsFixed(5)}",
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.titleColor(context),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Panneau bas de page : Fiche de consultation OU Formulaire d'edition
            Container(
              padding: EdgeInsets.fromLTRB(18, 14, 18, MediaQuery.of(context).padding.bottom + 16),
              decoration: BoxDecoration(
                color: AppTheme.surfaceColor(context),
                border: Border(top: BorderSide(color: AppTheme.borderColor(context))),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.08),
                    blurRadius: 10,
                    offset: const Offset(0, -3),
                  ),
                ],
              ),
              child: _isReadOnly
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Fiche de localisation validée
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF0F172A) : Colors.grey.shade50,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: AppTheme.borderColor(context)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(6),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF047857).withValues(alpha: 0.12),
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(Icons.check_circle_rounded, color: Color(0xFF047857), size: 18),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          widget.order.clientNom,
                                          style: TextStyle(
                                            fontWeight: FontWeight.w900,
                                            fontSize: 14,
                                            color: AppTheme.titleColor(context),
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        const Text(
                                          "Position GPS certifiée pour la livraison",
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: Color(0xFF047857),
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  IconButton(
                                    tooltip: "Recentrer la carte sur le client",
                                    icon: const Icon(Icons.my_location_rounded, color: AppTheme.primaryRoyal, size: 20),
                                    onPressed: () {
                                      try {
                                        _mapController.move(_currentPosition, 17.0);
                                      } catch (_) {}
                                    },
                                  ),
                                ],
                              ),
                              const Divider(height: 16),
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Icon(Icons.location_on_outlined, size: 16, color: isDark ? AppTheme.accentMint : AppTheme.primaryRoyal),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Text(
                                      widget.order.adresseLivraison.isNotEmpty
                                          ? widget.order.adresseLivraison
                                          : "$currentCommune ($currentPostalCode)",
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: AppTheme.titleColor(context),
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Row(
                                children: [
                                  Icon(Icons.gps_fixed, size: 13, color: AppTheme.mutedColor(context)),
                                  const SizedBox(width: 6),
                                  Text(
                                    "Coordonnées GPS : ${_currentPosition.latitude.toStringAsFixed(5)}, ${_currentPosition.longitude.toStringAsFixed(5)}",
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: AppTheme.mutedColor(context),
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton.icon(
                                style: OutlinedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                  side: BorderSide(color: AppTheme.borderColor(context)),
                                ),
                                icon: const Icon(Icons.edit_location_alt_outlined, size: 16),
                                label: const Text("Corriger position", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                onPressed: () {
                                  setState(() {
                                    _isReadOnly = false;
                                  });
                                },
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppTheme.primaryRoyal,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                  elevation: 0,
                                ),
                                icon: const Icon(Icons.close_rounded, size: 18),
                                label: const Text("Fermer la carte", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                onPressed: () => Navigator.pop(context),
                              ),
                            ),
                          ],
                        ),
                      ],
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Ligne Commune & Code Postal
                        Row(
                          children: [
                            Expanded(
                              flex: 2,
                              child: TextField(
                                controller: _communeController,
                                style: TextStyle(color: AppTheme.titleColor(context), fontSize: 13, fontWeight: FontWeight.bold),
                                decoration: InputDecoration(
                                  labelText: "Commune Haïti *",
                                  prefixIcon: const Icon(Icons.location_city, size: 18),
                                  isDense: true,
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                                  filled: true,
                                  fillColor: isDark ? const Color(0xFF0F172A) : Colors.grey.shade50,
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              flex: 1,
                              child: TextField(
                                controller: _postalCodeController,
                                style: const TextStyle(
                                  color: Color(0xFF047857),
                                  fontSize: 13,
                                  fontWeight: FontWeight.w900,
                                ),
                                decoration: InputDecoration(
                                  labelText: "Code Postal *",
                                  prefixIcon: const Icon(Icons.markunread_mailbox_outlined, size: 18),
                                  isDense: true,
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                                  filled: true,
                                  fillColor: isDark ? const Color(0xFF0F172A) : Colors.grey.shade50,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),

                        // Champ Adresse exacte avec synchronisation et recentrage de la carte
                        TextField(
                          controller: _addressController,
                          maxLines: 2,
                          style: TextStyle(color: AppTheme.titleColor(context), fontSize: 13),
                          decoration: InputDecoration(
                            labelText: "Adresse exacte & Repères visuels *",
                            hintText: "Ex: Rue Lamarre, Pétion-Ville, près de l'église...",
                            prefixIcon: const Icon(Icons.edit_location_alt_outlined, size: 20),
                            suffixIcon: Padding(
                              padding: const EdgeInsets.only(right: 6),
                              child: _isSearchingAddress
                                  ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: Center(
                                        child: SizedBox(
                                          width: 16,
                                          height: 16,
                                          child: CircularProgressIndicator(strokeWidth: 2),
                                        ),
                                      ),
                                    )
                                  : IconButton(
                                      icon: const Icon(Icons.travel_explore, size: 22),
                                      color: isDark ? AppTheme.accentSky : AppTheme.primaryRoyal,
                                      tooltip: "Recentrer la carte sur cette adresse",
                                      onPressed: _searchAddressOnMap,
                                    ),
                            ),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                            filled: true,
                            fillColor: isDark ? const Color(0xFF0F172A) : Colors.grey.shade50,
                          ),
                        ),
                        const SizedBox(height: 14),

                        // Bouton de confirmation
                        SizedBox(
                          height: 48,
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _gpsCaptured ? const Color(0xFF047857) : AppTheme.primaryRoyal,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                              elevation: 2,
                            ),
                            onPressed: _isSaving ? null : _onSaveAddress,
                            icon: _isSaving
                                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                                : const Icon(Icons.check_circle_outline, size: 20),
                            label: Text(
                              _isSaving ? "Validation en cours..." : "Confirmer l'Adresse & GPS pour le Client",
                              style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14),
                            ),
                          ),
                        ),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
