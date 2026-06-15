import '../../domain/entities/compensation_volume.dart';

class CompensationVolumeModel extends CompensationVolume {
  const CompensationVolumeModel({
    required super.today,
    required super.week,
    required super.month,
    required super.total,
  });

  factory CompensationVolumeModel.fromJson(Map<String, dynamic> json) {
    return CompensationVolumeModel(
      today: (json['today'] as num).toDouble(),
      week: (json['week'] as num).toDouble(),
      month: (json['month'] as num).toDouble(),
      total: (json['total'] as num).toDouble(),
    );
  }

  factory CompensationVolumeModel.mock() {
    return const CompensationVolumeModel(
      today: 120000,
      week: 540000,
      month: 1850000,
      total: 4200000,
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
