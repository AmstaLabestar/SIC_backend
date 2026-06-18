import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/network_providers.dart';
import '../../../../core/usecases/usecase.dart';
import '../../data/datasources/alert_remote_datasource.dart';
import '../../data/repositories/alert_repository_impl.dart';
import '../../domain/entities/alert_config.dart';
import '../../domain/repositories/alert_repository.dart';
import '../../domain/usecases/get_alert_configs.dart';
import '../../domain/usecases/update_alert_config.dart';

final alertRemoteDatasourceProvider = Provider<AlertRemoteDatasource>(
  (ref) => AlertRemoteDatasource(ref.watch(dioProvider)),
);

/// Point de bascule unique de la feature : changer la source des alertes
/// (remote, cache local, mock de test) se fait ici seul.
final alertRepositoryProvider = Provider<AlertRepository>((ref) {
  return AlertRepositoryImpl(ref.watch(alertRemoteDatasourceProvider));
});

final getAlertConfigsProvider = Provider<GetAlertConfigs>((ref) {
  return GetAlertConfigs(ref.watch(alertRepositoryProvider));
});

final updateAlertConfigProvider = Provider<UpdateAlertConfig>((ref) {
  return UpdateAlertConfig(ref.watch(alertRepositoryProvider));
});

final alertNotifierProvider =
    AsyncNotifierProvider<AlertNotifier, List<AlertConfig>>(
  AlertNotifier.new,
);

class AlertNotifier extends AsyncNotifier<List<AlertConfig>> {
  @override
  Future<List<AlertConfig>> build() {
    return _loadConfigs();
  }

  Future<void> refresh() async {
    state = const AsyncLoading<List<AlertConfig>>();
    state = await AsyncValue.guard(_loadConfigs);
  }

  Future<void> save(AlertConfig config) async {
    final usecase = ref.read(updateAlertConfigProvider);
    final result = await usecase(
      UpdateAlertConfigParams(
        id: config.id,
        threshold: config.threshold,
        isEnabled: config.isEnabled,
      ),
    );

    result.fold(
      (failure) => state = AsyncError<List<AlertConfig>>(
        failure,
        StackTrace.current,
      ),
      _replaceConfig,
    );
  }

  Future<List<AlertConfig>> _loadConfigs() async {
    final usecase = ref.read(getAlertConfigsProvider);
    final result = await usecase(const NoParams());

    return result.fold((failure) => throw failure, (configs) => configs);
  }

  void _replaceConfig(AlertConfig updatedConfig) {
    final currentConfigs = state.valueOrNull ?? [];
    state = AsyncData([
      for (final config in currentConfigs)
        if (config.id == updatedConfig.id) updatedConfig else config,
    ]);
  }
}
