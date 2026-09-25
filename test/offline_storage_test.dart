import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:jlg_mobile/core/storage/offline_storage.dart';
import 'package:jlg_mobile/modules/deliveries/models/delivery_model.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('OfflineStorage Tests', () {
    test('saveOrders and loadOrders correctly persist and retrieve delivery orders', () async {
      final sampleOrder = DeliveryOrder(
        id: 'ord-123',
        code: 'CMD-2026-001',
        clientNom: 'Jean Baptiste',
        clientTel: '+50937123456',
        clientEmail: 'jean@example.com',
        adresseLivraison: '12 Rue Panamericaine, Petion-Ville',
        statut: 'EN_COURS',
        dateCreation: DateTime.parse('2026-09-25T10:00:00Z'),
        montantTotal: 2500.0,
        modePaiement: 'CASH',
        items: [
          DeliveryItem(
            articleId: 'art-1',
            designation: 'Eau 5 Gallons',
            quantiteCommandee: 5,
            quantiteOfferte: 0,
            prixUnitaire: 500.0,
            totalLigne: 2500.0,
          ),
        ],
        latitude: 18.5125,
        longitude: -72.2850,
      );

      await OfflineStorage.saveOrders([sampleOrder]);
      final loaded = await OfflineStorage.loadOrders();

      expect(loaded.length, 1);
      expect(loaded.first.id, 'ord-123');
      expect(loaded.first.code, 'CMD-2026-001');
      expect(loaded.first.clientNom, 'Jean Baptiste');
      expect(loaded.first.latitude, 18.5125);
      expect(loaded.first.longitude, -72.2850);
      expect(loaded.first.items.length, 1);
      expect(loaded.first.items.first.designation, 'Eau 5 Gallons');

      final lastSync = await OfflineStorage.getLastSync();
      expect(lastSync, isNotNull);
    });

    test('enqueuePendingAction and removePendingAction manage sync queue accurately', () async {
      final action1 = PendingAction(
        id: 'act-1',
        orderId: 'ord-123',
        type: 'UPDATE_STATUS',
        payload: {'statut': 'LIVREE'},
        createdAt: DateTime.now(),
      );

      final action2 = PendingAction(
        id: 'act-2',
        orderId: 'ord-456',
        type: 'DECLARE_DISPUTE',
        payload: {'motif': 'Client absent'},
        createdAt: DateTime.now(),
      );

      await OfflineStorage.enqueuePendingAction(action1);
      await OfflineStorage.enqueuePendingAction(action2);

      var actions = await OfflineStorage.loadPendingActions();
      expect(actions.length, 2);
      expect(actions.any((a) => a.id == 'act-1'), isTrue);
      expect(actions.any((a) => a.id == 'act-2'), isTrue);

      await OfflineStorage.removePendingAction('act-1');
      actions = await OfflineStorage.loadPendingActions();
      expect(actions.length, 1);
      expect(actions.first.id, 'act-2');

      await OfflineStorage.clearPendingActions();
      actions = await OfflineStorage.loadPendingActions();
      expect(actions.isEmpty, isTrue);
    });
  });
}
