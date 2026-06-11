import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/usecases/usecase.dart';
import '../../data/datasources/alert_local_datasource.dart';
import '../../data/repositories/alert_repository_impl.dart';
import '../../domain/entities/alert_config.dart';
import '../../domain/repositories/alert_repository.dart';
import '../../domain/usecases/get_alert_configs.dart';
import '../../domain/usecases/save_alert_config.dart';

final alertLocalDatasourceProvider = Provider<AlertLocalDatasource>(
  (ref) => const AlertLocalDatasource(),
);

final alertRepositoryProvider = Provider<AlertRepository>((ref) {
  return AlertRepositoryImpl(ref.watch(alertLocalDatasourceProvider));
});

final getAlertConfigsProvider = Provider<GetAlertConfigs>((ref) {
  return GetAlertConfigs(ref.watch(alertRepositoryProvider));
});

final saveAlertConfigProvider = Provider<SaveAlertConfig>((ref) {
  return SaveAlertConfig(ref.watch(alertRepositoryProvider));
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
    final usecase = ref.read(saveAlertConfigProvider);
    final result = await usecase(config);

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
        if (config.operatorCode == updatedConfig.operatorCode)
          updatedConfig
        else
          config,
    ]);
  }
}
