import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/theme_provider.dart';
import '../../../widgets/layout/app_shell.dart';
import '../../../widgets/overlays/app_notifications.dart';
import '../../deliveries/providers/delivery_provider.dart';
import '../../deliveries/views/delivery_list_view.dart';
import '../../notifications/providers/notification_provider.dart';
import '../providers/auth_provider.dart';
import 'force_change_password_view.dart';

class LoginView extends StatefulWidget {
  final bool sessionExpired;

  const LoginView({
    super.key,
    this.sessionExpired = false,
  });

  @override
  State<LoginView> createState() => _LoginViewState();
}

class _LoginViewState extends State<LoginView> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _submitLogin() async {
    if (_formKey.currentState!.validate()) {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final success = await authProvider.login(
        _emailController.text,
        _passwordController.text,
      );

      if (!mounted) return;
      if (success) {
        final user = authProvider.currentUser;
        // Démarrage des synchronisations d'arrière-plan ciblées par rôle
        if (user != null && (user.role == 'LIVREUR' || user.role == 'CHAUFFEUR')) {
          Provider.of<DeliveryProvider>(context, listen: false).startPolling();
        }
        Provider.of<NotificationProvider>(context, listen: false).startPolling();
        AppNotifications.showSuccess(context, "Connexion réussie !");
        if (user != null && user.doitChangerMotDePasse) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (context) => ForceChangePasswordView()),
          );
          return;
        }

        final userRole = user?.role;
        if (userRole == 'LIVREUR' || userRole == 'CHAUFFEUR') {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (context) => DeliveryListView()),
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
    final themeProvider = Provider.of<ThemeProvider>(context);
    final bool isDark = AppTheme.isDark(context);

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Logo & Header
                Container(
                  width: 110,
                  height: 110,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: (isDark ? Colors.black : AppTheme.primaryRoyal).withValues(alpha: 0.15),
                        blurRadius: 18,
                        offset: const Offset(0, 8),
                      ),
                    ],
                    border: Border.all(
                      color: isDark ? AppTheme.accentSky.withValues(alpha: 0.3) : AppTheme.borderColor(context),
                      width: 1.5,
                    ),
                  ),
                  child: Image.asset(
                    'assets/images/logo.png',
                    fit: BoxFit.contain,
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  themeProvider.tr('app_title'),
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        color: isDark ? Colors.white : AppTheme.primaryRoyal,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.5,
                      ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  "Portail Opérationnel & Gestion Station",
                  style: TextStyle(
                    fontSize: 14,
                    color: AppTheme.mutedColor(context),
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 36),

                // Form Card
                Card(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                    side: BorderSide(color: AppTheme.borderColor(context)),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if (widget.sessionExpired || (authProvider.errorMessage != null && authProvider.errorMessage!.toLowerCase().contains("session expirée")))
                            Container(
                              margin: const EdgeInsets.only(bottom: 20),
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                              decoration: BoxDecoration(
                                color: isDark ? const Color(0xFF451A03) : const Color(0xFFFEF3C7),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: isDark ? const Color(0xFFD97706) : const Color(0xFFF59E0B),
                                ),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.lock_clock_outlined,
                                    color: isDark ? const Color(0xFFFDE68A) : const Color(0xFFB45309),
                                    size: 22,
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      "Votre session a expiré pour des raisons de sécurité. Veuillez vous reconnecter pour poursuivre vos opérations.",
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: isDark ? const Color(0xFFFDE68A) : const Color(0xFF92400E),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),

                          Text(
                            themeProvider.tr('login_title'),
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.titleColor(context),
                            ),
                          ),
                          const SizedBox(height: 20),

                          // Email Field
                          TextFormField(
                            controller: _emailController,
                            keyboardType: TextInputType.emailAddress,
                            decoration: InputDecoration(
                              labelText: themeProvider.tr('email'),
                              prefixIcon: const Icon(Icons.email_outlined),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return "Veuillez entrer votre email";
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),

                          // Password Field
                          TextFormField(
                            controller: _passwordController,
                            obscureText: _obscurePassword,
                            decoration: InputDecoration(
                              labelText: themeProvider.tr('password'),
                              prefixIcon: const Icon(Icons.lock_outline),
                              suffixIcon: IconButton(
                                icon: Icon(_obscurePassword ? Icons.visibility_off : Icons.visibility),
                                onPressed: () {
                                  setState(() {
                                    _obscurePassword = !_obscurePassword;
                                  });
                                },
                              ),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return "Veuillez entrer votre mot de passe";
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 24),

                          // Submit Button
                          SizedBox(
                            height: 52,
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: isDark ? AppTheme.accentMint : AppTheme.primaryEmerald,
                                foregroundColor: isDark ? const Color(0xFF0B0F19) : Colors.white,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                              ),
                              onPressed: authProvider.isLoading ? null : _submitLogin,
                              child: authProvider.isLoading
                                  ? SizedBox(
                                      width: 24,
                                      height: 24,
                                      child: CircularProgressIndicator(
                                        color: isDark ? const Color(0xFF0B0F19) : Colors.white,
                                        strokeWidth: 2.5,
                                      ),
                                    )
                                  : Text(
                                      themeProvider.tr('login_button'),
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                    ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
