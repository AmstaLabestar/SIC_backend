import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:sic_mobile/config/theme.dart';
import 'package:sic_mobile/core/utils/formatters.dart';
import 'package:sic_mobile/data/repositories/sic_repository.dart';
import 'package:sic_mobile/data/models/agent.dart';
import 'package:sic_mobile/shared/widgets/cards.dart';
import 'package:sic_mobile/shared/widgets/sic_widgets.dart';

/// Puces List Screen
class PucesListScreen extends ConsumerStatefulWidget {
  const PucesListScreen({super.key});

  @override
  ConsumerState<PucesListScreen> createState() => _PucessListScreenState();
}

class _PucessListScreenState extends ConsumerState<PucesListScreen> {
  List<Puce> _puces = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadPuces();
  }

  Future<void> _loadPuces() async {
    setState(() => _isLoading = true);
    final repo = SicRepository();
    final puces = await repo.getPuces();
    if (!mounted) return;
    setState(() {
      _puces = puces;
      _isLoading = false;
    });
  }

  double get _totalBalance {
    return _puces.fold(0.0, (sum, puce) => sum + puce.balance);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mes Puces'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => context.push('/puces/add'),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadPuces,
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _puces.isEmpty
                ? SicEmptyState(
                    icon: Icons.sim_card,
                    title: 'Aucune puce',
                    subtitle: 'Ajoutez une puce pour commencer',
                    action: ElevatedButton.icon(
                      onPressed: () => context.push('/puces/add'),
                      icon: const Icon(Icons.add),
                      label: const Text('Ajouter une puce'),
                    ),
                  )
                : ListView(
                    padding: const EdgeInsets.all(SicTheme.spaceMd),
                    children: [
                      // Total balance card
                      SicCard(
                        backgroundColor: Theme.of(context)
                            .colorScheme
                            .primary
                            .withValues(alpha: 0.1),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Solde Total',
                                  style:
                                      Theme.of(context).textTheme.bodySmall,
                                ),
                                Text(
                                  Formatters.currency(_totalBalance),
                                  style: Theme.of(context)
                                      .textTheme
                                      .headlineMedium
                                      ?.copyWith(
                                        fontWeight: FontWeight.bold,
                                        color: Theme.of(context)
                                            .colorScheme
                                            .primary,
                                      ),
                                ),
                              ],
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: Theme.of(context)
                                    .colorScheme
                                    .primary
                                    .withValues(alpha: 0.2),
                                borderRadius:
                                    BorderRadius.circular(SicTheme.radiusSm),
                              ),
                              child: Text(
                                '${_puces.length} puce${_puces.length > 1 ? 's' : ''}',
                                style: Theme.of(context).textTheme.labelMedium,
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: SicTheme.spaceLg),

                      // Puces list
                      ..._puces.map(
                        (puce) => PuceCard(
                          puce: puce,
                          showFullDetails: true,
                          onTap: () {
                            // TODO: Navigate to puce detail
                          },
                        ),
                      ),
                    ],
                  ),
      ),
    );
  }
}

/// Add Puce Screen
class AddPuceScreen extends ConsumerStatefulWidget {
  const AddPuceScreen({super.key});

  @override
  ConsumerState<AddPuceScreen> createState() => _AddPuceScreenState();
}

class _AddPuceScreenState extends ConsumerState<AddPuceScreen> {
  final _formKey = GlobalKey<FormState>();
  final _phoneController = TextEditingController();
  String _selectedOperator = 'ORANGE';
  bool _isLoading = false;

  final List<Map<String, dynamic>> _operators = [
    {'code': 'ORANGE', 'name': 'Orange', 'color': const Color(0xFFFF6600)},
    {'code': 'MOOV', 'name': 'Moov', 'color': const Color(0xFF1E88E5)},
    {'code': 'TELECEL', 'name': 'Togocel', 'color': const Color(0xFFFF6F00)},
    {'code': 'CORIS', 'name': 'Coris', 'color': const Color(0xFF4CAF50)},
  ];

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _submitPuce() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    final repo = SicRepository();
    final result = await repo.addPuce(
      operator: _selectedOperator,
      phoneNumber: _phoneController.text.replaceAll(' ', ''),
    );

    if (!mounted) return;
    setState(() => _isLoading = false);

    if (result.isSuccess) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Puce $_selectedOperator ajoutée avec succès !'),
          backgroundColor: Colors.green,
        ),
      );
      context.pop();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result.error ?? 'Erreur'),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Ajouter une Puce'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(SicTheme.spaceMd),
          children: [
            // Icon
            Center(
              child: Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: Theme.of(context)
                      .colorScheme
                      .primary
                      .withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.sim_card,
                  size: 40,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
            ),

            const SizedBox(height: SicTheme.spaceLg),

            // Operator
            Text(
              'Opérateur',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
            ),
            const SizedBox(height: SicTheme.spaceSm),
            Wrap(
              spacing: SicTheme.spaceSm,
              runSpacing: SicTheme.spaceSm,
              children: _operators.map((op) {
                final isSelected = _selectedOperator == op['code'];
                return ChoiceChip(
                  label: Text(op['name']),
                  selected: isSelected,
                  onSelected: (selected) {
                    if (selected) {
                      setState(() => _selectedOperator = op['code']);
                    }
                  },
                  selectedColor: (op['color'] as Color).withValues(alpha: 0.2),
                );
              }).toList(),
            ),

            const SizedBox(height: SicTheme.spaceLg),

            // Phone Number
            Text(
              'Numéro de téléphone',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
            ),
            const SizedBox(height: SicTheme.spaceSm),
            TextFormField(
              controller: _phoneController,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                hintText: '621 23 45 67',
                prefixIcon: Icon(Icons.phone_android),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Veuillez entrer le numéro';
                }
                final phone = value.replaceAll(' ', '');
                if (phone.length < 8) {
                  return 'Numéro invalide';
                }
                return null;
              },
            ),

            const SizedBox(height: SicTheme.spaceXl),

            // Info
            SicCard(
              backgroundColor:
                  Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.info_outline,
                        size: 20,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Information',
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '• Maximum 5 puces par compte\n• Le solde initial est 0 FCFA\n• Vous pouvez ajouter du crédit plus tard',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),

            const SizedBox(height: SicTheme.spaceXl),

            // Submit
            ElevatedButton(
              onPressed: _isLoading ? null : _submitPuce,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: _isLoading
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : const Text('Ajouter la Puce'),
            ),
          ],
        ),
      ),
    );
  }
}