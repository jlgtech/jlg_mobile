import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';
import 'package:jlg_mobile/core/models/maintenance_info.dart';
import 'package:jlg_mobile/core/providers/maintenance_provider.dart';
import 'package:jlg_mobile/widgets/maintenance_warning_banner.dart';
import 'package:jlg_mobile/modules/maintenance/views/maintenance_view.dart';

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await initializeDateFormatting('fr_FR', null);
  });

  group('MaintenanceInfo Model Tests', () {
    test('MaintenanceInfo.fromJson parses full valid payload correctly', () {
      final json = {
        'is_active': false,
        'is_scheduled': true,
        'is_warning': true,
        'debut': '2026-10-30T14:00:00Z',
        'fin': '2026-10-30T16:00:00Z',
        'message': 'Mise à niveau des serveurs de base de données.',
        'delai_alerte_minutes': 30,
        'minutes_remaining': 25,
        'server_time': '2026-10-30T13:35:00Z',
      };

      final info = MaintenanceInfo.fromJson(json);

      expect(info.isActive, isFalse);
      expect(info.isScheduled, isTrue);
      expect(info.isWarning, isTrue);
      expect(info.debut, isNotNull);
      expect(info.fin, isNotNull);
      expect(info.message, 'Mise à niveau des serveurs de base de données.');
      expect(info.delaiAlerteMinutes, 30);
      expect(info.minutesRemaining, 25);
      expect(info.serverTime, isNotNull);
      expect(info.formattedDebut, contains('30 oct. 2026'));
      expect(info.displayMessage, 'Mise à niveau des serveurs de base de données.');
    });

    test('MaintenanceInfo handles fallback and null values gracefully', () {
      final json = {
        'active': true,
        'server_time': '2026-10-30T14:00:00Z',
      };

      final info = MaintenanceInfo.fromJson(json);

      expect(info.isActive, isTrue);
      expect(info.isScheduled, isFalse);
      expect(info.isWarning, isFalse);
      expect(info.debut, isNull);
      expect(info.fin, isNull);
      expect(info.formattedDebut, 'Non spécifié');
      expect(info.formattedFin, 'Indéterminée');
      expect(info.displayMessage, contains('opération de maintenance'));
    });

    test('MaintenanceInfo copyWith updates values correctly', () {
      final info = MaintenanceInfo(
        isActive: false,
        isScheduled: true,
        isWarning: true,
        message: 'Message original',
        serverTime: DateTime.now(),
      );

      final updated = info.copyWith(
        isActive: true,
        isWarning: false,
        message: 'Maintenance active en cours',
      );

      expect(updated.isActive, isTrue);
      expect(updated.isWarning, isFalse);
      expect(updated.message, 'Maintenance active en cours');
      expect(updated.isScheduled, isTrue);
    });
  });

  group('MaintenanceProvider Logic Tests', () {
    test('handle503 sets isActive to true and parses error body payload', () {
      final provider = MaintenanceProvider();
      expect(provider.isActive, isFalse);

      final payload503 = {
        'status': 'maintenance',
        'maintenance': true,
        'message': 'Coupure d\'urgence pour sécurité.',
        'debut': '2026-10-30T14:00:00Z',
        'fin': '2026-10-30T15:30:00Z',
        'minutes_remaining': 0,
      };

      provider.handle503(payload503);

      expect(provider.isActive, isTrue);
      expect(provider.isWarning, isFalse);
      expect(provider.message, 'Coupure d\'urgence pour sécurité.');
      expect(provider.info?.debut, isNotNull);
      expect(provider.info?.fin, isNotNull);
    });

    test('dismissWarningBanner temporarily hides warning banner', () {
      final provider = MaintenanceProvider();

      // Forcer un état d'avertissement
      provider.handle503(null); // Active
      // Simuler l'arrivée d'une alerte préventive non active
      final warningInfo = MaintenanceInfo(
        isActive: false,
        isScheduled: true,
        isWarning: true,
        debut: DateTime.now().add(const Duration(minutes: 20)),
        fin: DateTime.now().add(const Duration(hours: 2)),
        minutesRemaining: 20,
        serverTime: DateTime.now(),
      );

      final dummyProvider = MaintenanceProvider();
      expect(dummyProvider.bannerDismissed, isFalse);

      dummyProvider.dismissWarningBanner();
      expect(dummyProvider.bannerDismissed, isTrue);
    });
  });

  group('Maintenance Widgets Tests', () {
    testWidgets('MaintenanceWarningBanner does not render when isWarning is false', (tester) async {
      final provider = MaintenanceProvider();

      await tester.pumpWidget(
        MaterialApp(
          home: ChangeNotifierProvider<MaintenanceProvider>.value(
            value: provider,
            child: const Scaffold(
              body: MaintenanceWarningBanner(),
            ),
          ),
        ),
      );

      expect(find.text('Alerte Maintenance'), findsNothing);
    });

    testWidgets('MaintenanceWarningBanner renders warning and allows dismissal', (tester) async {
      final provider = MaintenanceProvider();

      // Injection d'un statut en alerte
      final warningInfo = MaintenanceInfo(
        isActive: false,
        isScheduled: true,
        isWarning: true,
        debut: DateTime(2026, 10, 30, 15, 30),
        fin: DateTime(2026, 10, 30, 17, 30),
        delaiAlerteMinutes: 30,
        minutesRemaining: 20,
        serverTime: DateTime.now(),
      );

      // Simuler la présence d'une alerte sans appel réseau
      final testProvider = _TestMaintenanceProvider(warningInfo);

      await tester.pumpWidget(
        MaterialApp(
          home: ChangeNotifierProvider<MaintenanceProvider>.value(
            value: testProvider,
            child: const Scaffold(
              body: MaintenanceWarningBanner(),
            ),
          ),
        ),
      );

      expect(find.text('Alerte Maintenance'), findsOneWidget);
      expect(find.textContaining('dans 20 min'), findsOneWidget);
      expect(find.byIcon(Icons.warning_amber_rounded), findsOneWidget);

      // Cliquer sur le bouton fermer
      await tester.tap(find.byIcon(Icons.close_rounded));
      await tester.pumpAndSettle();

      expect(testProvider.bannerDismissed, isTrue);
      expect(find.text('Alerte Maintenance'), findsNothing);
    });

    testWidgets('MaintenanceView renders correctly with details and availability button', (tester) async {
      final activeInfo = MaintenanceInfo(
        isActive: true,
        isScheduled: true,
        isWarning: false,
        debut: DateTime(2026, 10, 30, 14, 0),
        fin: DateTime(2026, 10, 30, 16, 0),
        message: 'Mise à jour planifiée de l\'infrastructure.',
        serverTime: DateTime.now(),
      );

      final testProvider = _TestMaintenanceProvider(activeInfo);

      await tester.pumpWidget(
        MaterialApp(
          home: ChangeNotifierProvider<MaintenanceProvider>.value(
            value: testProvider,
            child: const MaintenanceView(),
          ),
        ),
      );

      expect(find.text('GROUPE JL GREEN'), findsOneWidget);
      expect(find.text('Système en Maintenance'), findsOneWidget);
      expect(find.text('Mise à jour planifiée de l\'infrastructure.'), findsOneWidget);
      expect(find.text('Début de coupure'), findsOneWidget);
      expect(find.text('Reprise estimée'), findsOneWidget);
      expect(find.text('Vérifier la disponibilité'), findsOneWidget);
      expect(find.byIcon(Icons.construction_rounded), findsOneWidget);
    });
  });
}

class _TestMaintenanceProvider extends MaintenanceProvider {
  MaintenanceInfo? _testInfo;
  bool _dismissed = false;

  _TestMaintenanceProvider(this._testInfo);

  @override
  MaintenanceInfo? get info => _testInfo;

  @override
  bool get isActive => _testInfo?.isActive ?? false;

  @override
  bool get isWarning => (_testInfo?.isWarning ?? false) && !_dismissed && !isActive;

  @override
  bool get bannerDismissed => _dismissed;

  @override
  void dismissWarningBanner() {
    _dismissed = true;
    notifyListeners();
  }

  @override
  Future<MaintenanceInfo?> checkMaintenance({bool silent = false}) async {
    return _testInfo;
  }
}
