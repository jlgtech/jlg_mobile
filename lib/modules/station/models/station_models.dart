class CamionStationModel {
  final String id;
  final String plaqueImmatriculation;
  final String? nomProprietaire;
  final String? telephone;

  CamionStationModel({
    required this.id,
    required this.plaqueImmatriculation,
    this.nomProprietaire,
    this.telephone,
  });

  factory CamionStationModel.fromJson(Map<String, dynamic> json) {
    return CamionStationModel(
      id: json['id']?.toString() ?? '',
      plaqueImmatriculation: json['plaque_immatriculation']?.toString() ?? '',
      nomProprietaire: json['nom_proprietaire']?.toString(),
      telephone: json['telephone']?.toString(),
    );
  }
}

class TransactionStationModel {
  final String id;
  final String codeTicket;
  final String camionId;
  final String agentStationId;
  final double montantHtg;
  final String modePaiement;
  final String statut; // EN_ATTENTE, EN_COURS, TERMINEE, ANNULEE
  final DateTime heureEntree;
  final DateTime? heureDebutRemplissage;
  final DateTime? heureSortie;
  final CamionStationModel? camion;

  TransactionStationModel({
    required this.id,
    required this.codeTicket,
    required this.camionId,
    required this.agentStationId,
    required this.montantHtg,
    required this.modePaiement,
    required this.statut,
    required this.heureEntree,
    this.heureDebutRemplissage,
    this.heureSortie,
    this.camion,
  });

  factory TransactionStationModel.fromJson(Map<String, dynamic> json) {
    String rawStatut = 'EN_ATTENTE';
    if (json['statut'] != null) {
      if (json['statut'] is String) {
        rawStatut = json['statut'];
      } else if (json['statut'] is Map && json['statut']['value'] != null) {
        rawStatut = json['statut']['value'].toString();
      }
    }

    return TransactionStationModel(
      id: json['id']?.toString() ?? '',
      codeTicket: json['code_ticket']?.toString() ?? '',
      camionId: json['camion_id']?.toString() ?? '',
      agentStationId: json['agent_station_id']?.toString() ?? '',
      montantHtg: (json['montant_htg'] is num) ? (json['montant_htg'] as num).toDouble() : 12500.0,
      modePaiement: json['mode_paiement']?.toString() ?? 'CASH',
      statut: rawStatut.toUpperCase().trim(),
      heureEntree: DateTime.tryParse(json['heure_entree']?.toString() ?? '') ?? DateTime.now(),
      heureDebutRemplissage: json['heure_debut_remplissage'] != null ? DateTime.tryParse(json['heure_debut_remplissage'].toString()) : null,
      heureSortie: json['heure_sortie'] != null ? DateTime.tryParse(json['heure_sortie'].toString()) : null,
      camion: json['camion'] != null ? CamionStationModel.fromJson(json['camion']) : null,
    );
  }
}
