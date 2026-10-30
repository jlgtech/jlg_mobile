import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/providers/maintenance_provider.dart';

class MaintenanceWarningBanner extends StatelessWidget {
  const MaintenanceWarningBanner({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<MaintenanceProvider>(
      builder: (context, maintenance, child) {
        if (!maintenance.isWarning) {
          return const SizedBox.shrink();
        }

        final info = maintenance.info;
        final minutes = info?.minutesRemaining ?? info?.delaiAlerteMinutes ?? 30;
        final startTimeStr = info?.formattedDebutTimeOnly ?? '--:--';

        return Material(
          color: Colors.transparent,
          child: Container(
            width: double.infinity,
            margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFFF59E0B), // Ambre vif
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.18),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
              border: Border.all(
                color: const Color(0xFFD97706),
                width: 1,
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(7),
                  decoration: BoxDecoration(
                    color: const Color(0xFF78350F).withValues(alpha: 0.18),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.warning_amber_rounded,
                    color: Color(0xFF451A03),
                    size: 20,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          const Text(
                            "Alerte Maintenance",
                            style: TextStyle(
                              color: Color(0xFF451A03),
                              fontWeight: FontWeight.w800,
                              fontSize: 13,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFF78350F).withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              "dans $minutes min ($startTimeStr)",
                              style: const TextStyle(
                                color: Color(0xFF451A03),
                                fontWeight: FontWeight.w700,
                                fontSize: 11,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      const Text(
                        "Une coupure technique est imminente. Pensez à finaliser vos opérations en cours.",
                        style: TextStyle(
                          color: Color(0xFF78350F),
                          fontSize: 11,
                          height: 1.25,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(
                    Icons.close_rounded,
                    color: Color(0xFF451A03),
                    size: 18,
                  ),
                  tooltip: "Masquer temporairement",
                  onPressed: () {
                    maintenance.dismissWarningBanner();
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
