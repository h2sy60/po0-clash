import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/common/node_profile.dart';
import 'package:fl_clash/providers/app.dart';
import 'package:fl_clash/providers/node_profile.dart';
import 'package:fl_clash/state.dart';
import 'package:fl_clash/views/profiles/nodes.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import '../helpers/test_app.dart';

class _FakeNodeProfileAction extends NodeProfileAction {
  final renamed = <(String, String)>[];
  final deleted = <String>[];
  final imported = <String>[];

  @override
  Future<void> renameNode(String from, String to) async =>
      renamed.add((from, to));

  @override
  Future<void> deleteNode(String name) async => deleted.add(name);

  @override
  Future<void> importWithFeedback(String text) async => imported.add(text);
}

const _nodes = <ProxyNode>[
  {'name': 'HK', 'type': 'vless', 'server': '203.0.113.7', 'port': 443},
  {'name': 'JP', 'type': 'hysteria2', 'server': '2001:db8::1', 'port': 8443},
];

Future<_FakeNodeProfileAction> _pump(
  WidgetTester tester, {
  List<ProxyNode> nodes = _nodes,
}) async {
  const size = Size(1200, 1000);
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final action = _FakeNodeProfileAction();
  final container = ProviderContainer(
    overrides: [
      nodeProfileNodesProvider.overrideWith((ref) async => nodes),
      nodeProfileActionProvider.overrideWith(() => action),
    ],
  );
  addTearDown(container.dispose);
  globalState.container = container;
  container.read(viewSizeProvider.notifier).update((_) => size);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: const TestApp(child: NodesView()),
    ),
  );
  await tester.pumpAndSettle();
  return action;
}

void main() {
  testWidgets('lists each node with its protocol and address', (tester) async {
    await _pump(tester);

    final l10n = currentAppLocalizations;
    expect(find.text('HK'), findsOne);
    expect(find.text('VLESS · 203.0.113.7:443'), findsOne);
    expect(find.text('HYSTERIA2 · [2001:db8::1]:8443'), findsOne);
    expect(find.text(l10n.manualNodesTip), findsOne);
    expect(tester.takeException(), null);
  });

  testWidgets('shows the empty state without nodes', (tester) async {
    await _pump(tester, nodes: const []);

    expect(find.text(currentAppLocalizations.noNodes), findsOne);
  });

  testWidgets('renames a node and refuses a name another node uses', (
    tester,
  ) async {
    final action = await _pump(tester);
    final l10n = currentAppLocalizations;

    await tester.tap(find.byTooltip(l10n.rename).first);
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField), 'JP');
    await tester.tap(find.text(l10n.submit));
    await tester.pumpAndSettle();

    expect(find.text(l10n.nodeNameDuplicate), findsOne);
    expect(action.renamed, isEmpty);

    await tester.enterText(find.byType(TextFormField), ' HK-01 ');
    await tester.tap(find.text(l10n.submit));
    await tester.pumpAndSettle();

    expect(action.renamed, [('HK', 'HK-01')]);
  });

  testWidgets('deletes a node only after confirmation', (tester) async {
    final action = await _pump(tester);
    final l10n = currentAppLocalizations;

    await tester.tap(find.byTooltip(l10n.delete).last);
    await tester.pumpAndSettle();
    await tester.tap(find.text(l10n.cancel));
    await tester.pumpAndSettle();
    expect(action.deleted, isEmpty);

    await tester.tap(find.byTooltip(l10n.delete).last);
    await tester.pumpAndSettle();
    await tester.tap(find.text(l10n.confirm));
    await tester.pumpAndSettle();
    expect(action.deleted, ['JP']);
  });

  testWidgets('imports the pasted share links', (tester) async {
    final action = await _pump(tester);
    final l10n = currentAppLocalizations;

    await tester.tap(find.text(l10n.import));
    await tester.pumpAndSettle();
    await tester.tap(find.text(l10n.submit));
    await tester.pumpAndSettle();
    expect(action.imported, isEmpty, reason: 'empty input must not submit');

    await tester.enterText(find.byType(TextFormField), 'vless://a@b:443#c');
    await tester.tap(find.text(l10n.submit));
    await tester.pumpAndSettle();

    expect(action.imported, ['vless://a@b:443#c']);
  });
}
