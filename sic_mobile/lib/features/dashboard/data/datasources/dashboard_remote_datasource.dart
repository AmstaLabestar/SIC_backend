import 'package:dio/dio.dart';

import '../../../../core/constants/api_constants.dart';
import '../../../../core/network/operator_mapping.dart';
import '../models/agent_summary_model.dart';
import '../models/balance_summary_model.dart';
import '../models/benefit_period_model.dart';

/// Construit le resume du dashboard a partir du backend reel :
/// - `/auth/profile/` -> agent + puces (soldes) ;
/// - `/transactions/` -> nombre d'operations du jour + benefice du jour.
///
/// Le backend n'expose pas de seuil d'alerte par puce ; on applique un seuil
/// par defaut cote client.
class DashboardRemoteDatasource {
  const DashboardRemoteDatasource(this._dio);

  final Dio _dio;

  static const double _defaultThreshold = 50000;

  Future<AgentSummaryModel> getDashboardSummary() async {
    final profileResponse = await _dio.get<Map<String, dynamic>>(
      ApiConstants.profile,
    );
    final profile = profileResponse.data!;

    final pucesJson = (profile['puces'] as List<dynamic>?) ?? const [];
    final balances = pucesJson
        .map((p) => _puceToBalance(p as Map<String, dynamic>))
        .toList();
    final total = balances.fold<double>(0, (sum, b) => sum + b.balance);

    final (countToday, benefitToday) = await _todayTransactions();

    final firstName = profile['first_name'] as String? ?? '';
    final lastName = profile['last_name'] as String? ?? '';
    final name =
        [firstName, lastName].where((p) => p.trim().isNotEmpty).join(' ');
    final agentCode = profile['username'] as String? ??
        profile['id']?.toString() ??
        'AGENT';

    return AgentSummaryModel(
      agentCode: agentCode,
      agentName: name.isEmpty ? 'Agent SIC' : name,
      totalBalance: total,
      benefits: BenefitPeriodModel(
        today: benefitToday,
        week: 0,
        month: 0,
        total: 0,
      ),
      balances: balances,
      transactionCountToday: countToday,
      hasUnreadNotifications: balances.any((b) => b.isLow || b.isEmpty),
      banners: const [],
    );
  }

  /// Le rechargement complet du resume se fait via un reload du notifier ;
  /// pas d'endpoint "refresh solde" dedie cote backend.
  Future<void> refreshBalance(String operatorCode) async {}

  /// Modifie une puce : `PATCH /puces/{id}/`.
  /// Le code operateur mobile (ex. OM) est traduit vers le format backend
  /// (ex. ORANGE). Le solde n'est jamais modifie ici (gere cote admin).
  Future<void> updatePuce({
    required String id,
    required String operatorCode,
    required String phoneNumber,
    required bool isActive,
  }) async {
    await _dio.patch<Map<String, dynamic>>(
      ApiConstants.puce(id),
      data: {
        'operator': OperatorMapping.toBackend(operatorCode),
        'phone_number': phoneNumber,
        'is_active': isActive,
      },
    );
  }

  /// Supprime une puce : `DELETE /puces/{id}/`.
  Future<void> deletePuce(String id) async {
    await _dio.delete<void>(ApiConstants.puce(id));
  }

  /// Ajoute une puce : `POST /puces/`.
  /// Le backend refuse les doublons et impose un maximum de puces par agent.
  Future<void> createPuce({
    required String operatorCode,
    required String phoneNumber,
  }) async {
    await _dio.post<Map<String, dynamic>>(
      ApiConstants.puces,
      data: {
        'operator': OperatorMapping.toBackend(operatorCode),
        'phone_number': phoneNumber,
      },
    );
  }

  Future<(int, double)> _todayTransactions() async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        ApiConstants.transactions,
      );
      final results = (response.data?['results'] as List<dynamic>?) ?? const [];
      final now = DateTime.now();
      var count = 0;
      var benefit = 0.0;
      for (final item in results) {
        final txn = item as Map<String, dynamic>;
        final created = DateTime.tryParse(
          txn['created_at']?.toString() ?? '',
        )?.toLocal();
        if (created != null && _isSameDay(created, now)) {
          count++;
          benefit += _toDouble(txn['agent_benefit']);
        }
      }
      return (count, benefit);
    } catch (_) {
      // Best-effort : si l'historique echoue (ex. KYC en attente), on n'empeche
      // pas l'affichage du dashboard.
      return (0, 0.0);
    }
  }

  BalanceSummaryModel _puceToBalance(Map<String, dynamic> puce) {
    final operator = OperatorMapping.fromBackend(
      puce['operator']?.toString() ?? '',
    );
    final balance = _toDouble(puce['balance']);
    return BalanceSummaryModel(
      id: puce['id']?.toString(),
      operatorCode: operator.code,
      operatorName: operator.name,
      phoneNumber: puce['phone_number']?.toString() ?? '',
      balance: balance,
      isLow: balance < _defaultThreshold,
      alertThreshold: _defaultThreshold,
      lastUpdated: DateTime.tryParse(
            puce['updated_at']?.toString() ?? '',
          )?.toLocal() ??
          DateTime.now(),
      isActive: puce['is_active'] as bool? ?? true,
    );
  }

  static double _toDouble(Object? value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? 0;
  }

  static bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;
}
