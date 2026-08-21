class UserModel {
  final String id;
  final String nom;
  final String email;
  final String role;
  final String? telephone;
  final bool actif;
  final bool doitChangerMotDePasse;

  UserModel({
    required this.id,
    required this.nom,
    required this.email,
    required this.role,
    this.telephone,
    required this.actif,
    this.doitChangerMotDePasse = false,
  });

  bool get isSuperAdmin => role == 'SUPER_ADMIN';
  bool get isAdmin => role == 'ADMIN' || isSuperAdmin;
  bool get isManager => role == 'MANAGER';
  bool get isStationStaff =>
      role == 'AGENT_STATION' ||
      role == 'GUICHETIER' ||
      role == 'OPERATEUR_PISTE' ||
      isAdmin ||
      isManager;
  bool get isLivreur => role == 'LIVREUR';
  bool get isClient => role == 'CLIENT';

  bool get isInternal => !isClient;

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'] ?? '',
      nom: json['nom'] ?? '',
      email: json['email'] ?? '',
      role: json['role'] ?? 'AGENT_STATION',
      telephone: json['telephone'],
      actif: json['actif'] ?? true,
      doitChangerMotDePasse: json['doit_changer_mot_de_passe'] ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'nom': nom,
      'email': email,
      'role': role,
      'telephone': telephone,
      'actif': actif,
      'doit_changer_mot_de_passe': doitChangerMotDePasse,
    };
  }
}
