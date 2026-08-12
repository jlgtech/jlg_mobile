import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_theme.dart';
import '../../modules/auth/providers/auth_provider.dart';

class AppDrawer extends StatelessWidget {
  const AppDrawer({super.key});

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final user = authProvider.currentUser;

    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          // Drawer Header
          UserAccountsDrawerHeader(
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
            currentAccountPicture: CircleAvatar(
              backgroundColor: Colors.white.withOpacity(0.2),
              child: const Icon(Icons.person, size: 36, color: Colors.white),
            ),
            accountName: Text(
              user?.nom ?? "Agent Station",
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            accountEmail: Text(user?.email ?? "station@jlgpowerservicessupplies.com"),
          ),

          // Menu Items
          ListTile(
            leading: const Icon(Icons.dashboard_outlined, color: AppTheme.primaryEmerald),
            title: const Text("Station Remplissage"),
            onTap: () {
              Navigator.pop(context);
            },
          ),
          ListTile(
            leading: const Icon(Icons.history_outlined, color: AppTheme.primaryEmerald),
            title: const Text("Historique des Tickets"),
            onTap: () {
              Navigator.pop(context);
            },
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.info_outline, color: AppTheme.textMuted),
            title: const Text("À propos — JL Green v1.0"),
            onTap: () {},
          ),
          ListTile(
            leading: const Icon(Icons.logout, color: AppTheme.statusCancelled),
            title: const Text("Déconnexion", style: TextStyle(color: AppTheme.statusCancelled)),
            onTap: () {
              Navigator.pop(context);
              authProvider.logout(context);
            },
          ),
        ],
      ),
    );
  }
}
