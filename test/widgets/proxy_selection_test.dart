import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/providers/providers.dart';
import 'package:fl_clash/state.dart';
import 'package:fl_clash/views/proxies/card.dart';
import 'package:fl_clash/widgets/selection_badge.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/test_app.dart';
import '../helpers/test_profiles.dart';

void main() {
  for (final saved in [null, 'removed']) {
    testWidgets('default proxy is marked with saved selection $saved', (
      tester,
    ) async {
      final profile = Profile.normal().copyWith(
        selectedMap: saved == null ? {} : {'subscription': saved},
      );
      final groups = await buildGroups(
        const ComputeGroupsState(
          proxiesData: ProxiesData(
            all: ['subscription'],
            proxies: {
              'subscription': {
                'name': 'subscription',
                'type': 'Selector',
                'all': ['Zulu', 'Alpha'],
              },
              'Zulu': {'name': 'Zulu', 'type': 'Direct'},
              'Alpha': {'name': 'Alpha', 'type': 'Direct'},
            },
          ),
          sortType: ProxiesSortType.name,
          delayMap: {},
          selectedMap: {},
          defaultTestUrl: '',
        ),
      );
      final container = ProviderContainer(
        overrides: [
          profilesProvider.overrideWith(() => TestProfiles([profile])),
          currentProfileIdProvider.overrideWithBuild((_, _) => profile.id),
          groupsProvider.overrideWithBuild((_, _) => groups),
        ],
      );
      addTearDown(container.dispose);
      globalState.container = container;
      container.listen(
        realSelectedProxyStateProvider('subscription'),
        (_, _) {},
      );
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: TestApp(
            child: Scaffold(
              body: Column(
                children: [
                  for (final proxy in groups.single.all)
                    SizedBox(
                      height: 140,
                      child: ProxyCard(
                        groupName: 'subscription',
                        proxy: proxy,
                        groupType: GroupType.Selector,
                        type: ProxyCardType.min,
                        testUrl: null,
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      Finder badgeOf(String name) => find.descendant(
        of: find.byWidgetPredicate(
          (widget) => widget is ProxyCard && widget.proxy.name == name,
        ),
        matching: find.byType(SelectionBadge),
      );
      expect(badgeOf('Zulu'), findsOneWidget);
      expect(badgeOf('Alpha'), findsNothing);
      expect(container.read(selectedMapProvider), profile.selectedMap);

      container
          .read(profilesActionProvider.notifier)
          .updateCurrentSelectedMap('subscription', 'Alpha');
      await tester.pump();
      expect(badgeOf('Alpha'), findsOneWidget);
      expect(badgeOf('Zulu'), findsNothing);
      expect(
        container
            .read(realSelectedProxyStateProvider('subscription'))
            .proxyName,
        'Alpha',
      );

      await tester.pumpWidget(const SizedBox.shrink());
    });
  }
}
