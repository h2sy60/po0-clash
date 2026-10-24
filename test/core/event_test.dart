import 'package:fl_clash/core/event.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/models/models.dart';
import 'package:flutter_test/flutter_test.dart';

class _RecordingListener with CoreEventListener {
  _RecordingListener({this.onLoadedCallback, this.onLogCallback});

  final void Function()? onLoadedCallback;
  final void Function()? onLogCallback;
  final List<String> loaded = [];
  final List<Log> logs = [];
  final List<Delay> delays = [];
  final List<TrackerInfo> requests = [];

  @override
  void onLog(Log log) {
    logs.add(log);
    onLogCallback?.call();
  }

  @override
  void onDelay(Delay delay) => delays.add(delay);

  @override
  void onRequest(TrackerInfo request) => requests.add(request);

  @override
  void onLoaded(String providerName) {
    loaded.add(providerName);
    onLoadedCallback?.call();
  }
}

void main() {
  test('event parsing skips non-string map keys and keeps valid events', () {
    final events = coreEventsFromData([
      {'type': 'loaded', 'data': 'first'},
      <Object, Object?>{1: 'invalid'},
      42,
      <dynamic, dynamic>{'type': 'loaded', 'data': 'second'},
    ]);
    expect(events.map((event) => event.data), ['first', 'second']);
  });

  test('immutable event models are parsed once for all listeners', () async {
    final first = _RecordingListener();
    final second = _RecordingListener();
    coreEventManager.addListener(first);
    coreEventManager.addListener(second);
    addTearDown(() {
      coreEventManager.removeListener(first);
      coreEventManager.removeListener(second);
    });
    coreEventManager.sendEvent(
      const CoreEvent(
        type: CoreEventType.log,
        data: {'LogLevel': 'info', 'Payload': 'hello'},
      ),
    );
    coreEventManager.sendEvent(
      const CoreEvent(
        type: CoreEventType.delay,
        data: {'url': 'https://example.test', 'name': 'node', 'value': 123},
      ),
    );
    coreEventManager.sendEvent(
      const CoreEvent(
        type: CoreEventType.request,
        data: {
          'id': 'request',
          'start': '2026-10-25T00:00:00Z',
          'metadata': <String, Object?>{},
          'chains': ['node'],
          'rule': 'MATCH',
          'rulePayload': '',
        },
      ),
    );
    await pumpEventQueue();
    expect(first.logs.single.payload, 'hello');
    expect(first.logs.single, same(second.logs.single));
    expect(first.delays.single.value, 123);
    expect(first.delays.single, same(second.delays.single));
    expect(first.requests.single.id, 'request');
    expect(first.requests.single, same(second.requests.single));
  });

  test(
    'a throwing listener does not interrupt the remaining listeners',
    () async {
      final first = _RecordingListener(
        onLogCallback: () => throw StateError('listener failure'),
      );
      final second = _RecordingListener();
      coreEventManager.addListener(first);
      coreEventManager.addListener(second);
      addTearDown(() {
        coreEventManager.removeListener(first);
        coreEventManager.removeListener(second);
      });
      for (final payload in ['first', 'second']) {
        coreEventManager.sendEvent(
          CoreEvent(
            type: CoreEventType.log,
            data: {'LogLevel': 'info', 'Payload': payload},
          ),
        );
      }
      await pumpEventQueue();
      expect(second.logs.map((log) => log.payload), ['first', 'second']);
      expect(first.logs.first, same(second.logs.first));
    },
  );

  test('listener changes apply on the next event', () async {
    final lateListener = _RecordingListener();
    final removed = _RecordingListener();
    late _RecordingListener first;
    first = _RecordingListener(
      onLoadedCallback: () {
        coreEventManager.removeListener(first);
        coreEventManager.removeListener(removed);
        coreEventManager.addListener(lateListener);
      },
    );
    coreEventManager.addListener(first);
    coreEventManager.addListener(removed);
    addTearDown(() {
      coreEventManager.removeListener(first);
      coreEventManager.removeListener(removed);
      coreEventManager.removeListener(lateListener);
    });
    coreEventManager.sendEvent(
      const CoreEvent(type: CoreEventType.loaded, data: 'first'),
    );
    coreEventManager.sendEvent(
      const CoreEvent(type: CoreEventType.loaded, data: 'second'),
    );
    await pumpEventQueue();
    expect(first.loaded, ['first']);
    expect(removed.loaded, ['first']);
    expect(lateListener.loaded, ['second']);
  });

  test(
    'a listener may unregister itself while an event is dispatched',
    () async {
      late _RecordingListener first;
      final second = _RecordingListener();
      first = _RecordingListener(
        onLoadedCallback: () => coreEventManager.removeListener(first),
      );

      coreEventManager.addListener(first);
      coreEventManager.addListener(second);
      addTearDown(() {
        coreEventManager.removeListener(first);
        coreEventManager.removeListener(second);
      });

      coreEventManager.sendEvent(
        const CoreEvent(type: CoreEventType.loaded, data: 'provider-a'),
      );
      await pumpEventQueue();

      expect(first.loaded, ['provider-a']);
      expect(second.loaded, ['provider-a']);

      coreEventManager.sendEvent(
        const CoreEvent(type: CoreEventType.loaded, data: 'provider-b'),
      );
      await pumpEventQueue();

      expect(first.loaded, ['provider-a']);
      expect(second.loaded, ['provider-a', 'provider-b']);
    },
  );
}
