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

    test('DeliveryOrder correctly identifies pickup and self-service orders', () {
      // 1. Commande avec flag explicite est_retrait_sur_place
      final orderFlag = DeliveryOrder.fromJson({
        'id': 'cmd-p1',
        'est_retrait_sur_place': true,
        'adresse_livraison': 'Route de Freres',
      });
      expect(orderFlag.isPickupOrder, true);

      // 2. Commande où le client vient récupérer lui-même
      final orderSelfPickup = DeliveryOrder.fromJson({
        'id': 'cmd-p2',
        'est_retrait_sur_place': false,
        'adresse_livraison': 'Le client vient récupérer lui-même la marchandise',
      });
      expect(orderSelfPickup.isPickupOrder, true);

      // 3. Commande retrait comptoir / dépôt
      final orderComptoir = DeliveryOrder.fromJson({
        'id': 'cmd-p3',
        'est_retrait_sur_place': false,
        'adresse_livraison': 'Retrait direct au Comptoir Aquafresh',
      });
      expect(orderComptoir.isPickupOrder, true);

      // 4. Vraie livraison physique à domicile
      final orderDelivery = DeliveryOrder.fromJson({
        'id': 'cmd-d1',
        'est_retrait_sur_place': false,
        'adresse_livraison': '12 Rue Panamericaine, Petion-Ville',
      });
      expect(orderDelivery.isPickupOrder, false);
    });

    test('DeliveryOrder requiresGpsValidation correctly identifies pre-validated address to skip step', () {
      // 1. Commande avec coordonnées certifiées en base (adresse déjà validée lors d'une livraison précédente)
      final validatedOrder = DeliveryOrder.fromJson({
        'id': 'cmd-val-1',
        'adresse_livraison': '12 Rue Lamarre, Pétion-Ville',
        'latitude_livraison': 18.5135,
        'longitude_livraison': -72.2874,
        'confirmation_gps_requise': false,
        'premiere_livraison_adresse': false,
      });
      expect(validatedOrder.requiresGpsValidation, false);
      expect(validatedOrder.isGpsValidated, true);

      // 2. Première livraison ou coordonnées manquantes (validation obligatoire sur place)
      final unvalidatedOrder = DeliveryOrder.fromJson({
        'id': 'cmd-val-2',
        'adresse_livraison': 'Nouvelle adresse sans repère',
        'latitude_livraison': null,
        'longitude_livraison': null,
        'confirmation_gps_requise': true,
        'premiere_livraison_adresse': true,
      });
      expect(unvalidatedOrder.requiresGpsValidation, true);
      expect(unvalidatedOrder.isGpsValidated, false);
    });

    test('DeliveryItem parses consigne attributes correctly', () {
      final json = {
        'id': 'line-1',
        'article_id': 'art-5gal',
        'designation': 'Bonbonne Eau Purifiee 5 Gallons',
        'quantite_commandee': 20,
        'quantite_offerte': 0,
        'prix_unitaire': 150.0,
        'total_ligne': 3000.0,
        'exige_retour_emballage': true,
        'nom_emballage_recupere': 'Bonbonne vide 5G',
      };

      final item = DeliveryItem.fromJson(json);

      expect(item.articleId, 'art-5gal');
      expect(item.quantiteCommandee, 20);
      expect(item.exigeRetourEmballage, true);
      expect(item.nomEmballageRecupere, 'Bonbonne vide 5G');
    });

    test('DeliveryOrder isUnassigned correctly identifies open pool orders', () {
      final unassignedOrder = DeliveryOrder.fromJson({
        'id': 'cmd-unassigned-1',
        'chauffeur_id': null,
        'statut': 'VALIDEE',
      });
      expect(unassignedOrder.isUnassigned, true);
      expect(unassignedOrder.chauffeurId, isNull);

      final assignedOrder = DeliveryOrder.fromJson({
        'id': 'cmd-assigned-1',
        'chauffeur_id': 'driver-456',
        'statut': 'EN_COURS_DE_LIVRAISON',
      });
      expect(assignedOrder.isUnassigned, false);
      expect(assignedOrder.chauffeurId, 'driver-456');
    });

    testWidgets('DisputeDialog renders safely with quantity stepper and redelivery options', (tester) async {
      final dummyOrder = DeliveryOrder(
        id: 'ord-123',
        code: 'CMD-TEST-001',
        clientNom: 'Client VIP',
        clientTel: '+509 3700 0000',
        clientEmail: 'vip@test.com',
        adresseLivraison: 'Delmas 75',
        modePaiement: 'ESPECES',
        montantTotal: 1500.0,
        statut: 'EN_COURS_DE_LIVRAISON',
        dateCreation: DateTime.now(),
        items: [
          DeliveryItem(
            articleId: 'art-001',
            designation: 'Pack Eau Pure 500ml',
            quantiteCommandee: 10,
            quantiteOfferte: 0,
            prixUnitaire: 150.0,
            totalLigne: 1500.0,
          ),
        ],
      );

      String? submittedMotif;
      int? submittedQty;
      bool? submittedReliv;
      String? submittedAction;

      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: DisputeDialog(
                order: dummyOrder,
              onSubmit: ({
                required String articleId,
                required int quantiteDefectueuse,
                required String motif,
                String? description,
                required bool doitEtreRelivree,
                required String actionChoisie,
              }) async {
                submittedMotif = motif;
                submittedQty = quantiteDefectueuse;
                submittedReliv = doitEtreRelivree;
                submittedAction = actionChoisie;
                return true;
              },
            ),
          ),
        ),
      ),
    );

      // Verify title, order code and product rendered
      expect(find.text('Déclaration de Litige'), findsOneWidget);
      expect(find.textContaining('CMD-TEST-001'), findsOneWidget);
      expect(find.text('Pack Eau Pure 500ml'), findsOneWidget);
      expect(find.text('Quantité défectueuse :'), findsOneWidget);
      expect(find.text('1'), findsOneWidget);

      // Test stepper: increment quantity
      await tester.tap(find.byIcon(Icons.add_circle_outline));
      await tester.pump();
      expect(find.text('2'), findsOneWidget);

      // Verify redelivery options
      expect(find.text('Relivraison de la quantité ?'), findsOneWidget);
      expect(find.text('Reprogrammer'), findsOneWidget);
      expect(find.text('Nouvelle Cmd'), findsOneWidget);

      // Switch to Nouvelle Cmd
      await tester.tap(find.text('Nouvelle Cmd'));
      await tester.pump();

      // Tap submit and verify parameters
      await tester.tap(find.text('Déclarer le Litige'));
      await tester.pump();

      expect(submittedMotif, contains('Produit Défectueux'));
      expect(submittedQty, 2);
      expect(submittedReliv, true);
      expect(submittedAction, 'NOUVELLE_COMMANDE');
    });
  });
}
