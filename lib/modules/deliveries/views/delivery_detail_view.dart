import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/delivery_model.dart';
import '../providers/delivery_provider.dart';
import '../widgets/dispute_dialog.dart';
import '../widgets/address_map_modal.dart';
import '../services/delivery_service.dart';
import '../../auth/providers/auth_provider.dart';
import '../../../core/config/app_config.dart';
import '../../../core/theme/app_theme.dart';

class DeliveryDetailView extends StatefulWidget {
  final DeliveryOrder order;

  const DeliveryDetailView({super.key, required this.order});

  @override
  State<DeliveryDetailView> createState() => _DeliveryDetailViewState();
}

class _DeliveryDetailViewState extends State<DeliveryDetailView> {
  bool _isProcessing = false;
  final Map<String, int> _consignesRecuperees = {};
  final TextEditingController _consignesNotesController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _initConsignes();
  }

  void _initConsignes() {
    for (final it in widget.order.items) {
      if (it.exigeRetourEmballage) {
        _consignesRecuperees[it.articleId] = it.quantiteCommandee;
      }
    }
  }

  @override
  void dispose() {
    _consignesNotesController.dispose();
    super.dispose();
  }

  void _handleStart() async {
    setState(() => _isProcessing = true);
    final provider = Provider.of<DeliveryProvider>(context, listen: false);
    final success = await provider.startDelivery(widget.order.id);
    setState(() => _isProcessing = false);

    if (!mounted) return;
    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Livraison démarrée. En route vers le client.'),
          backgroundColor: AppTheme.primaryRoyal,
        ),
      );
    } else if (provider.errorMessage != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(provider.errorMessage!),
          backgroundColor: Colors.red.shade700,
        ),
      );
    }
  }

  void _handleComplete() async {
    setState(() => _isProcessing = true);
    final provider = Provider.of<DeliveryProvider>(context, listen: false);

    // Si la commande comporte des articles consignés, enregistrer les contenants récupérés
    final hasConsignes = widget.order.items.any((it) => it.exigeRetourEmballage);
    if (hasConsignes) {
      final consigneItems = widget.order.items
          .where((it) => it.exigeRetourEmballage)
          .map((it) => {
                'article_id': it.articleId,
                'nom_emballage': it.nomEmballageRecupere ?? 'Bonbonne vide 5G',
                'quantite_livree': it.quantiteCommandee,
                'quantite_recuperee': _consignesRecuperees[it.articleId] ?? it.quantiteCommandee,
                'observations': _consignesNotesController.text.trim().isNotEmpty
                    ? _consignesNotesController.text.trim()
                    : null,
              })
          .toList();

      if (consigneItems.isNotEmpty) {
        try {
          await DeliveryService.declareConsignes(
            orderId: widget.order.id,
            items: consigneItems,
          );
        } catch (_) {}
      }
    }

    final success = await provider.completeDelivery(
      widget.order.id,
      lat: widget.order.latitude ?? AppConfig.fallbackLatitude,
      lng: widget.order.longitude ?? AppConfig.fallbackLongitude,
    );

    setState(() => _isProcessing = false);

    if (!mounted) return;
    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Livraison validée avec succès. Remise client confirmée.'),
          backgroundColor: AppTheme.primaryRoyal,
        ),
      );
      Navigator.pop(context);
    } else if (provider.errorMessage != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(provider.errorMessage!),
          backgroundColor: Colors.red.shade700,
        ),
      );
    }
  }

  void _openPaymentModal() {
    String selectedMode = widget.order.modePaiement;
    final notesController = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) {
          final isDarkModal = AppTheme.isDark(ctx);
          return SafeArea(
            top: false,
            child: Container(
              decoration: BoxDecoration(
                color: AppTheme.surfaceColor(ctx),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                border: Border(
                  top: BorderSide(color: AppTheme.borderColor(ctx), width: 1),
                ),
              ),
              padding: EdgeInsets.only(
                top: 16,
                left: 20,
                right: 20,
                bottom: MediaQuery.of(ctx).viewInsets.bottom + MediaQuery.of(ctx).padding.bottom + 24,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Center(
                      child: Container(
                        width: 44,
                        height: 5,
                        decoration: BoxDecoration(
                          color: isDarkModal ? const Color(0xFF475569) : Colors.grey.shade300,
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: isDarkModal
                                ? AppTheme.accentMint.withValues(alpha: 0.15)
                                : const Color(0xFFEBF3FC),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(
                            Icons.point_of_sale,
                            color: isDarkModal ? AppTheme.accentMint : AppTheme.primaryRoyal,
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "Étape 2 : Encaissement de la Commande",
                                style: TextStyle(
                                  fontWeight: FontWeight.w900,
                                  fontSize: 16,
                                  color: AppTheme.titleColor(ctx),
                                ),
                              ),
                              Text(
                                "Règlement physique à la livraison",
                                style: TextStyle(fontSize: 11, color: AppTheme.mutedColor(ctx)),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: isDarkModal ? AppTheme.cardDarkSubtle : Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isDarkModal ? AppTheme.borderDark : Colors.grey.shade200,
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            "Montant à Encaisser :",
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                              color: AppTheme.titleColor(ctx),
                            ),
                          ),
                          Text(
                            "${widget.order.montantTotal.toStringAsFixed(2)} HTG",
                            style: TextStyle(
                              fontWeight: FontWeight.w900,
                              fontSize: 17,
                              color: isDarkModal ? AppTheme.accentMint : AppTheme.primaryRoyal,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    DropdownButtonFormField<String>(
                      initialValue: ["ESPECES", "MONCASH", "NATCASH", "VIREMENT", "CHEQUE"].contains(selectedMode)
                          ? selectedMode
                          : "ESPECES",
                      decoration: InputDecoration(
                        labelText: "Mode d'Encaissement",
                        prefixIcon: const Icon(Icons.payment),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      items: const [
                        DropdownMenuItem(value: "ESPECES", child: Text("ESPÈCES (Cash)")),
                        DropdownMenuItem(value: "MONCASH", child: Text("MONCASH")),
                        DropdownMenuItem(value: "NATCASH", child: Text("NATCASH")),
                        DropdownMenuItem(value: "VIREMENT", child: Text("VIREMENT BANCAIRE")),
                        DropdownMenuItem(value: "CHEQUE", child: Text("CHÈQUE")),
                      ],
                      onChanged: (val) {
                        if (val != null) setModalState(() => selectedMode = val);
                      },
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: notesController,
                      decoration: InputDecoration(
                        labelText: "Notes ou Référence (Optionnel)",
                        hintText: "Ex: Réf MonCash #88219...",
                        prefixIcon: const Icon(Icons.note_alt_outlined),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                    const SizedBox(height: 20),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isDarkModal ? AppTheme.accentMint : AppTheme.primaryRoyal,
                        foregroundColor: isDarkModal ? const Color(0xFF03162C) : Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: () async {
                        Navigator.of(ctx).pop();
                        setState(() => _isProcessing = true);
                        final provider = Provider.of<DeliveryProvider>(context, listen: false);
                        final ok = await provider.recordPayment(
                          widget.order.id,
                          modePaiement: selectedMode,
                          notesPaiement: notesController.text.trim().isNotEmpty
                              ? notesController.text.trim()
                              : "Paiement encaissé par le livreur (${widget.order.code})",
                        );
                        setState(() => _isProcessing = false);
                        if (!mounted) return;
                        if (ok) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text("Paiement de ${widget.order.montantTotal.toStringAsFixed(2)} HTG validé avec succès."),
                              backgroundColor: AppTheme.primaryRoyal,
                            ),
                          );
                        } else if (provider.errorMessage != null) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(provider.errorMessage!),
                              backgroundColor: Colors.red.shade700,
                            ),
                          );
                        }
                      },
                      icon: const Icon(Icons.check_circle_outline),
                      label: const Text("Valider l'Encaissement", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  void _openAddressValidationModal([DeliveryOrder? customOrder]) async {
    final provider = Provider.of<DeliveryProvider>(context, listen: false);
    final orderToUse = customOrder ?? provider.orders.firstWhere(
      (o) => o.id == widget.order.id,
      orElse: () => widget.order,
    );
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AddressMapModal(order: orderToUse),
    );
    if (result == true && mounted) {
      Provider.of<DeliveryProvider>(context, listen: false).fetchOrders(force: true);
    }
  }

  void _openDisputeModal() {
    showDialog(
      context: context,
      builder: (context) => DisputeDialog(
        order: widget.order,
        onSubmit: ({
          required String articleId,
          required int quantiteDefectueuse,
          required String motif,
          String? description,
          required bool doitEtreRelivree,
          required String actionChoisie,
        }) async {
          final provider = Provider.of<DeliveryProvider>(context, listen: false);
          final success = await provider.submitDispute(
            orderId: widget.order.id,
            articleId: articleId,
            quantiteDefectueuse: quantiteDefectueuse,
            motif: motif,
            description: description,
            doitEtreRelivree: doitEtreRelivree,
            actionChoisie: actionChoisie,
          );
          if (!context.mounted) return success;
          if (success) {
            final String message;
            if (doitEtreRelivree && actionChoisie == 'NOUVELLE_COMMANDE') {
              message = 'Litige enregistré : une nouvelle commande de $quantiteDefectueuse unité(s) a été créée pour le client.';
            } else if (doitEtreRelivree) {
              message = 'Litige enregistré : $quantiteDefectueuse unité(s) reprogrammée(s) pour relivraison garantie.';
            } else {
              message = 'Litige enregistré sans relivraison (constat transmis).';
            }
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(message),
                backgroundColor: Colors.orange.shade800,
                duration: const Duration(seconds: 4),
              ),
            );
            Navigator.pop(context);
          } else if (provider.errorMessage != null) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(provider.errorMessage!),
                backgroundColor: Colors.red.shade700,
              ),
            );
          }
          return success;
        },
      ),
    );
  }

  void _openBreakdownDialog() {
    final reasonController = TextEditingController(text: "Panne mécanique / Incident véhicule");
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.car_crash_outlined, color: Colors.red.shade700, size: 22),
            ),
            const SizedBox(width: 10),
            const Expanded(
              child: Text(
                "Signaler Panne / Relais",
                style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Cette action libère la course de votre tournée et avertit immédiatement le dispatcheur et les autres livreurs pour qu'un collègue prenne le relais.",
              style: TextStyle(fontSize: 12, color: Colors.black87),
            ),
            const SizedBox(height: 14),
            const Text(
              "Motif de l'immobilisation :",
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            TextField(
              controller: reasonController,
              maxLines: 2,
              decoration: InputDecoration(
                hintText: "Ex: Crevaison, panne moteur, accident...",
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                contentPadding: const EdgeInsets.all(12),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Annuler"),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade700,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () async {
              Navigator.pop(ctx);
              final provider = Provider.of<DeliveryProvider>(context, listen: false);
              setState(() => _isProcessing = true);
              final res = await provider.reportBreakdown(widget.order.id, motif: reasonController.text.trim());
              setState(() => _isProcessing = false);
              if (mounted) {
                if (res.success) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text("Course libérée pour relais. Alerte transmise au dispatcheur."),
                      backgroundColor: Colors.orange,
                    ),
                  );
                  Navigator.pop(context);
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(res.errorMessage ?? "Impossible de libérer la course."),
                      backgroundColor: Colors.red.shade700,
                    ),
                  );
                }
              }
            },
            child: const Text("Confirmer le Relais", style: TextStyle(fontWeight: FontWeight.w900)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Obtenir la commande a jour depuis le provider si disponible
    final provider = Provider.of<DeliveryProvider>(context);
    final currentOrder = provider.orders.firstWhere(
      (o) => o.id == widget.order.id,
      orElse: () => widget.order,
    );

    final isDone = currentOrder.statut == 'CLOTUREE' || currentOrder.statut == 'LIVREE_EN_ATTENTE';
    final isDispute = currentOrder.statut == 'EN_ATTENTE_DE_RELIVRAISON';
    final inProgress = currentOrder.statut == 'EN_COURS_DE_LIVRAISON';
    final isStarted = inProgress || isDone;

    // Conditions d'etapes
    final bool step1Done = isStarted;
    final bool step2PaidOrCredit = currentOrder.estPayee || currentOrder.isCreditOrder;
    final bool step3GpsDone = !currentOrder.requiresGpsValidation || isDone;

    final isDark = AppTheme.isDark(context);
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          currentOrder.code,
          style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
        ),
        backgroundColor: AppTheme.primaryRoyal,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: SafeArea(
        top: false,
        bottom: true,
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(16, 16, 16, bottomPadding + 36),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Synthese Destinataire
              _buildCustomerCard(context, currentOrder),

              const SizedBox(height: 16),

              // Stepper Guidé Titre
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    "Progression de la Livraison",
                    style: TextStyle(fontWeight: FontWeight.w900, fontSize: 15),
                  ),
                  Text(
                    isDone ? "Terminée" : (isDispute ? "Litige" : (inProgress ? "En cours" : "À débuter")),
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: isDone ? const Color(0xFF047857) : (inProgress ? Colors.blue.shade700 : Colors.grey.shade600),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              if (currentOrder.isUnassigned) ...[
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0C4E55).withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFF0C4E55).withValues(alpha: 0.25)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.radar_outlined, color: Color(0xFF0C4E55), size: 20),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              "Course disponible (Bourse libre)",
                              style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13, color: Color(0xFF0C4E55)),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        "Cette livraison n'a pas encore de chauffeur attitré. Vous pouvez la prendre en charge dès maintenant.",
                        style: TextStyle(fontSize: 11, color: Colors.black87),
                      ),
                      const SizedBox(height: 12),
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF0C4E55),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        icon: const Icon(Icons.add_task_rounded, size: 18),
                        label: const Text("Prendre en charge cette course", style: TextStyle(fontWeight: FontWeight.w900)),
                        onPressed: _isProcessing ? null : () async {
                          final auth = Provider.of<AuthProvider>(context, listen: false);
                          final currentDriverId = auth.currentUser?.id;
                          if (currentDriverId == null) return;
                          final messenger = ScaffoldMessenger.of(context);
                          setState(() => _isProcessing = true);
                          final res = await provider.claimOrder(
                            currentOrder.id,
                            driverId: currentDriverId,
                          );
                          if (!mounted) return;
                          setState(() => _isProcessing = false);
                          if (res.success) {
                            messenger.showSnackBar(
                              const SnackBar(
                                content: Text("Course prise en charge avec succès !"),
                                backgroundColor: Color(0xFF0C4E55),
                              ),
                            );
                          } else {
                            messenger.showSnackBar(
                              SnackBar(
                                content: Text(res.errorMessage ?? "Action impossible"),
                                backgroundColor: Colors.red.shade700,
                              ),
                            );
                          }
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
              ],

              // Stepper 4 Etapes Sequentielles
              _buildStepItem(
                context,
                stepNumber: 1,
                title: "1. Départ course",
                subtitle: step1Done
                    ? "En déplacement vers le client"
                    : "Signaler le départ au système",
                isCompleted: step1Done,
                isActive: !step1Done && !isDone,
                badgeText: step1Done ? "En cours" : "À débuter",
                badgeColor: step1Done ? const Color(0xFF047857) : Colors.blue.shade800,
                child: !step1Done && !isDone
                    ? Padding(
                        padding: const EdgeInsets.only(top: 10),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.blue.shade800,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                padding: const EdgeInsets.symmetric(vertical: 14),
                              ),
                              icon: const Icon(Icons.navigation_rounded, size: 20),
                              label: const Text("Débuter la course", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                              onPressed: _isProcessing ? null : _handleStart,
                            ),
                            const SizedBox(height: 10),
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: isDark ? const Color(0xFF1E293B) : Colors.grey.shade100,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Row(
                                children: [
                                  Icon(Icons.lock_outline, size: 14, color: AppTheme.mutedColor(context)),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      "Étapes suivantes verrouillées jusqu'au départ.",
                                      style: TextStyle(fontSize: 11, color: AppTheme.mutedColor(context)),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      )
                    : null,
              ),

              // Etape 2 visible uniquement si Etape 1 accomplie
              if (step1Done) ...[
                const SizedBox(height: 10),
                _buildStepItem(
                  context,
                  stepNumber: 2,
                  title: "2. Encaissement",
                  subtitle: currentOrder.estPayee
                      ? "Paiement reçu (${currentOrder.modePaiement})"
                      : (currentOrder.isCreditOrder
                          ? "Vente à crédit : encaissement non requis"
                          : "Règlement comptant obligatoire"),
                  isCompleted: step2PaidOrCredit,
                  isActive: !step2PaidOrCredit && !isDone,
                  badgeText: currentOrder.isCreditOrder ? "Vente à Crédit" : (currentOrder.estPayee ? "Réglée" : "À Encaisser"),
                  badgeColor: currentOrder.isCreditOrder ? Colors.blue.shade700 : (currentOrder.estPayee ? const Color(0xFF047857) : Colors.amber.shade800),
                  child: !step2PaidOrCredit && !isDone
                      ? Padding(
                          padding: const EdgeInsets.only(top: 10),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.amber.shade800,
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                  padding: const EdgeInsets.symmetric(vertical: 14),
                                ),
                                icon: const Icon(Icons.point_of_sale_rounded, size: 20),
                                label: Text(
                                  "Encaisser : ${currentOrder.montantTotal.toStringAsFixed(2)} HTG",
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                ),
                                onPressed: _isProcessing ? null : _openPaymentModal,
                              ),
                              const SizedBox(height: 10),
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: isDark ? const Color(0xFF1E293B) : Colors.grey.shade100,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Row(
                                  children: [
                                    Icon(Icons.lock_outline, size: 14, color: AppTheme.mutedColor(context)),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        "Étape suivante débloquée dès le règlement.",
                                        style: TextStyle(fontSize: 11, color: AppTheme.mutedColor(context)),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        )
                      : null,
                ),
              ],

              // Etape de Validation GPS : Visible UNIQUEMENT si la commande REQUIERT une validation GPS sur place.
              if (currentOrder.requiresGpsValidation && step1Done && step2PaidOrCredit) ...[
                const SizedBox(height: 10),
                _buildStepItem(
                  context,
                  stepNumber: 3,
                  title: "3. Localisation GPS",
                  subtitle: step3GpsDone
                      ? "Position confirmée sur place"
                      : "1ère livraison : capture requise",
                  isCompleted: step3GpsDone,
                  isActive: !step3GpsDone && !isDone,
                  badgeText: step3GpsDone ? "GPS Confirmé" : "À Capturer",
                  badgeColor: step3GpsDone ? const Color(0xFF047857) : Colors.indigo.shade700,
                  child: !step3GpsDone && !isDone
                    ? Padding(
                        padding: const EdgeInsets.only(top: 10),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppTheme.primaryRoyal,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                padding: const EdgeInsets.symmetric(vertical: 14),
                              ),
                              icon: const Icon(Icons.my_location_rounded, size: 20),
                              label: const Text("Capturer position GPS", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                              onPressed: _openAddressValidationModal,
                            ),
                            const SizedBox(height: 10),
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: isDark ? const Color(0xFF1E293B) : Colors.grey.shade100,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Row(
                                children: [
                                  Icon(Icons.lock_outline, size: 14, color: AppTheme.mutedColor(context)),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      "Contrôle final disponible après capture.",
                                      style: TextStyle(fontSize: 11, color: AppTheme.mutedColor(context)),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      )
                    : null,
                ),
              ],

              // Etape finale de Contrôle & Clôture :
              if (step1Done && step2PaidOrCredit && step3GpsDone) ...[
                const SizedBox(height: 10),
                _buildStepItem(
                  context,
                  stepNumber: currentOrder.requiresGpsValidation ? 4 : 3,
                  title: "${currentOrder.requiresGpsValidation ? 4 : 3}. Remise & Contrôle",
                  subtitle: isDone
                      ? "Livraison clôturée"
                      : "Vérifier la marchandise avant remise",
                  isCompleted: isDone,
                  isActive: !isDone,
                  child: !isDone
                      ? Padding(
                          padding: const EdgeInsets.only(top: 12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              // Récapitulatif Articles
                              _buildItemsSummary(context, currentOrder),
                              const SizedBox(height: 14),

                              // Récupération des Emballages Vides
                              _buildConsignesSection(context, currentOrder),

                              // Bouton Terminer Conforme
                              ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF047857),
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(vertical: 14),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                  elevation: 2,
                                ),
                                icon: const Icon(Icons.verified_rounded, size: 20),
                                label: const Text(
                                  "Confirmer la remise",
                                  style: TextStyle(fontWeight: FontWeight.w900, fontSize: 14),
                                ),
                                onPressed: _isProcessing ? null : _handleComplete,
                              ),

                              const SizedBox(height: 10),

                              // Bouton Litige / Produit Défectueux
                              OutlinedButton.icon(
                                style: OutlinedButton.styleFrom(
                                  side: const BorderSide(color: Colors.orange, width: 1.5),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                ),
                                icon: const Icon(Icons.report_problem_rounded, color: Colors.orange, size: 18),
                                label: const Text(
                                  "Signaler un litige",
                                  style: TextStyle(fontWeight: FontWeight.bold, color: Colors.orange),
                                ),
                                onPressed: _isProcessing ? null : _openDisputeModal,
                              ),

                              const SizedBox(height: 8),

                              // Bouton Signaler Panne / Relais
                              OutlinedButton.icon(
                                style: OutlinedButton.styleFrom(
                                  side: BorderSide(color: Colors.red.shade400, width: 1.5),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                ),
                                icon: Icon(Icons.car_crash_outlined, color: Colors.red.shade700, size: 18),
                                label: Text(
                                  "Signaler panne / Passer le relais",
                                  style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red.shade700),
                                ),
                                onPressed: _isProcessing ? null : _openBreakdownDialog,
                              ),
                            ],
                          ),
                        )
                      : null,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStepItem(
    BuildContext context, {
    required int stepNumber,
    required String title,
    required String subtitle,
    required bool isCompleted,
    required bool isActive,
    String? badgeText,
    Color? badgeColor,
    Widget? child,
  }) {
    final isDark = AppTheme.isDark(context);

    Color getStatusColor() {
      if (isCompleted) return const Color(0xFF047857);
      if (isActive) return AppTheme.primaryRoyal;
      return Colors.grey.shade400;
    }

    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor(context),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isActive
              ? AppTheme.primaryRoyal.withValues(alpha: 0.6)
              : (isCompleted ? const Color(0xFF047857).withValues(alpha: 0.3) : AppTheme.borderColor(context)),
          width: isActive ? 1.8 : 1.0,
        ),
        boxShadow: isActive
            ? [
                BoxShadow(
                  color: AppTheme.primaryRoyal.withValues(alpha: 0.08),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ]
            : null,
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: getStatusColor().withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                  border: Border.all(color: getStatusColor(), width: 1.5),
                ),
                child: Center(
                  child: isCompleted
                      ? const Icon(Icons.check, size: 16, color: Color(0xFF047857))
                      : Text(
                          "$stepNumber",
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w900,
                            color: getStatusColor(),
                          ),
                        ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            title,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w900,
                              color: AppTheme.titleColor(context),
                            ),
                          ),
                        ),
                        if (badgeText != null)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: (badgeColor ?? AppTheme.primaryRoyal).withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              badgeText,
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: badgeColor ?? AppTheme.primaryRoyal,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 11,
                        color: isDark ? AppTheme.mutedColor(context) : Colors.grey.shade600,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          ?child,
        ],
      ),
    );
  }

  Widget _buildCustomerCard(BuildContext context, DeliveryOrder order) {
    final isDark = AppTheme.isDark(context);

    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor(context),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.borderColor(context)),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "Informations Destinataire",
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 13,
                  color: AppTheme.titleColor(context),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: order.isCreditOrder
                      ? Colors.blue.withValues(alpha: 0.12)
                      : Colors.amber.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  order.isCreditOrder ? "Vente à Crédit" : "Vente Comptant",
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: order.isCreditOrder ? Colors.blue.shade800 : Colors.amber.shade900,
                  ),
                ),
              ),
            ],
          ),
          const Divider(height: 18),
          Row(
            children: [
              CircleAvatar(
                backgroundColor: isDark
                    ? AppTheme.accentSky.withValues(alpha: 0.15)
                    : const Color(0xFFEBF3FC),
                child: Icon(Icons.person, color: isDark ? AppTheme.accentSky : AppTheme.primaryRoyal),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      order.clientNom,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: AppTheme.titleColor(context),
                      ),
                    ),
                    Text(
                      order.clientTel.isEmpty ? "Téléphone non renseigné" : order.clientTel,
                      style: TextStyle(color: AppTheme.mutedColor(context), fontSize: 11),
                    ),
                  ],
                ),
              ),
              if (order.clientTel.isNotEmpty)
                IconButton(
                  icon: Icon(Icons.phone, color: isDark ? AppTheme.accentSky : AppTheme.primaryRoyal),
                  tooltip: "Appeler le client",
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text("Numéro du destinataire : ${order.clientTel}"),
                        backgroundColor: isDark ? AppTheme.cardDarkElevated : AppTheme.primaryRoyal,
                      ),
                    );
                  },
                ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.location_on_outlined, color: isDark ? AppTheme.accentMint : Colors.grey.shade600, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      order.adresseLivraison,
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.titleColor(context)),
                    ),
                    if (order.latitude != null && order.longitude != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Row(
                          children: [
                            Text(
                              "GPS : ${order.latitude!.toStringAsFixed(4)}, ${order.longitude!.toStringAsFixed(4)} (Vérifié)",
                              style: const TextStyle(fontSize: 10, color: Color(0xFF047857), fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(width: 8),
                            InkWell(
                              onTap: () => _openAddressValidationModal(order),
                              borderRadius: BorderRadius.circular(4),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.map_outlined, size: 12, color: isDark ? AppTheme.accentSky : AppTheme.primaryRoyal),
                                    const SizedBox(width: 3),
                                    Text(
                                      "Voir carte",
                                      style: TextStyle(
                                        fontSize: 10,
                                        color: isDark ? AppTheme.accentSky : AppTheme.primaryRoyal,
                                        fontWeight: FontWeight.bold,
                                        decoration: TextDecoration.underline,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildItemsSummary(BuildContext context, DeliveryOrder order) {
    final isDark = AppTheme.isDark(context);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.cardDarkSubtle : Colors.grey.shade50,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.borderColor(context)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                "Articles à livrer",
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
              ),
              Text(
                "${order.montantTotal.toStringAsFixed(2)} HTG",
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 13,
                  color: isDark ? AppTheme.accentMint : AppTheme.primaryRoyal,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ...order.items.map((item) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryRoyal.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        "${item.quantiteCommandee}x",
                        style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 11, color: AppTheme.primaryRoyal),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        item.designation,
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                      ),
                    ),
                    if (item.quantiteOfferte > 0)
                      Text(
                        "+${item.quantiteOfferte} offert",
                        style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF047857)),
                      ),
                  ],
                ),
              )),
        ],
      ),
    );
  }

  Widget _buildConsignesSection(BuildContext context, DeliveryOrder order) {
    final consigneItems = order.items.where((it) => it.exigeRetourEmballage).toList();
    if (consigneItems.isEmpty) return const SizedBox.shrink();

    final isDark = AppTheme.isDark(context);

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF0FDF4),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? const Color(0xFF334155) : const Color(0xFF86EFAC),
          width: 1.2,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF047857).withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.recycling_rounded,
                  color: Color(0xFF047857),
                  size: 20,
                ),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Retour de vides (Bonbonnes)",
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 13,
                        color: Color(0xFF047857),
                      ),
                    ),
                    Text(
                      "Nombre de bonbonnes ou contenants vides recuperes",
                      style: TextStyle(fontSize: 11, color: Colors.grey),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(height: 1),
          const SizedBox(height: 12),
          ...consigneItems.map((it) {
            final qtyRecuperee = _consignesRecuperees[it.articleId] ?? it.quantiteCommandee;
            final ecart = qtyRecuperee - it.quantiteCommandee;

            Color ecartColor;
            String ecartLabel;
            IconData ecartIcon;

            if (ecart == 0) {
              ecartColor = const Color(0xFF047857);
              ecartLabel = "Equilibre parfait (0 ecart)";
              ecartIcon = Icons.check_circle_rounded;
            } else if (ecart < 0) {
              ecartColor = Colors.orange.shade800;
              ecartLabel = "Deficit client : ${ecart.abs()} vide(s) manquant(s)";
              ecartIcon = Icons.warning_amber_rounded;
            } else {
              ecartColor = Colors.blue.shade700;
              ecartLabel = "Surplus client : +$ecart vide(s) rendu(s)";
              ecartIcon = Icons.add_circle_outline_rounded;
            }

            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF0F172A) : Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isDark ? const Color(0xFF334155) : Colors.grey.shade200,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              it.nomEmballageRecupere ?? "Bonbonne vide 5G",
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                            ),
                            Text(
                              "Pour ${it.designation}",
                              style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade200,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          "Livre : ${it.quantiteCommandee}",
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Colors.black87),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        "Quantite vide recue :",
                        style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
                      ),
                      Row(
                        children: [
                          IconButton(
                            visualDensity: VisualDensity.compact,
                            icon: const Icon(Icons.remove_circle_outline, size: 24),
                            color: Colors.red.shade600,
                            onPressed: qtyRecuperee > 0
                                ? () {
                                    setState(() {
                                      _consignesRecuperees[it.articleId] = qtyRecuperee - 1;
                                    });
                                  }
                                : null,
                          ),
                          Container(
                            constraints: const BoxConstraints(minWidth: 42),
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: isDark ? const Color(0xFF1E293B) : Colors.grey.shade100,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: isDark ? const Color(0xFF475569) : Colors.grey.shade300,
                              ),
                            ),
                            child: Text(
                              "$qtyRecuperee",
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontWeight: FontWeight.w900,
                                fontSize: 16,
                              ),
                            ),
                          ),
                          IconButton(
                            visualDensity: VisualDensity.compact,
                            icon: const Icon(Icons.add_circle_outline, size: 24),
                            color: const Color(0xFF047857),
                            onPressed: () {
                              setState(() {
                                _consignesRecuperees[it.articleId] = qtyRecuperee + 1;
                              });
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: ecartColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: ecartColor.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(ecartIcon, size: 14, color: ecartColor),
                        const SizedBox(width: 6),
                        Text(
                          ecartLabel,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: ecartColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          }),
          const SizedBox(height: 6),
          TextField(
            controller: _consignesNotesController,
            maxLines: 2,
            style: const TextStyle(fontSize: 12),
            decoration: InputDecoration(
              labelText: "Observation sur les vides (optionnel)",
              hintText: "Ex : Client a garde 2 bonbonnes encore pleines...",
              hintStyle: TextStyle(fontSize: 11, color: Colors.grey.shade400),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              isDense: true,
            ),
          ),
        ],
      ),
    );
  }
}
