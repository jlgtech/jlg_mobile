import 'dart:math';
import 'package:flutter/material.dart';
import '../models/delivery_model.dart';
import '../../../core/theme/app_theme.dart';

class DisputeDialog extends StatefulWidget {
  final DeliveryOrder? order;
  final String? orderCode;
  final Future<bool> Function({
    required String articleId,
    required int quantiteDefectueuse,
    required String motif,
    String? description,
    required bool doitEtreRelivree,
    required String actionChoisie,
  }) onSubmit;

  const DisputeDialog({
    super.key,
    this.order,
    this.orderCode,
    required this.onSubmit,
  });

  @override
  State<DisputeDialog> createState() => _DisputeDialogState();
}

class _DisputeDialogState extends State<DisputeDialog> {
  final _motifDetailController = TextEditingController();
  late String _selectedReason;
  DeliveryItem? _selectedItem;
  int _quantiteDefectueuse = 1;
  bool _doitEtreRelivree = true;
  String _modeRelivraison = 'RELIVRAISON_DEMANDEE'; // 'RELIVRAISON_DEMANDEE' ou 'NOUVELLE_COMMANDE'
  bool _isSubmitting = false;

  static const List<String> _commonReasons = [
    'Produit Défectueux (Fuite / Défaut usine)',
    'Sachet ou Bouteille Percé(e) / Cassé(e)',
    'Bouchon ou Capsule Endommagé(e)',
    'Altération de la Qualité ou Goût',
    'Colis Endommagé en cours de Transport',
    'Erreur de Quantité ou Référence Livrée',
    'Refus de Réception par le Client',
  ];

  @override
  void initState() {
    super.initState();
    _selectedReason = _commonReasons.first;

    final items = widget.order?.items ?? [];
    if (items.isNotEmpty) {
      _selectedItem = items.first;
      _quantiteDefectueuse = min(1, _selectedItem!.quantiteCommandee > 0 ? _selectedItem!.quantiteCommandee : 1);
    }
  }

  @override
  void dispose() {
    _motifDetailController.dispose();
    super.dispose();
  }

  int get _maxQuantity {
    if (_selectedItem != null && _selectedItem!.quantiteCommandee > 0) {
      return _selectedItem!.quantiteCommandee;
    }
    return 999;
  }

  String get _displayOrderCode {
    if (widget.order != null) return widget.order!.code;
    if (widget.orderCode != null) return widget.orderCode!;
    return 'Commande';
  }

  @override
  Widget build(BuildContext context) {
    final items = widget.order?.items ?? [];
    final bool isDark = AppTheme.isDark(context);

    return AlertDialog(
      backgroundColor: AppTheme.surfaceColor(context),
      scrollable: false,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: BorderSide(color: AppTheme.borderColor(context)),
      ),
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF450A0A) : Colors.red.shade50,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: isDark ? const Color(0xFF7F1D1D) : Colors.transparent),
                ),
                child: Icon(Icons.report_problem_outlined, color: isDark ? const Color(0xFFF87171) : Colors.red.shade800, size: 20),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Déclaration de Litige',
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 18,
                    color: isDark ? const Color(0xFFFCA5A5) : Colors.red.shade900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            '$_displayOrderCode ${widget.order?.clientNom.isNotEmpty == true ? '• ${widget.order!.clientNom}' : ''}',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppTheme.mutedColor(context),
            ),
          ),
        ],
      ),
      content: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.65,
        ),
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. Choix du produit / article
              if (items.isNotEmpty) ...[
                Text(
                  'Article concerné :',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.titleColor(context)),
                ),
                const SizedBox(height: 6),
                if (items.length > 1)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF0F172A) : Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppTheme.borderColor(context)),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: _selectedItem?.articleId ?? items.first.articleId,
                        isExpanded: true,
                        dropdownColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.titleColor(context),
                        ),
                        items: items.map((item) {
                          return DropdownMenuItem<String>(
                            value: item.articleId,
                            child: Text(
                              '${item.designation} (Cmd: ${item.quantiteCommandee})',
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(color: AppTheme.titleColor(context)),
                            ),
                          );
                        }).toList(),
                        onChanged: (val) {
                          if (val != null) {
                            final found = items.firstWhere(
                              (i) => i.articleId == val,
                              orElse: () => items.first,
                            );
                            setState(() {
                              _selectedItem = found;
                              if (_quantiteDefectueuse > found.quantiteCommandee && found.quantiteCommandee > 0) {
                                _quantiteDefectueuse = found.quantiteCommandee;
                              }
                            });
                          }
                        },
                      ),
                    ),
                  )
                else
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF0F172A) : Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppTheme.borderColor(context)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            items.first.designation,
                            style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppTheme.titleColor(context)),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF1E293B) : Colors.blueGrey.shade100,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            'Total cmd: ${items.first.quantiteCommandee}',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: isDark ? const Color(0xFF94A3B8) : Colors.blueGrey.shade800,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                const SizedBox(height: 14),
              ],

              // 2. Quantite defectueuse avec controle stepper
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Quantité défectueuse :',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.titleColor(context)),
                  ),
                  Text(
                    'Max : $_maxQuantity',
                    style: TextStyle(fontSize: 11, color: AppTheme.mutedColor(context), fontWeight: FontWeight.w600),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF450A0A).withValues(alpha: 0.3) : Colors.red.shade50.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: isDark ? const Color(0xFF7F1D1D) : Colors.red.shade200),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.remove_circle_outline),
                      color: _quantiteDefectueuse > 1
                          ? (isDark ? const Color(0xFFF87171) : Colors.red.shade700)
                          : (isDark ? const Color(0xFF475569) : Colors.grey.shade400),
                      onPressed: _quantiteDefectueuse > 1
                          ? () => setState(() => _quantiteDefectueuse--)
                          : null,
                    ),
                    Text(
                      '$_quantiteDefectueuse',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                        color: isDark ? const Color(0xFFFCA5A5) : Colors.red.shade900,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.add_circle_outline),
                      color: _quantiteDefectueuse < _maxQuantity
                          ? (isDark ? const Color(0xFFF87171) : Colors.red.shade700)
                          : (isDark ? const Color(0xFF475569) : Colors.grey.shade400),
                      onPressed: _quantiteDefectueuse < _maxQuantity
                          ? () => setState(() => _quantiteDefectueuse++)
                          : null,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),

              // 3. Motif principal
              Text(
                'Motif principal :',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.titleColor(context)),
              ),
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF0F172A) : Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppTheme.borderColor(context)),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _commonReasons.contains(_selectedReason) ? _selectedReason : _commonReasons.first,
                    isExpanded: true,
                    dropdownColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.titleColor(context),
                    ),
                    items: _commonReasons.map((String reason) {
                      return DropdownMenuItem<String>(
                        value: reason,
                        child: Text(reason, style: TextStyle(color: AppTheme.titleColor(context))),
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
              const SizedBox(height: 14),

              // 4. Choix : Relivraison requise ?
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: _doitEtreRelivree
                      ? (isDark ? const Color(0xFF0C243B) : Colors.blue.shade50)
                      : (isDark ? const Color(0xFF0F172A) : Colors.grey.shade100),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: _doitEtreRelivree
                        ? (isDark ? const Color(0xFF0284C7) : Colors.blue.shade300)
                        : AppTheme.borderColor(context),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Relivraison de la quantité ?',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w900,
                                  color: _doitEtreRelivree
                                      ? (isDark ? const Color(0xFF38BDF8) : Colors.blue.shade900)
                                      : AppTheme.titleColor(context),
                                ),
                              ),
                              Text(
                                _doitEtreRelivree
                                    ? 'Oui, programmer une relivraison'
                                    : 'Non, aucune relivraison (perte / avoir)',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: _doitEtreRelivree
                                      ? (isDark ? const Color(0xFF7DD3FC) : Colors.blue.shade700)
                                      : AppTheme.mutedColor(context),
                                ),
                              ),
                            ],
                          ),
                        ),
                        Switch(
                          value: _doitEtreRelivree,
                          activeThumbColor: isDark ? const Color(0xFF38BDF8) : Colors.blue.shade800,
                          onChanged: (val) {
                            setState(() => _doitEtreRelivree = val);
                          },
                        ),
                      ],
                    ),

                    // Si Oui : Options de reprogrammation
                    if (_doitEtreRelivree) ...[
                      Divider(height: 16, color: isDark ? const Color(0xFF1E293B) : Colors.grey.shade300),
                      Text(
                        'Mode de prise en charge :',
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.titleColor(context)),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Expanded(
                            child: InkWell(
                              onTap: () => setState(() => _modeRelivraison = 'RELIVRAISON_DEMANDEE'),
                              borderRadius: BorderRadius.circular(10),
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
                                decoration: BoxDecoration(
                                  color: _modeRelivraison == 'RELIVRAISON_DEMANDEE'
                                      ? (isDark ? const Color(0xFF0284C7) : Colors.blue.shade700)
                                      : (isDark ? const Color(0xFF1E293B) : Colors.white),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: _modeRelivraison == 'RELIVRAISON_DEMANDEE'
                                        ? (isDark ? const Color(0xFF38BDF8) : Colors.blue.shade700)
                                        : AppTheme.borderColor(context),
                                  ),
                                ),
                                child: Column(
                                  children: [
                                    Icon(
                                      Icons.replay,
                                      size: 18,
                                      color: _modeRelivraison == 'RELIVRAISON_DEMANDEE'
                                          ? Colors.white
                                          : (isDark ? const Color(0xFF38BDF8) : Colors.blue.shade700),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      'Reprogrammer',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w800,
                                        color: _modeRelivraison == 'RELIVRAISON_DEMANDEE'
                                            ? Colors.white
                                            : AppTheme.titleColor(context),
                                      ),
                                    ),
                                    Text(
                                      'Relivraison auto',
                                      style: TextStyle(
                                        fontSize: 9,
                                        color: _modeRelivraison == 'RELIVRAISON_DEMANDEE'
                                            ? Colors.white70
                                            : AppTheme.mutedColor(context),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: InkWell(
                              onTap: () => setState(() => _modeRelivraison = 'NOUVELLE_COMMANDE'),
                              borderRadius: BorderRadius.circular(10),
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
                                decoration: BoxDecoration(
                                  color: _modeRelivraison == 'NOUVELLE_COMMANDE'
                                      ? (isDark ? const Color(0xFF0284C7) : Colors.blue.shade700)
                                      : (isDark ? const Color(0xFF1E293B) : Colors.white),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: _modeRelivraison == 'NOUVELLE_COMMANDE'
                                        ? (isDark ? const Color(0xFF38BDF8) : Colors.blue.shade700)
                                        : AppTheme.borderColor(context),
                                  ),
                                ),
                                child: Column(
                                  children: [
                                    Icon(
                                      Icons.add_shopping_cart,
                                      size: 18,
                                      color: _modeRelivraison == 'NOUVELLE_COMMANDE'
                                          ? Colors.white
                                          : (isDark ? const Color(0xFF38BDF8) : Colors.blue.shade700),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      'Nouvelle Cmd',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w800,
                                        color: _modeRelivraison == 'NOUVELLE_COMMANDE'
                                            ? Colors.white
                                            : AppTheme.titleColor(context),
                                      ),
                                    ),
                                    Text(
                                      'Créer commande',
                                      style: TextStyle(
                                        fontSize: 9,
                                        color: _modeRelivraison == 'NOUVELLE_COMMANDE'
                                            ? Colors.white70
                                            : AppTheme.mutedColor(context),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 14),

              // 5. Notes complémentaires optionnelles
              Text(
                'Précisions complémentaires (Optionnel) :',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.titleColor(context)),
              ),
              const SizedBox(height: 6),
              TextField(
                controller: _motifDetailController,
                maxLines: 2,
                style: TextStyle(fontSize: 13, color: AppTheme.titleColor(context)),
                decoration: InputDecoration(
                  hintText: 'Notes sur l\'état du produit ou le constat terrain...',
                  hintStyle: TextStyle(color: AppTheme.mutedColor(context), fontSize: 12),
                  fillColor: isDark ? const Color(0xFF0F172A) : Colors.grey.shade50,
                  filled: true,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(color: AppTheme.borderColor(context)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(color: AppTheme.borderColor(context)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text('Annuler', style: TextStyle(color: AppTheme.mutedColor(context), fontWeight: FontWeight.bold)),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: isDark ? const Color(0xFFDC2626) : Colors.red.shade700,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          ),
          onPressed: _isSubmitting
              ? null
              : () async {
                  setState(() => _isSubmitting = true);
                  final articleId = _selectedItem?.articleId ?? (items.isNotEmpty ? items.first.articleId : '');
                  final actionCode = _doitEtreRelivree ? _modeRelivraison : 'ACCORDE_SANS_RELIVRAISON';
                  final desc = _motifDetailController.text.trim();

                  await widget.onSubmit(
                    articleId: articleId,
                    quantiteDefectueuse: _quantiteDefectueuse,
                    motif: _selectedReason,
                    description: desc.isNotEmpty ? desc : null,
                    doitEtreRelivree: _doitEtreRelivree,
                    actionChoisie: actionCode,
                  );
                },
          child: _isSubmitting
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                )
              : const Text('Déclarer le Litige', style: TextStyle(fontWeight: FontWeight.w900)),
        ),
      ],
    );
  }
}
