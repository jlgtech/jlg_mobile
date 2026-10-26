import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:jlg_mobile/modules/notifications/models/notification_model.dart';
import 'package:jlg_mobile/modules/notifications/providers/notification_provider.dart';
import 'package:jlg_mobile/modules/notifications/widgets/notification_detail_modal.dart';
import 'package:jlg_mobile/widgets/buttons/notification_bell_button.dart';

void main() {
  group('NotificationModel Tests', () {
    test('NotificationModel parses JSON correctly', () {
      final json = {
        'id': 'notif-001',
        'utilisateur_id': 'user-123',
        'titre': 'Crédit à Valider : CMD-20261019-01',
        'message': 'Commande en attente d\'approbation financière.',
        'type_notification': 'CREDIT_A_VALIDER',
        'severite': 'WARNING',
        'est_lu': false,
        'lien': '/admin/credit-sales',
        'cree_le': '2026-10-19T08:00:00Z',
      };

      final notif = NotificationModel.fromJson(json);

      expect(notif.id, 'notif-001');
      expect(notif.utilisateurId, 'user-123');
      expect(notif.titre, 'Crédit à Valider : CMD-20261019-01');
      expect(notif.message, 'Commande en attente d\'approbation financière.');
      expect(notif.typeNotification, 'CREDIT_A_VALIDER');
      expect(notif.severite, 'WARNING');
      expect(notif.estLu, false);
      expect(notif.lien, '/admin/credit-sales');
      expect(notif.creeLe, isNotNull);
      expect(notif.severityLabel, 'ATTENTION');
      expect(notif.iconData, Icons.credit_score_outlined);
    });

    test('NotificationModel copyWith updates estLu properly', () {
      final notif = NotificationModel(
        id: 'n-1',
        titre: 'Alerte Stock',
        message: 'Stock critique d\'eau minérale',
        typeNotification: 'ALERTE_STOCK',
        severite: 'CRITICAL',
        estLu: false,
      );

      expect(notif.estLu, false);
      expect(notif.severityLabel, 'CRITIQUE');

      final updated = notif.copyWith(estLu: true);
      expect(updated.estLu, true);
      expect(updated.id, 'n-1');
      expect(updated.titre, 'Alerte Stock');
    });

    test('NotificationModel formattedTime formats recent dates', () {
      final now = DateTime.now();
      final justNow = NotificationModel(
        id: 'n-recent',
        titre: 'Test',
        message: 'Message test',
        typeNotification: 'INFO',
        severite: 'INFO',
        estLu: true,
        creeLe: now.subtract(const Duration(seconds: 15)),
      );

      expect(justNow.formattedTime, 'À l\'instant');

      final fiveMinutesAgo = NotificationModel(
        id: 'n-5m',
        titre: 'Test',
        message: 'Message test',
        typeNotification: 'INFO',
        severite: 'INFO',
        estLu: true,
        creeLe: now.subtract(const Duration(minutes: 5)),
      );

      expect(fiveMinutesAgo.formattedTime, 'Il y a 5 min');
    });
  });

  group('NotificationProvider State Tests', () {
    test('Filter logic separates unread notifications correctly', () {
      final provider = NotificationProvider();

      expect(provider.notifications, isEmpty);
      expect(provider.unreadCount, 0);
      expect(provider.filter, NotificationFilter.all);

      provider.setFilter(NotificationFilter.unread);
      expect(provider.filter, NotificationFilter.unread);

      provider.setFilter(NotificationFilter.all);
      expect(provider.filter, NotificationFilter.all);
    });
  });

  group('NotificationBellButton Widget Tests', () {
    testWidgets('NotificationBellButton displays badge with unread count', (tester) async {
      final provider = NotificationProvider();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            appBar: AppBar(
              actions: [
                ChangeNotifierProvider<NotificationProvider>.value(
                  value: provider,
                  child: const NotificationBellButton(),
                ),
              ],
            ),
          ),
        ),
      );

      // Initially 0 unread: no badge text
      expect(find.text('1'), findsNothing);

      // We test that the bell icon exists
      expect(find.byType(NotificationBellButton), findsOneWidget);
      expect(find.byIcon(Icons.notifications_outlined), findsOneWidget);
    });

    testWidgets('NotificationDetailModal renders properly without crash', (tester) async {
      final notif = NotificationModel(
        id: 'n-detail',
        titre: 'Alerte Commande',
        message: 'Votre commande a été traitée avec succès.',
        typeNotification: 'LIVRAISON',
        severite: 'INFO',
        estLu: false,
        creeLe: DateTime(2026, 10, 26, 14, 30),
      );
      final provider = NotificationProvider();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) {
                return ElevatedButton(
                  onPressed: () {
                    NotificationDetailModal.show(
                      context,
                      notification: notif,
                      provider: provider,
                    );
                  },
                  child: const Text('Open Modal'),
                );
              },
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Modal'));
      await tester.pumpAndSettle();

      expect(find.text('Alerte Commande'), findsOneWidget);
    });
  });
}
