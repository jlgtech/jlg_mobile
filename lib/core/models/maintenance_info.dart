import 'package:intl/intl.dart';

class MaintenanceInfo {
  final bool isActive;
  final bool isScheduled;
  final bool isWarning;
  final DateTime? debut;
  final DateTime? fin;
  final String? message;
  final int delaiAlerteMinutes;
  final int? minutesRemaining;
  final DateTime serverTime;

  MaintenanceInfo({
    required this.isActive,
    required this.isScheduled,
    required this.isWarning,
    this.debut,
    this.fin,
    this.message,
    this.delaiAlerteMinutes = 30,
    this.minutesRemaining,
    required this.serverTime,
  });

  factory MaintenanceInfo.fromJson(Map<String, dynamic> json) {
    DateTime? parseDate(dynamic val) {
      if (val == null) return null;
      return DateTime.tryParse(val.toString())?.toLocal();
    }

    DateTime serverDt = parseDate(json['server_time']) ?? DateTime.now();

    return MaintenanceInfo(
      isActive: json['is_active'] == true || json['active'] == true,
      isScheduled: json['is_scheduled'] == true,
      isWarning: json['is_warning'] == true,
      debut: parseDate(json['debut']),
      fin: parseDate(json['fin']),
      message: json['message']?.toString(),
      delaiAlerteMinutes: (json['delai_alerte_minutes'] as num?)?.toInt() ?? 30,
      minutesRemaining: (json['minutes_remaining'] as num?)?.toInt(),
      serverTime: serverDt,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'is_active': isActive,
      'is_scheduled': isScheduled,
      'is_warning': isWarning,
      'debut': debut?.toIso8601String(),
      'fin': fin?.toIso8601String(),
      'message': message,
      'delai_alerte_minutes': delaiAlerteMinutes,
      'minutes_remaining': minutesRemaining,
      'server_time': serverTime.toIso8601String(),
    };
  }

  String get formattedDebut {
    if (debut == null) return 'Non spécifié';
    try {
      return DateFormat("dd MMM yyyy à HH:mm", "fr_FR").format(debut!);
    } catch (_) {
      return debut!.toString();
    }
  }

  String get formattedFin {
    if (fin == null) return 'Indéterminée';
    try {
      return DateFormat("dd MMM yyyy à HH:mm", "fr_FR").format(fin!);
    } catch (_) {
      return fin!.toString();
    }
  }

  String get formattedDebutTimeOnly {
    if (debut == null) return '--:--';
    try {
      return DateFormat("HH:mm", "fr_FR").format(debut!);
    } catch (_) {
      return debut!.toString();
    }
  }

  String get displayMessage {
    if (message != null && message!.trim().isNotEmpty) {
      return message!.trim();
    }
    return 'Une opération de maintenance technique et de sécurisation de nos infrastructures est en cours.';
  }

  MaintenanceInfo copyWith({
    bool? isActive,
    bool? isScheduled,
    bool? isWarning,
    DateTime? debut,
    DateTime? fin,
    String? message,
    int? delaiAlerteMinutes,
    int? minutesRemaining,
    DateTime? serverTime,
  }) {
    return MaintenanceInfo(
      isActive: isActive ?? this.isActive,
      isScheduled: isScheduled ?? this.isScheduled,
      isWarning: isWarning ?? this.isWarning,
      debut: debut ?? this.debut,
      fin: fin ?? this.fin,
      message: message ?? this.message,
      delaiAlerteMinutes: delaiAlerteMinutes ?? this.delaiAlerteMinutes,
      minutesRemaining: minutesRemaining ?? this.minutesRemaining,
      serverTime: serverTime ?? this.serverTime,
    );
  }
}
