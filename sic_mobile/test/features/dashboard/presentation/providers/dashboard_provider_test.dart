import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sic_mobile/features/dashboard/domain/entities/agent_summary.dart';
import 'package:sic_mobile/features/dashboard/presentation/providers/dashboard_provider.dart';

void main() {
  test('should load mocked dashboard summary through provider chain', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final summary = await container.read(dashboardNotifierProvider.future);

    expect(summary, isA<AgentSummary>());
    expect(summary.agentCode, 'AGT-0042');
    expect(summary.totalBalance, 485000);
  });

  test('should default selected benefit period to today', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final selectedPeriod = container.read(selectedBenefitPeriodProvider);

    expect(selectedPeriod, DashboardBenefitPeriod.today);
  });
}
