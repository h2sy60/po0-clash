import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/views/proxies/group_tabs.dart';
import 'package:fl_clash/widgets/widgets.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/test_app.dart';

void main() {
  testWidgets('reveals distant selections without building every group', (
    tester,
  ) async {
    final controller = TabController(length: 200, vsync: tester);
    final groups = List.generate(
      200,
      (index) => Group(name: 'Group $index', type: GroupType.Selector),
    );
    await tester.pumpWidget(
      TestApp(
        child: Scaffold(
          body: Align(
            alignment: Alignment.topCenter,
            child: GroupTabs(controller: controller, groups: groups),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(CommonCard).evaluate().length, lessThan(20));

    controller.animateTo(199);
    await tester.pumpAndSettle();
    expect(
      find.text('Group 199', findRichText: true).hitTestable(),
      findsOneWidget,
    );
    expect(find.byType(CommonCard).evaluate().length, lessThan(20));
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    controller.dispose();
  });

  testWidgets(
    'taps select groups and a resized strip keeps the selection visible',
    (tester) async {
      final controller = TabController(length: 3, vsync: tester);
      final groups = [
        'A',
        'B',
        'C',
      ].map((name) => Group(name: name, type: GroupType.Selector)).toList();
      await tester.pumpWidget(
        TestApp(
          child: Scaffold(
            body: Align(
              alignment: Alignment.topCenter,
              child: SizedBox(
                width: 240,
                child: GroupTabs(controller: controller, groups: groups),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('C', findRichText: true));
      await tester.pumpAndSettle();
      expect(controller.index, 2);
      expect(find.text('C', findRichText: true).hitTestable(), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
      controller.dispose();
    },
  );
}
