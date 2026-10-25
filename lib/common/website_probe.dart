import 'dart:async';
import 'dart:io';

class WebsiteProbe {
  final Set<HttpClient> _clients = {};

  Future<int> measure(
    Uri uri, {
    required String proxy,
    Duration timeout = const Duration(seconds: 8),
  }) async {
    final client = HttpClient()
      ..connectionTimeout = timeout
      ..findProxy = (_) => proxy;
    _clients.add(client);
    final watch = Stopwatch()..start();
    try {
      await (() async {
        final request = await client.openUrl('HEAD', uri);
        request
          ..followRedirects = false
          ..persistentConnection = false;
        await request.close();
      })().timeout(timeout);
      return watch.elapsedMilliseconds.clamp(1, 0x7fffffff);
    } on Exception {
      return -1;
    } finally {
      watch.stop();
      _clients.remove(client);
      client.close(force: true);
    }
  }

  void close() {
    for (final client in _clients) {
      client.close(force: true);
    }
    _clients.clear();
  }
}
