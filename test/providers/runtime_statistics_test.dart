import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/providers/providers.dart';
import 'package:fl_clash/state.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:riverpod/riverpod.dart';

import '../helpers/test_profiles.dart';

class _Stats extends CommonAction {
  int samples = 0;

  @override
  Future<void> updateTraffic() async {
    samples++;
  }
}

class _Runtime extends SetupAction {
  bool tray = false;
  DateTime clock = DateTime(2026, 10, 23, 12);
  final calls = <bool>[];

  @override
  bool get supportsTrayTraffic => tray;

  @override
  DateTime runtimeNow() => clock;

  @override
  Future<bool> setCoreRunning(bool running) async {
    calls.add(running);
    return true;
  }

  @override
  Future<bool> applyProfile({
    bool silence = false,
    bool force = false,
    Future<void> Function()? preloadInvoke,
  }) async {
    await preloadInvoke?.call();
    return true;
  }
}

Future<void> _withRuntime(
  Future<void> Function(
    ProviderContainer container,
    _Runtime runtime,
    _Stats stats,
  )
  body,
) async {
  final runtime = _Runtime();
  final stats = _Stats();
  final container = ProviderContainer(
    overrides: [
      profilesProvider.overrideWith(TestProfiles.new),
      setupActionProvider.overrideWith(() => runtime),
      commonActionProvider.overrideWith(() => stats),
    ],
  );
  globalState.container = container;
  container.read(setupActionProvider.notifier);
  container.read(coreStatusProvider.notifier).value = CoreStatus.connected;
  try {
    await body(container, runtime, stats);
  } finally {
    container.dispose();
  }
}

void main() {
  testWidgets(
    'a disconnected core is not polled while restart is pending',
    (tester) => _withRuntime((container, runtime, stats) async {
      await runtime.setRunning(true, initialize: true);
      final samples = stats.samples;
      container.read(coreStatusProvider.notifier).value =
          CoreStatus.disconnected;
      await tester.pump(const Duration(minutes: 1));
      expect(stats.samples, samples);
      expect(runtime.calls, [true]);
      container.read(coreStatusProvider.notifier).value = CoreStatus.connected;
      expect(stats.samples, samples + 1);
    }),
  );
  testWidgets(
    'hidden UI stops sampling without stopping the proxy',
    (tester) => _withRuntime((container, runtime, stats) async {
      await runtime.setRunning(true, initialize: true);
      final samples = stats.samples;
      container.read(uiVisibleProvider.notifier).value = false;
      container
          .read(trafficsProvider.notifier)
          .addTraffic(const Traffic(up: 12, down: 34));
      const total = Traffic(up: 1234, down: 5678);
      container.read(totalTrafficProvider.notifier).value = total;
      await tester.pump(const Duration(minutes: 1));
      expect(stats.samples, samples);
      expect(container.read(runTimeProvider), isNotNull);
      expect(runtime.calls, [true]);
      runtime.clock = runtime.clock.add(const Duration(minutes: 1));
      container.read(uiVisibleProvider.notifier).value = true;
      expect(stats.samples, samples + 1);
      expect(
        container.read(runTimeProvider),
        const Duration(minutes: 1).inMilliseconds,
      );
      expect(container.read(trafficsProvider).list, isEmpty);
      expect(container.read(totalTrafficProvider), total);
    }),
  );

  testWidgets(
    'leaving the dashboard pauses unobserved statistics',
    (tester) => _withRuntime((container, runtime, stats) async {
      await runtime.setRunning(true, initialize: true);
      final samples = stats.samples;
      container
          .read(currentPageLabelProvider.notifier)
          .toPage(PageLabel.profiles);
      await tester.pump(const Duration(seconds: 10));
      expect(stats.samples, samples);
      expect(runtime.calls, [true]);
      container
          .read(currentPageLabelProvider.notifier)
          .toPage(PageLabel.dashboard);
      expect(stats.samples, samples + 1);
    }),
  );

  testWidgets(
    'enabled macOS tray traffic keeps its background samples',
    (tester) => _withRuntime((container, runtime, stats) async {
      runtime.tray = true;
      container
          .read(appSettingProvider.notifier)
          .update((state) => state.copyWith(showTrayTitle: true));
      container.read(uiVisibleProvider.notifier).value = false;
      await runtime.setRunning(true, initialize: true);
      final samples = stats.samples;
      await tester.pump(const Duration(seconds: 3));
      expect(stats.samples, greaterThan(samples));
      container
          .read(appSettingProvider.notifier)
          .update((state) => state.copyWith(showTrayTitle: false));
      final paused = stats.samples;
      await tester.pump(const Duration(seconds: 3));
      expect(stats.samples, paused);
    }),
  );

  testWidgets(
    'tray preferences on other platforms do not keep sampling',
    (tester) => _withRuntime((container, runtime, stats) async {
      container
          .read(appSettingProvider.notifier)
          .update((state) => state.copyWith(showTrayTitle: true));
      container.read(uiVisibleProvider.notifier).value = false;
      await runtime.setRunning(true, initialize: true);
      await tester.pump(const Duration(seconds: 3));
      expect(stats.samples, 0);
    }),
  );
}
