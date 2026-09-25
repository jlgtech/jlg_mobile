import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/delivery_model.dart';
import '../providers/delivery_provider.dart';
import '../widgets/dispute_dialog.dart';

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

    if (mounted) {
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Livraison démarrée ! En route vers le client...'),
            backgroundColor: Colors.teal,
          ),
        );
        Navigator.pop(context);
      }
    }
  }

  void _handleComplete() async {
    setState(() => _isProcessing = true);
    final provider = Provider.of<DeliveryProvider>(context, listen: false);

    // Capture simulated GPS coordinates for Port-au-Prince
    final success = await provider.completeDelivery(
      widget.order.id,
      lat: 18.5392,
      lng: -72.3364,
    );

    setState(() => _isProcessing = false);

    if (mounted) {
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Livraison validée avec succès ! Géolocalisation GPS enregistrée.'),
            backgroundColor: Color(0xFF0C4E55),
          ),
        );
        Navigator.pop(context);
      }
    }
  }

  void _openDisputeModal() {
    showDialog(
      context: context,
      builder: (context) => DisputeDialog(
        orderCode: widget.order.code,
        onSubmit: (motif) async {
          final provider = Provider.of<DeliveryProvider>(context, listen: false);
          final success = await provider.submitDispute(widget.order.id, motif);
          if (mounted && success) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Litige transmis à l\'administration avec demande de relivraison.'),
                backgroundColor: Colors.orange,
              ),
            );
            Navigator.pop(context);
          }
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
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
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
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        const Icon(Icons.payment_outlined, color: Colors.grey, size: 20),
                        const SizedBox(width: 8),
                        Text(
                          'Mode : ${order.modePaiement} ${order.precisionPaiement != null ? "(${order.precisionPaiement})" : ""}',
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),

                    const SizedBox(height: 14),

                    // Bouton de Confirmation d'Adresse (Spécification Première Livraison)
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
                        side: BorderSide(color: Colors.teal.shade700),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      icon: const Icon(Icons.pin_drop_outlined, size: 18, color: Color(0xFF0C4E55)),
                      label: const Text(
                        "Confirmer / Valider Adresse & GPS",
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF0C4E55)),
                      ),
                      onPressed: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text("Adresse '${order.adresseLivraison}' et position GPS confirmées pour ce client !"),
                            backgroundColor: const Color(0xFF0C4E55),
                          ),
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
    );
  }
}
