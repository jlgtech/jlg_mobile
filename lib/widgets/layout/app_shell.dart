import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/theme_provider.dart';
import '../../modules/station/providers/station_provider.dart';
import '../../modules/station/views/station_dashboard_view.dart';
import '../../modules/station/views/station_history_view.dart';
import '../../modules/settings/views/settings_view.dart';
import '../overlays/app_drawer.dart';
import '../overlays/app_modal_sheet.dart';
import '../overlays/app_notifications.dart';
import 'app_bottom_nav.dart';

class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _currentTabIndex = 0;

  final _plaqueController = TextEditingController();
  final _proprietaireController = TextEditingController();
  final _telephoneController = TextEditingController();
  final double _montantHtg = 12500.0;
  String _modePaiement = "CASH";

  Timer? _debounceTimer;

  @override
  void dispose() {
    _plaqueController.dispose();
    _proprietaireController.dispose();
    _telephoneController.dispose();
    _debounceTimer?.cancel();
    super.dispose();
  }

  void _openNewTicketModal() {
    _plaqueController.clear();
    _proprietaireController.clear();
    _telephoneController.clear();

    bool isSearching = false;
    bool isSearched = false;
    bool isTruckFound = false;

    AppModalSheet.showCustomBottomSheet(
      context: context,
      title: "Entrée Camion & Ticket",
      titleIcon: Icons.local_shipping_outlined,
      child: StatefulBuilder(
        builder: (context, setModalState) {
          final provider = Provider.of<StationProvider>(context, listen: false);
          final themeProvider = Provider.of<ThemeProvider>(context, listen: false);

          void handlePlaqueChanged(String query) {
            _debounceTimer?.cancel();
            final text = query.trim().toUpperCase();
            if (text.length < 2) {
              setModalState(() {
                isSearching = false;
                isSearched = false;
                isTruckFound = false;
                _proprietaireController.clear();
                _telephoneController.clear();
              });
              return;
            }

            setModalState(() {
              isSearching = true;
            });

            _debounceTimer = Timer(const Duration(milliseconds: 350), () async {
              final truck = await provider.searchTruck(text);
              if (!context.mounted) return;

              setModalState(() {
                isSearching = false;
                isSearched = true;
                if (truck != null) {
                  isTruckFound = true;
                  _proprietaireController.text = truck.nomProprietaire ?? "";
                  _telephoneController.text = truck.telephone ?? "";
                } else {
                  isTruckFound = false;
                }
              });
            });
          }

          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                controller: _plaqueController,
                textCapitalization: TextCapitalization.characters,
                onChanged: handlePlaqueChanged,
                decoration: InputDecoration(
                  labelText: "${themeProvider.tr('search_placeholder')} *",
                  prefixIcon: const Icon(Icons.badge_outlined, color: AppTheme.primaryEmerald),
                  suffixIcon: isSearching
                      ? const Padding(
                          padding: EdgeInsets.all(12),
                          child: SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.primaryEmerald),
                          ),
                        )
                      : (_plaqueController.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear, size: 18),
                              onPressed: () {
                                _plaqueController.clear();
                                handlePlaqueChanged("");
                              },
                            )
                          : null),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 12),

              // RED ALERT CARD IF TRUCK ALREADY EXISTS IN DB WHEN TRYING TO ADD
              if (isSearched && isTruckFound) ...[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.red.shade300),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline, color: Colors.red, size: 20),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          "Le camion ${_plaqueController.text} existe déjà en base (Propriétaire: ${_proprietaireController.text}).",
                          style: const TextStyle(
                            color: Colors.red,
                            fontWeight: FontWeight.bold,
                            fontSize: 12.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
              ],

              // Chauffeur / Propriétaire
              TextField(
                controller: _proprietaireController,
                readOnly: isTruckFound,
                decoration: InputDecoration(
                  labelText: themeProvider.tr('driver_owner'),
                  prefixIcon: const Icon(Icons.person_outline),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  filled: isTruckFound,
                  fillColor: isTruckFound ? Colors.grey.shade100 : null,
                ),
              ),
              const SizedBox(height: 12),

              // Téléphone
              TextField(
                controller: _telephoneController,
                readOnly: isTruckFound,
                keyboardType: TextInputType.phone,
                decoration: InputDecoration(
                  labelText: themeProvider.tr('phone'),
                  prefixIcon: const Icon(Icons.phone_outlined),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  filled: isTruckFound,
                  fillColor: isTruckFound ? Colors.grey.shade100 : null,
                ),
              ),
              const SizedBox(height: 16),

              // Forfait Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(themeProvider.tr('amount'), style: const TextStyle(color: AppTheme.textMuted, fontSize: 13)),
                  Text(
                    "${_montantHtg.toStringAsFixed(2)} HTG",
                    style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.primaryEmerald, fontSize: 15),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Mode de Paiement Dropdown
              DropdownButtonFormField<String>(
                value: _modePaiement,
                decoration: InputDecoration(
                  labelText: themeProvider.tr('payment_mode'),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
                items: const [
                  DropdownMenuItem(value: "CASH", child: Text("CASH (Espèces)")),
                  DropdownMenuItem(value: "VIREMENT", child: Text("VIREMENT")),
                  DropdownMenuItem(value: "CHEQUE", child: Text("CHÈQUE")),
                ],
                onChanged: (val) {
                  if (val != null) setModalState(() => _modePaiement = val);
                },
              ),
              const SizedBox(height: 24),

              // Single Main Submit Button
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  backgroundColor: AppTheme.primaryEmerald,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: () async {
                  if (_plaqueController.text.trim().isEmpty) {
                    AppNotifications.showError(context, "Veuillez saisir une plaque d'immatriculation.");
                    return;
                  }

                  if (!isTruckFound && _proprietaireController.text.trim().isEmpty) {
                    AppNotifications.showError(context, "Le nom du propriétaire/chauffeur est obligatoire pour un nouveau camion.");
                    return;
                  }

                  final success = await provider.createTicket(
                    plaqueImmatriculation: _plaqueController.text,
                    montantHtg: _montantHtg,
                    modePaiement: _modePaiement,
                    nomProprietaire: _proprietaireController.text,
                    telephone: _telephoneController.text,
                  );

                  if (!mounted) return;
                  if (success) {
                    Navigator.pop(context);
                    _plaqueController.clear();
                    _proprietaireController.clear();
                    _telephoneController.clear();
                    AppNotifications.showSuccess(context, "Ticket émis avec succès !");
                  } else if (provider.errorMessage != null) {
                    AppNotifications.showError(context, provider.errorMessage!);
                  }
                },
                icon: const Icon(Icons.check_circle_outline),
                label: Text(
                  isTruckFound ? themeProvider.tr('issue_ticket') : themeProvider.tr('register_and_issue'),
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final List<Widget> pages = [
      const StationDashboardView(),
      const StationHistoryView(),
      const SettingsView(),
    ];

    return Scaffold(
      drawer: const AppDrawer(),
      body: pages[_currentTabIndex],
      bottomNavigationBar: AppBottomNav(
        currentIndex: _currentTabIndex,
        onTap: (index) {
          setState(() {
            _currentTabIndex = index;
          });
        },
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      floatingActionButton: _currentTabIndex == 0
          ? FloatingActionButton.extended(
              onPressed: _openNewTicketModal,
              backgroundColor: AppTheme.primaryEmerald,
              elevation: 4,
              icon: const Icon(Icons.add, color: Colors.white),
              label: Text(
                Provider.of<ThemeProvider>(context).tr('truck_entry'),
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
            )
          : null,
    );
  }
}
