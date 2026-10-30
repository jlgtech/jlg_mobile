import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/providers/maintenance_provider.dart';
import '../../../core/theme/app_theme.dart';

class MaintenanceView extends StatefulWidget {
  const MaintenanceView({super.key});

  @override
  State<MaintenanceView> createState() => _MaintenanceViewState();
}

class _MaintenanceViewState extends State<MaintenanceView> {
  String? _feedbackMessage;
  bool _isSuccess = false;

  Future<void> _handleRefresh(MaintenanceProvider provider) async {
    setState(() {
      _feedbackMessage = null;
    });

    final updated = await provider.checkMaintenance(silent: false);

    if (!mounted) return;

    if (updated != null && !updated.isActive) {
      setState(() {
        _isSuccess = true;
        _feedbackMessage = "Le système est à nouveau opérationnel. Reprise en cours...";
      });
    } else {
      setState(() {
        _isSuccess = false;
        _feedbackMessage = "La maintenance est toujours en cours d'exécution.";
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<MaintenanceProvider>(
      builder: (context, maintenance, child) {
        final info = maintenance.info;
        final debut = info?.formattedDebut;
        final fin = info?.formattedFin;
        final message = info?.displayMessage ??
            "Une opération de maintenance technique et de sécurisation de nos infrastructures est en cours.";

        return Scaffold(
          backgroundColor: AppTheme.bgDark,
          body: Stack(
            children: [
              // Lueur radiale d'ambiance d'arrière-plan
              Positioned(
                top: MediaQuery.of(context).size.height * 0.25,
                left: MediaQuery.of(context).size.width * 0.1,
                right: MediaQuery.of(context).size.width * 0.1,
                child: Center(
                  child: Container(
                    width: 280,
                    height: 280,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppTheme.primaryRoyal.withValues(alpha: 0.12),
                    ),
                  ),
                ),
              ),

              // Contenu principal sécurisé
              SafeArea(
                child: Center(
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 480),
                      child: Container(
                        padding: const EdgeInsets.all(28),
                        decoration: BoxDecoration(
                          color: AppTheme.cardDark.withValues(alpha: 0.95),
                          borderRadius: BorderRadius.circular(28),
                          border: Border.all(
                            color: AppTheme.borderDark,
                            width: 1,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.4),
                              blurRadius: 30,
                              offset: const Offset(0, 10),
                            ),
                          ],
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Icône emblématique de maintenance
                            Container(
                              width: 68,
                              height: 68,
                              decoration: BoxDecoration(
                                color: const Color(0xFFF59E0B).withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: const Color(0xFFF59E0B).withValues(alpha: 0.35),
                                  width: 1.5,
                                ),
                              ),
                              child: const Icon(
                                Icons.construction_rounded,
                                color: Color(0xFFF59E0B),
                                size: 34,
                              ),
                            ),
                            const SizedBox(height: 20),

                            // En-tête marque
                            const Text(
                              "GROUPE JL GREEN",
                              style: TextStyle(
                                color: AppTheme.textDarkMuted,
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 1.5,
                              ),
                            ),
                            const SizedBox(height: 6),

                            // Titre principal
                            const Text(
                              "Système en Maintenance",
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 22,
                                fontWeight: FontWeight.w900,
                                letterSpacing: -0.3,
                              ),
                            ),
                            const SizedBox(height: 12),

                            // Message explicatif Super-Admin
                            Text(
                              message,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: AppTheme.textDarkBody,
                                fontSize: 13,
                                height: 1.5,
                              ),
                            ),
                            const SizedBox(height: 24),

                            // Boîte des horaires programmés
                            if (info != null && (info.debut != null || info.fin != null))
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: AppTheme.cardDarkSubtle,
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: AppTheme.borderDark,
                                    width: 1,
                                  ),
                                ),
                                child: Column(
                                  children: [
                                    if (debut != null)
                                      Row(
                                        children: [
                                          const Icon(Icons.schedule_rounded, size: 16, color: AppTheme.textDarkMuted),
                                          const SizedBox(width: 8),
                                          const Text(
                                            "Début de coupure",
                                            style: TextStyle(
                                              color: AppTheme.textDarkMuted,
                                              fontSize: 12,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: Text(
                                              debut,
                                              textAlign: TextAlign.end,
                                              style: const TextStyle(
                                                color: Colors.white,
                                                fontSize: 12,
                                                fontWeight: FontWeight.w700,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    if (debut != null && fin != null)
                                      const Padding(
                                        padding: EdgeInsets.symmetric(vertical: 10),
                                        child: Divider(color: AppTheme.borderDark, height: 1),
                                      ),
                                    if (fin != null)
                                      Row(
                                        children: [
                                          const Icon(Icons.check_circle_outline_rounded, size: 16, color: Color(0xFF10B981)),
                                          const SizedBox(width: 8),
                                          const Text(
                                            "Reprise estimée",
                                            style: TextStyle(
                                              color: AppTheme.textDarkMuted,
                                              fontSize: 12,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: Text(
                                              fin,
                                              textAlign: TextAlign.end,
                                              style: const TextStyle(
                                                color: Color(0xFF34D399),
                                                fontSize: 12,
                                                fontWeight: FontWeight.w700,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                  ],
                                ),
                              ),

                            // Message de statut après vérification manuelle
                            if (_feedbackMessage != null) ...[
                              const SizedBox(height: 16),
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                decoration: BoxDecoration(
                                  color: _isSuccess
                                      ? const Color(0xFF065F46).withValues(alpha: 0.3)
                                      : const Color(0xFF78350F).withValues(alpha: 0.3),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: _isSuccess
                                        ? const Color(0xFF059669)
                                        : const Color(0xFFD97706),
                                    width: 1,
                                  ),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      _isSuccess ? Icons.check_circle_rounded : Icons.info_outline_rounded,
                                      size: 16,
                                      color: _isSuccess ? const Color(0xFF34D399) : const Color(0xFFFBBF24),
                                    ),
                                    const SizedBox(width: 8),
                                    Flexible(
                                      child: Text(
                                        _feedbackMessage!,
                                        style: TextStyle(
                                          color: _isSuccess ? const Color(0xFF34D399) : const Color(0xFFFBBF24),
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                        ),
                                        textAlign: TextAlign.center,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],

                            const SizedBox(height: 24),

                            // Bouton d'actualisation de disponibilité
                            SizedBox(
                              width: double.infinity,
                              height: 48,
                              child: ElevatedButton.icon(
                                onPressed: maintenance.isChecking ? null : () => _handleRefresh(maintenance),
                                icon: maintenance.isChecking
                                    ? const SizedBox(
                                        width: 18,
                                        height: 18,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Colors.white,
                                        ),
                                      )
                                    : const Icon(Icons.refresh_rounded, size: 20),
                                label: Text(
                                  maintenance.isChecking ? "Vérification en cours..." : "Vérifier la disponibilité",
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppTheme.primaryRoyal,
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  elevation: 2,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
