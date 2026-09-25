import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../modules/auth/providers/auth_provider.dart';
import '../../modules/station/views/station_dashboard_view.dart';
import '../../modules/station/views/station_history_view.dart';
import '../../modules/deliveries/views/delivery_list_view.dart';
import '../../modules/settings/views/settings_view.dart';
import '../overlays/app_drawer.dart';
import 'app_bottom_nav.dart';
import 'app_nav_tab.dart';

class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  AppNavTab _currentTab = AppNavTab.station;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final user = Provider.of<AuthProvider>(context, listen: false).currentUser;
      if (user != null && user.isLivreurOnly) {
        setState(() {
          _currentTab = AppNavTab.deliveries;
        });
      }
    });
  }

  void _onTabSelected(AppNavTab tab) {
    setState(() {
      _currentTab = tab;
    });
  }

  @override
  Widget build(BuildContext context) {
    final user = Provider.of<AuthProvider>(context).currentUser;
    final visibleTabs = user.visibleTabs;

    // Safety fallback if active tab is restricted for user role
    AppNavTab activeTab = _currentTab;
    if (!visibleTabs.contains(activeTab)) {
      activeTab = visibleTabs.first;
    }

    Widget body;
    switch (activeTab) {
      case AppNavTab.station:
        body = StationDashboardView(onSelectTab: _onTabSelected);
        break;
      case AppNavTab.deliveries:
        body = DeliveryListView(onSelectTab: _onTabSelected);
        break;
      case AppNavTab.history:
        body = StationHistoryView(onSelectTab: _onTabSelected);
        break;
      case AppNavTab.settings:
        body = SettingsView(onSelectTab: _onTabSelected);
        break;
    }

    return Scaffold(
      drawer: AppDrawer(
        selectedTab: activeTab,
        onSelectTab: _onTabSelected,
      ),
      body: body,
      bottomNavigationBar: AppBottomNav(
        currentTab: activeTab,
        onSelectTab: _onTabSelected,
      ),
    );
  }
}
