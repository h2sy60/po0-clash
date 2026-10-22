import 'dart:io';

import 'package:collection/collection.dart';
import 'package:fl_clash/common/node_profile.dart';
import 'package:test/test.dart';
import 'package:yaml/yaml.dart';

ProxyNode _trojan(String name, {String server = 'a.example.com'}) => {
  'name': name,
  'type': 'trojan',
  'server': server,
  'port': 443,
  'password': 'secret',
  'udp': true,
};

Map<String, dynamic> _groupNamed(Object? config, String name) {
  final groups = (config! as Map)['proxy-groups'] as List;
  return Map<String, dynamic>.from(
    groups.cast<Map>().firstWhere((group) => group['name'] == name),
  );
}

void main() {
  group('isShareLinkText', () {
    test('accepts any line with a share-link scheme', () {
      expect(isShareLinkText('vless://id@host:443#a'), isTrue);
      expect(isShareLinkText('note\n  HY2://pw@host:443'), isTrue);
      expect(isShareLinkText('hysteria2+realm://x'), isTrue);
    });

    test('leaves subscription URLs and plain text alone', () {
      expect(isShareLinkText('https://example.com/sub?token=1'), isFalse);
      expect(isShareLinkText('http://user:pw@host:8080'), isFalse);
      expect(isShareLinkText('just some text'), isFalse);
      expect(isShareLinkText('://nothing'), isFalse);
    });
  });

  group('bundled template', () {
    final source = File(nodeProfileTemplateAsset).readAsStringSync();
    final template = NodeProfileTemplate(source);

    test('fills proxies and drops placeholders mihomo already covers', () {
      final nodes = [_trojan('HK-01'), _trojan('JP-01', server: 'b.example')];

      final config = loadYaml(template.render(nodes));

      expect(nodesOfProfile(template.render(nodes)), nodes);
      expect(_groupNamed(config, '🚀 默认节点')['proxies'], isEmpty);
      expect(_groupNamed(config, '🌐 DNS 解析组')['proxies'], ['🚀 默认节点']);
      final rendered = template.render(nodes);
      expect(rendered, isNot(contains('__PROXY_NODES__')));
      expect(rendered, isNot(contains('__PROXY_PROVIDERS__')));
    });

    test('keeps every other setting of the template', () {
      final original = loadYaml(source) as Map;
      final config = loadYaml(template.render([])) as Map;

      expect(config['bind-address'], '*');
      expect(config['find-process-mode'], 'off');
      expect(config['mixed-port'], 7890);
      expect(
        (config['dns'] as Map)['nameserver'],
        (original['dns'] as Map)['nameserver'],
      );
      expect(config['rules'], original['rules']);
      expect(config['rule-providers'], original['rule-providers']);
      expect(config['proxies'], isEmpty);
    });

    test('reserves the group and built-in names', () {
      expect(
        template.reservedNames,
        containsAll(['🚀 默认节点', '🌐 DNS 解析组', 'DIRECT', 'REJECT', 'GLOBAL']),
      );
    });
  });

  group('NodeProfileTemplate', () {
    const source = '''
proxy-providers:
  remote:
    type: http
    url: https://example.com/sub
proxy-groups:
  - name: pick
    type: select
    proxies:
      - DIRECT
      - __PROXY_NODES__
      - __PROXY_PROVIDERS__
  - name: only-nodes
    type: url-test
    proxies:
      - __PROXY_NODES__
''';

    test('expands placeholders in groups that list members', () {
      final config = loadYaml(
        NodeProfileTemplate(
          source,
        ).render([_trojan('B'), _trojan('A', server: 'c.example')]),
      );

      final pick = _groupNamed(config, 'pick');
      expect(pick['proxies'], ['DIRECT', 'B', 'A']);
      expect(pick['use'], ['remote']);
      expect(_groupNamed(config, 'only-nodes')['proxies'], ['B', 'A']);
    });

    test('falls back to DIRECT when a group would have no members', () {
      final config = loadYaml(NodeProfileTemplate(source).render([]));

      expect(_groupNamed(config, 'only-nodes')['proxies'], ['DIRECT']);
    });

    test('round-trips names and secrets YAML would otherwise retype', () {
      final names = [
        '!HK',
        '+1',
        'True',
        'null',
        '2024-01-01',
        '1e3',
        '0x1F',
        '`tick',
        'a #b',
        '"quoted"',
        "it's",
        '- dash',
        '香港 01 🇭🇰',
      ];
      final nodes = [
        for (final (index, name) in names.indexed)
          {..._trojan(name, server: 'h$index.example'), 'password': name},
      ];

      final parsed = nodesOfProfile(NodeProfileTemplate(source).render(nodes));

      expect(const DeepCollectionEquality().equals(parsed, nodes), isTrue);
    });
  });

  group('mergeNodes', () {
    test('skips nodes whose settings are already present', () {
      final merge = mergeNodes(
        [_trojan('HK')],
        [_trojan('HK copy'), _trojan('JP', server: 'b.example')],
        reservedNames: {},
      );

      expect(merge.added, 1);
      expect(merge.skipped, 1);
      expect(merge.nodes.map((node) => node.nodeName), ['HK', 'JP']);
    });

    test('renames clashes with existing, reserved and empty names', () {
      final merge = mergeNodes(
        [_trojan('HK')],
        [
          _trojan('HK', server: 'b.example'),
          _trojan('DIRECT', server: 'c.example'),
          _trojan(' ', server: 'd.example'),
          {..._trojan('', server: '2001:db8::1'), 'port': 8443},
        ],
        reservedNames: {'DIRECT'},
      );

      expect(merge.nodes.map((node) => node.nodeName), [
        'HK',
        'HK 2',
        'DIRECT 2',
        'd.example:443',
        '[2001:db8::1]:8443',
      ]);
    });
  });

  test('uniqueNodeName counts past taken suffixes', () {
    expect(uniqueNodeName('A', {}), 'A');
    expect(uniqueNodeName('A', {'A', 'A 2', 'A 3'}), 'A 4');
  });

  test('nodesOfProfile tolerates profiles without proxies', () {
    expect(nodesOfProfile(''), isEmpty);
    expect(nodesOfProfile('mode: rule'), isEmpty);
    expect(nodesOfProfile('proxies: [1, {name: a}]'), [
      {'name': 'a'},
    ]);
  });
}
