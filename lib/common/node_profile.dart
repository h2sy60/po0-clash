import 'package:collection/collection.dart';
import 'package:yaml/yaml.dart';
import 'package:yaml_writer/yaml_writer.dart';

typedef ProxyNode = Map<String, dynamic>;

typedef NodeMerge = ({List<ProxyNode> nodes, int added, int skipped});

const nodeProfileTemplateAsset = 'assets/data/node_profile_template.yaml';

const _nodesPlaceholder = '__PROXY_NODES__';
const _providersPlaceholder = '__PROXY_PROVIDERS__';

const _builtinProxyNames = {
  'DIRECT',
  'REJECT',
  'REJECT-DROP',
  'PASS',
  'PASS-RULE',
  'COMPATIBLE',
  'GLOBAL',
};

// Schemes mihomo's share-link converter understands. http and https are left
// out on purpose: a lone http(s) URL is a subscription, not an HTTP proxy.
const _shareLinkSchemes = {
  'vmess',
  'vless',
  'trojan',
  'ss',
  'ssr',
  'tuic',
  'anytls',
  'mierus',
  'hysteria',
  'hysteria2',
  'hy2',
  'hysteria2+realm',
  'hy2+realm',
  'socks',
  'socks5',
  'socks5h',
};

bool isShareLinkText(String text) => text.split('\n').any((line) {
  final index = line.indexOf('://');
  return index > 0 &&
      _shareLinkSchemes.contains(line.substring(0, index).trim().toLowerCase());
});

extension ProxyNodeExt on ProxyNode {
  String get nodeName => this['name']?.toString() ?? '';

  String get nodeType => this['type']?.toString() ?? '';

  String get nodeAddress {
    final server = this['server']?.toString() ?? '';
    final host = server.contains(':') ? '[$server]' : server;
    return '$host:${this['port'] ?? ''}';
  }
}

class NodeProfileTemplate {
  NodeProfileTemplate(String source) : _config = _plainMap(loadYaml(source));

  final Map<String, dynamic> _config;

  Set<String> get reservedNames => {
    ..._builtinProxyNames,
    for (final group in _groupsOf(_config)) group['name'].toString(),
  };

  String render(List<ProxyNode> nodes) {
    final config = _plainMap(_config);
    final nodeNames = [for (final node in nodes) node.nodeName];
    final providers = config['proxy-providers'];
    final providerNames = [
      if (providers is Map) ...providers.keys.map((key) => key.toString()),
    ];
    config['proxies'] = nodes;
    config['proxy-groups'] = [
      for (final group in _groupsOf(config))
        _fillGroup(group, nodeNames, providerNames),
    ];
    // Node names, passwords and UUIDs are user text; quoting every string keeps
    // values such as `!HK`, `+1` or `2024-01-01` from being read as tags,
    // numbers or dates.
    return YamlWriter.config(
      config: const YamlWriterConfig(forceQuotedString: true),
    ).convert(config);
  }
}

List<ProxyNode> nodesOfProfile(String content) {
  final config = loadYaml(content);
  final proxies = config is Map ? config['proxies'] : null;
  return [
    if (proxies is List)
      for (final node in proxies)
        if (node is Map) _plainMap(node),
  ];
}

NodeMerge mergeNodes(
  List<ProxyNode> current,
  List<ProxyNode> incoming, {
  required Set<String> reservedNames,
}) {
  final nodes = [...current];
  final taken = {...reservedNames, ...current.map((node) => node.nodeName)};
  var skipped = 0;
  for (final node in incoming) {
    if (nodes.any((it) => _sameEndpoint(it, node))) {
      skipped++;
      continue;
    }
    final name = node.nodeName.trim();
    final unique = uniqueNodeName(
      name.isEmpty ? node.nodeAddress : name,
      taken,
    );
    taken.add(unique);
    nodes.add({...node, 'name': unique});
  }
  return (nodes: nodes, added: nodes.length - current.length, skipped: skipped);
}

String uniqueNodeName(String name, Set<String> taken) {
  if (!taken.contains(name)) {
    return name;
  }
  var index = 2;
  while (taken.contains('$name $index')) {
    index++;
  }
  return '$name $index';
}

bool _sameEndpoint(ProxyNode a, ProxyNode b) => const DeepCollectionEquality()
    .equals({...a}..remove('name'), {...b}..remove('name'));

Iterable<Map<String, dynamic>> _groupsOf(Map<String, dynamic> config) {
  final groups = config['proxy-groups'];
  return groups is List ? groups.whereType<Map<String, dynamic>>() : const [];
}

Map<String, dynamic> _fillGroup(
  Map<String, dynamic> group,
  List<String> nodeNames,
  List<String> providerNames,
) {
  final includeAll = group['include-all'] == true;
  final allProxies = includeAll || group['include-all-proxies'] == true;
  final allProviders = includeAll || group['include-all-providers'] == true;
  final proxies = <String>[];
  final use = [
    for (final name in group['use'] as List? ?? const []) name.toString(),
  ];
  for (final member in group['proxies'] as List? ?? const []) {
    if (member == _nodesPlaceholder) {
      if (!allProxies) {
        proxies.addAll(nodeNames);
      }
    } else if (member == _providersPlaceholder) {
      if (!allProviders) {
        use.addAll(providerNames.whereNot(use.contains));
      }
    } else {
      proxies.add(member.toString());
    }
  }
  final pullsProviders = allProviders && providerNames.isNotEmpty;
  if (proxies.isEmpty && use.isEmpty && !allProxies && !pullsProviders) {
    proxies.add('DIRECT');
  }
  return {...group, 'proxies': proxies, if (use.isNotEmpty) 'use': use};
}

Map<String, dynamic> _plainMap(Object? value) =>
    value is Map ? _plain(value) as Map<String, dynamic> : {};

Object? _plain(Object? value) => switch (value) {
  Map() => <String, dynamic>{
    for (final entry in value.entries)
      entry.key.toString(): _plain(entry.value),
  },
  List() => [for (final item in value) _plain(item)],
  _ => value,
};
