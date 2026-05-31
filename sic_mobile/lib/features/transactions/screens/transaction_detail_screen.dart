import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:sic_mobile/config/theme.dart';
import 'package:sic_mobile/core/utils/formatters.dart';
import 'package:sic_mobile/data/repositories/sic_repository.dart';
import 'package:sic_mobile/data/models/transaction.dart';
import 'package:sic_mobile/shared/widgets/sic_widgets.dart';
import 'package:sic_mobile/shared/widgets/splash_screen.dart';

/// Transaction Detail Screen - Complete implementation
class TransactionDetailScreen extends ConsumerStatefulWidget {
  final String id;

  const TransactionDetailScreen({super.key, required this.id});

  @override
  ConsumerState<TransactionDetailScreen> createState() =>
      _TransactionDetailScreenState();
}

class _TransactionDetailScreenState
    extends ConsumerState<TransactionDetailScreen> {
  Transaction? _transaction;
  bool _isLoading = true;
  bool _showSuccess = false;

  @override
  void initState() {
    super.initState();
    _loadTransaction();
  }

  Future<void> _loadTransaction() async {
    final repo = SicRepository();
    final transaction = await repo.getTransaction(widget.id);
    if (!mounted) return;
    setState(() {
      _transaction = transaction;
      _isLoading = false;
    });
  }

  Color _getStatusColor() {
    return Color(Formatters.statusColor(_transaction?.status ?? ''));
  }

  IconData _getTypeIcon() {
    switch (_transaction?.type.toUpperCase()) {
      case 'DEPOT':
        return Icons.arrow_downward;
      case 'RETRAIT':
        return Icons.arrow_upward;
      case 'SWAP':
        return Icons.swap_horiz;
      default:
        return Icons.receipt;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Détails de la transaction'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.share),
            onPressed: () {
              // TODO: Share transaction
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Fonctionnalité à venir')),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.print),
            onPressed: () {
              // TODO: Print receipt
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Fonctionnalité à venir')),
              );
            },
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _transaction == null
              ? SicErrorState(
                  message: 'Transaction introuvable',
                  onRetry: _loadTransaction,
                )
              : Stack(
                  children: [
                    SingleChildScrollView(
                      padding: const EdgeInsets.all(SicTheme.spaceMd),
                      child: Column(
                        children: [
                          // Status Card
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(SicTheme.spaceLg),
                            decoration: BoxDecoration(
                              color: _getStatusColor().withValues(alpha: 0.1),
                              borderRadius:
                                  BorderRadius.circular(SicTheme.radiusLg),
                              border: Border.all(
                                color: _getStatusColor().withValues(alpha: 0.3),
                              ),
                            ),
                            child: Column(
                              children: [
                                Container(
                                  width: 72,
                                  height: 72,
                                  decoration: BoxDecoration(
                                    color:
                                        _getStatusColor().withValues(alpha: 0.2),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    _getTypeIcon(),
                                    size: 36,
                                    color: _getStatusColor(),
                                  ),
                                ),
                                const SizedBox(height: SicTheme.spaceMd),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    color: _getStatusColor().withValues(alpha: 0.2),
                                    borderRadius:
                                        BorderRadius.circular(SicTheme.radiusSm),
                                  ),
                                  child: Text(
                                    _transaction!.statusLabel,
                                    style: TextStyle(
                                      color: _getStatusColor(),
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: SicTheme.spaceMd),
                                Text(
                                  '${_transaction!.isDeposit ? '+' : '-'}${Formatters.currency(_transaction!.amount)}',
                                  style: Theme.of(context)
                                      .textTheme
                                      .displaySmall
                                      ?.copyWith(
                                        fontWeight: FontWeight.bold,
                                        color: _transaction!.isDeposit
                                            ? Colors.green
                                            : Theme.of(context)
                                                .colorScheme
                                                .primary,
                                      ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  _transaction!.typeLabel,
                                  style: Theme.of(context)
                                      .textTheme
                                      .titleMedium
                                      ?.copyWith(
                                        color: Theme.of(context)
                                            .colorScheme
                                            .onSurface
                                            .withValues(alpha: 0.7),
                                      ),
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: SicTheme.spaceLg),

                          // Transaction Info
                          SicCard(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Informations',
                                  style: Theme.of(context)
                                      .textTheme
                                      .titleSmall
                                      ?.copyWith(fontWeight: FontWeight.bold),
                                ),
                                const Divider(),
                                _buildInfoRow(
                                  'Référence',
                                  widget.id,
                                  Icons.tag,
                                ),
                                _buildInfoRow(
                                  'Date',
                                  Formatters.dateTime(_transaction!.createdAt),
                                  Icons.calendar_today,
                                ),
                                _buildInfoRow(
                                  'Opérateur',
                                  Formatters.operatorLabel(
                                      _transaction!.targetOperator),
                                  Icons.signal_cellular_alt,
                                ),
                                if (_transaction!.targetPhoneNumber != null)
                                  _buildInfoRow(
                                    'Téléphone',
                                    Formatters.phoneNumber(
                                        _transaction!.targetPhoneNumber!),
                                    Icons.phone,
                                  ),
                                _buildInfoRow(
                                  'Statut',
                                  _transaction!.statusLabel,
                                  Icons.info_outline,
                                  valueColor: _getStatusColor(),
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: SicTheme.spaceMd),

                          // Commission Info
                          if (_transaction!.commissionSic > 0 ||
                              _transaction!.agentBenefit > 0)
                            SicCard(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Commissions',
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleSmall
                                        ?.copyWith(fontWeight: FontWeight.bold),
                                  ),
                                  const Divider(),
                                  if (_transaction!.commissionSic > 0)
                                    _buildInfoRow(
                                      'Commission SIC',
                                      Formatters.currency(
                                          _transaction!.commissionSic),
                                      Icons.account_balance,
                                    ),
                                  if (_transaction!.agentBenefit > 0)
                                    _buildInfoRow(
                                      'Votre bénéfice',
                                      Formatters.currency(
                                          _transaction!.agentBenefit),
                                      Icons.monetization_on,
                                      valueColor: Colors.green,
                                    ),
                                ],
                              ),
                            ),

                          const SizedBox(height: SicTheme.spaceLg),

                          // Actions
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: () {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                          content: Text('Fonctionnalité à venir')),
                                    );
                                  },
                                  icon: const Icon(Icons.help_outline),
                                  label: const Text('Signaler un problème'),
                                ),
                              ),
                              const SizedBox(width: SicTheme.spaceSm),
                              Expanded(
                                child: ElevatedButton.icon(
                                  onPressed: () {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                          content: Text('Reçu envoyé !')),
                                    );
                                  },
                                  icon: const Icon(Icons.send),
                                  label: const Text('Réessayer'),
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: SicTheme.spaceXl),
                        ],
                      ),
                    ),

                    // Success animation overlay
                    if (_showSuccess)
                      Container(
                        color: Colors.black.withValues(alpha: 0.7),
                        child: SuccessAnimation(
                          onComplete: () {
                            setState(() => _showSuccess = false);
                            context.go('/home');
                          },
                        ),
                      ),
                  ],
                ),
    );
  }

  Widget _buildInfoRow(
    String label,
    String value,
    IconData icon, {
    Color? valueColor,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: SicTheme.spaceSm),
      child: Row(
        children: [
          Icon(
            icon,
            size: 20,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(width: SicTheme.spaceMd),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context)
                            .colorScheme
                            .onSurface
                            .withValues(alpha: 0.6),
                      ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: valueColor,
                      ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}