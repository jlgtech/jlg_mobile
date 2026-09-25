import '../../modules/auth/models/user_model.dart';

enum AppNavTab {
  station,
  deliveries,
  history,
  settings,
}

extension UserModelRoleTabs on UserModel? {
  List<AppNavTab> get visibleTabs {
    if (this == null) {
      return AppNavTab.values;
    }
    if (this!.isLivreurOnly) {
      return const [
        AppNavTab.deliveries,
        AppNavTab.settings,
      ];
    }
    if (this!.isStationStaffOnly) {
      return const [
        AppNavTab.station,
        AppNavTab.history,
        AppNavTab.settings,
      ];
    }
    // Executives (ADMIN, SUPER_ADMIN, MANAGER, DIRECTEUR_EXPLOITATION)
    return const [
      AppNavTab.station,
      AppNavTab.deliveries,
      AppNavTab.history,
      AppNavTab.settings,
    ];
  }
}
