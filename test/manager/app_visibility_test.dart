import 'package:fl_clash/common/desktop_route.dart';
import 'package:fl_clash/manager/app_manager.dart';
import 'package:fl_clash/providers/providers.dart';
import 'package:fl_clash/state.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/test_profiles.dart';

class _VisibilitySystemAction extends SystemAction {
  @override
  void reconcileRoute({DesktopRoute? changed}) {}
}

Future<ProviderContainer> _pumpManager(WidgetTester tester) async {
  final container = ProviderContainer(
    overrides: [
      profilesProvider.overrideWith(TestProfiles.new),
      initProvider.overrideWithBuild((_, _) => false),
      systemActionProvider.overrideWith(_VisibilitySystemAction.new),
    ],
  );
  addTearDown(container.dispose);
  globalState.container = container;
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: const Directionality(
        textDirection: TextDirection.ltr,
        child: AppStateManager(child: SizedBox()),
      ),
    ),
  );
  return container;
}

void main() {
  testWidgets('an inactive event cannot undo an explicit window hide', (
    tester,
  ) async {
    final container = await _pumpManager(tester);
    final observer =
        tester.state(find.byType(AppStateManager)) as WidgetsBindingObserver;
    container.read(uiVisibleProvider.notifier).value = false;
    observer.didChangeAppLifecycleState(AppLifecycleState.inactive);
    await tester.pump();
    expect(container.read(uiVisibleProvider), isFalse);
    final ticker = tester.widget<TickerMode>(find.byType(TickerMode).last);
    expect(ticker.enabled, isFalse);
  });

  testWidgets('losing focus keeps a visible window active until it is hidden', (
    tester,
  ) async {
    final container = await _pumpManager(tester);
    final observer =
        tester.state(find.byType(AppStateManager)) as WidgetsBindingObserver;
    container.read(uiVisibleProvider.notifier).value = true;
    observer.didChangeAppLifecycleState(AppLifecycleState.inactive);
    expect(container.read(uiVisibleProvider), isTrue);
    observer.didChangeAppLifecycleState(AppLifecycleState.hidden);
    observer.didChangeAppLifecycleState(AppLifecycleState.inactive);
    await tester.pump();
    expect(container.read(uiVisibleProvider), isFalse);
  });
}
