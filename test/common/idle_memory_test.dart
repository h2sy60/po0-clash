import 'dart:async';

import 'package:fl_clash/common/idle_memory.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('one hidden transition reclaims caches and Core in order', (
    tester,
  ) async {
    final calls = <String>[];
    final trimmer = IdleMemoryTrimmer(
      setCacheLimit: (bytes) async => calls.add('gpu:$bytes'),
      clearCaches: () => calls.add('cache'),
      releaseCore: () async => calls.add('core'),
      releaseAllocator: () => calls.add('allocator'),
      onError: (error, stack) => fail('$error'),
    );
    addTearDown(trimmer.dispose);
    trimmer.setVisible(false);
    await tester.pump(const Duration(seconds: 2));
    trimmer.setVisible(false);
    await tester.pump(const Duration(seconds: 1));
    expect(calls, ['gpu:0', 'cache', 'core', 'allocator']);
    await tester.pump(const Duration(minutes: 1));
    expect(calls.length, 4);
  });

  testWidgets(
    'foreground return cancels an idle trim and restores the budget',
    (tester) async {
      final limits = <int>[];
      var trims = 0;
      final trimmer = IdleMemoryTrimmer(
        setCacheLimit: (bytes) async => limits.add(bytes),
        clearCaches: () => trims++,
        releaseCore: () async => trims++,
        releaseAllocator: () => trims++,
        onError: (error, stack) => fail('$error'),
      );
      addTearDown(trimmer.dispose);
      trimmer.setVisible(false);
      await tester.pump(const Duration(seconds: 2));
      trimmer.setVisible(true);
      await tester.pump(const Duration(seconds: 5));
      expect(trims, 0);
      expect(limits, [activeGpuCacheBytes]);
    },
  );

  testWidgets('a resumed UI stops a trim that is awaiting the renderer', (
    tester,
  ) async {
    final renderer = Completer<void>();
    final limits = <int>[];
    var trims = 0;
    final trimmer = IdleMemoryTrimmer(
      setCacheLimit: (bytes) {
        limits.add(bytes);
        return bytes == 0 ? renderer.future : Future.value();
      },
      clearCaches: () => trims++,
      releaseCore: () async => trims++,
      releaseAllocator: () => trims++,
      onError: (error, stack) => fail('$error'),
    );
    addTearDown(trimmer.dispose);
    trimmer.setVisible(false);
    await tester.pump(const Duration(seconds: 3));
    trimmer.setVisible(true);
    renderer.complete();
    await tester.pump();
    expect(trims, 0);
    expect(limits, [0, activeGpuCacheBytes]);
  });

  testWidgets('disposal cancels pending work', (tester) async {
    var trims = 0;
    final trimmer = IdleMemoryTrimmer(
      setCacheLimit: (_) async => trims++,
      clearCaches: () => trims++,
      releaseCore: () async => trims++,
      releaseAllocator: () => trims++,
      onError: (error, stack) => fail('$error'),
    );
    trimmer.setVisible(false);
    trimmer.dispose();
    await tester.pump(const Duration(seconds: 5));
    expect(trims, 0);
  });
}
