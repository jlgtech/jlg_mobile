import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/delivery_model.dart';
import '../providers/delivery_provider.dart';
import '../widgets/dispute_dialog.dart';
import '../widgets/address_map_modal.dart';
import '../../../core/config/app_config.dart';

class DeliveryDetailView extends StatefulWidget {
  final DeliveryOrder order;

  const DeliveryDetailView({super.key, required this.order});

  @override
  State<DeliveryDetailView> createState() => _DeliveryDetailViewState();
}

class _DeliveryDetailViewState extends State<DeliveryDetailView> {
  bool _isProcessing = false;

  void _handleStart() async {
    setState(() => _isProcessing = true);
    final provider = Provider.of<DeliveryProvider>(context, listen: false);
    final success = await provider.startDelivery(widget.order.id);
    setState(() => _isProcessing = false);

    if (!mounted) return;
    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Livraison démarrée ! En route vers le client...'),
          backgroundColor: Colors.teal,
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

  void _handleComplete() async {
    setState(() => _isProcessing = true);
    final provider = Provider.of<DeliveryProvider>(context, listen: false);

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
          content: Text('Livraison validée avec succès ! Remise client confirmée.'),
          backgroundColor: Color(0xFF0C4E55),
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
          return SafeArea(
            top: false,
            child: Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
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
                      color: Colors.grey.shade300,
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
                        color: Colors.teal.shade50,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.point_of_sale, color: Color(0xFF0C4E55), size: 24),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "Encaisser le Paiement",
                            style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: Color(0xFF0C4E55)),
                          ),
                          Text(
                            "Règlement de la commande à la livraison",
                            style: TextStyle(fontSize: 11, color: Colors.grey),
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
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text("Montant à Encaisser :", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                      Text(
                        "${widget.order.montantTotal.toStringAsFixed(2)} HTG",
                        style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 17, color: Color(0xFF0C4E55)),
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
                    backgroundColor: const Color(0xFF0C4E55),
                    foregroundColor: Colors.white,
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
                          content: Text("Paiement de ${widget.order.montantTotal.toStringAsFixed(2)} HTG validé avec succès !"),
                          backgroundColor: const Color(0xFF0C4E55),
                        ),
                      );
                      Navigator.of(context).pop();
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

  @override
  Widget build(BuildContext context) {
    final order = widget.order;
    final isDone = order.statut == 'CLOTUREE' || order.statut == 'LIVREE_EN_ATTENTE';
    final isDispute = order.statut == 'EN_ATTENTE_DE_RELIVRAISON';
    final inProgress = order.statut == 'EN_COURS_DE_LIVRAISON';

    final bottomPadding = MediaQuery.of(context).padding.bottom;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          order.code,
          style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
        ),
        backgroundColor: const Color(0xFF0C4E55),
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
            // Status Card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isDone
                    ? Colors.teal[50]
                    : (isDispute ? Colors.orange[50] : Colors.blue[50]),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isDone
                      ? Colors.teal[200]!
                      : (isDispute ? Colors.orange[200]! : Colors.blue[200]!),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    isDone
                        ? Icons.check_circle_outline
                        : (isDispute ? Icons.warning_amber_outlined : Icons.local_shipping_outlined),
                    color: isDone
                        ? Colors.teal[700]
                        : (isDispute ? Colors.orange[800] : Colors.blue[700]),
                    size: 32,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Statut de la Course',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey[600],
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          order.statut,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w900,
                            color: isDone
                                ? Colors.teal[900]
                                : (isDispute ? Colors.orange[900] : Colors.blue[900]),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Client Info Section & Confirmation d'Adresse Première Livraison
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Informations Destinataire',
                          style: TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 14,
                            color: Color(0xFF0C4E55),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.blue.shade50,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.blue.shade200),
                          ),
                          child: const Text(
                            "1ère Livraison",
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF0C4E55),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const Divider(height: 20),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const CircleAvatar(
                        backgroundColor: Color(0xFFE6F4F1),
                        child: Icon(Icons.person, color: Color(0xFF0C4E55)),
                      ),
                      title: Text(
                        order.clientNom,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                      subtitle: Text(
                        order.clientTel.isEmpty ? 'Téléphone non renseigné' : order.clientTel,
                        style: TextStyle(color: Colors.grey[600], fontSize: 12),
                      ),
                      trailing: order.clientTel.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.phone, color: Color(0xFF0C4E55)),
                              tooltip: "Appeler le client",
                              onPressed: () {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text("Numéro du destinataire : ${order.clientTel}"),
                                    backgroundColor: const Color(0xFF0C4E55),
                                    duration: const Duration(seconds: 3),
                                  ),
                                );
                              },
                            )
                          : null,
                    ),
                    const SizedBox(height: 8),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.location_on_outlined, color: Colors.grey, size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                order.adresseLivraison,
                                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                              ),
                              if (order.latitude != null && order.longitude != null)
                                Padding(
                                  padding: const EdgeInsets.only(top: 2),
                                  child: Text(
                                    "GPS : ${order.latitude!.toStringAsFixed(4)}, ${order.longitude!.toStringAsFixed(4)} (Confirmé)",
                                    style: TextStyle(fontSize: 11, color: Colors.teal.shade700, fontWeight: FontWeight.bold),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Badge Statut Paiement (Payée vs À Encaisser)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: order.estPayee ? Colors.teal.shade50 : Colors.amber.shade50,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: order.estPayee ? Colors.teal.shade300 : Colors.amber.shade400,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            order.estPayee ? Icons.check_circle : Icons.pending_outlined,
                            size: 18,
                            color: order.estPayee ? Colors.teal.shade700 : Colors.amber.shade900,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  order.estPayee ? "COMMANDE PAYÉE" : "PAIEMENT À ENCAISSER",
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w900,
                                    color: order.estPayee ? Colors.teal.shade900 : Colors.amber.shade900,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                                const SizedBox(height: 1),
                                Text(
                                  order.estPayee
                                      ? "Mode : ${order.modePaiement} ${order.precisionPaiement != null ? "(${order.precisionPaiement})" : ""}"
                                      : "Montant à percevoir : ${order.montantTotal.toStringAsFixed(2)} HTG (${order.modePaiement})",
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: order.estPayee ? Colors.teal.shade800 : Colors.brown.shade800,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 14),

                    // Bouton de Confirmation d'Adresse avec Carte Interactive (Spécification Première Livraison)
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0C4E55),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      icon: const Icon(Icons.map_outlined, size: 20),
                      label: const Text(
                        "Ouvrir Carte & Confirmer Adresse/GPS",
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                      onPressed: () {
                        showDialog(
                          context: context,
                          builder: (context) => AddressMapModal(order: order),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Articles Items Section
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Produits à Remettre',
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 14,
                        color: Color(0xFF0C4E55),
                      ),
                    ),
                    const Divider(height: 20),
                    if (order.items.isEmpty)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 8),
                        child: Text(
                          '1x Pack Sachets d\'Eau (500ml - Pack 50)',
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                        ),
                      )
                    else
                      ...order.items.map((item) => Padding(
                            padding: const EdgeInsets.symmetric(vertical: 6),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: Colors.teal[50],
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Text(
                                    '${item.quantiteCommandee}x',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w900,
                                      color: Color(0xFF0C4E55),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        item.designation,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 13,
                                        ),
                                      ),
                                      if (item.quantiteOfferte > 0)
                                        Text(
                                          '+${item.quantiteOfferte} Offert(s) (Bonus)',
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.teal[700],
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          )),
                    const Divider(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Montant Total :',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                        ),
                        Text(
                          '${order.montantTotal.toStringAsFixed(2)} HTG',
                          style: const TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 17,
                            color: Color(0xFF0C4E55),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),

            // Action Buttons
            if (!isDone && !isDispute) ...[
              // Bouton d'encaissement si non payée
              if (!order.estPayee) ...[
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.point_of_sale),
                    label: Text(
                      'Encaisser le Paiement (${order.montantTotal.toStringAsFixed(2)} HTG)',
                      style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.amber.shade800,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      elevation: 2,
                    ),
                    onPressed: _isProcessing ? null : _openPaymentModal,
                  ),
                ),
                const SizedBox(height: 12),
              ],

              if (!inProgress)
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.navigation_outlined),
                    label: const Text(
                      'Démarrer la Tournée vers ce Client',
                      style: TextStyle(fontWeight: FontWeight.w900, fontSize: 15),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue[800],
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      elevation: 3,
                    ),
                    onPressed: _isProcessing ? null : _handleStart,
                  ),
                )
              else
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.verified_outlined),
                    label: const Text(
                      'Valider Remise Client & GPS',
                      style: TextStyle(fontWeight: FontWeight.w900, fontSize: 15),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0C4E55),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      elevation: 3,
                    ),
                    onPressed: _isProcessing ? null : _handleComplete,
                  ),
                ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.report_problem_outlined, color: Colors.orange),
                  label: const Text(
                    'Signaler un Litige / Casse',
                    style: TextStyle(fontWeight: FontWeight.bold, color: Colors.orange),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Colors.orange, width: 1.5),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  onPressed: _openDisputeModal,
                ),
              ),
            ],
          ],
        ),
      ),
    ),
  );
}
}
