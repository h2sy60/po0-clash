import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:setup_hooks/src/build_cache.dart';
import 'package:setup_hooks/src/error.dart';
import 'package:setup_hooks/src/fingerprint.dart';
import 'package:setup_hooks/src/util.dart';
import 'package:setup_hooks/src/windows_signing.dart';
import 'package:test/test.dart';

void main() {
  late Directory root;
  final thumbprint = List.filled(40, 'A').join();

  setUp(() {
    root = Directory.systemTemp.createTempSync('windows signing ');
  });

  tearDown(() {
    root.deleteSync(recursive: true);
  });

  test(
    'an unsigned development build records a tracked signing input',
    () async {
      final signing = WindowsSigning.load(root.path);
      expect(signing.thumbprint, isNull);
      expect(File(WindowsSigning.configPath(root.path)).existsSync(), isTrue);
      await signing.sign(p.join(root.path, 'not-built.exe'));
    },
  );

  test('rejects a malformed certificate identifier before invoking tools', () {
    final config = File(WindowsSigning.configPath(root.path));
    config.parent.createSync(recursive: true);
    config.writeAsStringSync('{"thumbprint":"not a certificate"}');
    expect(
      () => WindowsSigning.load(root.path),
      throwsA(isA<BuildException>()),
    );
  });

  test(
    'passes paths with spaces and the exact certificate to the signer',
    () async {
      final executable = p.join(root.path, 'Po0ClashCore.exe');
      final calls = <List<String>>[];
      final signing = WindowsSigning(
        rootDir: root.path,
        thumbprint: thumbprint,
        command: (script, path, certificate) async {
          calls.add([script, path, certificate]);
        },
      );
      await signing.sign(executable);
      expect(calls, [
        [signing.script, executable, thumbprint],
      ]);
    },
  );

  test('signing failures prevent a successful build result', () async {
    final signing = WindowsSigning(
      rootDir: root.path,
      thumbprint: thumbprint,
      command: (_, _, _) async => throw BuildException('timestamp failed'),
    );
    await expectLater(signing.sign('core.exe'), throwsA(isA<BuildException>()));
  });

  test(
    'certificate changes invalidate cached signed bytes and Core hash',
    () async {
      final config = File(WindowsSigning.configPath(root.path));
      config.parent.createSync(recursive: true);
      final script = File(p.join(root.path, 'scripts', 'windows', 'sign.ps1'));
      script.parent.createSync(recursive: true);
      script.writeAsStringSync('sign');
      final core = File(p.join(root.path, 'core.exe'));
      final cache = BuildCache(rootDir: root.path);
      var signatures = 0;

      Future<BuildExecution> build(String certificate) async {
        config.writeAsStringSync(jsonEncode({'thumbprint': certificate}));
        final loaded = WindowsSigning.load(root.path);
        final signing = WindowsSigning(
          rootDir: root.path,
          thumbprint: loaded.thumbprint,
          command: (_, executable, signer) async {
            signatures++;
            File(executable).writeAsStringSync(signer, mode: FileMode.append);
          },
        );
        return cache.run(
          key: 'signed-core',
          fingerprint: () async {
            final fingerprint = FingerprintBuilder(rootDir: root.path)
              ..addFiles(signing.inputs);
            return fingerprint.finishWithInputs();
          },
          primaryOutput: core.path,
          notice: BuildNotice(),
          build: () async {
            core.writeAsStringSync('core');
            await signing.sign(core.path);
            return [core.path];
          },
        );
      }

      await build(thumbprint);
      final firstHash = await calcSha256(core.path);
      expect((await build(thumbprint)).rebuilt, isFalse);
      expect(signatures, 1);
      expect((await build(List.filled(40, 'B').join())).rebuilt, isTrue);
      expect(await calcSha256(core.path), isNot(firstHash));
      expect(signatures, 2);
    },
  );
}
