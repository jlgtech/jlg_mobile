import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/delivery_model.dart';
import '../providers/delivery_provider.dart';
import '../widgets/offline_status_banner.dart';
import 'delivery_detail_view.dart';
import '../../auth/providers/auth_provider.dart';
import '../../../widgets/overlays/app_drawer.dart';
import '../../../widgets/layout/app_nav_tab.dart';
import '../../../widgets/buttons/notification_bell_button.dart';
import '../../../core/theme/app_theme.dart';

class DeliveryListView extends StatefulWidget {
  final ValueChanged<AppNavTab>? onSelectTab;
  const DeliveryListView({super.key, this.onSelectTab});

  @override
  State<DeliveryListView> createState() => _DeliveryListViewState();
}

class _DeliveryListViewState extends State<DeliveryListView> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<DeliveryProvider>(context, listen: false).fetchOrders();
    });
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final user = authProvider.currentUser;

    return Scaffold(
      drawer: AppDrawer(
        selectedTab: AppNavTab.deliveries,
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
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Tournée Livreur',
              style: TextStyle(fontWeight: FontWeight.w900, fontSize: 17),
            ),
            Text(
              user?.nom ?? 'Chauffeur-Livreur',
              style: const TextStyle(fontSize: 11, color: Colors.white70),
            ),
          ],
        ),
        backgroundColor: AppTheme.primaryRoyal,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          const NotificationBellButton(color: Colors.white),
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: "Actualiser la tournée",
            onPressed: () {
              Provider.of<DeliveryProvider>(context, listen: false).fetchOrders();
            },
          ),
          Consumer<DeliveryProvider>(
            builder: (context, provider, _) => IconButton(
              icon: Icon(
                provider.isOffline ? Icons.cloud_off : Icons.cloud_download_outlined,
                color: provider.isOffline ? Colors.orange.shade300 : Colors.white,
              ),
              tooltip: provider.isOffline
                  ? "Hors ligne — cache disponible"
                  : "Télécharger pour usage offline",
              onPressed: provider.isOffline
                  ? null
                  : () async {
                      final messenger = ScaffoldMessenger.of(context);
                      final ok = await provider.downloadForOffline();
                      messenger.showSnackBar(SnackBar(
                        content: Text(
                          ok
                            ? "Livraisons téléchargées — disponibles hors ligne."
                            : "Impossible de mettre à jour le cache.",
                        ),
                        backgroundColor: ok ? AppTheme.primaryRoyal : Colors.red.shade700,
                        duration: const Duration(seconds: 3),
                      ));
                    },
            ),
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: "Se déconnecter",
            onPressed: () => authProvider.logout(context),
          ),
        ],
      ),
      body: Consumer<DeliveryProvider>(
        builder: (context, provider, child) {
          final orders = provider.filteredOrders;
          final myAssignedTourOrders = provider.orders.where((o) => !o.isPickupOrder && !o.isUnassigned).toList();
          final totalCount = myAssignedTourOrders.length;
          final completedCount = myAssignedTourOrders.where((o) => o.statut == 'CLOTUREE' || o.statut == 'LIVREE_EN_ATTENTE').length;
          final progressRatio = totalCount > 0 ? (completedCount / totalCount) : 0.0;

          return SafeArea(
            top: false,
            bottom: true,
            child: Column(
              children: [
                // Banniere statut offline / sync
                const OfflineStatusBanner(),
              // Hero Tour Progress Header Card
              Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      AppTheme.primaryRoyal,
                      AppTheme.primaryDeep,
                    ],
                  ),
                ),
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
                      ),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(10),
                                    decoration: BoxDecoration(
                                      color: AppTheme.accentSky.withValues(alpha: 0.2),
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(Icons.route, color: AppTheme.accentSky, size: 22),
                                  ),
                                  const SizedBox(width: 12),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        "Tournée",
                                        style: TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.bold),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        "$completedCount / $totalCount livrées",
                                        style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w900),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                decoration: BoxDecoration(
                                  color: AppTheme.accentSky,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  "${(progressRatio * 100).toInt()}%",
                                  style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w900),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: LinearProgressIndicator(
                              value: progressRatio,
                              minHeight: 8,
                              backgroundColor: Colors.white.withValues(alpha: 0.2),
                              color: AppTheme.accentSky,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // Filter Tabs (Tournée / Bourse / Livrées / Litiges)
              Container(
                color: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                child: Row(
                  children: [
                    _buildTabButton(context, provider, 'A_LIVRER', 'Tournée', Icons.local_shipping_outlined),
                    const SizedBox(width: 6),
                    _buildTabButton(context, provider, 'DISPONIBLES', 'Bourse', Icons.radar_outlined, badgeCount: provider.availableOrdersCount),
                    const SizedBox(width: 6),
                    _buildTabButton(context, provider, 'LIVREES', 'Livrées', Icons.check_circle_outlined),
                    const SizedBox(width: 6),
                    _buildTabButton(context, provider, 'LITIGES', 'Litiges', Icons.warning_amber_outlined),
                  ],
                ),
              ),

              const Divider(height: 1),

              // Order Cards List
              Expanded(
                child: provider.isLoading
                    ? const Center(child: CircularProgressIndicator(color: AppTheme.primaryRoyal))
                    : (orders.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(20),
                                  decoration: BoxDecoration(
                                    color: Colors.grey.shade100,
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(Icons.inbox_outlined, size: 48, color: Colors.grey[400]),
                                ),
                                const SizedBox(height: 14),
                                Text(
                                  'Aucune course dans cette rubrique',
                                  style: TextStyle(color: Colors.grey[700], fontSize: 14, fontWeight: FontWeight.bold),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  provider.activeTab == 'DISPONIBLES'
                                      ? 'Aucune course libre en attente sur la bourse'
                                      : (provider.activeTab == 'LITIGES'
                                          ? 'Aucun litige ou réclamation en cours'
                                          : (provider.activeTab == 'LIVREES'
                                              ? 'Aucune livraison clôturée pour le moment'
                                              : 'Toutes vos livraisons assignées sont à jour')),
                                  style: TextStyle(color: Colors.grey[500], fontSize: 12),
                                ),
                              ],
                            ),
                          )
                        : RefreshIndicator(
                            onRefresh: () => provider.fetchOrders(force: true),
                            child: ListView.builder(
                              padding: EdgeInsets.fromLTRB(16, 16, 16, MediaQuery.of(context).padding.bottom + 36),
                              itemCount: orders.length,
                              itemBuilder: (context, index) {
                                final order = orders[index];
                                return _buildDeliveryCard(context, order, provider);
                              },
                            ),
                          )),
              ),
            ],
          ),
        );
        },
      ),
    );
  }

  Widget _buildTabButton(BuildContext context, DeliveryProvider provider, String tabKey, String label, IconData icon, {int? badgeCount}) {
    final isSelected = provider.activeTab == tabKey;
    final isDark = AppTheme.isDark(context);
    final activeBg = isDark ? AppTheme.accentMint : AppTheme.primaryRoyal;
    final inactiveBg = isDark ? AppTheme.cardDarkElevated : Colors.grey.shade100;
    final activeFg = isDark ? const Color(0xFF03162C) : Colors.white;
    final inactiveFg = isDark ? AppTheme.textDarkMuted : Colors.grey.shade700;

    return Expanded(
      child: Semantics(
        button: true,
        selected: isSelected,
        label: label,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => provider.setActiveTab(tabKey),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(vertical: 8),
            decoration: BoxDecoration(
              color: isSelected ? activeBg : inactiveBg,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isSelected ? activeBg : (isDark ? AppTheme.borderDark : Colors.transparent),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 14, color: isSelected ? activeFg : inactiveFg),
                const SizedBox(width: 4),
                Text(
                  label,
                  style: TextStyle(
                    fontWeight: isSelected ? FontWeight.w900 : FontWeight.bold,
                    fontSize: 11,
                    color: isSelected ? activeFg : inactiveFg,
                  ),
                ),
                if (badgeCount != null && badgeCount > 0) ...[
                  const SizedBox(width: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                    decoration: BoxDecoration(
                      color: isSelected ? (isDark ? AppTheme.primaryRoyal : AppTheme.accentSky) : Colors.amber.shade700,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      "$badgeCount",
                      style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDeliveryCard(BuildContext context, DeliveryOrder order, DeliveryProvider provider) {
    final isUnassigned = order.isUnassigned;
    final isDone = order.statut == 'CLOTUREE' || order.statut == 'LIVREE_EN_ATTENTE';
    final isDispute = order.statut == 'EN_ATTENTE_DE_RELIVRAISON';
    final inProgress = order.statut == 'EN_COURS_DE_LIVRAISON';
    final isDark = AppTheme.isDark(context);

    final statusKey = isUnassigned ? 'PENDING' : (isDone ? 'DONE' : (isDispute ? 'DISPUTE' : (inProgress ? 'IN_PROGRESS' : 'PENDING')));

    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 14),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: AppTheme.borderColor(context), width: 1),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => DeliveryDetailView(order: order)),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Card Top Bar
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: isDark
                          ? AppTheme.accentMint.withValues(alpha: 0.15)
                          : AppTheme.primaryRoyal.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      order.code,
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 13,
                        color: isDark ? AppTheme.accentMint : AppTheme.primaryRoyal,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: isUnassigned
                          ? const Color(0xFF0C4E55).withValues(alpha: 0.12)
                          : AppTheme.badgeBg(context, statusKey),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isUnassigned
                            ? const Color(0xFF0C4E55).withValues(alpha: 0.3)
                            : AppTheme.badgeBorder(context, statusKey),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          isUnassigned
                              ? Icons.radar_outlined
                              : (inProgress
                                  ? Icons.navigation_rounded
                                  : (isDone ? Icons.check_circle_rounded : (isDispute ? Icons.warning_amber_rounded : Icons.schedule_rounded))),
                          size: 13,
                          color: isUnassigned ? const Color(0xFF0C4E55) : AppTheme.badgeText(context, statusKey),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          isUnassigned ? "DISPONIBLE" : (inProgress ? "EN ROUTE" : (isDone ? "LIVRÉE" : (isDispute ? "LITIGE" : "À LIVRER"))),
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w900,
                            color: isUnassigned ? const Color(0xFF0C4E55) : AppTheme.badgeText(context, statusKey),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 12),

              // Customer Name + Tel Action
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      order.clientNom,
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 16,
                        color: AppTheme.titleColor(context),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (order.clientTel.isNotEmpty)
                    Semantics(
                      button: true,
                      label: "Téléphoner au client ${order.clientNom}",
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppTheme.accentSky.withValues(alpha: 0.15),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.phone, size: 18, color: AppTheme.accentSky),
                      ),
                    ),
                ],
              ),

              const SizedBox(height: 8),

              // Address Container Box
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isDark ? AppTheme.cardDarkSubtle : Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isDark ? AppTheme.borderDark : Colors.grey.shade200,
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.location_on, size: 18, color: isDark ? AppTheme.accentMint : AppTheme.primaryRoyal),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        order.adresseLivraison,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: isDark ? AppTheme.textDarkBody : Colors.grey.shade800,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 12),

              // Footer Details, Badges & Amount
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        // Badge Statut Encaissement avec icône
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                          decoration: BoxDecoration(
                            color: AppTheme.badgeBg(context, order.estPayee ? 'DONE' : (order.isCreditOrder ? 'IN_PROGRESS' : 'PENDING')),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: AppTheme.badgeBorder(context, order.estPayee ? 'DONE' : (order.isCreditOrder ? 'IN_PROGRESS' : 'PENDING')),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                order.estPayee
                                    ? Icons.check_circle_outline
                                    : (order.isCreditOrder ? Icons.credit_card_outlined : Icons.payments_outlined),
                                size: 11,
                                color: AppTheme.badgeText(context, order.estPayee ? 'DONE' : (order.isCreditOrder ? 'IN_PROGRESS' : 'PENDING')),
                              ),
                              const SizedBox(width: 3),
                              Text(
                                order.estPayee ? "Payée" : (order.isCreditOrder ? "Crédit" : "À encaisser"),
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.badgeText(context, order.estPayee ? 'DONE' : (order.isCreditOrder ? 'IN_PROGRESS' : 'PENDING')),
                                ),
                              ),
                            ],
                          ),
                        ),
                        // Badge GPS / 1ère Adresse avec icône
                        if (order.requiresGpsValidation)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                            decoration: BoxDecoration(
                              color: Colors.indigo.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: Colors.indigo.withValues(alpha: 0.3)),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.gps_fixed, size: 10, color: Colors.indigo),
                                SizedBox(width: 3),
                                Text(
                                  "GPS requis",
                                  style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.indigo),
                                ),
                              ],
                            ),
                          )
                        else if (order.isGpsValidated)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                            decoration: BoxDecoration(
                              color: const Color(0xFF047857).withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.verified, size: 10, color: Color(0xFF047857)),
                                SizedBox(width: 3),
                                Text(
                                  "GPS OK",
                                  style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Color(0xFF047857)),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                  Text(
                    '${order.montantTotal.toStringAsFixed(2)} HTG',
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 15,
                      color: isDark ? AppTheme.accentMint : AppTheme.primaryRoyal,
                    ),
                  ),
                ],
              ),

              // Bouton d'action directe contextuel pour le livreur
              if (isUnassigned) ...[
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  height: 42,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0C4E55),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    icon: const Icon(Icons.add_task_rounded, size: 18),
                    label: const Text(
                      "Prendre la course",
                      style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13),
                    ),
                    onPressed: () async {
                      final auth = Provider.of<AuthProvider>(context, listen: false);
                      final currentDriverId = auth.currentUser?.id;
                      if (currentDriverId == null) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text("Chauffeur non identifié.")),
                        );
                        return;
                      }
                      final res = await provider.claimOrder(
                        order.id,
                        driverId: currentDriverId,
                      );
                      if (context.mounted) {
                        if (res.success) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text("Course ajoutée à votre tournée avec succès !"),
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
                    },
                  ),
                ),
              ] else if (!isDone && !isDispute) ...[
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  height: 40,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: inProgress ? AppTheme.primaryRoyal : Colors.blue.shade800,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    icon: Icon(inProgress ? Icons.arrow_forward_rounded : Icons.navigation_rounded, size: 16),
                    label: Text(
                      inProgress ? "Continuer la course" : "Débuter la course",
                      style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13),
                    ),
                    onPressed: () async {
                      if (!inProgress) {
                        final provider = Provider.of<DeliveryProvider>(context, listen: false);
                        await provider.startDelivery(order.id);
                      }
                      if (context.mounted) {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => DeliveryDetailView(order: order)),
                        );
                      }
                    },
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
