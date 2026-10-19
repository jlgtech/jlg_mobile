import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/station_models.dart';
import '../../../core/theme/app_theme.dart';

class StationReceiptModal extends StatelessWidget {
  final TransactionStationModel transaction;
  final Map<String, dynamic>? companyConfig;

  const StationReceiptModal({
    super.key,
    required this.transaction,
    this.companyConfig,
  });

  static void show(
    BuildContext context, {
    required TransactionStationModel transaction,
    Map<String, dynamic>? companyConfig,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StationReceiptModal(
        transaction: transaction,
        companyConfig: companyConfig,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final companyName = companyConfig?['company_name']?.toString() ?? "JLG WATER SERVICES & SUPPLIES";
    final companyAddress = companyConfig?['company_address']?.toString() ?? "Boulevard Toussaint Louverture, Port-au-Prince, Haïti";
    final companyPhone = companyConfig?['company_phone']?.toString() ?? "+509 3700-0000 / 3800-0000";

    final formattedEntree = DateFormat('dd/MM/yyyy HH:mm').format(transaction.heureEntree.toLocal());
    final formattedDebut = transaction.heureDebutRemplissage != null
        ? DateFormat('HH:mm').format(transaction.heureDebutRemplissage!.toLocal())
        : null;
    final formattedSortie = transaction.heureSortie != null
        ? DateFormat('HH:mm').format(transaction.heureSortie!.toLocal())
        : null;

    String dureeTxt = "—";
    if (transaction.heureSortie != null) {
      final diff = transaction.heureSortie!.difference(transaction.heureEntree);
      final minutesTotal = diff.inMinutes;
      if (minutesTotal >= 60) {
        final hours = minutesTotal ~/ 60;
        final mins = minutesTotal % 60;
        dureeTxt = "${hours}h ${mins.toString().padLeft(2, '0')}m";
      } else {
        dureeTxt = "$minutesTotal min";
      }
    }

    final bool isTerminee = transaction.statut == 'TERMINEE';
    final bool isEnCours = transaction.statut == 'EN_COURS';
    final bool isAnnulee = transaction.statut == 'ANNULEE';

    Color statusColor = AppTheme.statusPending;
    String statusLabel = "EN ATTENTE";
    if (isTerminee) {
      statusColor = AppTheme.accentMint;
      statusLabel = "REMPLISSAGE TERMINÉ";
    } else if (isEnCours) {
      statusColor = const Color(0xFF0284C7);
      statusLabel = "VANNE OUVERTE (EN COURS)";
    } else if (isAnnulee) {
      statusColor = AppTheme.statusCancelled;
      statusLabel = "ANNULÉ";
    }

    final bool isDark = AppTheme.isDark(context);

    return SafeArea(
      top: false,
      child: Container(
        decoration: BoxDecoration(
          color: AppTheme.surfaceColor(context),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          border: Border(top: BorderSide(color: AppTheme.borderColor(context), width: 1)),
        ),
        padding: EdgeInsets.only(
          top: 12,
          left: 20,
          right: 20,
          bottom: MediaQuery.of(context).viewInsets.bottom + MediaQuery.of(context).padding.bottom + 24,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Barre de préhension
              Center(
                child: Container(
                  width: 44,
                  height: 5,
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF475569) : Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // En-tête Reçu / Ticket
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: isDark
                              ? AppTheme.accentSky.withValues(alpha: 0.15)
                              : AppTheme.primaryRoyal.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          Icons.receipt_long,
                          color: isDark ? AppTheme.accentSky : AppTheme.primaryRoyal,
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        "Ticket de Station",
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                          color: AppTheme.titleColor(context),
                        ),
                      ),
                    ],
                  ),
                  IconButton(
                    icon: Icon(Icons.close, color: AppTheme.mutedColor(context)),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Conteneur imitation Ticket Thermique
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF0F172A) : const Color(0xFFFAFAFA),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppTheme.borderColor(context)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.04),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    // Logo / Nom Entreprise
                    Text(
                      companyName,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 15,
                        letterSpacing: 0.8,
                        color: AppTheme.titleColor(context),
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      "Station de Remplissage Camions-Citernes",
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.mutedColor(context)),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      companyAddress,
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 10, color: AppTheme.mutedColor(context)),
                    ),
                    Text(
                      "Tél : $companyPhone",
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 10, color: AppTheme.mutedColor(context)),
                    ),
                    const SizedBox(height: 12),

                    // Ligne pointillée
                    CustomPaint(
                      size: const Size(double.infinity, 1),
                      painter: _DottedLinePainter(color: isDark ? const Color(0xFF334155) : Colors.grey.shade400),
                    ),
                    const SizedBox(height: 14),

                    // Numéro Ticket & Statut
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "NUMÉRO TICKET",
                              style: TextStyle(fontSize: 10, color: AppTheme.mutedColor(context), fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              transaction.codeTicket,
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w900,
                                color: isDark ? AppTheme.accentSky : AppTheme.primaryRoyal,
                                letterSpacing: 1.1,
                              ),
                            ),
                          ],
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: statusColor.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: statusColor.withValues(alpha: 0.3)),
                          ),
                          child: Text(
                            statusLabel,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w900,
                              color: statusColor,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),

                    // Informations Camion
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF1E293B) : Colors.white,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: isDark ? const Color(0xFF334155) : Colors.grey.shade200),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                "Plaque d'Immatriculation",
                                style: TextStyle(fontSize: 11, color: AppTheme.mutedColor(context), fontWeight: FontWeight.bold),
                              ),
                              Text(
                                transaction.camion?.plaqueImmatriculation ?? "Inconnue",
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 0.8,
                                  color: AppTheme.titleColor(context),
                                ),
                              ),
                            ],
                          ),
                          if (transaction.camion?.nomProprietaire != null) ...[
                            const SizedBox(height: 6),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  "Chauffeur / Propriétaire",
                                  style: TextStyle(fontSize: 11, color: AppTheme.mutedColor(context)),
                                ),
                                Text(
                                  transaction.camion!.nomProprietaire!,
                                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.titleColor(context)),
                                ),
                              ],
                            ),
                          ],
                          if (transaction.camion?.telephone != null && transaction.camion!.telephone!.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  "Téléphone",
                                  style: TextStyle(fontSize: 11, color: AppTheme.mutedColor(context)),
                                ),
                                Text(
                                  transaction.camion!.telephone!,
                                  style: TextStyle(fontSize: 12, color: AppTheme.bodyColor(context)),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Horodatages
                    _buildReceiptRow(context, "Date & Heure d'Entrée", formattedEntree),
                    if (formattedDebut != null)
                      _buildReceiptRow(context, "Début Remplissage", formattedDebut),
                    if (formattedSortie != null)
                      _buildReceiptRow(context, "Fin & Sortie de Piste", formattedSortie),
                    if (transaction.heureSortie != null)
                      _buildReceiptRow(context, "Durée Totale de Passage", dureeTxt, isBold: true),
                    _buildReceiptRow(context, "Mode de Paiement", transaction.modePaiement),

                    const SizedBox(height: 10),
                    CustomPaint(
                      size: const Size(double.infinity, 1),
                      painter: _DottedLinePainter(color: isDark ? const Color(0xFF334155) : Colors.grey.shade400),
                    ),
                    const SizedBox(height: 12),

                    // Montant Total
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          "MONTANT PAYÉ",
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: AppTheme.titleColor(context)),
                        ),
                        Text(
                          "${transaction.montantHtg.toStringAsFixed(2)} HTG",
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                            color: isDark ? AppTheme.accentSky : AppTheme.primaryRoyal,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Mention légale de caisse
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF1E293B).withValues(alpha: 0.6) : Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: isDark ? const Color(0xFF334155) : Colors.transparent),
                      ),
                      child: Text(
                        "Ticket officiel de passage et remplissage de citerne. À présenter impérativement aux opérateurs de piste pour ouverture de vanne.",
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 10, color: AppTheme.mutedColor(context), fontStyle: FontStyle.italic),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Actions d'impression / partage
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        side: BorderSide(color: isDark ? AppTheme.borderColor(context) : AppTheme.primaryRoyal),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: () => Navigator.of(context).pop(),
                      icon: Icon(Icons.close, color: isDark ? AppTheme.mutedColor(context) : AppTheme.primaryRoyal),
                      label: Text(
                        "Fermer",
                        style: TextStyle(
                          color: isDark ? AppTheme.mutedColor(context) : AppTheme.primaryRoyal,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isDark ? AppTheme.accentSky : AppTheme.primaryRoyal,
                        foregroundColor: isDark ? const Color(0xFF0B0F19) : Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        elevation: 2,
                      ),
                      onPressed: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text("Ticket #${transaction.codeTicket} prêt pour impression thermique."),
                            backgroundColor: isDark ? const Color(0xFF1E293B) : AppTheme.primaryRoyal,
                            duration: const Duration(seconds: 2),
                          ),
                        );
                      },
                      icon: const Icon(Icons.print_outlined),
                      label: const Text(
                        "Imprimer Ticket",
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildReceiptRow(BuildContext context, String label, String value, {bool isBold = false}) {
    final isDark = AppTheme.isDark(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(fontSize: 11.5, color: AppTheme.mutedColor(context)),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: isBold ? FontWeight.w900 : FontWeight.w600,
              color: isBold
                  ? (isDark ? AppTheme.accentSky : AppTheme.primaryRoyal)
                  : AppTheme.titleColor(context),
            ),
          ),
        ],
      ),
    );
  }
}

class _DottedLinePainter extends CustomPainter {
  final Color color;
  _DottedLinePainter({this.color = const Color(0xFF94A3B8)});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;

    const dashWidth = 4.0;
    const dashSpace = 4.0;
    double startX = 0.0;

    while (startX < size.width) {
      canvas.drawLine(Offset(startX, 0), Offset(startX + dashWidth, 0), paint);
      startX += dashWidth + dashSpace;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
