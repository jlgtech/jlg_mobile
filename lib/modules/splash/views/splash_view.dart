import 'dart:math' as math;
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

class _SplashViewState extends State<SplashView> with TickerProviderStateMixin {
  late AnimationController _introController;
  late AnimationController _orbitController;
  late AnimationController _radarController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();

    // Controleur de l'entree progressive du logo et des titres
    _introController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );

    _scaleAnimation = Tween<double>(begin: 0.75, end: 1.0).animate(
      CurvedAnimation(parent: _introController, curve: Curves.easeOutBack),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _introController, curve: Curves.easeIn),
    );

    // Controleur de la rotation orbitale continue du camion
    _orbitController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3200),
    )..repeat();

    // Controleur des ondes radar et pulsations du hub
    _radarController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    )..repeat();

    _introController.forward();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _initializeApp();
      }
    });
  }

  @override
  void dispose() {
    _introController.dispose();
    _orbitController.dispose();
    _radarController.dispose();
    super.dispose();
  }

  Future<void> _initializeApp() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);

    // Temporisation minimale pour apprecier l'animation orbitale + verification auth
    final results = await Future.wait([
      Future.delayed(const Duration(milliseconds: 1400)),
      authProvider.checkAuth(),
    ]);

    final isAuthenticated = results[1] as bool;
    if (!mounted) return;

    final user = authProvider.currentUser;
    Widget destination;
    if (isAuthenticated) {
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
        transitionDuration: const Duration(milliseconds: 600),
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
              Color(0xFF040B18),
              Color(0xFF071933),
              Color(0xFF0A2246),
              Color(0xFF040A15),
            ],
          ),
        ),
        child: SafeArea(
          child: Stack(
            children: [
              // 1. Grille logistique et particules celestes en arriere-plan
              Positioned.fill(
                child: CustomPaint(
                  painter: _AmbientBackgroundPainter(
                    animation: _orbitController,
                  ),
                ),
              ),

              // 2. Hub Logistique Isometrique 3D avec Z-index dynamique
              Center(
                child: FadeTransition(
                  opacity: _fadeAnimation,
                  child: ScaleTransition(
                    scale: _scaleAnimation,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // Zone du hub orbital en 3D isometrique
                        SizedBox(
                          width: 320,
                          height: 300,
                          child: AnimatedBuilder(
                            animation: Listenable.merge([_orbitController, _radarController]),
                            builder: (context, _) {
                              final orbitValue = _orbitController.value;
                              final angle = orbitValue * 2 * math.pi;
                              // Le camion est derriere le logo quand sin(angle) < 0 (demi-cercle superieur)
                              final isBehind = math.sin(angle) < 0;

                              return Stack(
                                alignment: Alignment.center,
                                children: [
                                  // A. Couche Arriere : Piste isometrique, balises, radar et camion si derriere
                                  Positioned.fill(
                                    child: CustomPaint(
                                      painter: _OrbitLayerPainter(
                                        orbitProgress: orbitValue,
                                        radarProgress: _radarController.value,
                                        drawTruck: isBehind,
                                        isBehind: true,
                                      ),
                                    ),
                                  ),

                                  // B. Couche Centrale : Logo officiel JLG avec halo d'energie
                                  Container(
                                    width: 132,
                                    height: 132,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      boxShadow: [
                                        BoxShadow(
                                          color: AppTheme.accentSky.withValues(alpha: 0.35),
                                          blurRadius: 36,
                                          spreadRadius: 4,
                                        ),
                                        BoxShadow(
                                          color: Colors.black.withValues(alpha: 0.55),
                                          blurRadius: 24,
                                          offset: const Offset(0, 10),
                                        ),
                                      ],
                                    ),
                                    child: Container(
                                      padding: const EdgeInsets.all(16),
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                          color: AppTheme.accentSky.withValues(alpha: 0.40),
                                          width: 2.5,
                                        ),
                                      ),
                                      child: Image.asset(
                                        'assets/images/logo.png',
                                        fit: BoxFit.contain,
                                      ),
                                    ),
                                  ),

                                  // C. Couche Avant : Camion si devant (avec phares volumetriques et trainees)
                                  if (!isBehind)
                                    Positioned.fill(
                                      child: CustomPaint(
                                        painter: _OrbitLayerPainter(
                                          orbitProgress: orbitValue,
                                          radarProgress: _radarController.value,
                                          drawTruck: true,
                                          isBehind: false,
                                        ),
                                      ),
                                    ),
                                ],
                              );
                            },
                          ),
                        ),

                        const SizedBox(height: 32),

                        // Slogan épuré
                        const Text(
                          "Transport & Logistic",
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                            letterSpacing: 3.2,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // 3. Pied de page épuré : Barre de chargement et version de l'APK
              Positioned(
                bottom: 36,
                left: 0,
                right: 0,
                child: FadeTransition(
                  opacity: _fadeAnimation,
                  child: Column(
                    children: [
                      SizedBox(
                        width: 140,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: LinearProgressIndicator(
                            minHeight: 4,
                            backgroundColor: Colors.white.withValues(alpha: 0.12),
                            valueColor: const AlwaysStoppedAnimation<Color>(
                              AppTheme.accentSky,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      Text(
                        "v1.0.0",
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.45),
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 1.5,
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

/// ---------------------------------------------------------------------------
/// PEINTRE ORBITAL MULTI-COUCHES (Z-INDEX 3D ISOMETRIQUE)
/// ---------------------------------------------------------------------------
class _OrbitLayerPainter extends CustomPainter {
  final double orbitProgress; // 0.0 -> 1.0
  final double radarProgress; // 0.0 -> 1.0
  final bool drawTruck;
  final bool isBehind;

  static const double orbitRadiusX = 124.0;
  static const double orbitRadiusY = 82.0;

  _OrbitLayerPainter({
    required this.orbitProgress,
    required this.radarProgress,
    required this.drawTruck,
    required this.isBehind,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);

    // Si on est dans la couche arriere, on dessine la piste et les impulsions radar
    if (isBehind) {
      _drawRadarPulses(canvas, center);
      _drawIsometricTrack(canvas, center);
    }

    // Dessin du camion si mandate pour ce plan de profondeur
    if (drawTruck) {
      _drawOrbitingTruck(canvas, center);
    }
  }

  // 1. Ondes radar concentriques emanant du hub central
  void _drawRadarPulses(Canvas canvas, Offset center) {
    final pulsePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;

    for (int i = 0; i < 3; i++) {
      final pulse = (radarProgress + (i * 0.33)) % 1.0;
      final currentRx = 66.0 + (pulse * (orbitRadiusX - 40.0));
      final currentRy = (currentRx / orbitRadiusX) * orbitRadiusY;
      final alpha = (1.0 - pulse) * 0.35;

      pulsePaint.color = AppTheme.accentSky.withValues(alpha: alpha);
      canvas.drawOval(
        Rect.fromCenter(
          center: center,
          width: currentRx * 2,
          height: currentRy * 2,
        ),
        pulsePaint,
      );
    }
  }

  // 2. Anneau orbital isometrique avec balises GPS lumineuses
  void _drawIsometricTrack(Canvas canvas, Offset center) {
    // Halo lumineux externe
    final glowPaint = Paint()
      ..color = AppTheme.accentSky.withValues(alpha: 0.12)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5.0
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);

    canvas.drawOval(
      Rect.fromCenter(
        center: center,
        width: orbitRadiusX * 2,
        height: orbitRadiusY * 2,
      ),
      glowPaint,
    );

    // Ligne de guidage fine
    final trackPaint = Paint()
      ..color = AppTheme.accentSky.withValues(alpha: 0.25)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8;

    canvas.drawOval(
      Rect.fromCenter(
        center: center,
        width: orbitRadiusX * 2,
        height: orbitRadiusY * 2,
      ),
      trackPaint,
    );

    // 8 Balises lumineuses sur la piste
    final beaconPaint = Paint()..style = PaintingStyle.fill;
    for (int i = 0; i < 8; i++) {
      final angle = (i * math.pi / 4);
      final bx = center.dx + orbitRadiusX * math.cos(angle);
      final by = center.dy + orbitRadiusY * math.sin(angle);

      beaconPaint.color = AppTheme.accentSky.withValues(alpha: 0.40);
      canvas.drawCircle(Offset(bx, by), 2.0, beaconPaint);
    }
  }

  // 3. Camion en orbite avec orientation, perspective et eclairage
  void _drawOrbitingTruck(Canvas canvas, Offset center) {
    final angle = orbitProgress * 2 * math.pi;

    // Position exacte sur l'ellipse isometrique
    final truckPos = Offset(
      center.dx + orbitRadiusX * math.cos(angle),
      center.dy + orbitRadiusY * math.sin(angle),
    );

    // Trainee de comete de vitesse et micro-particules (dessinees avant le camion)
    _drawSpeedTrail(canvas, center, angle);

    // Calcul du cap / orientation tangentielle
    final tangentX = -orbitRadiusX * math.sin(angle);
    final tangentY = orbitRadiusY * math.cos(angle);
    final heading = math.atan2(tangentY, tangentX);

    // Echelle de profondeur 3D : 0.82 (au fond) -> 1.18 (au premier plan)
    final depthFactor = 0.82 + 0.36 * ((math.sin(angle) + 1.0) / 2.0);

    canvas.save();
    canvas.translate(truckPos.dx, truckPos.dy);
    canvas.rotate(heading);
    canvas.scale(depthFactor);

    _drawIsometricTruckBody(canvas, isBehind);

    canvas.restore();
  }

  // Trainee lumineuse et particules aerodynamiques
  void _drawSpeedTrail(Canvas canvas, Offset center, double angle) {
    const trailSpan = 0.65;
    const steps = 24;
    final trailPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    for (int i = 0; i < steps; i++) {
      final t1 = angle - (trailSpan * (i / steps));
      final t2 = angle - (trailSpan * ((i + 1) / steps));

      final p1 = Offset(
        center.dx + orbitRadiusX * math.cos(t1),
        center.dy + orbitRadiusY * math.sin(t1),
      );
      final p2 = Offset(
        center.dx + orbitRadiusX * math.cos(t2),
        center.dy + orbitRadiusY * math.sin(t2),
      );

      final ratio = 1.0 - (i / steps);
      final alpha = ratio * (isBehind ? 0.30 : 0.55);

      // Degradé de couleur : cyan vers ambre
      final color = Color.lerp(
        const Color(0xFFFFB300),
        AppTheme.accentSky,
        ratio,
      )!;

      trailPaint
        ..color = color.withValues(alpha: alpha)
        ..strokeWidth = 3.5 * ratio;

      canvas.drawLine(p1, p2, trailPaint);

      // Micro-particule d'energie tous les 4 crans
      if (i % 4 == 0) {
        final dotPaint = Paint()
          ..color = const Color(0xFFFFB300).withValues(alpha: alpha * 0.8)
          ..style = PaintingStyle.fill;
        canvas.drawCircle(p1, 1.4 * ratio, dotPaint);
      }
    }
  }

  // Carrosserie vectorielle haute precision du camion
  void _drawIsometricTruckBody(Canvas canvas, bool isDistant) {
    final opacity = isDistant ? 0.88 : 1.0;

    // Ombre portee douce sous le camion
    canvas.drawOval(
      Rect.fromCenter(center: const Offset(-1, 0), width: 48, height: 20),
      Paint()
        ..color = Colors.black.withValues(alpha: isDistant ? 0.25 : 0.45)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
    );

    // Faisceaux volumetriques des phares avant (projetes vers l'avant)
    final headlightBeam = Path()
      ..moveTo(20, -5)
      ..lineTo(70, -22)
      ..lineTo(70, 22)
      ..lineTo(20, 5)
      ..close();

    canvas.drawPath(
      headlightBeam,
      Paint()
        ..shader = LinearGradient(
          colors: [
            const Color(0xFFFFFBEB).withValues(alpha: isDistant ? 0.25 : 0.55),
            const Color(0xFF67E8F9).withValues(alpha: isDistant ? 0.08 : 0.20),
            Colors.transparent,
          ],
          stops: const [0.0, 0.45, 1.0],
        ).createShader(const Rect.fromLTRB(20, -22, 70, 22)),
    );

    // Chassis sombre et robuste
    final chassisPaint = Paint()
      ..color = const Color(0xFF0F172A).withValues(alpha: opacity);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTRB(-20, -8, 20, 8),
        const Radius.circular(3),
      ),
      chassisPaint,
    );

    // Roues doubles avec jantes alu
    final wheelPaint = Paint()
      ..color = const Color(0xFF1E293B).withValues(alpha: opacity);
    final rimPaint = Paint()
      ..color = const Color(0xFF94A3B8).withValues(alpha: opacity);

    const wheels = [
      Offset(-14, -9),
      Offset(-14, 9),
      Offset(-7, -9),
      Offset(-7, 9),
      Offset(12, -9),
      Offset(12, 9),
    ];

    for (final w in wheels) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(center: w, width: 7, height: 4),
          const Radius.circular(1.5),
        ),
        wheelPaint,
      );
      canvas.drawCircle(w, 1.1, rimPaint);
    }

    // Remorque Citerne JLG System (Degrade Bleu Royal avec reflets cylindriques)
    final trailerRect = const Rect.fromLTRB(-20, -7.5, 4, 7.5);
    final trailerPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          const Color(0xFF2563EB).withValues(alpha: opacity),
          AppTheme.primaryDeep.withValues(alpha: opacity),
          const Color(0xFF0A254D).withValues(alpha: opacity),
        ],
      ).createShader(trailerRect);

    canvas.drawRRect(
      RRect.fromRectAndRadius(trailerRect, const Radius.circular(3.5)),
      trailerPaint,
    );

    // Bandeau dore ambre corporatif JLG sur le flanc
    final stripePaint = Paint()
      ..color = const Color(0xFFFFB300).withValues(alpha: opacity);
    canvas.drawRect(const Rect.fromLTRB(-20, -1.2, 4, 1.2), stripePaint);

    // Cabine du camion (Blanc aerodynamique avec decoupe moderne)
    final cabinRect = const Rect.fromLTRB(4, -7, 19, 7);
    final cabinPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Colors.white.withValues(alpha: opacity),
          const Color(0xFFE2E8F0).withValues(alpha: opacity),
        ],
      ).createShader(cabinRect);

    canvas.drawRRect(
      RRect.fromRectAndRadius(cabinRect, const Radius.circular(3.5)),
      cabinPaint,
    );

    // Pare-brise panoramique teinte (Bleu Ciel Azure avec reflet)
    final windshieldPaint = Paint()
      ..color = const Color(0xFF0284C7).withValues(alpha: opacity);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTRB(13, -5.5, 17.5, 5.5),
        const Radius.circular(1.5),
      ),
      windshieldPaint,
    );

    // Reflet blanc biseaute sur le pare-brise
    final reflectionPaint = Paint()
      ..color = Colors.white.withValues(alpha: opacity * 0.7);
    canvas.drawLine(
      const Offset(14, -4),
      const Offset(16.5, 0),
      reflectionPaint..strokeWidth = 0.8,
    );

    // Vitres de portieres laterales
    final sideGlassPaint = Paint()
      ..color = const Color(0xFF0369A1).withValues(alpha: opacity);
    canvas.drawRect(const Rect.fromLTRB(6, -6.2, 11, -4.5), sideGlassPaint);
    canvas.drawRect(const Rect.fromLTRB(6, 4.5, 11, 6.2), sideGlassPaint);

    // Projecteurs phares LED avant (gemmes jaunes éclatantes)
    final headlightPaint = Paint()
      ..color = const Color(0xFFFDE047).withValues(alpha: opacity);
    canvas.drawCircle(const Offset(19, -4.8), 1.8, headlightPaint);
    canvas.drawCircle(const Offset(19, 4.8), 1.8, headlightPaint);

    // Feux stop de gabarit arriere (LEDs rouges avec micro-lueur)
    final taillightPaint = Paint()
      ..color = const Color(0xFFEF4444).withValues(alpha: opacity);
    canvas.drawCircle(const Offset(-20, -5.2), 1.4, taillightPaint);
    canvas.drawCircle(const Offset(-20, 5.2), 1.4, taillightPaint);
  }

  @override
  bool shouldRepaint(covariant _OrbitLayerPainter oldDelegate) {
    return oldDelegate.orbitProgress != orbitProgress ||
        oldDelegate.radarProgress != radarProgress ||
        oldDelegate.drawTruck != drawTruck ||
        oldDelegate.isBehind != isBehind;
  }
}

/// ---------------------------------------------------------------------------
/// PEINTRE D'AMBIANCE : Grille logistique et particules celestes
/// ---------------------------------------------------------------------------
class _AmbientBackgroundPainter extends CustomPainter {
  final Animation<double> animation;

  _AmbientBackgroundPainter({required this.animation}) : super(repaint: animation);

  @override
  void paint(Canvas canvas, Size size) {
    final t = animation.value;

    // 1. Grille logistique subtile en filigrane
    final gridPaint = Paint()
      ..color = AppTheme.accentSky.withValues(alpha: 0.04)
      ..strokeWidth = 0.8;

    const step = 44.0;
    for (double x = 0; x <= size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), gridPaint);
    }
    for (double y = 0; y <= size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    // 2. Micro-points et etoiles scintillantes
    final dotPaint = Paint();
    for (int i = 0; i < 28; i++) {
      final rnd = math.Random(i * 17 + 11);
      final dx = rnd.nextDouble() * size.width;
      final dy = rnd.nextDouble() * size.height;
      final twinkle = 0.25 + 0.75 * (0.5 + 0.5 * math.sin(t * 2 * math.pi + i));

      dotPaint.color = Colors.white.withValues(alpha: 0.16 * twinkle);
      canvas.drawCircle(Offset(dx, dy), 0.9 + rnd.nextDouble() * 1.1, dotPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _AmbientBackgroundPainter oldDelegate) => false;
}
