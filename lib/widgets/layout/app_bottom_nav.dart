import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/theme_provider.dart';

class AppBottomNav extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;

  const AppBottomNav({
    super.key,
    required this.currentIndex,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final bottomInset = MediaQuery.of(context).padding.bottom;

    return Container(
      padding: EdgeInsets.only(bottom: bottomInset > 0 ? bottomInset / 2 : 0),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 10,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: BottomNavigationBar(
          currentIndex: currentIndex > 3 ? 0 : currentIndex,
          onTap: onTap,
          backgroundColor: Theme.of(context).cardColor,
          selectedItemColor: AppTheme.primaryEmerald,
          unselectedItemColor: AppTheme.textMuted,
          selectedLabelStyle: const TextStyle(fontWeight: FontWeight.w900, fontSize: 11),
          unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 11),
          elevation: 0,
          type: BottomNavigationBarType.fixed,
          items: [
            BottomNavigationBarItem(
              icon: Semantics(
                label: "Station Remplissage",
                child: const Icon(Icons.water_drop_outlined, size: 24),
              ),
              activeIcon: const Icon(Icons.water_drop_rounded, size: 26),
              label: themeProvider.tr('queue_title'),
            ),
            BottomNavigationBarItem(
              icon: Semantics(
                label: "Tournées Livraisons",
                child: const Icon(Icons.local_shipping_outlined, size: 24),
              ),
              activeIcon: const Icon(Icons.local_shipping_rounded, size: 26),
              label: "Livraisons",
            ),
            BottomNavigationBarItem(
              icon: Semantics(
                label: "Historique Tickets",
                child: const Icon(Icons.history_outlined, size: 24),
              ),
              activeIcon: const Icon(Icons.history_rounded, size: 26),
              label: "Historique",
            ),
            BottomNavigationBarItem(
              icon: Semantics(
                label: "Paramètres",
                child: const Icon(Icons.settings_outlined, size: 24),
              ),
              activeIcon: const Icon(Icons.settings_rounded, size: 26),
              label: themeProvider.tr('settings_title'),
            ),
          ],
        ),
      ),
    );
  }
}

