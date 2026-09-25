import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_theme.dart';
import '../../modules/auth/providers/auth_provider.dart';
import '../layout/app_nav_tab.dart';

class AppDrawer extends StatelessWidget {
  final AppNavTab selectedTab;
  final ValueChanged<AppNavTab>? onSelectTab;

  const AppDrawer({
    super.key,
    this.selectedTab = AppNavTab.station,
    this.onSelectTab,
  });

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final user = authProvider.currentUser;

    final canAccessStation = user == null || user.isExecutive || user.isStationStaffOnly;
    final canAccessDeliveries = user == null || user.isExecutive || user.isLivreurOnly;

    return Drawer(
      child: SafeArea(
        top: false,
        child: Column(
          children: [
            // Drawer Header with AAA High Contrast
            UserAccountsDrawerHeader(
              margin: EdgeInsets.zero,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    AppTheme.primaryEmerald,
                    AppTheme.primaryDark,
                  ],
                ),
              ),
              currentAccountPicture: Semantics(
                label: "Photo de profil utilisateur",
                child: CircleAvatar(
                  backgroundColor: Colors.white.withValues(alpha: 0.2),
                  child: const Icon(Icons.person, size: 38, color: Colors.white),
                ),
              ),
              accountName: Text(
                user?.nom ?? "Agent Système JLG",
                style: const TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 17,
                  color: Colors.white,
                ),
              ),
              accountEmail: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    user?.email ?? "agent@jlgpowerservicessupplies.com",
                    style: const TextStyle(color: Colors.white70, fontSize: 13),
                  ),
                  const SizedBox(height: 2),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppTheme.accentMint,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      user?.role ?? "AGENT",
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Navigation List Items filtrés par Rôle
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(vertical: 8),
                children: [
                  // SECTION RACCOURCIS D'ACTION RAPIDE
                  _buildSectionHeader("RACCOURCIS D'ACTION RAPIDE"),
                  if (canAccessStation)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primaryEmerald,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          elevation: 2,
                        ),
                        icon: const Icon(Icons.add_circle_outline, size: 20),
                        label: const Text(
                          "+ Ticket Entrée Camion",
                          style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13),
                        ),
                        onPressed: () {
                          Navigator.pop(context);
                          if (onSelectTab != null) onSelectTab!(AppNavTab.station);
                        },
                      ),
                    ),
                  if (canAccessDeliveries && user != null && user.isLivreurOnly)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primaryEmerald,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          elevation: 2,
                        ),
                        icon: const Icon(Icons.route_outlined, size: 20),
                        label: const Text(
                          "Ma Feuille de Route Active",
                          style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13),
                        ),
                        onPressed: () {
                          Navigator.pop(context);
                          if (onSelectTab != null) onSelectTab!(AppNavTab.deliveries);
                        },
                      ),
                    ),

                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Divider(height: 1),
                  ),

                  // MODULES EXPLOITATION STATION
                  if (canAccessStation) ...[
                    _buildSectionHeader("EXPLOITATION STATION"),
                    _buildDrawerTile(
                      context: context,
                      tab: AppNavTab.station,
                      icon: Icons.water_drop_outlined,
                      selectedIcon: Icons.water_drop_rounded,
                      title: "Station de Remplissage",
                      subtitle: "File d'attente & Vannes piste",
                    ),
                    _buildDrawerTile(
                      context: context,
                      tab: AppNavTab.history,
                      icon: Icons.history_outlined,
                      selectedIcon: Icons.history_rounded,
                      title: "Historique des Tickets",
                      subtitle: "Registre des remplissages effectués",
                    ),
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                      child: Divider(height: 1),
                    ),
                  ],

                  // MODULES LOGISTIQUE & LIVRAISONS
                  if (canAccessDeliveries) ...[
                    _buildSectionHeader("LOGISTIQUE & LIVRAISONS"),
                    _buildDrawerTile(
                      context: context,
                      tab: AppNavTab.deliveries,
                      icon: Icons.local_shipping_outlined,
                      selectedIcon: Icons.local_shipping_rounded,
                      title: "Tournées de Livraison",
                      subtitle: "Courses, GPS & Validation client",
                    ),
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                      child: Divider(height: 1),
                    ),
                  ],

                  // MODULE CONFIGURATION
                  _buildSectionHeader("CONFIGURATION"),
                  _buildDrawerTile(
                    context: context,
                    tab: AppNavTab.settings,
                    icon: Icons.settings_outlined,
                    selectedIcon: Icons.settings_rounded,
                    title: "Paramètres Système",
                    subtitle: "Langue, Thème & Préférences",
                  ),
                ],
              ),
            ),

            // Footer Logout Action
            const Divider(height: 1),
            ListTile(
              minVerticalPadding: 14,
              leading: const Icon(Icons.logout, color: AppTheme.statusCancelled, size: 24),
              title: const Text(
                "Déconnexion",
                style: TextStyle(
                  color: AppTheme.statusCancelled,
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                ),
              ),
              subtitle: const Text(
                "Fermer la session actuelle",
                style: TextStyle(fontSize: 11, color: AppTheme.textMuted),
              ),
              onTap: () {
                Navigator.pop(context);
                authProvider.logout(context);
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w900,
          color: AppTheme.primaryEmerald,
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  Widget _buildDrawerTile({
    required BuildContext context,
    required AppNavTab tab,
    required IconData icon,
    required IconData selectedIcon,
    required String title,
    required String subtitle,
  }) {
    final isSelected = selectedTab == tab;
    return Semantics(
      button: true,
      selected: isSelected,
      label: "$title - $subtitle",
      child: ListTile(
        selected: isSelected,
        selectedTileColor: AppTheme.primaryEmerald.withValues(alpha: 0.1),
        minVerticalPadding: 12,
        leading: Icon(
          isSelected ? selectedIcon : icon,
          color: isSelected ? AppTheme.primaryEmerald : AppTheme.textDark,
          size: 24,
        ),
        title: Text(
          title,
          style: TextStyle(
            fontWeight: isSelected ? FontWeight.w900 : FontWeight.w700,
            fontSize: 14,
            color: isSelected ? AppTheme.primaryEmerald : AppTheme.textDark,
          ),
        ),
        subtitle: Text(
          subtitle,
          style: const TextStyle(
            fontSize: 11,
            color: AppTheme.textMuted,
          ),
        ),
        onTap: () {
          Navigator.pop(context);
          if (onSelectTab != null) {
            onSelectTab!(tab);
          }
        },
      ),
    );
  }
}
