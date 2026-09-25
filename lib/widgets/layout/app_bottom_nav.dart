import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/theme_provider.dart';
import '../../modules/auth/providers/auth_provider.dart';
import 'app_nav_tab.dart';

class AppBottomNav extends StatelessWidget {
  final AppNavTab currentTab;
  final ValueChanged<AppNavTab> onSelectTab;

  const AppBottomNav({
    super.key,
    required this.currentTab,
    required this.onSelectTab,
  });

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final user = Provider.of<AuthProvider>(context).currentUser;
    final visibleTabs = user.visibleTabs;

    int activeIndex = visibleTabs.indexOf(currentTab);
    if (activeIndex == -1) activeIndex = 0;

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
          currentIndex: activeIndex,
          onTap: (index) {
            if (index >= 0 && index < visibleTabs.length) {
              onSelectTab(visibleTabs[index]);
            }
          },
          backgroundColor: Theme.of(context).cardColor,
          selectedItemColor: AppTheme.primaryEmerald,
          unselectedItemColor: AppTheme.textMuted,
          selectedLabelStyle: const TextStyle(fontWeight: FontWeight.w900, fontSize: 11),
          unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 11),
          elevation: 0,
          type: BottomNavigationBarType.fixed,
          items: visibleTabs.map((tab) {
            switch (tab) {
              case AppNavTab.station:
                return BottomNavigationBarItem(
                  icon: Semantics(
                    label: "Station Remplissage",
                    child: const Icon(Icons.water_drop_outlined, size: 24),
                  ),
                  activeIcon: const Icon(Icons.water_drop_rounded, size: 26),
                  label: themeProvider.tr('queue_title'),
                );
              case AppNavTab.deliveries:
                return BottomNavigationBarItem(
                  icon: Semantics(
                    label: "Tournées Livraisons",
                    child: const Icon(Icons.local_shipping_outlined, size: 24),
                  ),
                  activeIcon: const Icon(Icons.local_shipping_rounded, size: 26),
                  label: "Livraisons",
                );
              case AppNavTab.history:
                return BottomNavigationBarItem(
                  icon: Semantics(
                    label: "Historique Tickets",
                    child: const Icon(Icons.history_outlined, size: 24),
                  ),
                  activeIcon: const Icon(Icons.history_rounded, size: 26),
                  label: "Historique",
                );
              case AppNavTab.settings:
                return BottomNavigationBarItem(
                  icon: Semantics(
                    label: "Paramètres",
                    child: const Icon(Icons.settings_outlined, size: 24),
                  ),
                  activeIcon: const Icon(Icons.settings_rounded, size: 26),
                  label: themeProvider.tr('settings_title'),
                );
            }
          }).toList(),
        ),
      ),
    );
  }
}
