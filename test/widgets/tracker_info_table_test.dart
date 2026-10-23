import 'package:fl_clash/features/connection/tracker_info_table.dart';
import 'package:fl_clash/models/models.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/test_app.dart';

TrackerInfo _info(String id, {int upload = 0, int second = 0}) => TrackerInfo(
  id: id,
  upload: upload,
  start: DateTime(2026, 10, 24, 12, 0, second),
  metadata: Metadata(
    host: '$id.example',
    network: 'tcp',
    destinationPort: '443',
  ),
  chains: const ['Proxy'],
  rule: 'MATCH',
  rulePayload: '',
);

Future<void> _pump(
  WidgetTester tester,
  List<TrackerInfo> rows, {
  ValueChanged<String>? onClose,
}) async {
  tester.view.physicalSize = const Size(1280, 600);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    TestApp(
      child: Scaffold(
        body: TrackerInfoTable(
          trackerInfos: rows,
          detailTitle: 'Details',
          onClose: onClose,
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('sorts current snapshots numerically in both directions', (
    tester,
  ) async {
    final rows = [_info('a', upload: 1000), _info('b', upload: 20, second: 1)];
    await _pump(tester, rows);
    double top(String id) => tester.getTopLeft(find.byKey(ValueKey(id))).dy;
    expect(top('b'), lessThan(top('a')));

    await tester.tap(find.text('Upload'));
    await tester.pumpAndSettle();
    expect(top('a'), lessThan(top('b')));

    await tester.tap(find.text('Upload'));
    await tester.pumpAndSettle();
    expect(top('b'), lessThan(top('a')));

    await _pump(tester, [rows.first, rows.last.copyWith(upload: 2000)]);
    expect(top('a'), lessThan(top('b')));
    expect(rows.first.id, 'a');
  });

  testWidgets('closes the intended connection after sorting', (tester) async {
    String? closed;
    await _pump(tester, [
      _info('a'),
      _info('b', second: 1),
    ], onClose: (id) => closed = id);
    await tester.tap(
      find.descendant(
        of: find.byKey(const ValueKey('a')),
        matching: find.byType(IconButton),
      ),
    );
    expect(closed, 'a');
  });

  testWidgets('large snapshots build only visible rows', (tester) async {
    await _pump(tester, List.generate(5000, (i) => _info('row-$i')));
    final builtRows = find.byWidgetPredicate(
      (widget) =>
          widget is InkWell &&
          widget.key is ValueKey<String> &&
          (widget.key! as ValueKey<String>).value.startsWith('row-'),
    );
    expect(builtRows.evaluate().length, lessThan(40));
    expect(tester.takeException(), isNull);
  });
}
