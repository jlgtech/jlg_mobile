import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_theme.dart';
import '../models/notification_model.dart';
import '../providers/notification_provider.dart';
import '../widgets/notification_detail_modal.dart';

class NotificationsView extends StatefulWidget {
  const NotificationsView({super.key});

  @override
  State<NotificationsView> createState() => _NotificationsViewState();
}

class _NotificationsViewState extends State<NotificationsView> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = Provider.of<NotificationProvider>(context, listen: false);
      provider.fetchNotifications();
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = AppTheme.isDark(context);

    return Scaffold(
      backgroundColor: isDark ? AppTheme.bgDark : AppTheme.bgLight,
      appBar: AppBar(
        title: const Text(
          "Centre de Notifications",
          style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18),
        ),
        actions: [
          Consumer<NotificationProvider>(
            builder: (context, provider, _) {
              if (provider.unreadCount == 0) return const SizedBox.shrink();

              return TextButton.icon(
                style: TextButton.styleFrom(
                  foregroundColor: isDark ? AppTheme.accentMint : AppTheme.primaryEmerald,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                ),
                icon: const Icon(Icons.done_all, size: 18),
                label: const Text(
                  "Tout lire",
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                ),
                onPressed: () => provider.markAllAsRead(),
              );
            },
          ),
        ],
      ),
      body: Consumer<NotificationProvider>(
        builder: (context, provider, _) {
          // Gestion d'erreur sans écran blanc
          if (provider.errorMessage != null && provider.notifications.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: AppTheme.statusCancelled.withValues(alpha: 0.12),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.cloud_off_rounded,
                        color: AppTheme.statusCancelled,
                        size: 42,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      "Impossible de charger les notifications",
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.titleColor(context),
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      provider.errorMessage!,
                      style: TextStyle(
                        fontSize: 13,
                        color: AppTheme.mutedColor(context),
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 20),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isDark ? AppTheme.accentSky : AppTheme.primaryRoyal,
                        foregroundColor: isDark ? const Color(0xFF03162C) : Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      icon: const Icon(Icons.refresh, size: 18),
                      label: const Text(
                        "Réessayer",
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      onPressed: () => provider.fetchNotifications(),
                    ),
                  ],
                ),
              ),
            );
          }

          final notifications = provider.filteredNotifications;

          return RefreshIndicator(
            color: AppTheme.primaryEmerald,
            onRefresh: () => provider.fetchNotifications(),
            child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                // Header d'état avec filtre
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Bannière de résumé
                        _buildSummaryCard(context, provider, isDark),
                        const SizedBox(height: 12),

                        // Sélecteur de filtre Toutes / Non lues
                        _buildFilterTabs(context, provider, isDark),
                        const SizedBox(height: 8),
                      ],
                    ),
                  ),
                ),

                // État de chargement initial
                if (provider.isLoading && provider.notifications.isEmpty)
                  const SliverFillRemaining(
                    hasScrollBody: false,
                    child: Center(
                      child: CircularProgressIndicator(),
                    ),
                  )
                // Liste vide
                else if (notifications.isEmpty)
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: _buildEmptyState(context, provider, isDark),
                  )
                // Liste des notifications
                else
                  SliverPadding(
                    padding: EdgeInsets.fromLTRB(
                      16,
                      0,
                      16,
                      MediaQuery.of(context).padding.bottom + 24,
                    ),
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          final notif = notifications[index];
                          return _buildNotificationItem(context, notif, provider, isDark);
                        },
                        childCount: notifications.length,
                      ),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildSummaryCard(
    BuildContext context,
    NotificationProvider provider,
    bool isDark,
  ) {
    final totalCount = provider.notifications.length;
    final unreadCount = provider.unreadCount;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark
              ? const [AppTheme.primaryDeep, Color(0xFF061528)]
              : const [AppTheme.primaryRoyal, AppTheme.primaryDeep],
        ),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primaryRoyal.withValues(alpha: 0.2),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 22,
            backgroundColor: Colors.white.withValues(alpha: 0.2),
            child: const Icon(
              Icons.notifications_active_outlined,
              color: Colors.white,
              size: 24,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "Journal des Alertes Opérationnelles",
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  unreadCount > 0
                      ? "$unreadCount notification${unreadCount > 1 ? 's' : ''} non lue${unreadCount > 1 ? 's' : ''} en attente"
                      : "Toutes vos notifications sont à jour",
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.85),
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white.withValues(alpha: 0.25)),
            ),
            child: Text(
              "$totalCount total",
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 11,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterTabs(
    BuildContext context,
    NotificationProvider provider,
    bool isDark,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppTheme.cardDarkSubtle : Colors.grey.shade100,
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.all(4),
      child: Row(
        children: [
          Expanded(
            child: _buildFilterTabButton(
              context: context,
              label: "Toutes (${provider.notifications.length})",
              isSelected: provider.filter == NotificationFilter.all,
              onTap: () => provider.setFilter(NotificationFilter.all),
              isDark: isDark,
            ),
          ),
          Expanded(
            child: _buildFilterTabButton(
              context: context,
              label: "Non lues (${provider.unreadCount})",
              isSelected: provider.filter == NotificationFilter.unread,
              onTap: () => provider.setFilter(NotificationFilter.unread),
              isDark: isDark,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterTabButton({
    required BuildContext context,
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
    required bool isDark,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 8),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: isSelected
              ? (isDark ? AppTheme.accentMint : AppTheme.primaryEmerald)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.w900 : FontWeight.w600,
            color: isSelected
                ? (isDark ? const Color(0xFF03162C) : Colors.white)
                : AppTheme.mutedColor(context),
          ),
        ),
      ),
    );
  }

  Widget _buildNotificationItem(
    BuildContext context,
    NotificationModel notif,
    NotificationProvider provider,
    bool isDark,
  ) {
    final severityColor = notif.getSeverityColor(isDark);

    return Dismissible(
      key: Key(notif.id),
      direction: DismissDirection.endToStart,
      background: Container(
        margin: const EdgeInsets.symmetric(vertical: 5),
        decoration: BoxDecoration(
          color: AppTheme.statusCancelled,
          borderRadius: BorderRadius.circular(16),
        ),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.delete_outline, color: Colors.white, size: 22),
            SizedBox(width: 8),
            Text(
              "Supprimer",
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
      onDismissed: (_) {
        provider.deleteNotification(notif.id);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Notification supprimée"),
            duration: Duration(seconds: 2),
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 5),
        decoration: BoxDecoration(
          color: notif.estLu
              ? AppTheme.surfaceColor(context)
              : (isDark
                  ? AppTheme.accentSky.withValues(alpha: 0.08)
                  : AppTheme.primaryRoyal.withValues(alpha: 0.05)),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: notif.estLu
                ? (isDark ? AppTheme.borderDark : Colors.grey.shade200)
                : (isDark ? AppTheme.accentSky.withValues(alpha: 0.3) : AppTheme.primaryRoyal.withValues(alpha: 0.3)),
            width: notif.estLu ? 1 : 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.15 : 0.03),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () {
              NotificationDetailModal.show(
                context,
                notification: notif,
                provider: provider,
              );
            },
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Icône avec badge de sévérité
                  Stack(
                    alignment: Alignment.topRight,
                    children: [
                      Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          color: severityColor.withValues(alpha: 0.14),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          notif.iconData,
                          color: severityColor,
                          size: 22,
                        ),
                      ),
                      if (!notif.estLu)
                        Container(
                          width: 10,
                          height: 10,
                          decoration: BoxDecoration(
                            color: AppTheme.primaryEmerald,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: AppTheme.surfaceColor(context),
                              width: 1.5,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(width: 12),

                  // Contenu synthétique concis (règle d'or: pas de surchage)
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                              decoration: BoxDecoration(
                                color: severityColor.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                notif.severityLabel,
                                style: TextStyle(
                                  color: severityColor,
                                  fontSize: 9,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 0.4,
                                ),
                              ),
                            ),
                            const Spacer(),
                            Text(
                              notif.formattedTime,
                              style: TextStyle(
                                fontSize: 11,
                                color: AppTheme.mutedColor(context),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          notif.titre,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: notif.estLu ? FontWeight.w700 : FontWeight.w900,
                            color: AppTheme.titleColor(context),
                          ),
                        ),
                        if (notif.message.isNotEmpty) ...[
                          const SizedBox(height: 3),
                          Text(
                            notif.message,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 12,
                              color: AppTheme.mutedColor(context),
                              height: 1.3,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),

                  // Bouton Action Fiche / Détails
                  IconButton(
                    icon: Icon(
                      Icons.chevron_right_rounded,
                      color: AppTheme.mutedColor(context),
                      size: 22,
                    ),
                    tooltip: "Consulter la fiche",
                    onPressed: () {
                      NotificationDetailModal.show(
                        context,
                        notification: notif,
                        provider: provider,
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState(
    BuildContext context,
    NotificationProvider provider,
    bool isDark,
  ) {
    final isFilteringUnread = provider.filter == NotificationFilter.unread;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                color: (isDark ? AppTheme.accentMint : AppTheme.primaryEmerald).withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                isFilteringUnread
                    ? Icons.mark_email_read_outlined
                    : Icons.notifications_none_rounded,
                color: isDark ? AppTheme.accentMint : AppTheme.primaryEmerald,
                size: 48,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              isFilteringUnread
                  ? "Aucune notification non lue"
                  : "Aucune notification",
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w900,
                color: AppTheme.titleColor(context),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              isFilteringUnread
                  ? "Toutes vos alertes et notifications ont été traitées."
                  : "Vous recevrez ici les alertes de commandes, arrivées de camions et messages système.",
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: AppTheme.mutedColor(context),
                height: 1.4,
              ),
            ),
            const SizedBox(height: 24),
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: isDark ? AppTheme.accentMint : AppTheme.primaryEmerald,
                side: BorderSide(
                  color: isDark ? AppTheme.accentMint : AppTheme.primaryEmerald,
                ),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              icon: const Icon(Icons.refresh, size: 18),
              label: const Text(
                "Actualiser",
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              onPressed: () => provider.fetchNotifications(),
            ),
          ],
        ),
      ),
    );
  }
}
