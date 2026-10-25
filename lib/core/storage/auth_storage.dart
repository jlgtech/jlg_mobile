import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class AuthStorage {
  static const _storage = FlutterSecureStorage();

  static const String _keyToken = "jwt_token";
  static const String _keyUserId = "user_id";
  static const String _keyUserNom = "user_nom";
  static const String _keyUserEmail = "user_email";
  static const String _keyUserRole = "user_role";
  static const String _keyMustChangePassword = "must_change_password";
  static const String _keyRememberMe = "remember_me";
  static const String _keySavedEmail = "saved_email";

  /// Vérifie si un jeton JWT est structurellement expiré sans nécessiter d'appel réseau
  static bool isTokenExpired(String? token) {
    if (token == null || token.trim().isEmpty) return true;
    final parts = token.split('.');
    if (parts.length != 3) return true;

    try {
      String payload = parts[1];
      // Normalisation du padding Base64
      switch (payload.length % 4) {
        case 2:
          payload += '==';
          break;
        case 3:
          payload += '=';
          break;
      }
      final decodedBytes = base64Url.decode(payload);
      final decodedJson = utf8.decode(decodedBytes);
      final Map<String, dynamic> data = jsonDecode(decodedJson);

      if (data.containsKey('exp')) {
        final exp = data['exp'];
        if (exp is int) {
          final expDate = DateTime.fromMillisecondsSinceEpoch(exp * 1000);
          // Marge de sécurité de 5 secondes pour éviter les requêtes à la limite
          return DateTime.now().isAfter(expDate.subtract(const Duration(seconds: 5)));
        }
      }
      return false;
    } catch (_) {
      return true;
    }
  }

  static Future<void> saveSession({
    required String token,
    required String userId,
    required String nom,
    required String email,
    required String role,
    bool doitChangerMotDePasse = false,
    bool rememberMe = true,
  }) async {
    await _storage.write(key: _keyToken, value: token);
    await _storage.write(key: _keyUserId, value: userId);
    await _storage.write(key: _keyUserNom, value: nom);
    await _storage.write(key: _keyUserEmail, value: email);
    await _storage.write(key: _keyUserRole, value: role);
    await _storage.write(
        key: _keyMustChangePassword, value: doitChangerMotDePasse.toString());
    await _storage.write(key: _keyRememberMe, value: rememberMe.toString());
    if (rememberMe) {
      await _storage.write(key: _keySavedEmail, value: email.trim());
    }
  }

  /// Retourne le jeton d'authentification s'il est encore valide, sinon purge la session
  static Future<String?> getToken() async {
    final token = await _storage.read(key: _keyToken);
    if (token != null && isTokenExpired(token)) {
      await clearSession();
      return null;
    }
    return token;
  }

  /// Vérifie si une session active et non expirée est présente
  static Future<bool> hasValidSession() async {
    final token = await _storage.read(key: _keyToken);
    return token != null && !isTokenExpired(token);
  }

  static Future<String?> getUserId() async => await _storage.read(key: _keyUserId);
  static Future<String?> getUserNom() async => await _storage.read(key: _keyUserNom);
  static Future<String?> getUserEmail() async => await _storage.read(key: _keyUserEmail);
  static Future<String?> getUserRole() async => await _storage.read(key: _keyUserRole);
  static Future<bool> getMustChangePassword() async {
    final val = await _storage.read(key: _keyMustChangePassword);
    return val == 'true';
  }

  static Future<bool> getRememberMe() async {
    final val = await _storage.read(key: _keyRememberMe);
    // Activé par défaut si non spécifié pour le confort des livreurs
    return val == null || val == 'true';
  }

  static Future<void> setRememberMe(bool value) async {
    await _storage.write(key: _keyRememberMe, value: value.toString());
  }

  static Future<String?> getSavedEmail() async => await _storage.read(key: _keySavedEmail);

  static Future<void> saveSavedEmail(String email) async {
    await _storage.write(key: _keySavedEmail, value: email.trim());
  }

  static Future<void> clearSession({bool keepSavedEmail = true}) async {
    String? savedEmail;
    String? rememberMe;
    if (keepSavedEmail) {
      savedEmail = await _storage.read(key: _keySavedEmail);
      rememberMe = await _storage.read(key: _keyRememberMe);
    }
    await _storage.deleteAll();
    if (keepSavedEmail) {
      if (savedEmail != null) {
        await _storage.write(key: _keySavedEmail, value: savedEmail);
      }
      if (rememberMe != null) {
        await _storage.write(key: _keyRememberMe, value: rememberMe);
      }
    }
  }
}
