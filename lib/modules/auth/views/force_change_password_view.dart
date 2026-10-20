import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../widgets/layout/app_shell.dart';
import '../../../widgets/overlays/app_notifications.dart';
import '../../deliveries/views/delivery_list_view.dart';
import '../providers/auth_provider.dart';

class ForceChangePasswordView extends StatefulWidget {
  const ForceChangePasswordView({super.key});

  @override
  State<ForceChangePasswordView> createState() => _ForceChangePasswordViewState();
}

class _ForceChangePasswordViewState extends State<ForceChangePasswordView> {
  final _formKey = GlobalKey<FormState>();
  final _oldPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _obscureOld = true;
  bool _obscureNew = true;
  bool _obscureConfirm = true;

  @override
  void dispose() {
    _oldPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  void _submitChangePassword() async {
    if (_formKey.currentState!.validate()) {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final success = await authProvider.changePassword(
        _oldPasswordController.text,
        _newPasswordController.text,
      );

      if (!mounted) return;

      if (success) {
        AppNotifications.showSuccess(
          context,
          "Votre mot de passe a été mis à jour avec succès !",
        );

        final userRole = authProvider.currentUser?.role;
        if (userRole == 'LIVREUR' || userRole == 'CHAUFFEUR') {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (context) => const DeliveryListView()),
          );
        } else {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (context) => const AppShell()),
          );
        }
      } else if (authProvider.errorMessage != null) {
        AppNotifications.showError(context, authProvider.errorMessage!);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final user = authProvider.currentUser;
    final bool isDark = AppTheme.isDark(context);

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF071426) : AppTheme.bgFrost,
      appBar: AppBar(
        title: const Text(
          "Sécurité du Compte",
          style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18),
        ),
        backgroundColor: AppTheme.primaryRoyal,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: "Se déconnecter",
            onPressed: () => authProvider.logout(context),
          ),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Header Icon
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: AppTheme.primaryRoyal.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: AppTheme.primaryRoyal.withValues(alpha: 0.25),
                      width: 2,
                    ),
                  ),
                  child: const Icon(
                    Icons.lock_reset_rounded,
                    size: 42,
                    color: AppTheme.primaryRoyal,
                  ),
                ),
                const SizedBox(height: 20),

                // Title
                Text(
                  "Changement Obligatoire",
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        color: isDark ? Colors.white : AppTheme.textNight,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.5,
                      ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),

                // Explanation Banner
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.amber.shade50,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Colors.amber.shade200),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.shield_outlined, color: Colors.amber.shade800, size: 20),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          "Bonjour ${user?.nom ?? ''}. Pour garantir la sécurité de votre accès, vous devez obligatoirement remplacer le mot de passe provisoire par un nouveau mot de passe personnel.",
                          style: TextStyle(
                            fontSize: 12.5,
                            color: Colors.amber.shade900,
                            fontWeight: FontWeight.w600,
                            height: 1.35,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Form Card
                Card(
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                    side: BorderSide(
                      color: isDark ? Colors.white12 : AppTheme.borderColor(context),
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(22.0),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Champ 1: Ancien mot de passe
                          TextFormField(
                            controller: _oldPasswordController,
                            obscureText: _obscureOld,
                            decoration: InputDecoration(
                              labelText: "Mot de passe actuel (provisoire)",
                              prefixIcon: const Icon(Icons.lock_outline),
                              suffixIcon: IconButton(
                                icon: Icon(_obscureOld ? Icons.visibility_off : Icons.visibility),
                                onPressed: () => setState(() => _obscureOld = !_obscureOld),
                              ),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            validator: (val) {
                              if (val == null || val.trim().isEmpty) {
                                return "Veuillez entrer votre mot de passe actuel";
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 18),

                          // Champ 2: Nouveau mot de passe
                          TextFormField(
                            controller: _newPasswordController,
                            obscureText: _obscureNew,
                            decoration: InputDecoration(
                              labelText: "Nouveau mot de passe",
                              helperText: "Au moins 8 caractères recommandés",
                              prefixIcon: const Icon(Icons.vpn_key_outlined),
                              suffixIcon: IconButton(
                                icon: Icon(_obscureNew ? Icons.visibility_off : Icons.visibility),
                                onPressed: () => setState(() => _obscureNew = !_obscureNew),
                              ),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            validator: (val) {
                              if (val == null || val.trim().isEmpty) {
                                return "Veuillez saisir un nouveau mot de passe";
                              }
                              if (val.trim().length < 8) {
                                return "Le mot de passe doit comporter au moins 8 caractères";
                              }
                              if (val.trim() == _oldPasswordController.text.trim()) {
                                return "Le nouveau mot de passe doit être différent de l'ancien";
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 18),

                          // Champ 3: Confirmation
                          TextFormField(
                            controller: _confirmPasswordController,
                            obscureText: _obscureConfirm,
                            decoration: InputDecoration(
                              labelText: "Confirmer le nouveau mot de passe",
                              prefixIcon: const Icon(Icons.check_circle_outline),
                              suffixIcon: IconButton(
                                icon: Icon(_obscureConfirm ? Icons.visibility_off : Icons.visibility),
                                onPressed: () => setState(() => _obscureConfirm = !_obscureConfirm),
                              ),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            validator: (val) {
                              if (val == null || val.trim().isEmpty) {
                                return "Veuillez confirmer votre nouveau mot de passe";
                              }
                              if (val.trim() != _newPasswordController.text.trim()) {
                                return "Les deux nouveaux mots de passe ne correspondent pas";
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 28),

                          // Bouton d'action
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.primaryRoyal,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                              elevation: 2,
                            ),
                            icon: authProvider.isLoading
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      color: Colors.white,
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Icon(Icons.check_circle),
                            label: Text(
                              authProvider.isLoading
                                  ? "Validation en cours..."
                                  : "Valider mon nouveau mot de passe",
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                            ),
                            onPressed: authProvider.isLoading ? null : _submitChangePassword,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // Bouton Annuler / Déconnexion
                TextButton.icon(
                  icon: const Icon(Icons.arrow_back, size: 18),
                  label: const Text(
                    "Annuler et se déconnecter",
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  onPressed: () => authProvider.logout(context),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
