import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/models/models.dart';

class ProxySelectionResolver {
  ProxySelectionResolver({
    required List<Group> groups,
    required Map<String, String> selectedMap,
  }) : _groups = {for (final group in groups) group.name: group},
       _selectedMap = selectedMap;

  final Map<String, Group> _groups;
  final Map<String, String> _selectedMap;
  final Map<String, SelectedProxyState> _resolved = {};

  SelectedProxyState resolve(String proxyName) {
    return _resolved.putIfAbsent(proxyName, () {
      var current = proxyName;
      String? testUrl;
      Set<String>? visited;
      while (current.isNotEmpty) {
        final group = _groups[current];
        if (group == null) break;
        if (!(visited ??= <String>{}).add(current)) break;
        final selected = group.getCurrentSelectedName(
          _selectedMap[current] ?? '',
        );
        if (selected.isEmpty) break;
        current = selected;
        testUrl = group.testUrl;
      }
      return SelectedProxyState(
        proxyName: current,
        group: proxyName.isNotEmpty,
        testUrl: testUrl,
      );
    });
  }
}

List<Group> computeSort({
  required List<Group> groups,
  required ProxiesSortType sortType,
  required DelayMap delayMap,
  required Map<String, String> selectedMap,
  required String defaultTestUrl,
}) {
  if (sortType == ProxiesSortType.none) return groups;
  late final resolver = ProxySelectionResolver(
    groups: groups,
    selectedMap: selectedMap,
  );
  late final delays = <String, Map<String, DelayState>>{};
  List<Proxy> sortOfDelay({
    required List<Proxy> proxies,
    required String testUrl,
  }) {
    final byName = delays.putIfAbsent(testUrl, () => {});
    for (final proxy in proxies) {
      byName.putIfAbsent(proxy.name, () {
        final selected = resolver.resolve(proxy.name);
        return DelayState(
          delay:
              delayMap[selected.testUrl.takeFirstValid([
                testUrl,
              ])]?[selected.proxyName] ??
              0,
          group: selected.group,
        );
      });
    }
    return List.of(proxies)
      ..sort((a, b) => byName[a.name]!.compareTo(byName[b.name]!));
  }

  List<Proxy> sortOfName(List<Proxy> proxies) {
    return List.of(proxies)..sort((a, b) => a.name.compareTo(b.name));
  }

  return groups.map((group) {
    final proxies = group.all;
    final newProxies = switch (sortType) {
      ProxiesSortType.none => proxies,
      ProxiesSortType.delay => sortOfDelay(
        proxies: proxies,
        testUrl: group.testUrl.takeFirstValid([defaultTestUrl]),
      ),
      ProxiesSortType.name => sortOfName(proxies),
    };
    return group.copyWith(all: newProxies);
  }).toList();
}

SelectedProxyState computeRealSelectedProxyState(
  String proxyName, {
  required List<Group> groups,
  required Map<String, String> selectedMap,
}) {
  return ProxySelectionResolver(
    groups: groups,
    selectedMap: selectedMap,
  ).resolve(proxyName);
}

String delayTestKey(String testUrl, String proxyName) {
  return '$testUrl\u0000$proxyName';
}

String resolveDelayTestUrl({
  String? requestedUrl,
  String? groupUrl,
  required String fallbackUrl,
}) {
  return requestedUrl.takeFirstValid([groupUrl, fallbackUrl]);
}

DelayState computeProxyDelayState({
  required String proxyName,
  required String testUrl,
  required List<Group> groups,
  required Map<String, String> selectedMap,
  required DelayMap delayMap,
}) {
  final state = computeRealSelectedProxyState(
    proxyName,
    groups: groups,
    selectedMap: selectedMap,
  );
  final currentDelayMap =
      delayMap[state.testUrl.takeFirstValid([testUrl])] ?? {};
  final delay = currentDelayMap[state.proxyName];
  return DelayState(delay: delay ?? 0, group: state.group);
}
