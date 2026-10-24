import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_theme.dart';

class NotificationModel {
  final String id;
  final String? utilisateurId;
  final String titre;
  final String message;
  final String typeNotification;
  final String severite;
  final bool estLu;
  final String? lien;
  final DateTime? creeLe;

  const NotificationModel({
    required this.id,
    this.utilisateurId,
    required this.titre,
    required this.message,
    required this.typeNotification,
    required this.severite,
    required this.estLu,
    this.lien,
    this.creeLe,
  });

  factory NotificationModel.fromJson(Map<String, dynamic> json) {
    DateTime? parsedDate;
    if (json['cree_le'] != null) {
      parsedDate = DateTime.tryParse(json['cree_le'].toString())?.toLocal();
    }

    return NotificationModel(
      id: json['id']?.toString() ?? '',
      utilisateurId: json['utilisateur_id']?.toString(),
      titre: json['titre']?.toString() ?? 'Notification',
      message: json['message']?.toString() ?? '',
      typeNotification: (json['type_notification']?.toString() ?? 'INFO').toUpperCase(),
      severite: (json['severite']?.toString() ?? 'INFO').toUpperCase(),
      estLu: json['est_lu'] == true,
      lien: json['lien']?.toString(),
      creeLe: parsedDate,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'utilisateur_id': utilisateurId,
      'titre': titre,
      'message': message,
      'type_notification': typeNotification,
      'severite': severite,
      'est_lu': estLu,
      'lien': lien,
      'cree_le': creeLe?.toIso8601String(),
    };
  }

  NotificationModel copyWith({
    String? id,
    String? utilisateurId,
    String? titre,
    String? message,
    String? typeNotification,
    String? severite,
    bool? estLu,
    String? lien,
    DateTime? creeLe,
  }) {
    return NotificationModel(
      id: id ?? this.id,
      utilisateurId: utilisateurId ?? this.utilisateurId,
      titre: titre ?? this.titre,
      message: message ?? this.message,
      typeNotification: typeNotification ?? this.typeNotification,
      severite: severite ?? this.severite,
      estLu: estLu ?? this.estLu,
      lien: lien ?? this.lien,
      creeLe: creeLe ?? this.creeLe,
    );
  }

  /// Icône adaptée au type et contexte métier de la notification
  IconData get iconData {
    switch (typeNotification) {
      case 'LIVRAISON_ASSIGNEE':
      case 'LIVRAISON':
      case 'COMMANDE_DISPATCH':
        return Icons.local_shipping_outlined;
      case 'LIVRAISON_RETIREE':
        return Icons.remove_circle_outline;
      case 'COMMANDE_ANNULEE':
        return Icons.cancel_outlined;
      case 'PAIEMENT_VALIDE':
        return Icons.payments_outlined;
      case 'LITIGE_LIVRAISON':
        return Icons.report_problem_outlined;
      case 'LIVRAISON_EFFECTUEE':
        return Icons.check_circle_outline;
      case 'VEHICULE_ASSIGNE':
        return Icons.directions_car_outlined;
      case 'STOCK_RECHARGE':
      case 'STOCK':
      case 'ALERTE_STOCK':
        return Icons.inventory_2_outlined;
      case 'CREDIT_A_VALIDER':
        return Icons.credit_score_outlined;
      case 'CAMION_ARRIVE':
      case 'STATION':
        return Icons.storefront_outlined;
      case 'SECURITE':
        return Icons.shield_outlined;
      default:
        switch (severite) {
          case 'CRITICAL':
          case 'URGENT':
            return Icons.warning_amber_rounded;
          case 'WARNING':
            return Icons.info_outline;
          default:
            return Icons.notifications_active_outlined;
        }
    }
  }

  /// Couleur thématique du badge de sévérité
  Color getSeverityColor(bool isDark) {
    switch (severite) {
      case 'CRITICAL':
      case 'URGENT':
        return AppTheme.statusCancelled;
      case 'WARNING':
        return isDark ? const Color(0xFFFBBF24) : AppTheme.statusPending;
      case 'SUCCESS':
        return isDark ? AppTheme.accentMint : AppTheme.statusActive;
      default:
        return isDark ? AppTheme.accentMint : AppTheme.primaryEmerald;
    }
  }

  /// Libellé français du niveau de sévérité
  String get severityLabel {
    switch (severite) {
      case 'CRITICAL':
        return 'CRITIQUE';
      case 'URGENT':
        return 'URGENT';
      case 'WARNING':
        return 'ATTENTION';
      case 'SUCCESS':
        return 'SUCCÈS';
      default:
        return 'INFO';
    }
  }

  /// Horodatage relatif clair en français
  String get formattedTime {
    if (creeLe == null) return '';
    final now = DateTime.now();
    final difference = now.difference(creeLe!);

    if (difference.inSeconds < 60) {
      return "À l'instant";
    } else if (difference.inMinutes < 60) {
      return "Il y a ${difference.inMinutes} min";
    } else if (difference.inHours < 24) {
      return "Il y a ${difference.inHours} h";
    } else if (difference.inDays == 1) {
      final hourMinute = DateFormat('HH:mm').format(creeLe!);
      return "Hier à $hourMinute";
    } else if (difference.inDays < 7) {
      return "Il y a ${difference.inDays} jours";
    } else {
      return DateFormat('dd/MM/yyyy HH:mm').format(creeLe!);
    }
  }
}
