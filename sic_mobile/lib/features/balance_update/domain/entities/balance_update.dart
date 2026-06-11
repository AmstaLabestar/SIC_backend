import 'package:equatable/equatable.dart';

class BalanceUpdate extends Equatable {
  const BalanceUpdate({
    required this.operatorCode,
    required this.previousBalance,
    required this.newBalance,
    required this.updatedAt,
  });

  final String operatorCode;
  final double previousBalance;
  final double newBalance;
  final DateTime updatedAt;

  @override
  List<Object?> get props => [
        operatorCode,
        previousBalance,
        newBalance,
        updatedAt,
      ];
}
