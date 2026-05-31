import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:sic_mobile/config/theme.dart';
import 'package:sic_mobile/core/utils/formatters.dart';
import 'package:sic_mobile/data/repositories/sic_repository.dart';
import 'package:sic_mobile/data/models/agent.dart';
import 'package:sic_mobile/shared/widgets/sic_widgets.dart';
import 'package:sic_mobile/shared/widgets/cards.dart';

/// Conversion Screen - Swap between puces
class ConversionScreen extends ConsumerStatefulWidget {
  const ConversionScreen({super.key});

  @override
  ConsumerState<ConversionScreen> createState() => _ConversionScreenState();
}

class _ConversionScreenState extends ConsumerState<ConversionScreen> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();

  List<Puce> _puces = [];
  Puce? _sourcePuce;
  Puce? _targetPuce;
  bool _isLoading = true;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _loadPuces();
  }

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _loadPuces() async {
    final repo = SicRepository();
    final puces = await repo.getPuces();
    if (!mounted) return;
    setState(() {
      _puces = puces;
      _isLoading = false;
      if (puces.length >= 2) {
        _sourcePuce = puces[0];
        _targetPuce = puces[1];
      }
    });
  }

  Future<void> _submitConversion() async {
    if (!_formKey.currentState!.validate()) return;
    if (_sourcePuce == null || _targetPuce == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Veuillez sélectionner deux puces'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    if (_sourcePuce!.balance < double.parse(_amountController.text)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Solde insuffisant'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    final amount = double.tryParse(_amountController.text.replaceAll(' ', '')) ?? 0;
    final repo = SicRepository();
    final result = await repo.convert(
      amount: amount,
      sourcePuceId: _sourcePuce!.id,
      targetPuceId: _targetPuce!.id,
    );

    if (!mounted) return;
    setState(() => _isSubmitting = false);

    if (result.isSuccess) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Conversion de ${Formatters.currency(amount)} réussie !'),
          backgroundColor: Colors.green,
        ),
      );
      context.go('/home');
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result.error ?? 'Erreur lors de la conversion'),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    }
  }

  void _swapPuces() {
    setState(() {
      final temp = _sourcePuce;
      _sourcePuce = _targetPuce;
      _targetPuce = temp;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Conversion'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _puces.length < 2
              ? SicEmptyState(
                  icon: Icons.swap_horiz,
                  title: 'Conversion impossible',
                  subtitle: 'Vous avez besoin d\'au moins 2 puces pour effectuer une conversion',
                  action: ElevatedButton.icon(
                    onPressed: () => context.push('/puces/add'),
                    icon: const Icon(Icons.add),
                    label: const Text('Ajouter une puce'),
                  ),
                )
              : Form(
                  key: _formKey,
                  child: ListView(
                    padding: const EdgeInsets.all(SicTheme.spaceMd),
                    children: [
                      // Source Puce
                      Text(
                        'Puce source (débit)',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                      const SizedBox(height: SicTheme.spaceSm),
                      _buildPuceSelector(
                        value: _sourcePuce,
                        onChanged: (puce) => setState(() => _sourcePuce = puce),
                        excludePuce: _targetPuce,
                      ),

                      const SizedBox(height: SicTheme.spaceMd),

                      // Swap button
                      Center(
                        child: IconButton(
                          onPressed: _swapPuces,
                          icon: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.swap_vert,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: SicTheme.spaceMd),

                      // Target Puce
                      Text(
                        'Puce cible (crédit)',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                      const SizedBox(height: SicTheme.spaceSm),
                      _buildPuceSelector(
                        value: _targetPuce,
                        onChanged: (puce) => setState(() => _targetPuce = puce),
                        excludePuce: _sourcePuce,
                      ),

                      const SizedBox(height: SicTheme.spaceLg),

                      // Amount
                      Text(
                        'Montant à convertir',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                      const SizedBox(height: SicTheme.spaceSm),
                      TextFormField(
                        controller: _amountController,
                        keyboardType: TextInputType.number,
                        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                        decoration: InputDecoration(
                          hintText: 'Entrez le montant',
                          prefixIcon: const Icon(Icons.attach_money),
                          suffixText: 'FCFA',
                          helperText: _sourcePuce != null
                              ? 'Solde disponible: ${Formatters.currency(_sourcePuce!.balance)}'
                              : null,
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Veuillez entrer un montant';
                          }
                          final amount = double.tryParse(value);
                          if (amount == null || amount < 100) {
                            return 'Montant minimum: 100 FCFA';
                          }
                          if (_sourcePuce != null && amount > _sourcePuce!.balance) {
                            return 'Solde insuffisant';
                          }
                          return null;
                        },
                      ),

                      const SizedBox(height: SicTheme.spaceLg),

                      // Info
                      SicCard(
                        backgroundColor: Colors.blue.withValues(alpha: 0.1),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.info_outline, size: 20, color: Colors.blue),
                                const SizedBox(width: 8),
                                Text(
                                  'Conversion',
                                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                        fontWeight: FontWeight.w600,
                                      ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              '• Commission: 0.5%\n• Le montant sera débité de la puce source et crédité sur la puce cible\n• Minimum: 100 FCFA',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: SicTheme.spaceXl),

                      // Submit
                      ElevatedButton(
                        onPressed: _isSubmitting ? null : _submitConversion,
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                        child: _isSubmitting
                            ? const SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                ),
                              )
                            : const Text('Effectuer la Conversion'),
                      ),
                    ],
                  ),
                ),
    );
  }

  Widget _buildPuceSelector({
    required Puce? value,
    required void Function(Puce?) onChanged,
    Puce? excludePuce,
  }) {
    final availablePuces = excludePuce != null
        ? _puces.where((p) => p.id != excludePuce.id).toList()
        : _puces;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: Theme.of(context).brightness == Brightness.dark
            ? SicTheme.surfaceLightDark
            : Colors.grey.shade100,
        borderRadius: BorderRadius.circular(SicTheme.radiusMd),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<Puce>(
          value: value,
          isExpanded: true,
          hint: const Text('Sélectionner une puce'),
          items: availablePuces.map((puce) {
            return DropdownMenuItem<Puce>(
              value: puce,
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: Color(Formatters.operatorColor(puce.operator))
                          .withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Center(
                      child: Icon(
                        Icons.sim_card,
                        color: Color(Formatters.operatorColor(puce.operator)),
                        size: 20,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${Formatters.operatorLabel(puce.operator)} - ${puce.formattedPhone}',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                        Text(
                          Formatters.currency(puce.balance),
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: Theme.of(context).colorScheme.primary,
                                fontWeight: FontWeight.w600,
                              ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }
}