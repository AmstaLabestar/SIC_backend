import 'package:equatable/equatable.dart';

import 'balance_summary.dart';
import 'compensation_volume.dart';
import 'promo_banner.dart';

class AgentSummary extends Equatable {
  const AgentSummary({
    required this.agentCode,
    required this.agentName,
    required this.totalBalance,
    required this.compensation,
    required this.balances,
    required this.transactionCountToday,
    this.hasUnreadNotifications = false,
    this.banners = const [],
  });

  final String agentCode;
  final String agentName;
  final double totalBalance;
  final CompensationVolume compensation;
  final List<BalanceSummary> balances;
  final int transactionCountToday;
  final bool hasUnreadNotifications;
  final List<PromoBanner> banners;

  int get activeSimCount => balances.length;

  /// Initiales de l'agent (prenom + nom), ex: 'Kone Moussa' -> 'KM'.
  String get agentInitials => agentName
      .split(' ')
      .where((part) => part.isNotEmpty)
      .take(2)
      .map((part) => part[0])
      .join()
      .toUpperCase();

  bool get hasLowBalance {
    return balances.any((balance) => balance.isLow || balance.isEmpty);
  }

  AgentSummary copyWith({
    String? agentCode,
    String? agentName,
    double? totalBalance,
    CompensationVolume? compensation,
    List<BalanceSummary>? balances,
    int? transactionCountToday,
    bool? hasUnreadNotifications,
    List<PromoBanner>? banners,
  }) {
    final nextBalances = balances ?? this.balances;

    return AgentSummary(
      agentCode: agentCode ?? this.agentCode,
      agentName: agentName ?? this.agentName,
      totalBalance: totalBalance ??
          nextBalances.fold<double>(
            0,
            (total, balance) => total + balance.balance,
          ),
      compensation: compensation ?? this.compensation,
      balances: nextBalances,
      transactionCountToday:
          transactionCountToday ?? this.transactionCountToday,
      hasUnreadNotifications:
          hasUnreadNotifications ?? this.hasUnreadNotifications,
      banners: banners ?? this.banners,
    );
  }

  @override
  List<Object?> get props => [
        agentCode,
        agentName,
        totalBalance,
        compensation,
        balances,
        transactionCountToday,
        hasUnreadNotifications,
        banners,
      ];
}
