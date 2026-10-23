import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/l10n/l10n.dart';
import 'package:fl_clash/manager/theme_manager.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/pages/home.dart';
import 'package:fl_clash/pages/shell.dart';
import 'package:fl_clash/providers/providers.dart';
import 'package:fl_clash/state.dart';
import 'package:fl_clash/views/tools.dart';
import 'package:fl_clash/widgets/widgets.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/test_app.dart';

NavigationItem _item(PageLabel label, IconData icon, {WidgetBuilder? builder}) {
  return NavigationItem(
    icon: Icon(icon),
    label: label,
    builder: builder ?? (_) => Center(child: Text('page:${label.name}')),
  );
}

final _items = [
  _item(PageLabel.dashboard, Icons.space_dashboard),
  _item(PageLabel.profiles, Icons.folder),
  _item(PageLabel.tools, Icons.construction),
];

ProviderContainer _container(
  WidgetTester tester,
  Size size, {
  List<NavigationItem>? items,
}) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final container = ProviderContainer(
    overrides: [
      navigationItemsStateProvider.overrideWithValue(
        NavigationItemsState(value: items ?? _items),
      ),
      profilesProvider.overrideWith(() => _HomeTestProfiles(const [])),
    ],
  );
  addTearDown(container.dispose);
  globalState.container = container;
  container.read(viewSizeProvider.notifier).value = size;
  return container;
}

Future<void> _pumpHome(WidgetTester tester, ProviderContainer container) async {
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: const TestApp(includeNavigatorKey: false, child: HomePage()),
    ),
  );
  await tester.pump();
}

Future<void> _resize(
  WidgetTester tester,
  ProviderContainer container,
  Size size,
) async {
  tester.view.physicalSize = size;
  container.read(viewSizeProvider.notifier).value = size;
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('the first desktop frame already shows the control sidebar', (
    tester,
  ) async {
    final container = _container(tester, const Size(1200, 800));
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const _ThemeManagedTestApp(),
      ),
    );
    await tester.pump();

    expect(find.byType(ControlSidebar), findsOneWidget);
    expect(find.byType(GlassDock), findsNothing);
    expect(find.byType(GlassRail), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a sidebar destination opens its page in the workspace', (
    tester,
  ) async {
    final container = _container(tester, const Size(1200, 800));
    await _pumpHome(tester, container);

    await tester.tap(
      find.descendant(
        of: find.byType(ControlSidebar),
        matching: find.text('Settings'),
      ),
    );
    await tester.pumpAndSettle();

    expect(container.read(currentPageLabelProvider), PageLabel.tools);
    expect(find.text('page:tools').hitTestable(), findsOneWidget);
  });

  testWidgets('compact navigation keeps the selected destination in sync', (
    tester,
  ) async {
    final container = _container(tester, const Size(700, 800));
    await _pumpHome(tester, container);
    expect(find.byType(GlassRail), findsOneWidget);

    for (final label in [PageLabel.profiles, PageLabel.tools]) {
      await tester.tap(
        find.descendant(
          of: find.byType(GlassRail),
          matching: find.text(label.label),
        ),
      );
      await tester.pumpAndSettle();
      expect(container.read(currentPageLabelProvider), label);

      final semantics = tester.widgetList<Semantics>(
        find.ancestor(
          of: find.descendant(
            of: find.byType(GlassRail),
            matching: find.text(label.label),
          ),
          matching: find.byType(Semantics),
        ),
      );
      expect(
        semantics.any((widget) => widget.properties.selected == true),
        isTrue,
      );
      expect(find.byType(BackdropFilter), findsNothing);
    }
  });

  testWidgets('the phone dock switches pages and lifts content above it', (
    tester,
  ) async {
    final container = _container(tester, const Size(400, 800));
    await _pumpHome(tester, container);
    expect(find.byType(GlassDock), findsOneWidget);
    expect(find.byType(ControlSidebar), findsNothing);

    final inset = BottomInsetScope.of(
      tester.element(find.text('page:dashboard')),
    );
    expect(inset, 0);

    final dock = tester.getRect(find.byType(GlassDock));
    expect(
      tester.getRect(find.byType(PageView).first).bottom,
      lessThanOrEqualTo(dock.top),
    );
    final tools = tester.getRect(
      find.descendant(
        of: find.byType(GlassDock),
        matching: find.byWidgetPredicate(
          (widget) =>
              widget is NavigationDestination &&
              widget.label == PageLabel.tools.label,
        ),
      ),
    );
    expect(tools.center.dy, closeTo(dock.center.dy, 12));
    await tester.tapAt(tools.bottomCenter - const Offset(0, 2));
    await tester.pumpAndSettle();
    expect(container.read(currentPageLabelProvider), PageLabel.tools);
    expect(find.text('page:tools').hitTestable(), findsOneWidget);
  });

  testWidgets('resizing across every breakpoint keeps the page state', (
    tester,
  ) async {
    final container = _container(
      tester,
      const Size(1200, 800),
      items: [
        _item(
          PageLabel.profiles,
          Icons.folder,
          builder: (_) =>
              const _StatefulContent(key: GlobalObjectKey(PageLabel.profiles)),
        ),
        _item(PageLabel.tools, Icons.construction),
      ],
    );
    container
        .read(currentPageLabelProvider.notifier)
        .toPage(PageLabel.profiles);
    await _pumpHome(tester, container);

    await tester.tap(find.text('count: 0'));
    await tester.pump();
    for (final size in const [
      Size(700, 800),
      Size(400, 800),
      Size(1200, 800),
    ]) {
      await _resize(tester, container, size);
      expect(find.text('count: 1'), findsOneWidget, reason: '$size');
      expect(tester.takeException(), isNull, reason: '$size');
    }
  });

  testWidgets('list content stays valid while resizing through breakpoints', (
    tester,
  ) async {
    final container = _container(
      tester,
      const Size(1200, 800),
      items: [
        _item(
          PageLabel.tools,
          Icons.construction,
          builder: (_) =>
              const ToolsView(key: GlobalObjectKey(PageLabel.tools)),
        ),
        _item(PageLabel.profiles, Icons.folder),
      ],
    );
    container.read(currentPageLabelProvider.notifier).toPage(PageLabel.tools);
    await _pumpHome(tester, container);

    for (var width = 1180.0; width >= 380; width -= 40) {
      tester.view.physicalSize = Size(width, 800);
      container.read(viewSizeProvider.notifier).value = Size(width, 800);
      await tester.pump(const Duration(milliseconds: 16));
      expect(tester.takeException(), isNull, reason: 'width: $width');
    }
  });

  testWidgets('switching home pages exits a generic search layer', (
    tester,
  ) async {
    var query = '';
    final container = _container(
      tester,
      const Size(500, 800),
      items: [
        _item(
          PageLabel.dashboard,
          Icons.space_dashboard,
          builder: (_) => CommonScaffold(
            title: 'Search page',
            searchState: AppBarSearchState(onSearch: (value) => query = value),
            body: const SizedBox(),
          ),
        ),
        _item(PageLabel.tools, Icons.construction),
      ],
    );
    await _pumpHome(tester, container);

    await tester.tap(find.byIcon(Icons.search));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'needle');
    expect(query, 'needle');

    await tester.tap(find.byIcon(Icons.construction));
    await tester.pumpAndSettle();
    expect(query, isEmpty);
    await tester.tap(find.byIcon(Icons.space_dashboard));
    await tester.pumpAndSettle();
    expect(find.byType(TextField), findsNothing);
  });

  testWidgets('a desktop nested route inherits its page activity', (
    tester,
  ) async {
    var query = '';
    final container = _container(
      tester,
      const Size(1200, 800),
      items: [
        _item(
          PageLabel.profiles,
          Icons.folder,
          builder: (_) =>
              _NestedSearchLauncher(onSearch: (value) => query = value),
        ),
        _item(PageLabel.tools, Icons.construction),
      ],
    );
    container
        .read(currentPageLabelProvider.notifier)
        .toPage(PageLabel.profiles);
    await _pumpHome(tester, container);

    await tester.tap(find.text('Open nested search'));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.search));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'needle');
    expect(query, 'needle');

    final sidebar = find.byType(ControlSidebar);
    await tester.tap(
      find.descendant(of: sidebar, matching: find.byIcon(Icons.construction)),
    );
    await tester.pumpAndSettle();
    expect(query, isEmpty);

    await tester.tap(
      find.descendant(of: sidebar, matching: find.byIcon(Icons.folder)),
    );
    await tester.pumpAndSettle();
    expect(find.text('Nested search'), findsOneWidget);
    expect(find.byType(TextField), findsNothing);
  });
}

class _ThemeManagedTestApp extends StatelessWidget {
  const _ThemeManagedTestApp();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: globalState.navigatorKey,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        ...GlobalMaterialLocalizations.delegates,
      ],
      supportedLocales: AppLocalizations.delegate.supportedLocales,
      builder: (_, child) => ThemeManager(child: child!),
      home: const HomePage(),
    );
  }
}

class _StatefulContent extends StatefulWidget {
  const _StatefulContent({super.key});

  @override
  State<_StatefulContent> createState() => _StatefulContentState();
}

class _StatefulContentState extends State<_StatefulContent> {
  var _count = 0;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: TextButton(
        onPressed: () => setState(() => _count++),
        child: Text('count: $_count'),
      ),
    );
  }
}

class _NestedSearchLauncher extends StatelessWidget {
  final ValueChanged<String> onSearch;

  const _NestedSearchLauncher({required this.onSearch});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: FilledButton(
        onPressed: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => CommonScaffold(
                title: 'Nested search',
                searchState: AppBarSearchState(onSearch: onSearch),
                body: const SizedBox(),
              ),
            ),
          );
        },
        child: const Text('Open nested search'),
      ),
    );
  }
}

class _HomeTestProfiles extends Profiles {
  final List<Profile> initial;

  _HomeTestProfiles(this.initial);

  @override
  List<Profile> build() => initial;
}
