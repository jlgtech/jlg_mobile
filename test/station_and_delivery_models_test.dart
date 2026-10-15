import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jlg_mobile/modules/station/models/station_models.dart';
import 'package:jlg_mobile/modules/deliveries/models/delivery_model.dart';
import 'package:jlg_mobile/modules/deliveries/widgets/dispute_dialog.dart';

void main() {
  group('Station Models Tests', () {
    test('TransactionStationModel parses correctly with all attributes', () {
      final json = {
        'id': 'tx-1234',
        'code_ticket': 'TK-88210',
        'camion_id': 'truck-001',
        'agent_station_id': 'agent-001',
        'montant_htg': 1000.0,
        'mode_paiement': 'CASH',
        'statut': 'EN_ATTENTE',
        'heure_entree': '2026-10-15T10:00:00Z',
        'camion': {
          'id': 'truck-001',
          'plaque_immatriculation': 'AA-12345',
          'nom_proprietaire': 'Jean Baptiste',
          'telephone': '+509 3712-3456',
        },
      };

      final tx = TransactionStationModel.fromJson(json);

      expect(tx.id, 'tx-1234');
      expect(tx.codeTicket, 'TK-88210');
      expect(tx.montantHtg, 1000.0);
      expect(tx.modePaiement, 'CASH');
      expect(tx.statut, 'EN_ATTENTE');
      expect(tx.camion?.plaqueImmatriculation, 'AA-12345');
      expect(tx.camion?.nomProprietaire, 'Jean Baptiste');
    });

    test('TransactionStationModel handles enum-map statut gracefully', () {
      final json = {
        'id': 'tx-5678',
        'code_ticket': 'TK-99999',
        'camion_id': 'truck-002',
        'agent_station_id': 'agent-002',
        'montant_htg': 1200.0,
        'statut': {'value': 'EN_COURS'},
        'heure_entree': '2026-10-15T11:00:00Z',
      };

      final tx = TransactionStationModel.fromJson(json);
      expect(tx.statut, 'EN_COURS');
    });
  });

  group('Delivery Models Tests', () {
    test('DeliveryOrder parses full FastAPI LigneCommandeResponse payload', () {
      final json = {
        'id': 'cmd-1111',
        'code_commande': 'CMD-20261015-01',
        'client_nom': 'Marie Laurent',
        'client_telephone': '+509 3600-1122',
        'client_email': 'marie@example.com',
        'adresse_livraison': 'Route de Delmas 75, Impasse 3',
        'mode_paiement': 'ESPECES',
        'montant_total': 3500.0,
        'statut': 'EN_COURS_DE_LIVRAISON',
        'est_payee': false,
        'confirmation_gps_requise': true,
        'premiere_livraison_adresse': true,
        'cree_le': '2026-10-15T09:30:00Z',
        'latitude_livraison': 18.528491,
        'longitude_livraison': -72.273404,
        'lignes': [
          {
            'article_id': 'art-001',
            'article_designation': 'Pack Eau Purifiee 500ml',
            'quantite_commandee': 10,
            'quantite_offerte': 1,
            'prix_unitaire_facture': 350.0,
          }
        ],
      };

      final order = DeliveryOrder.fromJson(json);

      expect(order.id, 'cmd-1111');
      expect(order.code, 'CMD-20261015-01');
      expect(order.clientNom, 'Marie Laurent');
      expect(order.estPayee, false);
      expect(order.confirmationGpsRequise, true);
      expect(order.premiereLivraisonAdresse, true);
      expect(order.latitude, 18.528491);
      expect(order.longitude, -72.273404);
      expect(order.items.length, 1);
      expect(order.items.first.designation, 'Pack Eau Purifiee 500ml');
      expect(order.items.first.quantiteCommandee, 10);
      expect(order.items.first.quantiteOfferte, 1);
      expect(order.items.first.prixUnitaire, 350.0);
      expect(order.items.first.totalLigne, 3500.0);
    });

    test('DeliveryOrder handles paid orders correctly', () {
      final json = {
        'id': 'cmd-2222',
        'code_commande': 'CMD-20261015-02',
        'client_nom': 'Pierre Richard',
        'mode_paiement': 'MONCASH',
        'montant_total': 1800.0,
        'statut': 'CLOTUREE',
        'est_payee': true,
        'payee_le': '2026-10-15T12:00:00Z',
        'encaisse_par': 'LIVREUR',
        'items': [],
      };

      final order = DeliveryOrder.fromJson(json);

      expect(order.estPayee, true);
      expect(order.encaissePar, 'LIVREUR');
      expect(order.statut, 'CLOTUREE');
    });

    testWidgets('DisputeDialog renders safely without Dropdown assertion error', (tester) async {
      String? submittedMotif;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DisputeDialog(
              orderCode: 'CMD-TEST-001',
              onSubmit: (motif) {
                submittedMotif = motif;
              },
            ),
          ),
        ),
      );

      // Verify title and order code rendered
      expect(find.text('Déclaration de Litige'), findsOneWidget);
      expect(find.text('Commande : CMD-TEST-001'), findsOneWidget);
      expect(find.byType(DropdownButton<String>), findsOneWidget);

      // Tap submit and verify default motif submitted without error
      await tester.tap(find.text('Transmettre Litige'));
      await tester.pump();

      expect(submittedMotif, isNotNull);
      expect(submittedMotif, contains('Produit Défectueux'));
    });
  });
}
