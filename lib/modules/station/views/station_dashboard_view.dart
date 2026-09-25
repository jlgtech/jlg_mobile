import 'dart:async';
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

import '../../../widgets/overlays/app_drawer.dart';
import '../../../widgets/layout/app_nav_tab.dart';

class StationDashboardView extends StatefulWidget {
  final ValueChanged<AppNavTab>? onSelectTab;
  const StationDashboardView({super.key, this.onSelectTab});

  @override
  State<StationDashboardView> createState() => _StationDashboardViewState();
}

class _StationDashboardViewState extends State<StationDashboardView> {
  final _plaqueController = TextEditingController();
  final _proprietaireController = TextEditingController();
  final _telephoneController = TextEditingController();
  final _searchController = TextEditingController();
  
  String _modePaiement = "CASH";

  List<CamionStationModel> _searchResults = [];
  bool _isSearching = false;
  bool _hasSearched = false;

  Timer? _searchDebounceTimer;

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
    _searchDebounceTimer?.cancel();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    _searchDebounceTimer?.cancel();
    final text = query.trim().toUpperCase();
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
    });

    _searchDebounceTimer = Timer(const Duration(milliseconds: 300), () async {
      final provider = Provider.of<StationProvider>(context, listen: false);
      final results = await provider.searchMatchingTrucks(text);

      if (!mounted) return;
      setState(() {
        _searchResults = results;
        _isSearching = false;
        _hasSearched = true;
      });
    });
  }

  void _onSubmitPlaque(String query) async {
    final text = query.trim().toUpperCase();
    if (text.isEmpty) return;

    _searchDebounceTimer?.cancel();
    setState(() => _isSearching = true);

    final provider = Provider.of<StationProvider>(context, listen: false);
    final results = await provider.searchMatchingTrucks(text);

    if (!mounted) return;
    setState(() {
      _searchResults = results;
      _isSearching = false;
      _hasSearched = true;
    });

    final exactMatch = results.where((t) => t.plaqueImmatriculation.toUpperCase() == text).firstOrNull;
    if (exactMatch != null) {
      _openTicketModalForTruck(exactMatch);
    } else if (results.isNotEmpty) {
      _openTicketModalForTruck(results.first);
    } else {
      _openTicketModalForTruck(null, initialPlaque: text);
    }
  }

  void _openTicketModalForTruck(CamionStationModel? truck, {String initialPlaque = ""}) {
    final isKnown = truck != null;
    _plaqueController.text = isKnown ? truck.plaqueImmatriculation : initialPlaque.toUpperCase().trim();
    _proprietaireController.text = isKnown ? (truck.nomProprietaire ?? "") : "";
    _telephoneController.text = isKnown ? (truck.telephone ?? "") : "";

    final provider = Provider.of<StationProvider>(context, listen: false);
    final currentTarif = provider.tarifHtg;

    AppModalSheet.showCustomBottomSheet(
      context: context,
      title: isKnown ? "Émission Ticket — Camion Référencé" : "Ajouter le Camion & Émettre Ticket",
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
                "Montant Forfaitaire (Tarif Officiel): ${currentTarif.toStringAsFixed(2)} HTG",
                style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.primaryEmerald),
              ),
              const SizedBox(height: 12),

              DropdownButtonFormField<String>(
                initialValue: _modePaiement,
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

                  final scaffoldMessenger = ScaffoldMessenger.of(context);
                  final navigator = Navigator.of(context);

                  final success = await provider.createTicket(
                    plaqueImmatriculation: _plaqueController.text,
                    montantHtg: currentTarif,
                    modePaiement: _modePaiement,
                    nomProprietaire: _proprietaireController.text,
                    telephone: _telephoneController.text,
                  );

                  if (!mounted) return;

                  if (success) {
                    navigator.pop();
                    _searchController.clear();
                    setState(() {
                      _searchResults = [];
                      _hasSearched = false;
                    });
                    scaffoldMessenger.showSnackBar(
                      const SnackBar(
                        content: Text("Ticket émis avec succès !"),
                        backgroundColor: Color(0xFF0C4E55),
                      ),
                    );
                  } else if (provider.errorMessage != null) {
                    scaffoldMessenger.showSnackBar(
                      SnackBar(
                        content: Text(provider.errorMessage!),
                        backgroundColor: Colors.red.shade700,
                      ),
                    );
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
      drawer: AppDrawer(
        selectedTab: AppNavTab.station,
        onSelectTab: widget.onSelectTab,
      ),
      appBar: AppBar(
        leading: Builder(
          builder: (context) => IconButton(
            icon: const Icon(Icons.menu),
            tooltip: "Ouvrir le menu principal",
            onPressed: () => Scaffold.of(context).openDrawer(),
          ),
        ),
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
              // Header Station Summary & Agent Identity Card
              Container(
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Color(0xFF0C4E55),
                      Color(0xFF063C42),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF0C4E55).withValues(alpha: 0.25),
                      blurRadius: 12,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 26,
                          backgroundColor: Colors.white.withValues(alpha: 0.18),
                          child: const Icon(Icons.water_drop_rounded, color: Colors.white, size: 28),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                user?.nom ?? "Agent Station",
                                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 17),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                "Piste de Remplissage — ${user?.role ?? 'AGENT'}",
                                style: const TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w600),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    Row(
                      children: [
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  "En Attente",
                                  style: TextStyle(color: Colors.white70, fontSize: 10, fontWeight: FontWeight.bold),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  "${stationProvider.pendingTransactions.where((t) => t.statut == 'EN_ATTENTE').length} Camions",
                                  style: const TextStyle(color: Colors.amberAccent, fontSize: 15, fontWeight: FontWeight.w900),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  "En Remplissage",
                                  style: TextStyle(color: Colors.white70, fontSize: 10, fontWeight: FontWeight.bold),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  "${stationProvider.pendingTransactions.where((t) => t.statut == 'EN_COURS').length} Vannes",
                                  style: const TextStyle(color: Color(0xFF38BDF8), fontSize: 15, fontWeight: FontWeight.w900),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // PROMINENT LIVE TRUCK ENTRY & CONTROL CARD
              Card(
                elevation: 2,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: AppTheme.primaryEmerald.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(Icons.pin_outlined, color: AppTheme.primaryEmerald, size: 20),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  "Entrée Camion — Contrôle de la Plaque",
                                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppTheme.primaryEmerald),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  "Tapez la plaque d'immatriculation pour émettre un ticket ou ajouter un camion",
                                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      TextField(
                        controller: _searchController,
                        onChanged: _onSearchChanged,
                        onSubmitted: _onSubmitPlaque,
                        textInputAction: TextInputAction.go,
                        textCapitalization: TextCapitalization.characters,
                        style: const TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.1),
                        decoration: InputDecoration(
                          hintText: "Ex : AA-12345...",
                          labelText: "Plaque d'immatriculation",
                          prefixIcon: const Icon(Icons.local_shipping_outlined, color: AppTheme.primaryEmerald),
                          suffixIcon: _isSearching
                              ? const Padding(
                                  padding: EdgeInsets.all(12),
                                  child: SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.primaryEmerald),
                                  ),
                                )
                              : (_searchController.text.isNotEmpty
                                  ? IconButton(
                                      icon: const Icon(Icons.clear),
                                      onPressed: () {
                                        _searchController.clear();
                                        _onSearchChanged("");
                                      },
                                    )
                                  : null),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          contentPadding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                        ),
                      ),

                      // AUTOCOMPLETE MATCHING RESULTS LIST OR PROMPT TO ADD
                      if (_hasSearched && !_isSearching) ...[
                        const SizedBox(height: 14),
                        if (_searchResults.isNotEmpty) ...[
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                "Camion(s) trouvé(s) (${_searchResults.length}) :",
                                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.textMuted),
                              ),
                              Text(
                                "Sélectionnez pour émettre le ticket",
                                style: TextStyle(fontSize: 11, color: Colors.grey.shade600, fontStyle: FontStyle.italic),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          ..._searchResults.map(
                            (truck) => Card(
                              elevation: 0,
                              color: AppTheme.accentMint.withValues(alpha: 0.08),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                                side: BorderSide(color: AppTheme.primaryEmerald.withValues(alpha: 0.25)),
                              ),
                              margin: const EdgeInsets.only(bottom: 8),
                              child: ListTile(
                                leading: CircleAvatar(
                                  backgroundColor: AppTheme.primaryEmerald.withValues(alpha: 0.15),
                                  child: const Icon(Icons.local_shipping, color: AppTheme.primaryEmerald, size: 20),
                                ),
                                title: Text(
                                  truck.plaqueImmatriculation,
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, letterSpacing: 0.8),
                                ),
                                subtitle: Text(
                                  "Chauffeur: ${truck.nomProprietaire ?? 'Non renseigné'}${truck.telephone != null ? ' • ${truck.telephone}' : ''}",
                                  style: const TextStyle(fontSize: 13),
                                ),
                                trailing: ElevatedButton.icon(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppTheme.primaryEmerald,
                                    foregroundColor: Colors.white,
                                    elevation: 0,
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                  ),
                                  onPressed: () => _openTicketModalForTruck(truck),
                                  icon: const Icon(Icons.confirmation_number_outlined, size: 16),
                                  label: const Text("Émettre Ticket", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                                ),
                              ),
                            ),
                          ),
                        ] else ...[
                          // PROMPT TO ADD UNKNOWN TRUCK
                          Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF0FDF4),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: const Color(0xFF86EFAC)),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    const Icon(Icons.help_outline, color: Color(0xFF15803D), size: 22),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        "Le camion '${_searchController.text.toUpperCase().trim()}' n'existe pas encore.",
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 13.5,
                                          color: Color(0xFF166534),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  "Ce véhicule n'est pas encore enregistré dans le système. Souhaitez-vous l'ajouter pour émettre son ticket d'entrée ?",
                                  style: TextStyle(fontSize: 12.5, color: Colors.green.shade900),
                                ),
                                const SizedBox(height: 12),
                                SizedBox(
                                  width: double.infinity,
                                  child: ElevatedButton.icon(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFF0C4E55),
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(vertical: 12),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                    ),
                                    onPressed: () => _openTicketModalForTruck(null, initialPlaque: _searchController.text.trim()),
                                    icon: const Icon(Icons.add_circle_outline, size: 18),
                                    label: Text(
                                      "Ajouter le camion '${_searchController.text.toUpperCase().trim()}' & émettre le ticket",
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                    ),
                                  ),
                                ),
                              ],
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
                        final provider = Provider.of<StationProvider>(context, listen: false);
                        final messenger = ScaffoldMessenger.of(context);
                        final ok = await provider.updateStatus(tx.id, "EN_COURS");
                        if (ok) {
                          messenger.showSnackBar(const SnackBar(
                            content: Text("Vanne ouverte — Remplissage en cours."),
                            backgroundColor: Color(0xFF0C4E55),
                          ));
                        } else if (provider.errorMessage != null) {
                          messenger.showSnackBar(SnackBar(
                            content: Text(provider.errorMessage!),
                            backgroundColor: Colors.red,
                          ));
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
                        final provider = Provider.of<StationProvider>(context, listen: false);
                        final messenger = ScaffoldMessenger.of(context);
                        final ok = await provider.updateStatus(tx.id, "TERMINEE");
                        if (ok) {
                          messenger.showSnackBar(const SnackBar(
                            content: Text("Remplissage terminé — Ticket validé !"),
                            backgroundColor: Color(0xFF0C4E55),
                          ));
                        } else if (provider.errorMessage != null) {
                          messenger.showSnackBar(SnackBar(
                            content: Text(provider.errorMessage!),
                            backgroundColor: Colors.red,
                          ));
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
