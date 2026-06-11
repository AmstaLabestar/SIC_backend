import 'package:equatable/equatable.dart';

class BenefitPeriod extends Equatable {
  const BenefitPeriod({
    required this.today,
    required this.week,
    required this.month,
    required this.total,
  });

  final double today;
  final double week;
  final double month;
  final double total;

  @override
  List<Object?> get props => [today, week, month, total];
}
