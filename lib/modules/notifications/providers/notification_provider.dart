import 'dart:async';
import 'package:flutter/material.dart';
import '../models/notification_model.dart';
import '../services/notification_service.dart';

enum NotificationFilter {
  all,
  unread,
}

class NotificationProvider with ChangeNotifier {
  List<NotificationModel> _notifications = [];
  int _unreadCount = 0;
  bool _isLoading = false;
  String? _errorMessage;
  NotificationFilter _filter = NotificationFilter.all;

  Timer? _pollingTimer;

  List<NotificationModel> get notifications => _notifications;
  int get unreadCount => _unreadCount;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  NotificationFilter get filter => _filter;

  List<NotificationModel> get filteredNotifications {
    if (_filter == NotificationFilter.unread) {
      return _notifications.where((n) => !n.estLu).toList();
    }
    return _notifications;
  }

  void setFilter(NotificationFilter filter) {
    if (_filter != filter) {
      _filter = filter;
      notifyListeners();
    }
  }

  /// Chargement des notifications depuis l'API
  Future<void> fetchNotifications({bool silent = false}) async {
    if (!silent) {
      _isLoading = true;
      _errorMessage = null;
      notifyListeners();
    }

    final result = await NotificationService.fetchNotifications();

    if (result.error != null && _notifications.isEmpty) {
      _errorMessage = result.error;
    } else {
      _notifications = result.notifications;
      _unreadCount = result.unreadCount;
      _errorMessage = null;
    }

    _isLoading = false;
    notifyListeners();
  }

  /// Marquer une notification comme lue
  Future<void> markAsRead(String notificationId) async {
    // Mise à jour optimiste immédiate dans l'état local
    final index = _notifications.indexWhere((n) => n.id == notificationId);
    if (index != -1 && !_notifications[index].estLu) {
      _notifications[index] = _notifications[index].copyWith(estLu: true);
      _unreadCount = (_unreadCount > 0) ? _unreadCount - 1 : 0;
      notifyListeners();

      final success = await NotificationService.markAsRead(notificationId);
      if (!success) {
        // En cas d'échec distant, rafraîchir silencieusement
        await fetchNotifications(silent: true);
      }
    }
  }

  /// Marquer l'ensemble des notifications comme lues
  Future<void> markAllAsRead() async {
    if (_unreadCount == 0 && _notifications.every((n) => n.estLu)) return;

    // Optimiste
    _notifications = _notifications.map((n) => n.copyWith(estLu: true)).toList();
    _unreadCount = 0;
    notifyListeners();

    final success = await NotificationService.markAllAsRead();
    if (!success) {
      await fetchNotifications(silent: true);
    }
  }

  /// Supprimer une notification
  Future<bool> deleteNotification(String notificationId) async {
    final existing = _notifications.firstWhere(
      (n) => n.id == notificationId,
      orElse: () => NotificationModel(
        id: '',
        titre: '',
        message: '',
        typeNotification: '',
        severite: '',
        estLu: true,
      ),
    );

    final wasUnread = !existing.estLu;

    // Optimiste
    _notifications.removeWhere((n) => n.id == notificationId);
    if (wasUnread && _unreadCount > 0) {
      _unreadCount -= 1;
    }
    notifyListeners();

    final success = await NotificationService.deleteNotification(notificationId);
    if (!success) {
      await fetchNotifications(silent: true);
      return false;
    }
    return true;
  }

  /// Démarrer le polling périodique pour garder les notifications et le badge à jour
  void startPolling({Duration interval = const Duration(seconds: 45)}) {
    _pollingTimer?.cancel();
    _pollingTimer = Timer.periodic(interval, (_) {
      fetchNotifications(silent: true);
    });
    // Premier appel immédiat
    fetchNotifications(silent: true);
  }

  /// Arrêter le polling
  void stopPolling() {
    _pollingTimer?.cancel();
    _pollingTimer = null;
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    super.dispose();
  }
}
