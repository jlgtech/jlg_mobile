import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/delivery_model.dart';
import '../providers/delivery_provider.dart';
import '../widgets/offline_status_banner.dart';
import 'delivery_detail_view.dart';
import '../../auth/providers/auth_provider.dart';
import '../../../widgets/overlays/app_drawer.dart';
import '../../../widgets/layout/app_nav_tab.dart';

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
        backgroundColor: const Color(0xFF0C4E55),
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
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
                        backgroundColor: ok ? const Color(0xFF0C4E55) : Colors.red.shade700,
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
          final totalCount = provider.orders.length;
          final completedCount = provider.orders.where((o) => o.statut == 'CLOTUREE' || o.statut == 'LIVREE_EN_ATTENTE').toList().length;
          final progressRatio = totalCount > 0 ? (completedCount / totalCount) : 0.0;

          return Column(
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
                      Color(0xFF0C4E55),
                      Color(0xFF063C42),
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
                                      color: const Color(0xFF10B981).withValues(alpha: 0.2),
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(Icons.route, color: Color(0xFF10B981), size: 22),
                                  ),
                                  const SizedBox(width: 12),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        "Progression de la Tournée",
                                        style: TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.bold),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        "$completedCount sur $totalCount Livrées",
                                        style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w900),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF10B981),
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
                              color: const Color(0xFF10B981),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // Filter Tabs (A Livrer / Livrées / Litiges)
              Container(
                color: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  children: [
                    _buildTabButton(context, provider, 'A_LIVRER', 'À Livrer', Icons.local_shipping_outlined),
                    const SizedBox(width: 8),
                    _buildTabButton(context, provider, 'LIVREES', 'Livrées', Icons.check_circle_outlined),
                    const SizedBox(width: 8),
                    _buildTabButton(context, provider, 'LITIGES', 'Litiges', Icons.warning_amber_outlined),
                  ],
                ),
              ),

              const Divider(height: 1),

              // Order Cards List
              Expanded(
                child: provider.isLoading
                    ? const Center(child: CircularProgressIndicator(color: Color(0xFF0C4E55)))
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
                                  'Toutes vos livraisons assignées sont à jour',
                                  style: TextStyle(color: Colors.grey[500], fontSize: 12),
                                ),
                              ],
                            ),
                          )
                        : RefreshIndicator(
                            onRefresh: () => provider.fetchOrders(),
                            child: ListView.builder(
                              padding: const EdgeInsets.all(16),
                              itemCount: orders.length,
                              itemBuilder: (context, index) {
                                final order = orders[index];
                                return _buildDeliveryCard(context, order, provider);
                              },
                            ),
                          )),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildTabButton(BuildContext context, DeliveryProvider provider, String tabKey, String label, IconData icon) {
    final isSelected = provider.activeTab == tabKey;
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
            padding: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(
              color: isSelected ? const Color(0xFF0C4E55) : Colors.grey.shade100,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 16, color: isSelected ? Colors.white : Colors.grey.shade700),
                const SizedBox(width: 6),
                Text(
                  label,
                  style: TextStyle(
                    fontWeight: isSelected ? FontWeight.w900 : FontWeight.bold,
                    fontSize: 12,
                    color: isSelected ? Colors.white : Colors.grey.shade700,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDeliveryCard(BuildContext context, DeliveryOrder order, DeliveryProvider provider) {
    final isDone = order.statut == 'CLOTUREE' || order.statut == 'LIVREE_EN_ATTENTE';
    final isDispute = order.statut == 'EN_ATTENTE_DE_RELIVRAISON';
    final inProgress = order.statut == 'EN_COURS_DE_LIVRAISON';

    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 14),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
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
                      color: const Color(0xFF0C4E55).withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      order.code,
                      style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13, color: Color(0xFF0C4E55)),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: isDone
                          ? Colors.teal.shade50
                          : (isDispute ? Colors.red.shade50 : (inProgress ? Colors.blue.shade50 : Colors.amber.shade50)),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isDone
                            ? Colors.teal.shade200
                            : (isDispute ? Colors.red.shade200 : (inProgress ? Colors.blue.shade200 : Colors.amber.shade300)),
                      ),
                    ),
                    child: Text(
                      inProgress ? "EN ROUTE" : (isDone ? "LIVRÉE" : (isDispute ? "LITIGE" : "À LIVRER")),
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                        color: isDone
                            ? Colors.teal.shade800
                            : (isDispute ? Colors.red.shade900 : (inProgress ? Colors.blue.shade900 : Colors.amber.shade900)),
                      ),
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
                      style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: Color(0xFF0F172A)),
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
                          color: const Color(0xFF10B981).withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.phone, size: 18, color: Color(0xFF10B981)),
                      ),
                    ),
                ],
              ),

              const SizedBox(height: 8),

              // Address Container Box
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.location_on, size: 18, color: Color(0xFF0C4E55)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        order.adresseLivraison,
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey.shade800),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 12),

              // Footer Details & Amount
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.payment, size: 16, color: Colors.grey),
                      const SizedBox(width: 4),
                      Text(
                        order.modePaiement,
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey.shade700),
                      ),
                    ],
                  ),
                  Text(
                    '${order.montantTotal.toStringAsFixed(2)} HTG',
                    style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: Color(0xFF0C4E55)),
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
