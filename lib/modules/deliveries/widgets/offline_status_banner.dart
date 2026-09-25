import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/delivery_provider.dart';

/// Bannière affichée en haut de la vue des livraisons.
/// Indique le mode offline, la présence d'actions en attente de sync, et la progression.
class OfflineStatusBanner extends StatelessWidget {
  const OfflineStatusBanner({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<DeliveryProvider>(
      builder: (context, provider, _) {
        final isOffline = provider.isOffline;
        final hasPending = provider.hasPendingSync;
        final isSyncing = provider.isSyncing;
        final lastSync = provider.lastSync;

        // Rien à afficher si en ligne et synchronisé
        if (!isOffline && !hasPending && !isSyncing) return const SizedBox.shrink();

        Color bgColor;
        IconData icon;
        String message;
        Widget? trailing;

        if (isSyncing) {
          bgColor = Colors.blue.shade700;
          icon = Icons.sync;
          message = "Synchronisation en cours...";
          trailing = const SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
          );
        } else if (isOffline && hasPending) {
          bgColor = Colors.orange.shade800;
          icon = Icons.cloud_off;
          message = "Hors ligne — ${_pendingLabel()} en attente";
          trailing = null;
        } else if (isOffline) {
          bgColor = Colors.grey.shade700;
          icon = Icons.wifi_off;
          message = "Mode hors ligne${lastSync != null ? " · Sync: ${_formatTime(lastSync)}" : ""}";
          trailing = null;
        } else if (hasPending) {
          bgColor = Colors.teal.shade700;
          icon = Icons.cloud_upload;
          message = "Connexion rétablie — Synchronisation automatique...";
          trailing = const SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
          );
        } else {
          return const SizedBox.shrink();
        }

        return AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          width: double.infinity,
          color: bgColor,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            children: [
              Icon(icon, color: Colors.white, size: 18),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  message,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              ?trailing,
            ],
          ),
        );
      },
    );
  }

  String _pendingLabel() {
    return "actions";
  }

  String _formatTime(DateTime dt) {
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    return "$h:$m";
  }
}
