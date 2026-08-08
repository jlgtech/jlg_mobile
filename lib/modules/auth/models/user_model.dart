class UserModel {
  final String id;
  final String nom;
  final String email;
  final String role;
  final String? telephone;
  final bool actif;

  UserModel({
    required this.id,
    required this.nom,
    required this.email,
    required this.role,
    this.telephone,
    required this.actif,
  });

  bool get isInternal =>
      role == 'ADMIN' ||
      role == 'AGENT_STATION' ||
      role == 'RESPONSABLE_STATION' ||
      role == 'SUPERVISEUR';

  bool get isExternal => !isInternal;

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'] ?? '',
      nom: json['nom'] ?? '',
      email: json['email'] ?? '',
      role: json['role'] ?? 'AGENT_STATION',
      telephone: json['telephone'],
      actif: json['actif'] ?? true,
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
    };
  }
}
