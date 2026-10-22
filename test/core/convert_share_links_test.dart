import 'package:fl_clash/core/desktop/model.dart';
import 'package:fl_clash/core/interface.dart';
import 'package:fl_clash/core/method.dart';
import 'package:test/test.dart';

class _RecordingCore extends CoreHandlerInterface {
  _RecordingCore(this.result);

  final Object? result;
  final calls = <(CoreMethod, Object?)>[];

  @override
  Future<T?> invokeMethod<T>({
    required CoreMethod method,
    Object? arguments,
    Duration? timeout,
  }) async {
    calls.add((method, arguments));
    return result as T?;
  }

  @override
  Future<CoreLifecycleResult> start() async => _unused;

  @override
  Future<CoreLifecycleResult> restart() async => _unused;

  @override
  Future<CoreLifecycleResult> stop() async => _unused;

  @override
  Future<CoreLifecycleResult> close() async => _unused;
}

const _unused = CoreLifecycleResult(
  revision: 0,
  outcome: CoreLifecycleOutcome.applied,
);

void main() {
  test('sends the raw text and decodes each proxy mapping', () async {
    final core = _RecordingCore([
      {'name': 'HK', 'type': 'vless', 'port': 443},
    ]);

    final proxies = await core.convertShareLinks('vless://x');

    expect(core.calls, [(CoreMethod.convertShareLinks, 'vless://x')]);
    expect(proxies, [
      {'name': 'HK', 'type': 'vless', 'port': 443},
    ]);
  });

  test('treats a missing answer as no proxies', () async {
    expect(await _RecordingCore(null).convertShareLinks('x'), isEmpty);
  });
}
