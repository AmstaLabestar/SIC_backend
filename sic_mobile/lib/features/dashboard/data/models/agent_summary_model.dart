import '../../domain/entities/agent_summary.dart';
import 'balance_summary_model.dart';
import 'compensation_volume_model.dart';
import 'promo_banner_model.dart';

class AgentSummaryModel extends AgentSummary {
  const AgentSummaryModel({
    required super.agentCode,
    required super.agentName,
    required super.totalBalance,
    required super.compensation,
    required super.balances,
    required super.transactionCountToday,
    super.hasUnreadNotifications,
    super.banners,
  });

  factory AgentSummaryModel.fromJson(Map<String, dynamic> json) {
    final balancesJson = json['balances'] as List<dynamic>;
    final bannersJson = json['banners'] as List<dynamic>? ?? const [];

    return AgentSummaryModel(
      agentCode: json['agent_code'] as String,
      agentName: json['agent_name'] as String,
      totalBalance: (json['total_balance'] as num).toDouble(),
      compensation: CompensationVolumeModel.fromJson(
        json['compensation'] as Map<String, dynamic>,
      ),
      balances: balancesJson
          .map(
            (balance) => BalanceSummaryModel.fromJson(
              balance as Map<String, dynamic>,
            ),
          )
          .toList(),
      transactionCountToday: json['transaction_count_today'] as int,
      hasUnreadNotifications:
          json['has_unread_notifications'] as bool? ?? false,
      banners: bannersJson
          .map(
            (banner) =>
                PromoBannerModel.fromJson(banner as Map<String, dynamic>),
          )
          .toList(),
    );
  }

  factory AgentSummaryModel.mock() {
    final balances = [
      BalanceSummaryModel.mock('OM'),
      BalanceSummaryModel.mock('MOOV'),
      BalanceSummaryModel.mock('TELECEL'),
    ];
    final totalBalance = balances.fold<double>(
      0,
      (total, balance) => total + balance.balance,
    );

    return AgentSummaryModel(
      agentCode: 'AGT-0042',
      agentName: 'Kone Moussa',
      totalBalance: totalBalance,
      compensation: CompensationVolumeModel.mock(),
      balances: balances,
      transactionCountToday: 8,
      hasUnreadNotifications: true,
      banners: [PromoBannerModel.mock()],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'agent_code': agentCode,
      'agent_name': agentName,
      'total_balance': totalBalance,
      'compensation': (compensation as CompensationVolumeModel).toJson(),
      'balances': balances
          .map((balance) => (balance as BalanceSummaryModel).toJson())
          .toList(),
      'transaction_count_today': transactionCountToday,
      'has_unread_notifications': hasUnreadNotifications,
      'banners': banners
          .map((banner) => (banner as PromoBannerModel).toJson())
          .toList(),
    };
  }
}
