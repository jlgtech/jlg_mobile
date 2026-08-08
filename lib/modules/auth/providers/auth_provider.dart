import 'dart:convert';
import 'package:flutter/material.dart';
import '../../../core/network/api_client.dart';
import '../../../core/storage/auth_storage.dart';
import '../models/user_model.dart';
import '../views/login_view.dart';

class AuthProvider extends ChangeNotifier {
  bool _isLoading = false;
  bool _isAuthenticated = false;
  UserModel? _currentUser;
  String? _errorMessage;

  bool get isLoading => _isLoading;
  bool get isAuthenticated => _isAuthenticated;
  UserModel? get currentUser => _currentUser;
  String? get errorMessage => _errorMessage;

  AuthProvider() {
    ApiClient.onSessionExpired = () {
      _isAuthenticated = false;
      _currentUser = null;
      _errorMessage = "Session expirée. Veuillez vous reconnecter.";
      notifyListeners();
    };
  }

  Future<bool> checkAuth() async {
    _isLoading = true;
    notifyListeners();

    final token = await AuthStorage.getToken();
    if (token != null && token.isNotEmpty) {
      final id = await AuthStorage.getUserId();
      final nom = await AuthStorage.getUserNom();
      final email = await AuthStorage.getUserEmail();
      final role = await AuthStorage.getUserRole();

      if (id != null && nom != null && email != null && role != null) {
        _currentUser = UserModel(
          id: id,
          nom: nom,
          email: email,
          role: role,
          actif: true,
        );
        _isAuthenticated = true;
        _isLoading = false;
        notifyListeners();
        return true;
      }
    }

    _isAuthenticated = false;
    _currentUser = null;
    _isLoading = false;
    notifyListeners();
    return false;
  }

  Future<bool> login(String email, String password) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final response = await ApiClient.post('/auth/login-json', {
        'email': email.trim(),
        'password': password,
      });

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final token = data['access_token'];
        final userData = data['user'];

        final user = UserModel.fromJson(userData);
        _currentUser = user;
        _isAuthenticated = true;

        await AuthStorage.saveSession(
          token: token,
          userId: user.id,
          nom: user.nom,
          email: user.email,
          role: user.role,
        );

        _isLoading = false;
        notifyListeners();
        return true;
      } else {
        final errorData = jsonDecode(response.body);
        _errorMessage = errorData['detail'] ?? 'Identifiants incorrects.';
        _isLoading = false;
        notifyListeners();
        return false;
      }
    } catch (e) {
      _errorMessage = "Impossible de contacter le serveur ($e). Vérifiez votre connexion.";
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<void> logout([BuildContext? context]) async {
    try {
      await ApiClient.post('/auth/logout', {});
    } catch (_) {}

    await AuthStorage.clearSession();
    _isAuthenticated = false;
    _currentUser = null;
    notifyListeners();

    if (context != null && context.mounted) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => const LoginView()),
        (route) => false,
      );
    }
  }
}
