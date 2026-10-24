import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../auth/providers/auth_provider.dart';
import '../../../widgets/layout/app_shell.dart';
import '../../auth/views/login_view.dart';
import '../../auth/views/force_change_password_view.dart';
import '../../deliveries/providers/delivery_provider.dart';
import '../../deliveries/views/delivery_list_view.dart';
import '../../notifications/providers/notification_provider.dart';

class SplashView extends StatefulWidget {
  const SplashView({super.key});

  @override
  State<SplashView> createState() => _SplashViewState();
}

class _SplashViewState extends State<SplashView> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );

    _scaleAnimation = Tween<double>(begin: 0.7, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutBack),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeIn),
    );

    _controller.forward();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _initializeApp();
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _initializeApp() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);

    // Lancer en parallèle la temporisation d'affichage et la vérification réseau
    final results = await Future.wait([
      Future.delayed(const Duration(milliseconds: 1200)),
      authProvider.checkAuth(),
    ]);

    final isAuthenticated = results[1] as bool;
    if (!mounted) return;

    final user = authProvider.currentUser;
    Widget destination;
    if (isAuthenticated) {
      // Démarrage des synchronisations d'arrière-plan uniquement si session active et rôle éligible
      if (user != null && (user.role == 'LIVREUR' || user.role == 'CHAUFFEUR')) {
        Provider.of<DeliveryProvider>(context, listen: false).startPolling();
      }
      Provider.of<NotificationProvider>(context, listen: false).startPolling();

      if (user != null && user.doitChangerMotDePasse) {
        destination = ForceChangePasswordView();
      } else if (user != null && (user.role == 'LIVREUR' || user.role == 'CHAUFFEUR')) {
        destination = DeliveryListView();
      } else {
        destination = const AppShell();
      }
    } else {
      final isExpired = authProvider.errorMessage != null &&
          authProvider.errorMessage!.toLowerCase().contains("session expirée");
      destination = LoginView(sessionExpired: isExpired);
    }

    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 500),
        pageBuilder: (context, animation, secondaryAnimation) {
          return FadeTransition(
            opacity: animation,
            child: destination,
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              AppTheme.primaryRoyal,
              AppTheme.primaryDeep,
            ],
          ),
        ),
        child: SafeArea(
          child: Stack(
            children: [
              Center(
                child: FadeTransition(
                  opacity: _fadeAnimation,
                  child: ScaleTransition(
                    scale: _scaleAnimation,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // Official Branding Logo
                        Container(
                          width: 140,
                          height: 140,
                          padding: const EdgeInsets.all(18),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.25),
                                blurRadius: 24,
                                offset: const Offset(0, 10),
                              ),
                            ],
                          ),
                          child: Image.asset(
                            'assets/images/logo.png',
                            fit: BoxFit.contain,
                          ),
                        ),
                        const SizedBox(height: 28),
                        const Text(
                          "TRANSPORT & LOGISTIC",
                          style: TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                            letterSpacing: 2.0,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 6),
                        Text(
                          "SYSTÈME D'EXPLOITATION & DISTRIBUTION",
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.accentSky.withValues(alpha: 0.95),
                            letterSpacing: 2.0,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // Bottom Loading Bar & Copyright
              Positioned(
                bottom: 40,
                left: 0,
                right: 0,
                child: FadeTransition(
                  opacity: _fadeAnimation,
                  child: Column(
                    children: const [
                      SizedBox(
                        width: 32,
                        height: 32,
                        child: CircularProgressIndicator(
                          color: AppTheme.accentSky,
                          strokeWidth: 3.0,
                        ),
                      ),
                      SizedBox(height: 20),
                      Text(
                        "v1.0.0 — Système d'Exploitation Station",
                        style: TextStyle(
                          color: Colors.white60,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
