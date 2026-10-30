import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../config/app_config.dart';
import '../models/maintenance_info.dart';

class MaintenanceService {
  static const Duration _timeout = Duration(seconds: 6);

  /// Récupère l'état courant de maintenance auprès de l'API publique
  static Future<MaintenanceInfo?> getMaintenanceStatus() async {
    try {
      final url = Uri.parse('${AppConfig.activeBaseUrl}/system/maintenance');
      final response = await http.get(
        url,
        headers: {
          'Accept': 'application/json',
        },
      ).timeout(_timeout);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data is Map<String, dynamic>) {
          return MaintenanceInfo.fromJson(data);
        }
      } else if (response.statusCode == 503) {
        // En cas de 503 reçu directement sur l'endpoint de vérification
        try {
          final data = jsonDecode(response.body);
          if (data is Map<String, dynamic>) {
            return MaintenanceInfo.fromJson(data);
          }
        } catch (_) {}
      }
    } catch (e) {
      if (kDebugMode) {
        print("Erreur lors de la recuperation du statut de maintenance: $e");
      }
    }
    return null;
  }
}
