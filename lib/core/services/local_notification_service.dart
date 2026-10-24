import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class LocalNotificationService {
  static final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();

  static bool _isInitialized = false;

  /// Canaux de notifications Android professionnels
  static const AndroidNotificationChannel _deliveryChannel = AndroidNotificationChannel(
    'jlg_deliveries_channel',
    'Tournées et Livraisons',
    description: 'Notifications pour les assignations, départs et clôtures de livraison.',
    importance: Importance.high,
    playSound: true,
    enableVibration: true,
  );

  static const AndroidNotificationChannel _alertsChannel = AndroidNotificationChannel(
    'jlg_alerts_channel',
    'Alertes Système',
    description: 'Alertes urgentes et messages de la direction.',
    importance: Importance.max,
    playSound: true,
    enableVibration: true,
  );

  static const AndroidNotificationChannel _paymentsChannel = AndroidNotificationChannel(
    'jlg_payments_channel',
    'Encaissements',
    description: 'Confirmations de paiements et reçus de livraison.',
    importance: Importance.defaultImportance,
    playSound: true,
  );

  /// Initialisation du service de notifications natives
  static Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      // Configuration pour Android
      const AndroidInitializationSettings androidSettings =
          AndroidInitializationSettings('@mipmap/ic_launcher');

      // Configuration pour iOS / Darwin
      const DarwinInitializationSettings iosSettings = DarwinInitializationSettings(
        requestAlertPermission: true,
        requestBadgePermission: true,
        requestSoundPermission: true,
      );

      const InitializationSettings initSettings = InitializationSettings(
        android: androidSettings,
        iOS: iosSettings,
      );

      await _notificationsPlugin.initialize(
        settings: initSettings,
        onDidReceiveNotificationResponse: (NotificationResponse response) {
          if (kDebugMode) {
            print("Notification cliquee avec payload: ${response.payload}");
          }
        },
      );

      // Création des canaux Android
      final androidImplementation = _notificationsPlugin
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();

      if (androidImplementation != null) {
        await androidImplementation.createNotificationChannel(_deliveryChannel);
        await androidImplementation.createNotificationChannel(_alertsChannel);
        await androidImplementation.createNotificationChannel(_paymentsChannel);

        // Demande de permission Android 13+ (POST_NOTIFICATIONS)
        await androidImplementation.requestNotificationsPermission();
      }

      _isInitialized = true;
    } catch (e) {
      if (kDebugMode) {
        print("Erreur initialisation LocalNotificationService: $e");
      }
    }
  }

  /// Notification pour une nouvelle livraison ou mise à jour de tournée
  static Future<void> showDeliveryNotification({
    int id = 100,
    required String title,
    required String body,
    String? payload,
  }) async {
    await initialize();

    final AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      _deliveryChannel.id,
      _deliveryChannel.name,
      channelDescription: _deliveryChannel.description,
      importance: Importance.high,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
    );

    const DarwinNotificationDetails iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    final NotificationDetails details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    try {
      await _notificationsPlugin.show(
        id: id,
        title: title,
        body: body,
        notificationDetails: details,
        payload: payload,
      );
    } catch (e) {
      if (kDebugMode) {
        print("Erreur affichage notification livraison: $e");
      }
    }
  }

  /// Notification de confirmation d'encaissement
  static Future<void> showPaymentNotification({
    int id = 200,
    required String title,
    required String body,
    String? payload,
  }) async {
    await initialize();

    final AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      _paymentsChannel.id,
      _paymentsChannel.name,
      channelDescription: _paymentsChannel.description,
      importance: Importance.defaultImportance,
      priority: Priority.defaultPriority,
      icon: '@mipmap/ic_launcher',
    );

    const DarwinNotificationDetails iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: false,
      presentSound: true,
    );

    final NotificationDetails details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    try {
      await _notificationsPlugin.show(
        id: id,
        title: title,
        body: body,
        notificationDetails: details,
        payload: payload,
      );
    } catch (e) {
      if (kDebugMode) {
        print("Erreur affichage notification encaissement: $e");
      }
    }
  }

  /// Notification pour une alerte système urgente
  static Future<void> showAlertNotification({
    int id = 300,
    required String title,
    required String body,
    String? payload,
  }) async {
    await initialize();

    final AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      _alertsChannel.id,
      _alertsChannel.name,
      channelDescription: _alertsChannel.description,
      importance: Importance.max,
      priority: Priority.max,
      icon: '@mipmap/ic_launcher',
    );

    const DarwinNotificationDetails iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    final NotificationDetails details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    try {
      await _notificationsPlugin.show(
        id: id,
        title: title,
        body: body,
        notificationDetails: details,
        payload: payload,
      );
    } catch (e) {
      if (kDebugMode) {
        print("Erreur affichage notification alerte: $e");
      }
    }
  }
}
