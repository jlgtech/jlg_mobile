import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/maintenance_info.dart';
import '../services/maintenance_service.dart';
import '../services/local_notification_service.dart';

class MaintenanceProvider with ChangeNotifier {
  MaintenanceInfo? _info;
  bool _isChecking = false;
  bool _bannerDismissed = false;
  String? _lastNotifiedScheduleKey;
  bool _hasNotifiedUrgentWarning = false;
  bool _hasNotifiedActive = false;
  bool _wasActivePreviously = false;

  Timer? _pollingTimer;

  MaintenanceInfo? get info => _info;
  bool get isChecking => _isChecking;
  bool get bannerDismissed => _bannerDismissed;

  bool get isActive => _info?.isActive ?? false;
  bool get isScheduled => _info?.isScheduled ?? false;
  bool get isWarning => (_info?.isWarning ?? false) && !_bannerDismissed && !isActive;
  int? get minutesRemaining => _info?.minutesRemaining;
  String? get message => _info?.message;

  void initialize() {
    checkMaintenance(silent: true);
    startPolling();
  }

  /// Masquer la bannière d'alerte préventive temporairement pour la session en cours
  void dismissWarningBanner() {
    _bannerDismissed = true;
    notifyListeners();
  }

  /// Traitement immédiat d'une réponse HTTP 503 renvoyée par le serveur
  void handle503(Map<String, dynamic>? data) {
    final bool alreadyActive = _info?.isActive ?? false;

    DateTime? parseDate(dynamic val) {
      if (val == null) return null;
      return DateTime.tryParse(val.toString())?.toLocal();
    }

    _info = MaintenanceInfo(
      isActive: true,
      isScheduled: _info?.isScheduled ?? false,
      isWarning: false,
      debut: parseDate(data?['debut']) ?? _info?.debut,
      fin: parseDate(data?['fin']) ?? _info?.fin,
      message: data?['message']?.toString() ?? data?['detail']?.toString() ?? _info?.message,
      delaiAlerteMinutes: _info?.delaiAlerteMinutes ?? 30,
      minutesRemaining: 0,
      serverTime: DateTime.now(),
    );

    if (!alreadyActive) {
      _triggerActiveNotification();
    }

    _wasActivePreviously = true;
    notifyListeners();
  }

  /// Vérifie l'état de maintenance auprès de l'API
  Future<MaintenanceInfo?> checkMaintenance({bool silent = false}) async {
    if (!silent) {
      _isChecking = true;
      notifyListeners();
    }

    try {
      final updatedInfo = await MaintenanceService.getMaintenanceStatus();

      if (updatedInfo != null) {
        final bool hadActiveBefore = _wasActivePreviously || (_info?.isActive ?? false);
        final bool isNowActive = updatedInfo.isActive;

        // Détection de rétablissement du service
        if (hadActiveBefore && !isNowActive) {
          _triggerRecoveryNotification();
          _hasNotifiedActive = false;
          _wasActivePreviously = false;
          _bannerDismissed = false;
        }

        _info = updatedInfo;

        if (isNowActive) {
          _wasActivePreviously = true;
          _triggerActiveNotification();
        } else if (updatedInfo.isWarning) {
          _triggerWarningNotification(updatedInfo);
        } else {
          // Hors fenêtre d'alerte
          _hasNotifiedUrgentWarning = false;
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print("Erreur checkMaintenance: $e");
      }
    } finally {
      if (!silent) {
        _isChecking = false;
        notifyListeners();
      } else {
        notifyListeners();
      }
    }

    return _info;
  }

  /// Notification locale native en cas d'approche de coupure
  void _triggerWarningNotification(MaintenanceInfo currentInfo) {
    final scheduleKey = "${currentInfo.debut?.toIso8601String()}_${currentInfo.fin?.toIso8601String()}";
    final remaining = currentInfo.minutesRemaining ?? currentInfo.delaiAlerteMinutes;

    // Premier avertissement à l'entrée dans le créneau d'alerte
    if (_lastNotifiedScheduleKey != scheduleKey) {
      _lastNotifiedScheduleKey = scheduleKey;
      _hasNotifiedUrgentWarning = false;

      LocalNotificationService.showAlertNotification(
        id: 301,
        title: "Alerte Maintenance Système",
        body: "Une interruption technique débutera dans $remaining min. Veuillez finaliser vos opérations.",
        payload: "maintenance_warning",
      );
    }

    // Deuxième avertissement urgent à 5 minutes de la coupure
    if (remaining <= 5 && !_hasNotifiedUrgentWarning) {
      _hasNotifiedUrgentWarning = true;

      LocalNotificationService.showAlertNotification(
        id: 302,
        title: "Interruption Imminente (5 min)",
        body: "Le système va entrer en maintenance sous peu. Enregistrez immédiatement vos opérations.",
        payload: "maintenance_imminent",
      );
    }
  }

  /// Notification locale native lorsque la maintenance devient active
  void _triggerActiveNotification() {
    if (_hasNotifiedActive) return;
    _hasNotifiedActive = true;

    LocalNotificationService.showAlertNotification(
      id: 300,
      title: "Système en Maintenance",
      body: _info?.message ?? "Une opération de maintenance technique est en cours. Accès temporairement suspendu.",
      payload: "maintenance_active",
    );
  }

  /// Notification locale native lors du retour à la normale
  void _triggerRecoveryNotification() {
    LocalNotificationService.showAlertNotification(
      id: 303,
      title: "Système Rétabli",
      body: "La maintenance technique est terminée. L'ensemble des services est à nouveau opérationnel.",
      payload: "maintenance_recovered",
    );
  }

  /// Démarre le polling automatique (toutes les 45 secondes au premier plan)
  void startPolling({Duration interval = const Duration(seconds: 45)}) {
    _pollingTimer?.cancel();
    _pollingTimer = Timer.periodic(interval, (_) {
      checkMaintenance(silent: true);
    });
  }

  /// Met en pause le polling lorsque l'application passe en arrière-plan
  void pausePolling() {
    _pollingTimer?.cancel();
    _pollingTimer = null;
  }

  /// Reprend le polling lorsque l'application revient au premier plan
  void resumePolling({Duration interval = const Duration(seconds: 45)}) {
    startPolling(interval: interval);
    checkMaintenance(silent: true);
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    super.dispose();
  }
}
