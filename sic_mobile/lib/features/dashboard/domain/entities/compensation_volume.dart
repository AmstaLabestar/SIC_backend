import 'package:equatable/equatable.dart';

/// Volume d'operations rendues possibles par la compensation inter-reseaux
/// (lot C4), agrege par periode. C'est le "business sauve" par SIC quand une
/// puce etait a sec — une mesure d'activite, pas une marge de l'agent.
class CompensationVolume extends Equatable {
  const CompensationVolume({
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
