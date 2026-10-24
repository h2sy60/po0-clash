import 'dart:collection';

import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/models/models.dart';
import 'package:flutter_test/flutter_test.dart';

class _ReadCountingList<T> extends ListBase<T> {
  _ReadCountingList(this._items);

  final List<T> _items;
  int reads = 0;

  @override
  int get length => _items.length;

  @override
  set length(int value) => throw UnsupportedError('read only');

  @override
  T operator [](int index) {
    reads++;
    return _items[index];
  }

  @override
  void operator []=(int index, T value) => throw UnsupportedError('read only');
}

void main() {
  const logs = [
    Log(payload: 'Alpha connected', dateTime: '', logLevel: LogLevel.info),
    Log(payload: 'Beta retry', dateTime: '', logLevel: LogLevel.warning),
    Log(payload: 'Gamma failed', dateTime: '', logLevel: LogLevel.error),
  ];
  final requests = [
    TrackerInfo(
      id: 'a',
      start: DateTime.utc(2026),
      rule: 'MATCH',
      rulePayload: '',
      metadata: const Metadata(
        network: 'TCP',
        host: 'Alpha.Example',
        destinationIP: '2001:db8::1',
        process: 'Curl',
      ),
      chains: const ['USA', 'Proxy A'],
    ),
    TrackerInfo(
      id: 'b',
      start: DateTime.utc(2026),
      rule: 'MATCH',
      rulePayload: '',
      metadata: const Metadata(
        network: 'udp',
        host: 'Beta.Example',
        destinationIP: '1.2.3.4',
        process: 'curl',
      ),
      chains: const ['Japan', 'Proxy B'],
    ),
  ];

  test('unfiltered logs do not scan the buffer', () {
    final source = _ReadCountingList(logs);
    final list = LogsState(logs: source).list;
    expect(list.length, logs.length);
    expect(source.reads, 0);
    expect(list, logs);
  });

  test('unfiltered requests and whitespace queries do not scan the buffer', () {
    for (final query in ['', '  ']) {
      final source = _ReadCountingList(requests);
      final list = TrackerInfosState(trackerInfos: source, query: query).list;
      expect(list.length, requests.length);
      expect(source.reads, 0);
      expect(list, requests);
    }
  });

  test('log filters preserve payload, level, and exact keyword matching', () {
    List<String> filter(String query, List<String> keywords) => LogsState(
      logs: logs,
      query: query,
      keywords: keywords,
    ).list.map((log) => log.payload).toList();

    expect(filter('ALPHA', []), ['Alpha connected']);
    expect(filter('WARN', []), ['Beta retry']);
    expect(filter('', ['info', 'info']), ['Alpha connected']);
    expect(filter('connected', ['info']), ['Alpha connected']);
    expect(filter('', ['info', 'warning']), isEmpty);
    expect(filter('', ['INFO']), isEmpty);
    expect(filter(' ', []), logs.map((log) => log.payload));
  });

  test('request filters preserve field, query, and keyword semantics', () {
    List<String> filter(String query, List<String> keywords) =>
        TrackerInfosState(
          trackerInfos: requests,
          query: query,
          keywords: keywords,
        ).list.map((request) => request.id).toList();

    expect(filter(' TCP ', []), ['a']);
    expect(filter('ALPHA', []), ['a']);
    expect(filter('1.2.3.4', []), ['b']);
    expect(filter('2001:DB8', []), ['a']);
    expect(filter(' 2001:db8::1 ', []), isEmpty);
    expect(filter('CURL', []), ['a', 'b']);
    expect(filter('proxy a', []), ['a']);
    expect(filter('', ['USA', 'Curl']), ['a']);
    expect(filter('', ['USA', 'USA']), ['a']);
    expect(filter('', ['USA', 'curl']), isEmpty);
    expect(filter('beta', ['Japan']), ['b']);
  });
}
