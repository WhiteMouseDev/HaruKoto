import 'package:harukoto_mobile/core/auth/current_account_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:harukoto_mobile/core/providers/study_clock_provider.dart';
import 'package:harukoto_mobile/features/home/data/home_repository.dart';
import 'package:harukoto_mobile/features/home/data/models/dashboard_model.dart';
import 'package:harukoto_mobile/features/home/providers/home_provider.dart';

void main() {
  test('Korea calendar crosses midnight, Monday and year at UTC 15:00', () {
    expect(
        studyDateKey(studyDateInKorea(DateTime.parse('2026-09-27T14:59:59Z'))),
        '2026-09-27');
    final monday = studyDateInKorea(DateTime.parse('2026-09-27T15:00:00Z'));
    expect(monday.weekday, DateTime.monday);
    expect(studyDateKey(monday), '2026-09-28');
    expect(
        studyDateKey(studyDateInKorea(DateTime.parse('2026-12-31T15:00:00Z'))),
        '2027-01-01');
    expect(
        studyDateKey(
            studyDateInKorea(DateTime.parse('2026-09-27T08:00:00-07:00'))),
        '2026-09-28');
  });

  testWidgets('midnight reloads dashboard and resume catches a suspended timer',
      (tester) async {
    var now = DateTime.utc(2026, 9, 27, 14, 59, 59);
    final repository = _HomeRepository();
    final container = ProviderContainer(overrides: [
      currentAccountIdProvider.overrideWithValue('test-account'),
      currentAccountReaderProvider.overrideWithValue(() => 'test-account'),
      studyClockProvider.overrideWithValue(() => now),
      homeRepositoryProvider.overrideWithValue(repository),
    ]);
    final subscription = container.listen(dashboardProvider, (_, __) {});
    try {
      await container.read(dashboardProvider.future);
      expect(repository.calls, 1);
      now = DateTime.utc(2026, 9, 27, 15);
      await tester.pump(const Duration(seconds: 1));
      await container.read(dashboardProvider.future);
      expect(container.read(studyDateProvider), DateTime.utc(2026, 9, 28));
      expect(repository.calls, 2);

      now = DateTime.utc(2026, 9, 29, 1);
      container.read(studyDateProvider.notifier).refresh();
      await container.read(dashboardProvider.future);
      expect(container.read(studyDateProvider), DateTime.utc(2026, 9, 29));
      expect(repository.calls, 3);
      container.read(studyDateProvider.notifier).refresh();
      await container.read(dashboardProvider.future);
      expect(repository.calls, 3);
    } finally {
      subscription.close();
      container.dispose();
    }
  });
}

class _HomeRepository extends Fake implements HomeRepository {
  int calls = 0;
  @override
  Future<DashboardModel> fetchDashboard() async {
    calls++;
    return DashboardModel.fromJson({});
  }
}
