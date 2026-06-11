import '../../domain/entities/benefit_period.dart';

class BenefitPeriodModel extends BenefitPeriod {
  const BenefitPeriodModel({
    required super.today,
    required super.week,
    required super.month,
    required super.total,
  });

  factory BenefitPeriodModel.fromJson(Map<String, dynamic> json) {
    return BenefitPeriodModel(
      today: (json['today'] as num).toDouble(),
      week: (json['week'] as num).toDouble(),
      month: (json['month'] as num).toDouble(),
      total: (json['total'] as num).toDouble(),
    );
  }

  factory BenefitPeriodModel.mock() {
    return const BenefitPeriodModel(
      today: 12500,
      week: 87300,
      month: 312000,
      total: 1250000,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'today': today,
      'week': week,
      'month': month,
      'total': total,
    };
  }
}
