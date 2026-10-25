import 'dart:async';
import 'dart:io';

import 'package:fl_clash/common/website_probe.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'website probes send each destination through the mixed proxy',
    () async {
      final proxy = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      final destinations = <Uri>[];
      final methods = <String>[];
      final received = Completer<void>();
      proxy.listen((request) async {
        destinations.add(request.uri);
        methods.add(request.method);
        request.response.statusCode = HttpStatus.forbidden;
        await request.response.close();
        if (destinations.length == 2) received.complete();
      });
      final probe = WebsiteProbe();
      addTearDown(probe.close);
      addTearDown(() => proxy.close(force: true));
      final sites = [
        Uri.parse('http://google.test/'),
        Uri.parse('http://github.test/'),
      ];
      final delays = await Future.wait([
        for (final site in sites)
          probe.measure(site, proxy: 'PROXY 127.0.0.1:${proxy.port}'),
      ]);
      await received.future;
      expect(destinations.toSet(), sites.toSet());
      expect(methods, ['HEAD', 'HEAD']);
      expect(delays, everyElement(greaterThan(0)));
    },
  );

  test('a timeout closes the request instead of retaining it', () async {
    final proxy = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    proxy.listen((_) {});
    final probe = WebsiteProbe();
    addTearDown(probe.close);
    addTearDown(() => proxy.close(force: true));
    expect(
      await probe.measure(
        Uri.parse('http://timeout.test/'),
        proxy: 'PROXY 127.0.0.1:${proxy.port}',
        timeout: const Duration(milliseconds: 100),
      ),
      -1,
    );
  });

  test('closing the probe cancels in-flight requests', () async {
    final proxy = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final received = Completer<void>();
    proxy.listen((_) => received.complete());
    final probe = WebsiteProbe();
    addTearDown(probe.close);
    addTearDown(() => proxy.close(force: true));
    final delay = probe.measure(
      Uri.parse('http://cancelled.test/'),
      proxy: 'PROXY 127.0.0.1:${proxy.port}',
    );
    await received.future;
    probe.close();
    expect(await delay, -1);
  });
}
