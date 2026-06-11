import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/usecases/usecase.dart';
import '../../data/datasources/sim_local_datasource.dart';
import '../../data/repositories/sim_repository_impl.dart';
import '../../domain/entities/sim_card.dart';
import '../../domain/repositories/sim_repository.dart';
import '../../domain/usecases/add_sim.dart';
import '../../domain/usecases/get_sims.dart';
import '../../domain/usecases/toggle_sim.dart';
import '../../domain/usecases/update_sim_threshold.dart';

final simLocalDatasourceProvider = Provider<SimLocalDatasource>(
  (ref) => SimLocalDatasource(),
);

final simRepositoryProvider = Provider<SimRepository>((ref) {
  return SimRepositoryImpl(ref.watch(simLocalDatasourceProvider));
});

final getSimsProvider = Provider<GetSims>((ref) {
  return GetSims(ref.watch(simRepositoryProvider));
});

final addSimProvider = Provider<AddSim>((ref) {
  return AddSim(ref.watch(simRepositoryProvider));
});

final toggleSimProvider = Provider<ToggleSim>((ref) {
  return ToggleSim(ref.watch(simRepositoryProvider));
});

final updateSimThresholdProvider = Provider<UpdateSimThreshold>((ref) {
  return UpdateSimThreshold(ref.watch(simRepositoryProvider));
});

final availableOperatorsProvider = Provider<Map<String, String>>((ref) {
  return SimLocalDatasource.availableOperators;
});

final simNotifierProvider = AsyncNotifierProvider<SimNotifier, List<SimCard>>(
  SimNotifier.new,
);

class SimNotifier extends AsyncNotifier<List<SimCard>> {
  @override
  Future<List<SimCard>> build() {
    return _loadSims();
  }

  Future<void> refresh() async {
    state = const AsyncLoading<List<SimCard>>();
    state = await AsyncValue.guard(_loadSims);
  }

  Future<void> addSim({
    required String operatorCode,
    required String phoneNumber,
  }) async {
    final usecase = ref.read(addSimProvider);
    final result = await usecase(
      AddSimParams(operatorCode: operatorCode, phoneNumber: phoneNumber),
    );

    result.fold(
      (failure) => state = AsyncError<List<SimCard>>(
        failure,
        StackTrace.current,
      ),
      (sim) {
        final currentSims = state.valueOrNull ?? [];
        state = AsyncData([...currentSims, sim]);
      },
    );
  }

  Future<void> toggleSim({
    required String id,
    required bool isActive,
  }) async {
    final usecase = ref.read(toggleSimProvider);
    final result = await usecase(ToggleSimParams(id: id, isActive: isActive));

    result.fold(
      (failure) => state = AsyncError<List<SimCard>>(
        failure,
        StackTrace.current,
      ),
      _replaceSim,
    );
  }

  Future<void> updateThreshold({
    required String id,
    required double threshold,
  }) async {
    final usecase = ref.read(updateSimThresholdProvider);
    final result = await usecase(
      UpdateSimThresholdParams(id: id, threshold: threshold),
    );

    result.fold(
      (failure) => state = AsyncError<List<SimCard>>(
        failure,
        StackTrace.current,
      ),
      _replaceSim,
    );
  }

  Future<List<SimCard>> _loadSims() async {
    final usecase = ref.read(getSimsProvider);
    final result = await usecase(const NoParams());

    return result.fold((failure) => throw failure, (sims) => sims);
  }

  void _replaceSim(SimCard updatedSim) {
    final currentSims = state.valueOrNull ?? [];
    state = AsyncData([
      for (final sim in currentSims)
        if (sim.id == updatedSim.id) updatedSim else sim,
    ]);
  }
}
