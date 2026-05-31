import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:sic_mobile/config/theme.dart';
import 'package:sic_mobile/core/utils/formatters.dart';
import 'package:sic_mobile/data/repositories/sic_repository.dart';
import 'package:sic_mobile/data/models/agent.dart';
import 'package:sic_mobile/data/models/transaction.dart';
import 'package:sic_mobile/shared/widgets/sic_widgets.dart';

/// Deposit Screen
class DepositScreen extends ConsumerStatefulWidget {
  const DepositScreen({super.key});

  @override
  ConsumerState<DepositScreen> createState() => _DepositScreenState();
}

class _DepositScreenState extends ConsumerState<DepositScreen> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
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
    _amountController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _submitDeposit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    final amount = double.tryParse(_amountController.text.replaceAll(' ', '')) ?? 0;
    final repo = SicRepository();

    final result = await repo.deposit(
      amount: amount,
      targetOperator: _selectedOperator,
      targetPhoneNumber: _phoneController.text.replaceAll(' ', ''),
    );

    if (!mounted) return;
    setState(() => _isLoading = false);

    if (result.isSuccess) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Dépôt de ${Formatters.currency(amount)} réussi !'),
          backgroundColor: Colors.green,
        ),
      );
      context.go('/home');
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result.error ?? 'Erreur lors du dépôt'),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Faire un Dépôt'),
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
            // Amount
            Text(
              'Montant',
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
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Veuillez entrer un montant';
                }
                final amount = double.tryParse(value);
                if (amount == null || amount < 100) {
                  return 'Montant minimum: 100 FCFA';
                }
                if (amount > 5000000) {
                  return 'Montant maximum: 5 000 000 FCFA';
                }
                return null;
              },
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
                  avatar: isSelected
                      ? const Icon(Icons.check, size: 18)
                      : null,
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
              decoration: InputDecoration(
                hintText: '621 23 45 67',
                prefixIcon: const Icon(Icons.phone_android),
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

            // Commission info
            SicCard(
              backgroundColor: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
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
                        'Informations',
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '• Frais SIC: 1%\n• Votre commission: 0.5%\n• Minimum: 100 FCFA\n• Maximum: 5 000 000 FCFA',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),

            const SizedBox(height: SicTheme.spaceXl),

            // Submit
            ElevatedButton(
              onPressed: _isLoading ? null : _submitDeposit,
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
                  : const Text('Effectuer le Dépôt'),
            ),
          ],
        ),
      ),
    );
  }
}

/// Withdraw Screen
class WithdrawScreen extends ConsumerStatefulWidget {
  const WithdrawScreen({super.key});

  @override
  ConsumerState<WithdrawScreen> createState() => _WithdrawScreenState();
}

class _WithdrawScreenState extends ConsumerState<WithdrawScreen> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
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
    _amountController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _submitWithdraw() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    final amount = double.tryParse(_amountController.text.replaceAll(' ', '')) ?? 0;
    final repo = SicRepository();

    final result = await repo.withdraw(
      amount: amount,
      targetOperator: _selectedOperator,
      targetPhoneNumber: _phoneController.text.replaceAll(' ', ''),
    );

    if (!mounted) return;
    setState(() => _isLoading = false);

    if (result.isSuccess) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Retrait de ${Formatters.currency(amount)} réussi !'),
          backgroundColor: Colors.green,
        ),
      );
      context.go('/home');
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result.error ?? 'Erreur lors du retrait'),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Faire un Retrait'),
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
            // Amount
            Text(
              'Montant',
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
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Veuillez entrer un montant';
                }
                final amount = double.tryParse(value);
                if (amount == null || amount < 100) {
                  return 'Montant minimum: 100 FCFA';
                }
                return null;
              },
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
                  avatar: isSelected
                      ? const Icon(Icons.check, size: 18)
                      : null,
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
              decoration: InputDecoration(
                hintText: '621 23 45 67',
                prefixIcon: const Icon(Icons.phone_android),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Veuillez entrer le numéro';
                }
                return null;
              },
            ),

            const SizedBox(height: SicTheme.spaceXl),

            // Info
            SicCard(
              backgroundColor: Colors.orange.withValues(alpha: 0.1),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.info_outline, size: 20, color: Colors.orange),
                      const SizedBox(width: 8),
                      Text(
                        'Retrait',
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '• Commission: 1.5%\n• Votre bénéfice: 0.5%\n• Minimum: 100 FCFA',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),

            const SizedBox(height: SicTheme.spaceXl),

            // Submit
            ElevatedButton(
              onPressed: _isLoading ? null : _submitWithdraw,
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
                  : const Text('Effectuer le Retrait'),
            ),
          ],
        ),
      ),
    );
  }
}

/// Transaction History Screen
class TransactionHistoryScreen extends ConsumerStatefulWidget {
  const TransactionHistoryScreen({super.key});

  @override
  ConsumerState<TransactionHistoryScreen> createState() =>
      _TransactionHistoryScreenState();
}

class _TransactionHistoryScreenState
    extends ConsumerState<TransactionHistoryScreen> {
  List<Transaction> _transactions = [];
  bool _isLoading = true;
  String _filterType = 'ALL';

  @override
  void initState() {
    super.initState();
    _loadTransactions();
  }

  Future<void> _loadTransactions() async {
    setState(() => _isLoading = true);
    final repo = SicRepository();
    final transactions = await repo.getTransactions();
    if (!mounted) return;
    setState(() {
      _transactions = transactions;
      _isLoading = false;
    });
  }

  List<Transaction> get _filteredTransactions {
    if (_filterType == 'ALL') return _transactions;
    return _transactions
        .where((tx) => tx.type.toUpperCase() == _filterType)
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Transactions'),
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_list),
            onPressed: () {
              // Show filter dialog
              showModalBottomSheet(
                context: context,
                builder: (context) => Container(
                  padding: const EdgeInsets.all(SicTheme.spaceMd),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ListTile(
                        leading: const Icon(Icons.all_inclusive),
                        title: const Text('Toutes'),
                        selected: _filterType == 'ALL',
                        onTap: () {
                          setState(() => _filterType = 'ALL');
                          Navigator.pop(context);
                        },
                      ),
                      ListTile(
                        leading: const Icon(Icons.arrow_downward),
                        title: const Text('Dépôts'),
                        selected: _filterType == 'DEPOT',
                        onTap: () {
                          setState(() => _filterType = 'DEPOT');
                          Navigator.pop(context);
                        },
                      ),
                      ListTile(
                        leading: const Icon(Icons.arrow_upward),
                        title: const Text('Retraits'),
                        selected: _filterType == 'RETRAIT',
                        onTap: () {
                          setState(() => _filterType = 'RETRAIT');
                          Navigator.pop(context);
                        },
                      ),
                      ListTile(
                        leading: const Icon(Icons.swap_horiz),
                        title: const Text('Conversions'),
                        selected: _filterType == 'SWAP',
                        onTap: () {
                          setState(() => _filterType = 'SWAP');
                          Navigator.pop(context);
                        },
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadTransactions,
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _filteredTransactions.isEmpty
                ? SicEmptyState(
                    icon: Icons.receipt_long,
                    title: 'Aucune transaction',
                    subtitle: 'Vos transactions apparaîtront ici',
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(SicTheme.spaceMd),
                    itemCount: _filteredTransactions.length,
                    itemBuilder: (context, index) {
                      final tx = _filteredTransactions[index];
                      return TransactionTile(
                        transaction: tx,
                        onTap: () => context.push('/transactions/${tx.id}'),
                      );
                    },
                  ),
      ),
    );
  }
}

/// Transaction Detail Screen
class TransactionDetailScreen extends ConsumerWidget {
  final String transactionId;

  const TransactionDetailScreen({super.key, required this.transactionId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Détails'),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.receipt, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            Text(
              'Transaction',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            Text(transactionId),
          ],
        ),
      ),
    );
  }
}