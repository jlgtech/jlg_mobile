class DeliveryItem {
  final String articleId;
  final String designation;
  final int quantiteCommandee;
  final int quantiteOfferte;
  final double prixUnitaire;
  final double totalLigne;

  DeliveryItem({
    required this.articleId,
    required this.designation,
    required this.quantiteCommandee,
    required this.quantiteOfferte,
    required this.prixUnitaire,
    required this.totalLigne,
  });

  factory DeliveryItem.fromJson(Map<String, dynamic> json) {
    final pu = double.tryParse((json['prix_unitaire_facture'] ?? json['prix_unitaire'] ?? '0').toString()) ?? 0.0;
    final qte = (json['quantite_commandee'] is num) ? (json['quantite_commandee'] as num).toInt() : 1;
    final total = double.tryParse((json['total_ligne'] ?? (pu * qte)).toString()) ?? (pu * qte);
    return DeliveryItem(
      articleId: json['article_id']?.toString() ?? '',
      designation: json['article_designation'] ?? json['designation'] ?? json['article']?['designation'] ?? 'Produit',
      quantiteCommandee: qte,
      quantiteOfferte: (json['quantite_offerte'] is num) ? (json['quantite_offerte'] as num).toInt() : 0,
      prixUnitaire: pu,
      totalLigne: total,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'article_id': articleId,
      'designation': designation,
      'quantite_commandee': quantiteCommandee,
      'quantite_offerte': quantiteOfferte,
      'prix_unitaire': prixUnitaire,
      'total_ligne': totalLigne,
    };
  }
}

class DeliveryOrder {
  final String id;
  final String code;
  final String clientNom;
  final String clientTel;
  final String clientEmail;
  final String adresseLivraison;
  final String modePaiement;
  final String? precisionPaiement;
  final double montantTotal;
  final String statut;
  final bool estPayee;
  final String? payeeLe;
  final String? encaissePar;
  final bool confirmationGpsRequise;
  final bool premiereLivraisonAdresse;
  final bool estRetraitSurPlace;
  final DateTime dateCreation;
  final List<DeliveryItem> items;
  final double? latitude;
  final double? longitude;

  DeliveryOrder({
    required this.id,
    required this.code,
    required this.clientNom,
    required this.clientTel,
    required this.clientEmail,
    required this.adresseLivraison,
    required this.modePaiement,
    this.precisionPaiement,
    required this.montantTotal,
    required this.statut,
    this.estPayee = false,
    this.payeeLe,
    this.encaissePar,
    this.confirmationGpsRequise = false,
    this.premiereLivraisonAdresse = false,
    this.estRetraitSurPlace = false,
    required this.dateCreation,
    required this.items,
    this.latitude,
    this.longitude,
  });

  /// Indique si la commande est à récupérer sur place par le client (retrait direct / comptoir / dépôt).
  bool get isPickupOrder {
    if (estRetraitSurPlace) return true;
    final addr = adresseLivraison.toLowerCase();
    const pickupKeywords = [
      'dépôt',
      'depot',
      'comptoir',
      'sur place',
      'retrait',
      'recuper',
      'récupér',
      'lui-même',
      'lui-meme',
      'lui meme',
      'a emporter',
      'à emporter',
      'enlevement',
      'enlèvement',
      'magasin',
      'boutique',
      'guichet',
    ];
    return pickupKeywords.any((k) => addr.contains(k));
  }

  factory DeliveryOrder.fromJson(Map<String, dynamic> json) {
    var rawItems = (json['lignes'] as List?) ?? (json['items'] as List?) ?? [];
    List<DeliveryItem> parsedItems = rawItems
        .whereType<Map<String, dynamic>>()
        .map((i) => DeliveryItem.fromJson(i))
        .toList();

    return DeliveryOrder(
      id: json['id']?.toString() ?? '',
      code: json['code_commande'] ?? json['code'] ?? 'CMD-${(json['id']?.toString() ?? '').length >= 8 ? (json['id']?.toString() ?? '').substring(0, 8).toUpperCase() : (json['id']?.toString() ?? '').toUpperCase()}',
      clientNom: json['client_nom'] ?? json['client_passage_nom'] ?? json['clientNom'] ?? json['client']?['nom'] ?? 'Client Particulier',
      clientTel: json['client_telephone'] ?? json['client_passage_telephone'] ?? json['clientTel'] ?? json['client']?['telephone'] ?? '',
      clientEmail: json['client_email'] ?? json['client_passage_email'] ?? json['clientEmail'] ?? json['client']?['email'] ?? '',
      adresseLivraison: json['adresse_livraison'] ?? json['client_adresse'] ?? json['adresseLivraison'] ?? 'Port-au-Prince',
      modePaiement: json['mode_paiement']?.toString() ?? json['modePaiement']?.toString() ?? 'ESPECES',
      precisionPaiement: json['precision_paiement']?.toString() ?? json['precisionPaiement']?.toString(),
      montantTotal: double.tryParse(json['montant_total']?.toString() ?? json['montantTotal']?.toString() ?? '0') ?? 0.0,
      statut: json['statut']?.toString() ?? 'ASSIGNEE',
      estPayee: json['est_payee'] == true,
      payeeLe: json['payee_le']?.toString(),
      encaissePar: json['encaisse_par']?.toString(),
      confirmationGpsRequise: json['confirmation_gps_requise'] == true,
      premiereLivraisonAdresse: json['premiere_livraison_adresse'] == true,
      estRetraitSurPlace: json['est_retrait_sur_place'] == true || json['estRetraitSurPlace'] == true,
      dateCreation: DateTime.tryParse(json['cree_le']?.toString() ?? json['dateCreation']?.toString() ?? '') ?? DateTime.now(),
      items: parsedItems,
      latitude: json['latitude_livraison'] != null ? double.tryParse(json['latitude_livraison'].toString()) : null,
      longitude: json['longitude_livraison'] != null ? double.tryParse(json['longitude_livraison'].toString()) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'code': code,
      'clientNom': clientNom,
      'clientTel': clientTel,
      'clientEmail': clientEmail,
      'adresseLivraison': adresseLivraison,
      'modePaiement': modePaiement,
      'precisionPaiement': precisionPaiement,
      'montantTotal': montantTotal,
      'statut': statut,
      'est_payee': estPayee,
      'payee_le': payeeLe,
      'encaisse_par': encaissePar,
      'confirmation_gps_requise': confirmationGpsRequise,
      'premiere_livraison_adresse': premiereLivraisonAdresse,
      'est_retrait_sur_place': estRetraitSurPlace,
      'dateCreation': dateCreation.toIso8601String(),
      'items': items.map((i) => i.toJson()).toList(),
      'latitude_livraison': latitude,
      'longitude_livraison': longitude,
    };
  }
}
