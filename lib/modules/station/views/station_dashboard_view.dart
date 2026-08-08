import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/theme_provider.dart';
import '../../../widgets/overlays/app_modal_sheet.dart';
import '../../../widgets/overlays/app_notifications.dart';
import '../../auth/providers/auth_provider.dart';
import '../providers/station_provider.dart';
import '../models/station_models.dart';

class StationDashboardView extends StatefulWidget {
  const StationDashboardView({super.key});

  @override
  State<StationDashboardView> createState() => _StationDashboardViewState();
}

class _StationDashboardViewState extends State<StationDashboardView> {
  final _plaqueController = TextEditingController();
  final _proprietaireController = TextEditingController();
  final _telephoneController = TextEditingController();
  final _searchController = TextEditingController();
  
  final double _montantHtg = 12500.0;
  String _modePaiement = "CASH";

  List<CamionStationModel> _searchResults = [];
  bool _isSearching = false;
  bool _hasSearched = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<StationProvider>(context, listen: false).fetchQueue();
    });
  }

  @override
  void dispose() {
    _plaqueController.dispose();
    _proprietaireController.dispose();
    _telephoneController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String query) async {
    final text = query.trim();
    if (text.isEmpty) {
      setState(() {
        _searchResults = [];
        _isSearching = false;
        _hasSearched = false;
      });
      return;
    }

    setState(() {
      _isSearching = true;
      _hasSearched = true;
    });

    final provider = Provider.of<StationProvider>(context, listen: false);
    final results = await provider.searchMatchingTrucks(text);

    if (!mounted) return;
    setState(() {
      _searchResults = results;
      _isSearching = false;
    });
  }

  void _openTicketModalForTruck(CamionStationModel? truck, {String initialPlaque = ""}) {
    final isKnown = truck != null;
    _plaqueController.text = isKnown ? truck.plaqueImmatriculation : initialPlaque.toUpperCase().trim();
    _proprietaireController.text = isKnown ? (truck.nomProprietaire ?? "") : "";
    _telephoneController.text = isKnown ? (truck.telephone ?? "") : "";

    AppModalSheet.showCustomBottomSheet(
      context: context,
      title: isKnown ? "Émission Ticket — Camion Référencé" : "Enregistrement Camion & Entrée",
      titleIcon: isKnown ? Icons.verified_outlined : Icons.add_circle_outline,
      child: StatefulBuilder(
        builder: (context, setModalState) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 8),

              TextField(
                controller: _plaqueController,
                readOnly: isKnown,
                textCapitalization: TextCapitalization.characters,
                decoration: InputDecoration(
                  labelText: "Plaque d'Immatriculation",
                  prefixIcon: const Icon(Icons.badge_outlined),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  filled: isKnown,
                  fillColor: isKnown ? Colors.grey.shade100 : null,
                ),
              ),
              const SizedBox(height: 12),

              TextField(
                controller: _proprietaireController,
                readOnly: isKnown,
                decoration: InputDecoration(
                  labelText: isKnown ? "Chauffeur / Propriétaire (Vérifié)" : "Nom du Chauffeur / Propriétaire *",
                  prefixIcon: const Icon(Icons.person_outline),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  filled: isKnown,
                  fillColor: isKnown ? Colors.grey.shade100 : null,
                ),
              ),
              const SizedBox(height: 12),

              TextField(
                controller: _telephoneController,
                readOnly: isKnown,
                keyboardType: TextInputType.phone,
                decoration: InputDecoration(
                  labelText: isKnown ? "Téléphone (Vérifié)" : "Numéro de Téléphone (Optionnel)",
                  prefixIcon: const Icon(Icons.phone_outlined),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  filled: isKnown,
                  fillColor: isKnown ? Colors.grey.shade100 : null,
                ),
              ),
              const SizedBox(height: 16),

              Text(
                "Montant Forfaitaire: ${_montantHtg.toStringAsFixed(2)} HTG",
                style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.primaryEmerald),
              ),
              const SizedBox(height: 12),

              DropdownButtonFormField<String>(
                value: _modePaiement,
                decoration: InputDecoration(
                  labelText: "Mode de Paiement",
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

              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  backgroundColor: AppTheme.primaryEmerald,
                ),
                onPressed: () async {
                  if (_plaqueController.text.trim().isEmpty) {
                    AppNotifications.showError(context, "Veuillez saisir une plaque d'immatriculation.");
                    return;
                  }

                  if (!isKnown && _proprietaireController.text.trim().isEmpty) {
                    AppNotifications.showError(context, "Le nom du propriétaire/chauffeur est obligatoire pour enregistrer un nouveau camion.");
                    return;
                  }

                  final provider = Provider.of<StationProvider>(context, listen: false);
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
                    _searchController.clear();
                    setState(() {
                      _searchResults = [];
                      _hasSearched = false;
                    });
                    AppNotifications.showSuccess(context, "Ticket émis avec succès !");
                  } else if (provider.errorMessage != null) {
                    AppNotifications.showError(context, provider.errorMessage!);
                  }
                },
                icon: const Icon(Icons.check_circle_outline),
                label: Text(
                  isKnown ? "Émettre le Ticket & Valider" : "Enregistrer le Camion & Émettre Ticket",
                  style: const TextStyle(fontWeight: FontWeight.bold),
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
    final authProvider = Provider.of<AuthProvider>(context);
    final stationProvider = Provider.of<StationProvider>(context);
    final themeProvider = Provider.of<ThemeProvider>(context);
    final user = authProvider.currentUser;

    return Scaffold(
      appBar: AppBar(
        title: Text(themeProvider.tr('station_title')),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => stationProvider.fetchQueue(),
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => authProvider.logout(context),
          ),
        ],
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () => stationProvider.fetchQueue(),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // User Badge Card
              Card(
                color: AppTheme.primaryEmerald,
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 24,
                        backgroundColor: Colors.white.withValues(alpha: 0.2),
                        child: const Icon(Icons.badge_outlined, color: Colors.white, size: 26),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              user?.nom ?? "Agent Station",
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                            ),
                            const SizedBox(height: 4),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppTheme.accentMint,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                user?.role ?? "AGENT_STATION",
                                style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                              ),
                            )
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // PROMINENT LIVE SEARCH BAR
              Card(
                elevation: 2,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        themeProvider.tr('search_quick'),
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppTheme.primaryEmerald),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _searchController,
                        onChanged: _onSearchChanged,
                        textCapitalization: TextCapitalization.characters,
                        decoration: InputDecoration(
                          hintText: themeProvider.tr('search_placeholder'),
                          prefixIcon: const Icon(Icons.search, color: AppTheme.primaryEmerald),
                          suffixIcon: _searchController.text.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.clear),
                                  onPressed: () {
                                    _searchController.clear();
                                    _onSearchChanged("");
                                  },
                                )
                              : null,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          contentPadding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),

                      // AUTOCOMPLETE MATCHING RESULTS LIST
                      if (_isSearching)
                        const Padding(
                          padding: EdgeInsets.all(16.0),
                          child: Center(child: CircularProgressIndicator()),
                        )
                      else if (_hasSearched) ...[
                        const SizedBox(height: 12),
                        if (_searchResults.isNotEmpty) ...[
                          const Text(
                            "Camions trouvés en base :",
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.textMuted),
                          ),
                          const SizedBox(height: 6),
                          ..._searchResults.map(
                            (truck) => Card(
                              color: AppTheme.accentMint.withValues(alpha: 0.08),
                              margin: const EdgeInsets.only(bottom: 8),
                              child: ListTile(
                                leading: const Icon(Icons.local_shipping, color: AppTheme.primaryEmerald),
                                title: Text(
                                  truck.plaqueImmatriculation,
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                ),
                                subtitle: Text(
                                  "Propriétaire: ${truck.nomProprietaire ?? 'Non renseigné'}",
                                  style: const TextStyle(fontSize: 13),
                                ),
                                trailing: ElevatedButton.icon(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppTheme.primaryEmerald,
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                  ),
                                  onPressed: () => _openTicketModalForTruck(truck),
                                  icon: const Icon(Icons.add, size: 16),
                                  label: const Text("Sélectionner", style: TextStyle(fontSize: 12)),
                                ),
                              ),
                            ),
                          ),
                        ] else ...[
                          // UNKNOWN TRUCK ACTION CARD
                          Card(
                            color: Colors.orange.shade50,
                            child: Padding(
                              padding: const EdgeInsets.all(14.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      const Icon(Icons.warning_amber_rounded, color: Colors.deepOrange),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          "Aucun camion correspondant à '${_searchController.text.trim()}'",
                                          style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.deepOrange),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 10),
                                  SizedBox(
                                    width: double.infinity,
                                    child: ElevatedButton.icon(
                                      style: ElevatedButton.styleFrom(backgroundColor: Colors.deepOrange),
                                      onPressed: () => _openTicketModalForTruck(null, initialPlaque: _searchController.text),
                                      icon: const Icon(Icons.add_business_outlined),
                                      label: Text("Enregistrer le camion ${_searchController.text.toUpperCase()}"),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Queue Section Title
              Text(
                "File d'attente en Station (${stationProvider.pendingTransactions.length})",
                style: Theme.of(context).textTheme.titleLarge?.copyWith(fontSize: 15),
              ),
              const SizedBox(height: 12),

              // Error Banner (if any)
              if (stationProvider.errorMessage != null) ...[
                Card(
                  color: Colors.red.shade50,
                  child: Padding(
                    padding: const EdgeInsets.all(14.0),
                    child: Row(
                      children: [
                        const Icon(Icons.error_outline, color: Colors.red),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            stationProvider.errorMessage!,
                            style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 13),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.refresh, color: Colors.red),
                          onPressed: () => stationProvider.fetchQueue(),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
              ],

              // QUEUE CARDS LIST (NO TEXT EMOJIS)
              if (stationProvider.isLoading)
                const Center(child: Padding(padding: EdgeInsets.all(32), child: CircularProgressIndicator()))
              else if (stationProvider.pendingTransactions.isEmpty)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(32.0),
                    child: Column(
                      children: const [
                        Icon(Icons.local_shipping_outlined, size: 48, color: AppTheme.textMuted),
                        SizedBox(height: 12),
                        Text(
                          "Aucun camion en file d'attente.",
                          style: TextStyle(color: AppTheme.textMuted, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                )
              else
                ...stationProvider.pendingTransactions.map((tx) => _buildTransactionCard(tx)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTransactionCard(TransactionStationModel tx) {
    final bool isEnCours = tx.statut == "EN_COURS";
    final Color statusColor = isEnCours ? AppTheme.accentMint : AppTheme.statusPending;
    final String statusLabel = isEnCours ? "Remplissage en cours" : "En attente";
    final IconData statusIcon = isEnCours ? Icons.water_drop_rounded : Icons.hourglass_top_rounded;

    final formattedTime = DateFormat('HH:mm').format(tx.heureEntree.toLocal());

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Flexible(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryEmerald.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      tx.codeTicket,
                      style: const TextStyle(fontWeight: FontWeight.w800, color: AppTheme.primaryEmerald),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(statusIcon, color: statusColor, size: 14),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            statusLabel,
                            style: TextStyle(fontWeight: FontWeight.bold, color: statusColor, fontSize: 12),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                const Icon(Icons.local_shipping, color: AppTheme.primaryEmerald, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    tx.camion?.plaqueImmatriculation ?? "Plaque Inconnue",
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            if (tx.camion?.nomProprietaire != null) ...[
              const SizedBox(height: 4),
              Text("Chauffeur: ${tx.camion!.nomProprietaire}", style: const TextStyle(color: AppTheme.textMuted)),
            ],
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Flexible(
                  child: Text(
                    "Heure d'entrée: $formattedTime",
                    style: const TextStyle(fontSize: 12, color: AppTheme.textMuted),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  "${tx.montantHtg.toStringAsFixed(2)} HTG",
                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                if (tx.statut == "EN_ATTENTE")
                  Expanded(
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(foregroundColor: AppTheme.accentMint),
                      onPressed: () async {
                        final ok = await Provider.of<StationProvider>(context, listen: false).updateStatus(tx.id, "EN_COURS");
                        if (context.mounted && ok) {
                          AppNotifications.showSuccess(context, "Vanne ouverte — Remplissage en cours.");
                        }
                      },
                      icon: const Icon(Icons.play_arrow),
                      label: const Text("Ouvrir Vanne"),
                    ),
                  ),
                if (tx.statut == "EN_COURS")
                  Expanded(
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(backgroundColor: AppTheme.accentMint),
                      onPressed: () async {
                        final ok = await Provider.of<StationProvider>(context, listen: false).updateStatus(tx.id, "TERMINEE");
                        if (context.mounted && ok) {
                          AppNotifications.showSuccess(context, "Remplissage terminé — Ticket validé !");
                        }
                      },
                      icon: const Icon(Icons.check),
                      label: const Text("Terminer & Fermer Vanne"),
                    ),
                  ),
              ],
            )
          ],
        ),
      ),
    );
  }
}
