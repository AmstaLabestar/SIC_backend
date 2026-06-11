import 'package:equatable/equatable.dart';

import 'balance_summary.dart';
import 'benefit_period.dart';
import 'promo_banner.dart';

class AgentSummary extends Equatable {
  const AgentSummary({
    required this.agentCode,
    required this.agentName,
    required this.totalBalance,
    required this.benefits,
    required this.balances,
    required this.transactionCountToday,
    this.hasUnreadNotifications = false,
    this.banners = const [],
  });

  final String agentCode;
  final String agentName;
  final double totalBalance;
  final BenefitPeriod benefits;
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
    BenefitPeriod? benefits,
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
      benefits: benefits ?? this.benefits,
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
        benefits,
        balances,
        transactionCountToday,
        hasUnreadNotifications,
        banners,
      ];
}
