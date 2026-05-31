import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:sic_mobile/config/theme.dart';
import 'package:sic_mobile/core/utils/formatters.dart';
import 'package:sic_mobile/core/utils/validators.dart';
import 'package:sic_mobile/data/repositories/sic_repository.dart';
import 'package:sic_mobile/data/models/agent.dart';
import 'package:sic_mobile/shared/widgets/cards.dart';

/// Home Screen - Main dashboard for agents
class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  bool _isLoading = true;
  Agent? _agent;
  List<Puce> _puces = [];
  List<Transaction> _recentTransactions = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final repo = SicRepository();

    // Load in parallel
    final results = await Future.wait([
      repo.getProfile(),
      repo.getPuces(),
      repo.getTransactions(),
    ]);

    if (!mounted) return;

    setState(() {
      _agent = results[0] as Agent?;
      _puces = (results[1] as List<dynamic>).cast<Puce>();
      _recentTransactions = (results[2] as List<dynamic>)
          .cast<Transaction>()
          .take(5)
          .toList();
      _isLoading = false;
    });
  }

  double get _totalBalance {
    return _puces.fold(0.0, (sum, puce) => sum + puce.balance);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: RefreshIndicator(
        onRefresh: () async {
          await _loadData();
        },
        child: CustomScrollView(
          slivers: [
            // App Bar
            SliverAppBar(
              expandedHeight: 120,
              floating: false,
              pinned: true,
              flexibleSpace: FlexibleSpaceBar(
                background: Container(
                  decoration: BoxDecoration(
                    gradient: SicTheme.primaryGradient,
                  ),
                ),
                title: Text(
                  'Bonjour, ${_agent?.firstName ?? 'Agent'}',
                  style: const TextStyle(color: Colors.white),
                ),
              ),
              actions: [
                IconButton(
                  icon: const Icon(Icons.notifications_outlined),
                  onPressed: () => context.push('/notifications'),
                  color: Colors.white,
                ),
                IconButton(
                  icon: const Icon(Icons.person_outline),
                  onPressed: () => context.go('/profile'),
                  color: Colors.white,
                ),
              ],
            ),

            // Content
            SliverPadding(
              padding: const EdgeInsets.all(SicTheme.spaceMd),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  // Balance Card
                  BalanceCard(
                    totalBalance: _totalBalance,
                    agent: _agent,
                    isLoading: _isLoading,
                  ),

                  const SizedBox(height: SicTheme.spaceLg),

                  // Quick Actions
                  Row(
                    children: [
                      Expanded(
                        child: QuickActionButton(
                          icon: Icons.arrow_downward,
                          label: 'Dépôt',
                          color: Colors.green,
                          onTap: () => context.push('/transactions/deposit'),
                        ),
                      ),
                      const SizedBox(width: SicTheme.spaceSm),
                      Expanded(
                        child: QuickActionButton(
                          icon: Icons.arrow_upward,
                          label: 'Retrait',
                          color: Colors.orange,
                          onTap: () => context.push('/transactions/withdraw'),
                        ),
                      ),
                      const SizedBox(width: SicTheme.spaceSm),
                      Expanded(
                        child: QuickActionButton(
                          icon: Icons.swap_horiz,
                          label: 'Conversion',
                          color: Colors.blue,
                          onTap: () {
                            // TODO: Navigate to conversion
                          },
                        ),
                      ),
                      const SizedBox(width: SicTheme.spaceSm),
                      Expanded(
                        child: QuickActionButton(
                          icon: Icons.history,
                          label: 'Historique',
                          color: Colors.purple,
                          onTap: () => context.go('/transactions'),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: SicTheme.spaceLg),

                  // Puces Section
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Mes Puces',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                      TextButton.icon(
                        onPressed: () => context.go('/puces'),
                        icon: const Icon(Icons.arrow_forward, size: 16),
                        label: const Text('Tout voir'),
                      ),
                    ],
                  ),

                  if (_isLoading)
                    const Center(
                      child: Padding(
                        padding: EdgeInsets.all(SicTheme.spaceLg),
                        child: CircularProgressIndicator(),
                      ),
                    )
                  else if (_puces.isEmpty)
                    SicEmptyState(
                      icon: Icons.sim_card,
                      title: 'Aucune puce',
                      subtitle: 'Ajoutez une puce pour commencer',
                      action: ElevatedButton.icon(
                        onPressed: () => context.push('/puces/add'),
                        icon: const Icon(Icons.add),
                        label: const Text('Ajouter une puce'),
                      ),
                    )
                  else
                    ..._puces.map(
                      (puce) => PuceCard(
                        puce: puce,
                        onTap: () => context.go('/puces'),
                      ),
                    ),

                  const SizedBox(height: SicTheme.spaceLg),

                  // Recent Transactions
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Transactions Récentes',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                      TextButton.icon(
                        onPressed: () => context.go('/transactions'),
                        icon: const Icon(Icons.arrow_forward, size: 16),
                        label: const Text('Tout voir'),
                      ),
                    ],
                  ),

                  if (_recentTransactions.isEmpty)
                    SicEmptyState(
                      icon: Icons.receipt_long,
                      title: 'Aucune transaction',
                      subtitle: 'Vos transactions apparaîtront ici',
                    )
                  else
                    ..._recentTransactions.map(
                      (tx) => TransactionTile(
                        transaction: tx,
                        onTap: () => context.go('/transactions/${tx.id}'),
                      ),
                    ),

                  const SizedBox(height: SicTheme.spaceXl),
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }
}