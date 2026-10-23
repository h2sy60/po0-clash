import 'package:fl_clash/widgets/line_chart.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('unchanged samples do not start another chart animation', (
    tester,
  ) async {
    Widget chart(double value) => MaterialApp(
      home: SizedBox(
        width: 300,
        height: 100,
        child: LineChart(
          points: [Point(0, value), Point(1, value)],
          color: Colors.blue,
          duration: const Duration(seconds: 1),
        ),
      ),
    );
    await tester.pumpWidget(chart(0));
    await tester.pumpAndSettle();
    await tester.pumpWidget(chart(0));
    expect(tester.binding.transientCallbackCount, 0);
    await tester.pumpWidget(chart(10));
    expect(tester.binding.transientCallbackCount, greaterThan(0));
    await tester.pumpAndSettle();
    expect(tester.binding.transientCallbackCount, 0);
  });
}
