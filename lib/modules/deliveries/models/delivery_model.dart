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
    return DeliveryItem(
      articleId: json['article_id'] ?? '',
      designation: json['designation'] ?? json['article']?['designation'] ?? 'Produit',
      quantiteCommandee: json['quantite_commandee'] ?? 1,
      quantiteOfferte: json['quantite_offerte'] ?? 0,
      prixUnitaire: double.tryParse(json['prix_unitaire'].toString()) ?? 0.0,
      totalLigne: double.tryParse(json['total_ligne'].toString()) ?? 0.0,
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
    required this.dateCreation,
    required this.items,
    this.latitude,
    this.longitude,
  });

  factory DeliveryOrder.fromJson(Map<String, dynamic> json) {
    var rawItems = json['items'] as List? ?? [];
    List<DeliveryItem> parsedItems = rawItems.map((i) => DeliveryItem.fromJson(i)).toList();

    return DeliveryOrder(
      id: json['id'] ?? '',
      code: json['code_commande'] ?? 'CMD-${json['id']?.toString().substring(0, 8).toUpperCase() ?? ''}',
      clientNom: json['client_passage_nom'] ?? json['client']?['nom'] ?? 'Client Particulier',
      clientTel: json['client_passage_telephone'] ?? json['client']?['telephone'] ?? '',
      clientEmail: json['client_passage_email'] ?? json['client']?['email'] ?? '',
      adresseLivraison: json['adresse_livraison'] ?? 'Port-au-Prince',
      modePaiement: json['mode_paiement'] ?? 'ESPECES',
      precisionPaiement: json['precision_paiement'],
      montantTotal: double.tryParse(json['montant_total'].toString()) ?? 0.0,
      statut: json['statut'] ?? 'ASSIGNEE',
      dateCreation: DateTime.tryParse(json['cree_le'] ?? '') ?? DateTime.now(),
      items: parsedItems,
      latitude: json['latitude_livraison'] != null ? double.tryParse(json['latitude_livraison'].toString()) : null,
      longitude: json['longitude_livraison'] != null ? double.tryParse(json['longitude_livraison'].toString()) : null,
    );
  }
}
