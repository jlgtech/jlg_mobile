import 'package:flutter/material.dart';

class DisputeDialog extends StatefulWidget {
  final String orderCode;
  final Function(String motif) onSubmit;

  const DisputeDialog({
    super.key,
    required this.orderCode,
    required this.onSubmit,
  });

  @override
  State<DisputeDialog> createState() => _DisputeDialogState();
}

class _DisputeDialogState extends State<DisputeDialog> {
  final _motifController = TextEditingController();
  String _selectedReason = 'Produit Perclé / Fuite';
  bool _isSubmitting = false;

  final List<String> _commonReasons = [
    'Produit Défectueux (Fuite / Défaut usine)',
    'Sachet ou Bouteille Perclé(e) / Cassé(e)',
    'Colis Endommagé en cours de Transport',
    'Erreur de Quantité ou Référence Livrée',
    'Client Absent au Point de Livraison',
    'Refus de Réception par le Client',
  ];

  @override
  void dispose() {
    _motifController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Déclaration de Litige',
            style: TextStyle(
              fontWeight: FontWeight.w900,
              fontSize: 18,
              color: Colors.red[900],
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Commande : ${widget.orderCode}',
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Colors.grey,
            ),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Motif principal :',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.grey[300]!),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _selectedReason,
                  isExpanded: true,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                  items: _commonReasons.map((String reason) {
                    return DropdownMenuItem<String>(
                      value: reason,
                      child: Text(reason),
                    );
                  }).toList(),
                  onChanged: (val) {
                    if (val != null) {
                      setState(() => _selectedReason = val);
                    }
                  },
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Précisions complémentaires (Optionnel) :',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _motifController,
              maxLines: 3,
              style: const TextStyle(fontSize: 13),
              decoration: InputDecoration(
                hintText: 'Notes sur l\'état du produit ou le constat terrain...',
                hintStyle: TextStyle(color: Colors.grey[400], fontSize: 12),
                fillColor: Colors.grey[50],
                filled: true,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(color: Colors.grey[300]!),
                ),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Annuler', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.red[700],
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          ),
          onPressed: _isSubmitting
              ? null
              : () async {
                  setState(() => _isSubmitting = true);
                  final fullMotif = '$_selectedReason ${_motifController.text.trim()}'.trim();
                  await widget.onSubmit(fullMotif);
                  if (mounted) {
                    Navigator.pop(context);
                  }
                },
          child: _isSubmitting
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                )
              : const Text('Transmettre Litige', style: TextStyle(fontWeight: FontWeight.w900)),
        ),
      ],
    );
  }
}
