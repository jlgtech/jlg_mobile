import 'dart:convert';
import '../../../core/network/api_client.dart';
import '../../../core/utils/error_sanitizer.dart';
import '../models/notification_model.dart';

class NotificationService {
  /// Récupérer les notifications de l'utilisateur courant et les alertes système
  static Future<({List<NotificationModel> notifications, int unreadCount, String? error})> fetchNotifications() async {
    try {
      final response = await ApiClient.get('/notifications');
      if (response.statusCode == 200) {
        final Map<String, dynamic> data = jsonDecode(response.body);
        final List list = data['notifications'] as List? ?? [];
        final notifs = list
            .map((item) => NotificationModel.fromJson(item as Map<String, dynamic>))
            .toList();
        final unreadCount = data['unread_count'] as int? ?? notifs.where((n) => !n.estLu).length;
        return (notifications: notifs, unreadCount: unreadCount, error: null);
      }
      return (
        notifications: <NotificationModel>[],
        unreadCount: 0,
        error: ErrorSanitizer.extractErrorMessage(response)
      );
    } catch (e) {
      return (
        notifications: <NotificationModel>[],
        unreadCount: 0,
        error: ErrorSanitizer.extractErrorMessage(e)
      );
    }
  }

  /// Marquer une notification spécifique comme lue
  static Future<bool> markAsRead(String notificationId) async {
    try {
      final response = await ApiClient.post('/notifications/$notificationId/mark-read', {});
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  /// Marquer l'ensemble des notifications comme lues
  static Future<bool> markAllAsRead() async {
    try {
      final response = await ApiClient.post('/notifications/mark-all-read', {});
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  /// Supprimer définitivement une notification
  static Future<bool> deleteNotification(String notificationId) async {
    try {
      final response = await ApiClient.delete('/notifications/$notificationId');
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }
}
