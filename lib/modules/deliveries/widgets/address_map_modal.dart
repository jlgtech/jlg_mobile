import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import '../models/delivery_model.dart';
import '../providers/delivery_provider.dart';
import '../../../core/config/app_config.dart';
import '../../../core/theme/app_theme.dart';

class AddressMapModal extends StatefulWidget {
  final DeliveryOrder order;

  const AddressMapModal({
    super.key,
    required this.order,
  });

  @override
  State<AddressMapModal> createState() => _AddressMapModalState();
}

class _AddressMapModalState extends State<AddressMapModal> {
  late MapController _mapController;
  late LatLng _currentPosition;
  final TextEditingController _addressController = TextEditingController();
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _mapController = MapController();
    
    // Coordonnees de la commande si disponibles, sinon coordonnees de repli (centre Port-au-Prince)
    final double initialLat = widget.order.latitude ?? AppConfig.fallbackLatitude;
    final double initialLng = widget.order.longitude ?? AppConfig.fallbackLongitude;
    _currentPosition = LatLng(initialLat, initialLng);

    _addressController.text = widget.order.adresseLivraison;
  }

  @override
  void dispose() {
    _addressController.dispose();
    super.dispose();
  }

  void _onSaveAddress() async {
    if (_addressController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Veuillez renseigner une description d'adresse."),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isSaving = true);

    final provider = Provider.of<DeliveryProvider>(context, listen: false);
    
    // Save confirmed location and address without forcing order completion
    final success = await provider.confirmLocation(
      widget.order.id,
      lat: _currentPosition.latitude,
      lng: _currentPosition.longitude,
      rawAddress: _addressController.text.trim(),
    );

    setState(() => _isSaving = false);

    if (mounted) {
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              "Adresse et position GPS (${_currentPosition.latitude.toStringAsFixed(4)}, ${_currentPosition.longitude.toStringAsFixed(4)}) confirmées pour les prochaines livraisons !",
            ),
            backgroundColor: const Color(0xFF0C4E55),
          ),
        );
        Navigator.pop(context, true);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Erreur lors de la sauvegarde des coordonnées GPS."),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = AppTheme.isDark(context);

    return Dialog.fullscreen(
      child: Scaffold(
        appBar: AppBar(
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "Localisation Première Livraison",
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
              ),
              Text(
                "Déplacez la carte pour caler le repère précis du client",
                style: TextStyle(fontSize: 11, color: isDark ? AppTheme.accentMint : Colors.white70),
              ),
            ],
          ),
          backgroundColor: isDark ? const Color(0xFF111827) : const Color(0xFF0C4E55),
          foregroundColor: Colors.white,
          elevation: 0,
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(1),
            child: Container(
              color: isDark ? const Color(0xFF1E293B) : Colors.transparent,
              height: 1,
            ),
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.close),
              onPressed: () => Navigator.pop(context),
            ),
          ],
        ),
        body: Column(
          children: [
            // Interactive Map Area
            Expanded(
              child: Stack(
                children: [
                  FlutterMap(
                    mapController: _mapController,
                    options: MapOptions(
                      initialCenter: _currentPosition,
                      initialZoom: 15.0,
                      onPositionChanged: (position, hasGesture) {
                        if (hasGesture) {
                          setState(() {
                            _currentPosition = position.center;
                          });
                        }
                      },
                    ),
                    children: [
                      TileLayer(
                        urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                        userAgentPackageName: 'com.jlgreen.jlg_mobile',
                      ),
                      MarkerLayer(
                        markers: [
                          Marker(
                            point: _currentPosition,
                            width: 50,
                            height: 50,
                            child: Container(
                              decoration: BoxDecoration(
                                color: isDark ? AppTheme.accentMint : const Color(0xFF0C4E55),
                                shape: BoxShape.circle,
                                boxShadow: const [
                                  BoxShadow(
                                    color: Colors.black26,
                                    blurRadius: 8,
                                    offset: Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: Icon(
                                Icons.pin_drop,
                                color: isDark ? const Color(0xFF0B0F19) : Colors.white,
                                size: 30,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),

                  // Floating GPS Reposition Badge
                  Positioned(
                    top: 16,
                    right: 16,
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
                            size: 16,
                            color: isDark ? AppTheme.accentMint : const Color(0xFF0C4E55),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            "${_currentPosition.latitude.toStringAsFixed(4)}, ${_currentPosition.longitude.toStringAsFixed(4)}",
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: isDark ? AppTheme.accentMint : const Color(0xFF0C4E55),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Bottom Form & Confirmation Section
            Container(
              padding: EdgeInsets.fromLTRB(20, 16, 20, MediaQuery.of(context).padding.bottom + 20),
              decoration: BoxDecoration(
                color: AppTheme.surfaceColor(context),
                border: Border(top: BorderSide(color: AppTheme.borderColor(context))),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.1),
                    blurRadius: 12,
                    offset: const Offset(0, -4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: isDark
                              ? AppTheme.accentMint.withValues(alpha: 0.15)
                              : const Color(0xFF0C4E55).withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.person,
                          color: isDark ? AppTheme.accentMint : const Color(0xFF0C4E55),
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          widget.order.clientNom,
                          style: TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 16,
                            color: AppTheme.titleColor(context),
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF451A03).withValues(alpha: 0.5) : Colors.amber.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: isDark ? const Color(0xFFD97706) : Colors.amber.shade300),
                        ),
                        child: Text(
                          "1ère Livraison",
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: isDark ? const Color(0xFFFBBF24) : Colors.amber.shade800,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  TextField(
                    controller: _addressController,
                    maxLines: 2,
                    style: TextStyle(color: AppTheme.titleColor(context), fontSize: 13),
                    decoration: InputDecoration(
                      labelText: "Adresse exacte du point de livraison *",
                      hintText: "Précisez l'adresse, repères visuels (ex: près de l'église...)",
                      prefixIcon: const Icon(Icons.edit_location_alt_outlined),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                      filled: true,
                      fillColor: isDark ? const Color(0xFF0F172A) : Colors.grey.shade50,
                    ),
                  ),

                  const SizedBox(height: 16),

                  SizedBox(
                    height: 52,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isDark ? AppTheme.accentMint : const Color(0xFF0C4E55),
                        foregroundColor: isDark ? const Color(0xFF0B0F19) : Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        elevation: 3,
                      ),
                      onPressed: _isSaving ? null : _onSaveAddress,
                      icon: const Icon(Icons.check_circle_outline),
                      label: _isSaving
                          ? CircularProgressIndicator(color: isDark ? const Color(0xFF0B0F19) : Colors.white)
                          : const Text(
                              "Confirmer l'Adresse & GPS pour le Client",
                              style: TextStyle(fontWeight: FontWeight.w900, fontSize: 14),
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
