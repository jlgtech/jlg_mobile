import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'core/config/app_config.dart';
import 'core/network/connectivity_service.dart';
import 'core/network/offline_sync_service.dart';
import 'core/services/local_notification_service.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/theme_provider.dart';
import 'modules/deliveries/providers/delivery_provider.dart';
import 'modules/auth/providers/auth_provider.dart';
import 'modules/station/providers/station_provider.dart';
import 'modules/notifications/providers/notification_provider.dart';
import 'modules/splash/views/splash_view.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialisation du service de notifications natives Android/iOS
  await LocalNotificationService.initialize();

  // Initialisation de la surveillance réseau
  await ConnectivityService().initialize();

  // Initialisation du service offline (chargement du cache et actions en attente)
  await OfflineSyncService().initialize();

  // Edge-to-Edge Universal Configuration for Android & iOS
  SystemChrome.setEnabledSystemUIMode(
    SystemUiMode.edgeToEdge,
  );

  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: AppTheme.primaryDeep,
      statusBarIconBrightness: Brightness.light,
      statusBarBrightness: Brightness.dark,
      systemNavigationBarColor: Colors.transparent,
      systemNavigationBarDividerColor: Colors.transparent,
      systemNavigationBarIconBrightness: Brightness.dark,
    ),
  );

  runApp(const JLGMobileApp());
}

class JLGMobileApp extends StatefulWidget {
  const JLGMobileApp({super.key});

  @override
  State<JLGMobileApp> createState() => _JLGMobileAppState();
}

class _JLGMobileAppState extends State<JLGMobileApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    final ctx = AppConfig.navigatorKey.currentContext;
    if (ctx == null) return;

    final authProvider = Provider.of<AuthProvider>(ctx, listen: false);
    if (!authProvider.isAuthenticated) return;

    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive ||
        state == AppLifecycleState.hidden) {
      // Mettre en pause le polling périodique en arrière-plan pour économiser la batterie et le réseau
      Provider.of<DeliveryProvider>(ctx, listen: false).pausePolling();
      Provider.of<NotificationProvider>(ctx, listen: false).pausePolling();
    } else if (state == AppLifecycleState.resumed) {
      // Reprise du polling uniquement au premier plan pour les rôles habilités
      final user = authProvider.currentUser;
      if (user != null && (user.role == 'LIVREUR' || user.role == 'CHAUFFEUR')) {
        Provider.of<DeliveryProvider>(ctx, listen: false).resumePolling();
      }
      Provider.of<NotificationProvider>(ctx, listen: false).resumePolling();
    }
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => StationProvider()),
        ChangeNotifierProvider(create: (_) => DeliveryProvider()),
        ChangeNotifierProvider(create: (_) => NotificationProvider()),
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
      ],
      child: Consumer<ThemeProvider>(
        builder: (context, themeProvider, child) {
          return MaterialApp(
            navigatorKey: AppConfig.navigatorKey,
            title: 'Transport & Logistic',
            debugShowCheckedModeBanner: false,
            theme: AppTheme.lightTheme,
            darkTheme: AppTheme.darkTheme,
            themeMode: themeProvider.themeMode,
            home: const SplashView(),
          );
        },
      ),
    );
  }
}
