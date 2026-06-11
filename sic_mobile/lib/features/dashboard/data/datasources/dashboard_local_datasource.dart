import '../models/agent_summary_model.dart';

class DashboardLocalDatasource {
  const DashboardLocalDatasource();

  Future<AgentSummaryModel> getDashboardSummary() async {
    await Future<void>.delayed(const Duration(milliseconds: 800));
    return AgentSummaryModel.mock();
  }

  Future<void> refreshBalance(String operatorCode) async {
    await Future<void>.delayed(const Duration(milliseconds: 500));
  }
}
