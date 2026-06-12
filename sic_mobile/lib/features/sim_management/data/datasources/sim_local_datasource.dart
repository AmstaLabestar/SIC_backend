import '../../../../core/errors/exceptions.dart';
import '../models/sim_card_model.dart';

class SimLocalDatasource {
  SimLocalDatasource();

  static final List<SimCardModel> _sims = [
    SimCardModel(
      id: 'sim_001',
      operatorCode: 'OM',
      operatorName: 'Orange Money',
      phoneNumber: '0701234567',
      balance: 250000,
      isActive: true,
      alertThreshold: 50000,
      addedAt: DateTime(2024, 1, 10),
    ),
    SimCardModel(
      id: 'sim_002',
      operatorCode: 'MOOV',
      operatorName: 'Moov Money',
      phoneNumber: '0509876543',
      balance: 85000,
      isActive: true,
      alertThreshold: 50000,
      addedAt: DateTime(2024, 1, 11),
    ),
    SimCardModel(
      id: 'sim_003',
      operatorCode: 'TELECEL',
      operatorName: 'Telecel Money',
      phoneNumber: '0104567890',
      balance: 150000,
      isActive: true,
      alertThreshold: 50000,
      addedAt: DateTime(2024, 1, 12),
    ),
  ];

  /// Operateurs acceptes par le backend (`TransactionValidator.VALID_OPERATORS`
  /// = ORANGE, MOOV, TELECEL, MTN). Le code mobile `OM` est traduit en
  /// `ORANGE` via [OperatorMapping].
  /// Burkina Faso : Orange, Moov, Telecel. Cote d'Ivoire : Orange, MTN, Moov.
  static const Map<String, String> availableOperators = {
    'OM': 'Orange Money',
    'MOOV': 'Moov Money',
    'TELECEL': 'Telecel Money',
    'MTN': 'MTN Money',
  };

  Future<List<SimCardModel>> getSims() async {
    await Future<void>.delayed(const Duration(milliseconds: 500));
    return List<SimCardModel>.unmodifiable(_sims);
  }

  Future<SimCardModel> addSim({
    required String operatorCode,
    required String phoneNumber,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 450));

    if (_sims.any((sim) => sim.phoneNumber == phoneNumber)) {
      throw const ServerException('Ce numero est deja enregistre.', 400);
    }

    if (_sims.length >= 5) {
      throw const ServerException('Maximum 5 puces par agent.', 400);
    }

    final normalizedOperatorCode = operatorCode.toUpperCase();
    final operatorName = availableOperators[normalizedOperatorCode];
    if (operatorName == null) {
      throw const ServerException('Operateur non pris en charge.', 400);
    }

    final sim = SimCardModel(
      id: 'sim_${DateTime.now().millisecondsSinceEpoch}',
      operatorCode: normalizedOperatorCode,
      operatorName: operatorName,
      phoneNumber: phoneNumber,
      balance: 0,
      isActive: true,
      alertThreshold: 50000,
      addedAt: DateTime.now(),
    );

    _sims.add(sim);
    return sim;
  }

  Future<SimCardModel> toggleSim({
    required String id,
    required bool isActive,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 350));
    final index = _indexOf(id);
    final updatedSim = _sims[index].copyModelWith(isActive: isActive);
    _sims[index] = updatedSim;
    return updatedSim;
  }

  Future<SimCardModel> updateSimThreshold({
    required String id,
    required double threshold,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 350));
    final index = _indexOf(id);
    final updatedSim = _sims[index].copyModelWith(alertThreshold: threshold);
    _sims[index] = updatedSim;
    return updatedSim;
  }

  int _indexOf(String id) {
    final index = _sims.indexWhere((sim) => sim.id == id);
    if (index == -1) {
      throw const ServerException('Puce introuvable.', 404);
    }

    return index;
  }
}
