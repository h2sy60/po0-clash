import 'package:fl_clash/widgets/active_feed.dart';
import 'package:fl_clash/widgets/inherited.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

class _Feed extends StatefulWidget {
  const _Feed({super.key, this.visible = true});

  final bool visible;

  @override
  State<_Feed> createState() => _FeedState();
}

class _FeedState extends State<_Feed>
    with WidgetsBindingObserver, ActiveFeedMixin<_Feed> {
  int refreshes = 0;
  bool fail = false;
  void Function()? onRefresh;

  @override
  Duration get feedRefreshInterval => const Duration(milliseconds: 300);

  @override
  bool get feedVisible => widget.visible;

  @override
  void didUpdateWidget(_Feed oldWidget) {
    super.didUpdateWidget(oldWidget);
    syncFeedVisibility();
  }

  @override
  void refreshFeed() {
    refreshes++;
    onRefresh?.call();
    if (fail) throw StateError('refresh failed');
  }

  @override
  Widget build(BuildContext context) => const SizedBox();
}

Future<void> _mount(
  WidgetTester tester,
  GlobalKey<_FeedState> key, {
  bool page = true,
  bool ticker = true,
  bool window = true,
}) async {
  await tester.pumpWidget(
    PageActivityScope(
      isActive: page,
      child: TickerMode(
        enabled: ticker,
        child: _Feed(key: key, visible: window),
      ),
    ),
  );
  await tester.pump(const Duration(milliseconds: 1));
}

void main() {
  testWidgets('arrivals coalesce and an idle feed schedules no refreshes', (
    tester,
  ) async {
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    final key = GlobalKey<_FeedState>();
    await _mount(tester, key);
    final state = key.currentState!;
    await tester.pump(const Duration(minutes: 1));
    expect(state.refreshes, 0);
    for (var i = 0; i < 100; i++) {
      state.requestFeedRefresh();
    }
    await tester.pump(const Duration(milliseconds: 299));
    expect(state.refreshes, 0);
    await tester.pump(const Duration(milliseconds: 1));
    expect(state.refreshes, 1);
    await tester.pump(const Duration(minutes: 1));
    expect(state.refreshes, 1);
    await tester.pumpWidget(const SizedBox());
  });

  for (final gate in ['page', 'ticker', 'window', 'lifecycle']) {
    testWidgets('$gate hides pending work and resumes once', (tester) async {
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      final key = GlobalKey<_FeedState>();
      await _mount(tester, key);
      final state = key.currentState!;
      state.requestFeedRefresh();
      if (gate == 'lifecycle') {
        for (final state in [
          AppLifecycleState.inactive,
          AppLifecycleState.hidden,
          AppLifecycleState.paused,
        ]) {
          tester.binding.handleAppLifecycleStateChanged(state);
        }
      } else {
        await _mount(
          tester,
          key,
          page: gate != 'page',
          ticker: gate != 'ticker',
          window: gate != 'window',
        );
      }
      for (var i = 0; i < 100; i++) {
        state.requestFeedRefresh();
      }
      await tester.pump(const Duration(minutes: 1));
      expect(state.refreshes, 0);
      if (gate == 'lifecycle') {
        for (final state in [
          AppLifecycleState.hidden,
          AppLifecycleState.inactive,
          AppLifecycleState.resumed,
        ]) {
          tester.binding.handleAppLifecycleStateChanged(state);
        }
      } else {
        await _mount(tester, key);
      }
      await tester.pump(const Duration(milliseconds: 1));
      expect(state.refreshes, 1);
      await tester.pump(const Duration(minutes: 1));
      expect(state.refreshes, 1);
      await tester.pumpWidget(const SizedBox());
    });
  }

  testWidgets('a refresh failure and disposal both release scheduled work', (
    tester,
  ) async {
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    final key = GlobalKey<_FeedState>();
    await _mount(tester, key);
    final state = key.currentState!..fail = true;
    state.onRefresh = state.requestFeedRefresh;
    state.requestFeedRefresh();
    await tester.pump(const Duration(milliseconds: 300));
    expect(state.refreshes, 1);
    expect(tester.takeException(), isNull);
    await tester.pump(const Duration(minutes: 1));
    expect(state.refreshes, 1);
    state.fail = false;
    state.onRefresh = null;
    state.requestFeedRefresh();
    await tester.pump(const Duration(milliseconds: 300));
    expect(state.refreshes, 2);
    state.requestFeedRefresh();
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(minutes: 1));
    expect(state.refreshes, 2);
    expect(tester.takeException(), isNull);
  });

  testWidgets('an arrival during refresh is delivered by one follow-up', (
    tester,
  ) async {
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    final key = GlobalKey<_FeedState>();
    await _mount(tester, key);
    final state = key.currentState!;
    state.onRefresh = () {
      state.onRefresh = null;
      state.requestFeedRefresh();
    };
    state.requestFeedRefresh();
    await tester.pump(const Duration(milliseconds: 300));
    expect(state.refreshes, 1);
    await tester.pump(const Duration(milliseconds: 300));
    expect(state.refreshes, 2);
    await tester.pump(const Duration(minutes: 1));
    expect(state.refreshes, 2);
    await tester.pumpWidget(const SizedBox());
  });
}
