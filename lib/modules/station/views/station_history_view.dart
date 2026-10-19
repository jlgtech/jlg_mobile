import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/theme_provider.dart';
import '../../../widgets/overlays/app_drawer.dart';
import '../../../widgets/layout/app_nav_tab.dart';
import '../providers/station_provider.dart';
import '../models/station_models.dart';
import '../widgets/station_receipt_modal.dart';

class StationHistoryView extends StatefulWidget {
  final ValueChanged<AppNavTab>? onSelectTab;
  const StationHistoryView({super.key, this.onSelectTab});

  @override
  State<StationHistoryView> createState() => _StationHistoryViewState();
}

class _StationHistoryViewState extends State<StationHistoryView> {
  String _selectedFilter = "TOUS"; // TOUS, TERMINEE, ANNULEE
  final _searchController = TextEditingController();
  String _searchQuery = "";

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final stationProvider = Provider.of<StationProvider>(context);
    final themeProvider = Provider.of<ThemeProvider>(context);

    // Filter historical transactions (TERMINEE or ANNULEE)
    final historyList = stationProvider.transactions.where((tx) {
      final isArchived = tx.statut == 'TERMINEE' || tx.statut == 'ANNULEE';
      if (!isArchived) return false;

      if (_selectedFilter != "TOUS" && tx.statut != _selectedFilter) {
        return false;
      }

      if (_searchQuery.isNotEmpty) {
        final query = _searchQuery.toUpperCase();
        final plaque = tx.camion?.plaqueImmatriculation.toUpperCase() ?? "";
        final ticket = tx.codeTicket.toUpperCase();
        final chauffeur = tx.camion?.nomProprietaire?.toUpperCase() ?? "";
        return plaque.contains(query) || ticket.contains(query) || chauffeur.contains(query);
      }

      return true;
    }).toList();

    return Scaffold(
      drawer: AppDrawer(
        selectedTab: AppNavTab.history,
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
        title: Text(themeProvider.tr('history_title')),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => stationProvider.fetchQueue(),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Search Bar & Filter Chips
            Container(
              padding: const EdgeInsets.all(16),
              color: Theme.of(context).cardColor,
              child: Column(
                children: [
                  TextField(
                    controller: _searchController,
                    onChanged: (val) {
                      setState(() => _searchQuery = val.trim());
                    },
                    decoration: InputDecoration(
                      hintText: themeProvider.tr('search_placeholder'),
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: _searchQuery.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear),
                              onPressed: () {
                                _searchController.clear();
                                setState(() => _searchQuery = "");
                              },
                            )
                          : null,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: AppTheme.borderLight),
                      ),
                      contentPadding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    physics: const BouncingScrollPhysics(),
                    child: Row(
                      children: [
                        _buildFilterChip("TOUS", themeProvider.tr('all')),
                        const SizedBox(width: 8),
                        _buildFilterChip("TERMINEE", themeProvider.tr('completed')),
                        const SizedBox(width: 8),
                        _buildFilterChip("ANNULEE", themeProvider.tr('cancelled')),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),

            // History List View
            Expanded(
              child: stationProvider.isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : historyList.isEmpty
                      ? ListView(
                          padding: const EdgeInsets.all(32),
                          children: [
                            Card(
                              child: Padding(
                                padding: const EdgeInsets.all(32.0),
                                child: Column(
                                  children: [
                                    const Icon(Icons.history_toggle_off, size: 56, color: AppTheme.textMuted),
                                    const SizedBox(height: 12),
                                    Text(
                                      themeProvider.tr('empty_history'),
                                      style: const TextStyle(color: AppTheme.textMuted, fontWeight: FontWeight.bold),
                                      textAlign: TextAlign.center,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        )
                      : ListView.builder(
                          padding: EdgeInsets.fromLTRB(16, 16, 16, MediaQuery.of(context).padding.bottom + 36),
                          itemCount: historyList.length,
                          itemBuilder: (context, index) {
                            final tx = historyList[index];
                            return _buildHistoryCard(tx, themeProvider);
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChip(String value, String label) {
    final isSelected = _selectedFilter == value;
    final isDark = AppTheme.isDark(context);
    return ChoiceChip(
      label: Text(
        label,
        style: TextStyle(
          color: isSelected
              ? (isDark ? const Color(0xFF03162C) : Colors.white)
              : AppTheme.titleColor(context),
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          fontSize: 12,
        ),
      ),
      selected: isSelected,
      selectedColor: isDark ? AppTheme.accentMint : AppTheme.primaryEmerald,
      backgroundColor: isDark ? AppTheme.cardDarkElevated : Colors.grey.shade100,
      side: BorderSide(
        color: isSelected
            ? (isDark ? AppTheme.accentMint : AppTheme.primaryEmerald)
            : (isDark ? AppTheme.borderDark : Colors.transparent),
      ),
      onSelected: (selected) {
        if (selected) setState(() => _selectedFilter = value);
      },
    );
  }

  Widget _buildHistoryCard(TransactionStationModel tx, ThemeProvider themeProvider) {
    final isDark = AppTheme.isDark(context);
    final isTerminee = tx.statut == "TERMINEE";
    final statusType = isTerminee ? 'DONE' : 'CANCELLED';
    final statusColor = AppTheme.badgeText(context, statusType);
    final statusLabel = isTerminee ? themeProvider.tr('completed') : themeProvider.tr('cancelled');
    final statusIcon = isTerminee ? Icons.check_circle_outlined : Icons.cancel_outlined;

    final formattedEntree = DateFormat('dd/MM/yyyy HH:mm').format(tx.heureEntree.toLocal());
    final formattedSortie = tx.heureSortie != null ? DateFormat('HH:mm').format(tx.heureSortie!.toLocal()) : "—";

    String dureeTxt = "—";
    if (tx.heureSortie != null) {
      final diff = tx.heureSortie!.difference(tx.heureEntree);
      final minutesTotal = diff.inMinutes;
      if (minutesTotal >= 60) {
        final hours = minutesTotal ~/ 60;
        final mins = minutesTotal % 60;
        dureeTxt = "${hours}h ${mins.toString().padLeft(2, '0')}m";
      } else {
        dureeTxt = "$minutesTotal min";
      }
    }

    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: AppTheme.borderColor(context), width: 1),
      ),
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
                      color: isDark
                          ? AppTheme.accentMint.withValues(alpha: 0.15)
                          : AppTheme.primaryEmerald.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      tx.codeTicket,
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        color: isDark ? AppTheme.accentMint : AppTheme.primaryEmerald,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppTheme.badgeBg(context, statusType),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppTheme.badgeBorder(context, statusType)),
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
                Icon(Icons.local_shipping_outlined, color: isDark ? AppTheme.accentMint : AppTheme.primaryEmerald, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    tx.camion?.plaqueImmatriculation ?? "Plaque Inconnue",
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: AppTheme.titleColor(context),
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Text(
                  "${tx.montantHtg.toStringAsFixed(2)} HTG",
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 14,
                    color: isDark ? AppTheme.accentMint : AppTheme.primaryEmerald,
                  ),
                ),
              ],
            ),
            if (tx.camion?.nomProprietaire != null) ...[
              const SizedBox(height: 4),
              Text("${themeProvider.tr('driver')}: ${tx.camion!.nomProprietaire}", style: TextStyle(color: AppTheme.mutedColor(context), fontSize: 13)),
            ],
            const Divider(height: 20),
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 8,
              runSpacing: 6,
              children: [
                Text("${themeProvider.tr('entry_time')}: $formattedEntree", style: TextStyle(fontSize: 11, color: AppTheme.mutedColor(context))),
                Text("${themeProvider.tr('exit_time')}: $formattedSortie", style: TextStyle(fontSize: 11, color: AppTheme.mutedColor(context))),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppTheme.badgeBg(context, 'IN_PROGRESS'),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    "${themeProvider.tr('duration')}: $dureeTxt",
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.badgeText(context, 'IN_PROGRESS')),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: isDark ? AppTheme.accentSky : AppTheme.primaryRoyal,
                  side: BorderSide(color: isDark ? AppTheme.accentSky : AppTheme.primaryRoyal),
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: () {
                  final stationProvider = Provider.of<StationProvider>(context, listen: false);
                  StationReceiptModal.show(
                    context,
                    transaction: tx,
                    companyConfig: stationProvider.companyConfig,
                  );
                },
                icon: const Icon(Icons.receipt_long, size: 16),
                label: const Text(
                  "Voir Reçu / Ticket Officiel",
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
