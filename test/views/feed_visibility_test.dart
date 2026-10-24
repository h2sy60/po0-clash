import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/providers/providers.dart';
import 'package:fl_clash/state.dart';
import 'package:fl_clash/views/connection/requests.dart';
import 'package:fl_clash/views/logs.dart';
import 'package:fl_clash/widgets/inherited.dart';
import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/test_app.dart';
import '../helpers/test_profiles.dart';

void main() {
  for (final logs in [true, false]) {
    for (final gate in ['page', 'ticker', 'window', 'lifecycle']) {
      testWidgets(
        '${logs ? 'logs' : 'requests'} catch up after $gate becomes visible',
        (tester) async {
          tester.binding.handleAppLifecycleStateChanged(
            AppLifecycleState.resumed,
          );
          final container = ProviderContainer(
            overrides: [profilesProvider.overrideWith(TestProfiles.new)],
          );
          addTearDown(container.dispose);
          globalState.container = container;
          if (logs) {
            container.read(logsProvider.notifier).value = FixedList<Log>(16);
          } else {
            container.read(requestsProvider.notifier).value =
                FixedList<TrackerInfo>(16);
          }
          void add(int id) {
            if (logs) {
              container
                  .read(logsProvider.notifier)
                  .add(Log(payload: 'entry-$id', dateTime: ''));
            } else {
              container
                  .read(requestsProvider.notifier)
                  .addRequest(
                    TrackerInfo(
                      id: '$id',
                      start: DateTime.utc(2026),
                      metadata: Metadata(network: 'tcp', host: 'host-$id.test'),
                      chains: const ['DIRECT'],
                      rule: 'MATCH',
                      rulePayload: '',
                    ),
                  );
            }
          }

          Future<void> mount({bool active = true}) async {
            await tester.pumpWidget(
              UncontrolledProviderScope(
                container: container,
                child: TestApp(
                  child: PageActivityScope(
                    isActive: active || gate != 'page',
                    child: TickerMode(
                      enabled: active || gate != 'ticker',
                      child: logs ? const LogsView() : const RequestsView(),
                    ),
                  ),
                ),
              ),
            );
            await tester.pump(const Duration(milliseconds: 1));
            await tester.pump();
          }

          add(0);
          await mount();
          final ValueListenable<Object> displayed = logs
              ? tester
                    .widget<ValueListenableBuilder<LogsState>>(
                      find.byType(ValueListenableBuilder<LogsState>).first,
                    )
                    .valueListenable
              : tester
                    .widget<ValueListenableBuilder<TrackerInfosState>>(
                      find
                          .byType(ValueListenableBuilder<TrackerInfosState>)
                          .first,
                    )
                    .valueListenable;
          int count() => switch (displayed.value) {
            LogsState(:final logs) => logs.length,
            TrackerInfosState(:final trackerInfos) => trackerInfos.length,
            _ => throw StateError('unexpected feed'),
          };
          expect(count(), 1);
          var refreshes = 0;
          displayed.addListener(() => refreshes++);
          if (gate == 'window') {
            container.read(uiVisibleProvider.notifier).value = false;
          } else if (gate == 'lifecycle') {
            for (final state in [
              AppLifecycleState.inactive,
              AppLifecycleState.hidden,
              AppLifecycleState.paused,
            ]) {
              tester.binding.handleAppLifecycleStateChanged(state);
            }
          } else {
            await mount(active: false);
          }
          for (var id = 1; id <= 100; id++) {
            add(id);
          }
          await tester.pump(const Duration(seconds: 2));
          expect(count(), 1);
          expect(refreshes, 0);
          expect(
            logs
                ? container.read(logsProvider).length
                : container.read(requestsProvider).length,
            16,
          );
          if (gate == 'window') {
            container.read(uiVisibleProvider.notifier).value = true;
          } else if (gate == 'lifecycle') {
            for (final state in [
              AppLifecycleState.hidden,
              AppLifecycleState.inactive,
              AppLifecycleState.resumed,
            ]) {
              tester.binding.handleAppLifecycleStateChanged(state);
            }
          } else {
            await mount();
          }
          await tester.pump(const Duration(milliseconds: 1));
          await tester.pump();
          expect(count(), 16);
          expect(refreshes, 1);
          await tester.pumpWidget(const SizedBox());
          await tester.pump(const Duration(seconds: 1));
          expect(tester.takeException(), isNull);
        },
      );
    }
  }
}
