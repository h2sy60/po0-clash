import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/widgets/widgets.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/test_app.dart';

Future<void> _pump(WidgetTester tester, Widget child) {
  return tester.pumpWidget(
    TestApp(
      child: Scaffold(
        body: Center(child: SizedBox(width: 360, child: child)),
      ),
    ),
  );
}

void main() {
  group('GlassSegmented', () {
    testWidgets('every part of a segment answers taps, down to its edge', (
      tester,
    ) async {
      var selected = 'a';
      await _pump(
        tester,
        StatefulBuilder(
          builder: (context, setState) => GlassSegmented<String>(
            values: const ['a', 'b', 'c'],
            selected: selected,
            labelOf: (value) => value.toUpperCase(),
            onChanged: (value) => setState(() => selected = value),
          ),
        ),
      );
      final track = tester.getRect(find.byType(GlassSegmented<String>));
      final b = tester.getRect(
        find.ancestor(of: find.text('B'), matching: find.byType(InkWell)),
      );
      expect(b.height, track.height, reason: 'the segment fills the track');
      expect(b.center.dy, closeTo(track.center.dy, 0.5));

      await tester.tapAt(b.bottomCenter - const Offset(0, 2));
      await tester.pumpAndSettle();
      expect(selected, 'b');
    });

    testWidgets('tapping the chosen segment reports nothing', (tester) async {
      var changes = 0;
      await _pump(
        tester,
        GlassSegmented<String>(
          values: const ['a', 'b'],
          selected: 'a',
          labelOf: (value) => value,
          iconOf: (value) => Icons.circle,
          onChanged: (_) => changes++,
        ),
      );
      await tester.tap(find.text('a'));
      await tester.pump();
      expect(changes, 0);
      expect(find.byIcon(Icons.circle), findsNWidgets(2));
    });
  });

  group('GlassButton', () {
    testWidgets('a circular button ignores taps outside its circle', (
      tester,
    ) async {
      var taps = 0;
      await _pump(
        tester,
        Center(
          child: SizedBox.square(
            dimension: 100,
            child: GlassButton(
              circle: true,
              onTap: () => taps++,
              child: const SizedBox.expand(),
            ),
          ),
        ),
      );
      final rect = tester.getRect(find.byType(GlassButton));
      await tester.tapAt(rect.topLeft + const Offset(4, 4));
      await tester.pump();
      expect(taps, 0, reason: 'the square corner lies outside the circle');
      await tester.tapAt(rect.center);
      await tester.pump();
      expect(taps, 1);
    });

    testWidgets('a plain button hosts ink without drawing glass', (
      tester,
    ) async {
      await _pump(
        tester,
        GlassButton(
          plain: true,
          onTap: () {},
          tooltip: 'plain',
          child: const Text('row'),
        ),
      );
      final materials = tester.widgetList<Material>(
        find.descendant(
          of: find.byType(GlassSurface),
          matching: find.byType(Material),
        ),
      );
      expect(materials.first.type, MaterialType.transparency);
      expect(find.byType(BackdropFilter), findsNothing);
      expect(find.byTooltip('plain'), findsOneWidget);
    });

    testWidgets('a selected surface uses the selection rim', (tester) async {
      await _pump(
        tester,
        const GlassSurface(
          selected: true,
          kind: GlassKind.chrome,
          child: SizedBox(height: 40),
        ),
      );
      expect(find.byType(BackdropFilter), findsNothing);
    });
  });

  testWidgets('GlassIconButton is exactly as large as it looks', (
    tester,
  ) async {
    await _pump(
      tester,
      Center(
        child: GlassIconButton(
          icon: Icons.tune,
          tooltip: 'Options',
          onPressed: () {},
        ),
      ),
    );
    expect(tester.getSize(find.byType(IconButton)), const Size.square(32));
  });

  testWidgets('small glass pieces render their content', (tester) async {
    await _pump(
      tester,
      const Column(
        children: [
          GlassPill(label: '52 ms', icon: Icons.bolt, monospace: true),
          GlassIconBadge(icon: Icons.key),
          GlassSectionLabel('Section', trailing: Text('more')),
        ],
      ),
    );
    expect(find.text('52 ms'), findsOneWidget);
    expect(find.byIcon(Icons.key), findsOneWidget);
    expect(find.text('Section'), findsOneWidget);
    expect(find.text('more'), findsOneWidget);
  });

  testWidgets('the floor is the neutral grouped background', (tester) async {
    await tester.pumpWidget(
      const TestApp(child: AppFloor(child: Text('floor'))),
    );
    final box = tester.widget<ColoredBox>(
      find
          .ancestor(of: find.text('floor'), matching: find.byType(ColoredBox))
          .first,
    );
    expect(
      box.color,
      Theme.of(tester.element(find.text('floor'))).colorScheme.surface,
    );
  });

  test('glass follows the brightness and system colors follow suit', () {
    final light = GlassStyle.of(ColorScheme.fromSeed(seedColor: Colors.indigo));
    final dark = GlassStyle.of(
      ColorScheme.fromSeed(
        seedColor: Colors.indigo,
        brightness: Brightness.dark,
      ),
    );
    expect(light.isDark, isFalse);
    expect(dark.isDark, isTrue);
    expect(
      dark.background,
      ColorScheme.fromSeed(
        seedColor: Colors.indigo,
        brightness: Brightness.dark,
      ).surface,
    );
    expect(
      GlassStyle.of(
        ColorScheme.fromSeed(
          seedColor: Colors.indigo,
          brightness: Brightness.dark,
        ),
        pureBlack: true,
      ).background,
      Colors.black,
    );
    expect(light.card.a, 1);
    expect(light.copyWith(card: Colors.red).card, Colors.red);
    expect(light.lerp(null, 0.5), light);
    expect(light.lerp(dark, 1).card, dark.card);
    expect(GlassTone.success.on(Brightness.light), const Color(0xFF34C759));
    expect(GlassTone.success.on(Brightness.dark), const Color(0xFF30D158));
  });

  testWidgets('tone colors resolve against the theme', (tester) async {
    late BuildContext context;
    await tester.pumpWidget(
      TestApp(
        child: Builder(
          builder: (value) {
            context = value;
            return const SizedBox();
          },
        ),
      ),
    );
    expect(context.toneColor(GlassTone.accent), context.colorScheme.primary);
    for (final tone in GlassTone.values.skip(1)) {
      expect(context.toneColor(tone), tone.on(Brightness.light));
    }
  });
}
