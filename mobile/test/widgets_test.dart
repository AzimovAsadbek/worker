import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:worker_os/core/db/database.dart';
import 'package:worker_os/core/l10n/strings.dart';
import 'package:worker_os/core/providers.dart';
import 'package:worker_os/core/theme.dart';
import 'package:worker_os/core/widgets/common.dart';
import 'package:worker_os/features/common/notification_bell.dart';
import 'package:worker_os/features/worker/today_screen.dart';
import 'package:worker_os/models/models.dart';

TodayData _today({bool noSites = false}) => TodayData.fromJson({
      'date': '2026-09-30',
      'assignments': noSites
          ? []
          : [
              {
                'assignmentId': 'a1',
                'isResident': true,
                'site': {'id': 'site-1', 'name': "Yangiqo'rg'on — Blok A", 'latitude': 41.19, 'longitude': 71.72, 'radiusMeters': 250, 'shiftStart': '08:00', 'shiftEnd': '18:00'},
                'company': {'id': 'c1', 'name': 'Taraqqiyot Construction'},
              },
            ],
      'openShift': null,
      'todayShifts': [],
      'openTasks': 2,
    });

Widget _app({required TodayData data, List<PendingEvent> pending = const []}) => ProviderScope(
      overrides: [
        todayRemoteProvider.overrideWith((ref) async => data),
        todayCacheProvider.overrideWith((ref) async => null),
        unsyncedEventsProvider.overrideWith((ref) => Stream.value(pending)),
        syncServiceProvider.overrideWith((ref) async => null),
        unreadCountProvider.overrideWith((ref) async => 3),
      ],
      child: MaterialApp(theme: buildTheme(), home: const TodayScreen()),
    );

void main() {
  setUpAll(() => initializeDateFormatting('uz'));

  testWidgets('worker sees site, status and the big START button within one screen', (tester) async {
    await tester.pumpWidget(_app(data: _today()));
    await tester.pumpAndSettle();
    expect(find.text("Yangiqo'rg'on — Blok A"), findsOneWidget);
    expect(find.text(S.notStarted), findsOneWidget);
    expect(find.text(S.startWork), findsOneWidget);
    expect(find.text(S.residentHint), findsOneWidget);
    expect(find.text(S.openTasks), findsOneWidget);
    // Big touch target
    final button = tester.getSize(find.ancestor(of: find.text(S.startWork), matching: find.byType(FilledButton)));
    expect(button.height, greaterThanOrEqualTo(88));
  });

  testWidgets('offline START tap shows working state + END button + pending banner', (tester) async {
    final at = DateTime.now().subtract(const Duration(minutes: 30));
    final ev = PendingEvent(
      clientEventId: 'e1',
      userId: 'u',
      type: 'WORK_STARTED',
      siteId: 'site-1',
      occurredAt: at,
      deviceId: 'd',
      status: 'PENDING',
      attempts: 1,
      createdAt: at,
      acknowledged: false,
      errorMessage: S.offlineSaved,
    );
    await tester.pumpWidget(_app(data: _today(), pending: [ev]));
    await tester.pumpAndSettle();
    expect(find.text(S.workingNow), findsOneWidget);
    expect(find.text(S.endWork), findsOneWidget);
    expect(find.text(S.pendingSync), findsOneWidget);
    expect(find.text(S.pendingCount(1)), findsOneWidget);
  });

  testWidgets('worker without a site gets a clear empty state with a next step', (tester) async {
    await tester.pumpWidget(_app(data: _today(noSites: true)));
    await tester.pumpAndSettle();
    expect(find.text(S.noSiteTitle), findsOneWidget);
    expect(find.text(S.browseJobs), findsOneWidget);
    expect(find.text(S.startWork), findsNothing);
  });

  testWidgets('AsyncBody shows retry on network error', (tester) async {
    var retried = 0;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: AsyncBody<int>(value: AsyncValue.error(Exception('x'), StackTrace.empty), onRetry: () => retried++, builder: (_) => const SizedBox()),
      ),
    ));
    expect(find.text(S.retry), findsOneWidget);
    await tester.tap(find.text(S.retry));
    expect(retried, 1);
  });
}
