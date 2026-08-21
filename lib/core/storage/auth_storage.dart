import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class AuthStorage {
  static const _storage = FlutterSecureStorage();

  static const String _keyToken = "jwt_token";
  static const String _keyUserId = "user_id";
  static const String _keyUserNom = "user_nom";
  static const String _keyUserEmail = "user_email";
  static const String _keyUserRole = "user_role";
  static const String _keyMustChangePassword = "must_change_password";

  static Future<void> saveSession({
    required String token,
    required String userId,
    required String nom,
    required String email,
    required String role,
    bool doitChangerMotDePasse = false,
  }) async {
    await _storage.write(key: _keyToken, value: token);
    await _storage.write(key: _keyUserId, value: userId);
    await _storage.write(key: _keyUserNom, value: nom);
    await _storage.write(key: _keyUserEmail, value: email);
    await _storage.write(key: _keyUserRole, value: role);
    await _storage.write(
        key: _keyMustChangePassword, value: doitChangerMotDePasse.toString());
  }

  static Future<String?> getToken() async => await _storage.read(key: _keyToken);
  static Future<String?> getUserId() async => await _storage.read(key: _keyUserId);
  static Future<String?> getUserNom() async => await _storage.read(key: _keyUserNom);
  static Future<String?> getUserEmail() async => await _storage.read(key: _keyUserEmail);
  static Future<String?> getUserRole() async => await _storage.read(key: _keyUserRole);
  static Future<bool> getMustChangePassword() async {
    final val = await _storage.read(key: _keyMustChangePassword);
    return val == 'true';
  }

  static Future<void> clearSession() async {
    await _storage.deleteAll();
  }
}
