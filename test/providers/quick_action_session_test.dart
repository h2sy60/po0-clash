import 'package:fl_clash/providers/providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _QuickSession extends SetupAction {
  final List<DateTime?> starts;
  _QuickSession(this.starts);
  final intents = <bool>[];
  int reloads = 0;

  @override
  Future<DateTime?> readServiceStartTime() async => starts.removeAt(0);

  @override
  Future<bool> applyProfile({
    bool force = false,
    bool silence = false,
    Future<void> Function()? preloadInvoke,
  }) async {
    expect(force, isTrue);
    reloads++;
    return true;
  }

  @override
  Future<bool> setRunning(bool running, {bool initialize = false}) async {
    intents.add(running);
    return true;
  }
}

void main() {
  test(
    'a quick action session attaches without another start intent',
    () async {
      final started = DateTime.now().subtract(const Duration(minutes: 1));
      final action = _QuickSession([started, started]);
      final container = ProviderContainer(
        overrides: [setupActionProvider.overrideWith(() => action)],
      );
      addTearDown(container.dispose);
      container.listen(runTimeProvider, (_, _) {});
      await container
          .read(setupActionProvider.notifier)
          .attachQuickActionSession();
      expect(container.read(isStartProvider), isTrue);
      expect(action.reloads, 1);
      expect(action.intents, isEmpty);
    },
  );

  test(
    'a native stop during configuration is never turned into a start',
    () async {
      final action = _QuickSession([
        DateTime.now().subtract(const Duration(minutes: 1)),
        null,
      ]);
      final container = ProviderContainer(
        overrides: [setupActionProvider.overrideWith(() => action)],
      );
      addTearDown(container.dispose);
      container.listen(runTimeProvider, (_, _) {});
      await container
          .read(setupActionProvider.notifier)
          .attachQuickActionSession();
      expect(container.read(isStartProvider), isFalse);
      expect(action.intents, isEmpty);
    },
  );
}
