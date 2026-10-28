class DeliveryItem {
  final String articleId;
  final String designation;
  final int quantiteCommandee;
  final int quantiteOfferte;
  final double prixUnitaire;
  final double totalLigne;
  final bool exigeRetourEmballage;
  final String? nomEmballageRecupere;

  DeliveryItem({
    required this.articleId,
    required this.designation,
    required this.quantiteCommandee,
    required this.quantiteOfferte,
    required this.prixUnitaire,
    required this.totalLigne,
    this.exigeRetourEmballage = false,
    this.nomEmballageRecupere,
  });

  factory DeliveryItem.fromJson(Map<String, dynamic> json) {
    final pu = double.tryParse((json['prix_unitaire_facture'] ?? json['prix_unitaire'] ?? '0').toString()) ?? 0.0;
    final qte = (json['quantite_commandee'] is num) ? (json['quantite_commandee'] as num).toInt() : 1;
    final total = double.tryParse((json['total_ligne'] ?? (pu * qte)).toString()) ?? (pu * qte);
    
    // Détection dynamique ou de compatibilité pour les articles 5 Gallons
    final desig = json['article_designation'] ?? json['designation'] ?? json['article']?['designation'] ?? 'Produit';
    final isExplicitConsigne = json['exige_retour_emballage'] == true || json['article']?['exige_retour_emballage'] == true;
    final isAutoConsigne = desig.toString().toLowerCase().contains('5 gallon') || desig.toString().toLowerCase().contains('bonbonne');

    return DeliveryItem(
      articleId: json['article_id']?.toString() ?? '',
      designation: desig,
      quantiteCommandee: qte,
      quantiteOfferte: (json['quantite_offerte'] is num) ? (json['quantite_offerte'] as num).toInt() : 0,
      prixUnitaire: pu,
      totalLigne: total,
      exigeRetourEmballage: isExplicitConsigne || isAutoConsigne,
      nomEmballageRecupere: json['nom_emballage_recupere'] ?? json['article']?['nom_emballage_recupere'] ?? (isAutoConsigne ? 'Bonbonne vide 5G' : null),
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
      'exige_retour_emballage': exigeRetourEmballage,
      'nom_emballage_recupere': nomEmballageRecupere,
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
  final bool estVenteACredit;
  final bool estRetraitSurPlace;
  final String? chauffeurId;
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
    this.estVenteACredit = false,
    this.estRetraitSurPlace = false,
    this.chauffeurId,
    required this.dateCreation,
    required this.items,
    this.latitude,
    this.longitude,
  });

  DeliveryOrder copyWith({
    String? id,
    String? code,
    String? clientNom,
    String? clientTel,
    String? clientEmail,
    String? adresseLivraison,
    String? modePaiement,
    String? precisionPaiement,
    double? montantTotal,
    String? statut,
    bool? estPayee,
    String? payeeLe,
    String? encaissePar,
    bool? confirmationGpsRequise,
    bool? premiereLivraisonAdresse,
    bool? estVenteACredit,
    bool? estRetraitSurPlace,
    String? chauffeurId,
    DateTime? dateCreation,
    List<DeliveryItem>? items,
    double? latitude,
    double? longitude,
  }) {
    return DeliveryOrder(
      id: id ?? this.id,
      code: code ?? this.code,
      clientNom: clientNom ?? this.clientNom,
      clientTel: clientTel ?? this.clientTel,
      clientEmail: clientEmail ?? this.clientEmail,
      adresseLivraison: adresseLivraison ?? this.adresseLivraison,
      modePaiement: modePaiement ?? this.modePaiement,
      precisionPaiement: precisionPaiement ?? this.precisionPaiement,
      montantTotal: montantTotal ?? this.montantTotal,
      statut: statut ?? this.statut,
      estPayee: estPayee ?? this.estPayee,
      payeeLe: payeeLe ?? this.payeeLe,
      encaissePar: encaissePar ?? this.encaissePar,
      confirmationGpsRequise: confirmationGpsRequise ?? this.confirmationGpsRequise,
      premiereLivraisonAdresse: premiereLivraisonAdresse ?? this.premiereLivraisonAdresse,
      estVenteACredit: estVenteACredit ?? this.estVenteACredit,
      estRetraitSurPlace: estRetraitSurPlace ?? this.estRetraitSurPlace,
      chauffeurId: chauffeurId ?? this.chauffeurId,
      dateCreation: dateCreation ?? this.dateCreation,
      items: items ?? this.items,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
    );
  }

  /// Indique si la course est encore libre (non assignée à un chauffeur)
  bool get isUnassigned => chauffeurId == null || chauffeurId!.trim().isEmpty;

  /// Indique si la commande est une vente a credit
  bool get isCreditOrder => estVenteACredit || modePaiement.toUpperCase() == 'CREDIT';

  /// Indique si un encaissement physique sur place est requis avant ou pendant la livraison
  bool get requiresPaymentOnDelivery => !estPayee && !isCreditOrder;

  /// Indique si l'adresse est deja verifiee et geolocalisee (coordonnees GPS valides)
  bool get isGpsValidated => latitude != null && longitude != null && !premiereLivraisonAdresse && !confirmationGpsRequise;

  /// Indique si une capture/validation des coordonnees GPS est obligatoire sur place
  bool get requiresGpsValidation => !isPickupOrder && (premiereLivraisonAdresse || confirmationGpsRequise || latitude == null || longitude == null);

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

    final rawMode = json['mode_paiement']?.toString() ?? json['modePaiement']?.toString() ?? 'ESPECES';
    final isCredit = json['est_vente_a_credit'] == true || rawMode.toUpperCase() == 'CREDIT';

    return DeliveryOrder(
      id: json['id']?.toString() ?? '',
      code: json['code_commande'] ?? json['code'] ?? 'CMD-${(json['id']?.toString() ?? '').length >= 8 ? (json['id']?.toString() ?? '').substring(0, 8).toUpperCase() : (json['id']?.toString() ?? '').toUpperCase()}',
      clientNom: json['client_nom'] ?? json['client_passage_nom'] ?? json['clientNom'] ?? json['client']?['nom'] ?? 'Client Particulier',
      clientTel: json['client_telephone'] ?? json['client_passage_telephone'] ?? json['clientTel'] ?? json['client']?['telephone'] ?? '',
      clientEmail: json['client_email'] ?? json['client_passage_email'] ?? json['clientEmail'] ?? json['client']?['email'] ?? '',
      adresseLivraison: json['adresse_livraison'] ?? json['client_adresse'] ?? json['adresseLivraison'] ?? 'Port-au-Prince',
      modePaiement: rawMode,
      precisionPaiement: json['precision_paiement']?.toString() ?? json['precisionPaiement']?.toString(),
      montantTotal: double.tryParse(json['montant_total']?.toString() ?? json['montantTotal']?.toString() ?? '0') ?? 0.0,
      statut: json['statut']?.toString() ?? 'ASSIGNEE',
      estPayee: json['est_payee'] == true,
      payeeLe: json['payee_le']?.toString(),
      encaissePar: json['encaisse_par']?.toString(),
      confirmationGpsRequise: json['confirmation_gps_requise'] == true,
      premiereLivraisonAdresse: json['premiere_livraison_adresse'] == true,
      estVenteACredit: isCredit,
      estRetraitSurPlace: json['est_retrait_sur_place'] == true || json['estRetraitSurPlace'] == true,
      chauffeurId: json['chauffeur_id']?.toString() ?? json['chauffeurId']?.toString(),
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
      'chauffeur_id': chauffeurId,
      'est_payee': estPayee,
      'payee_le': payeeLe,
      'encaisse_par': encaissePar,
      'confirmation_gps_requise': confirmationGpsRequise,
      'premiere_livraison_adresse': premiereLivraisonAdresse,
      'est_vente_a_credit': isCreditOrder,
      'est_retrait_sur_place': estRetraitSurPlace,
      'dateCreation': dateCreation.toIso8601String(),
      'items': items.map((i) => i.toJson()).toList(),
      'latitude_livraison': latitude,
      'longitude_livraison': longitude,
    };
  }
}
