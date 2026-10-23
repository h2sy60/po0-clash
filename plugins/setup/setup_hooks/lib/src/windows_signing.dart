import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

import 'error.dart';
import 'util.dart';

typedef WindowsSignCommand =
    Future<void> Function(String script, String executable, String thumbprint);

class WindowsSigning {
  WindowsSigning({
    required this.rootDir,
    required this.thumbprint,
    WindowsSignCommand? command,
  }) : _command = command ?? _sign;

  final String rootDir;
  final String? thumbprint;
  final WindowsSignCommand _command;

  static String configPath(String rootDir) =>
      p.join(rootDir, '.dart_tool', 'windows-signing.json');

  factory WindowsSigning.load(String rootDir) {
    final file = File(configPath(rootDir));
    if (!file.existsSync()) {
      file.parent.createSync(recursive: true);
      file.writeAsStringSync('{}\n');
    }
    final config = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
    final thumbprint = config['thumbprint'] as String?;
    if (thumbprint != null && !RegExp(r'^[0-9A-F]{40}$').hasMatch(thumbprint)) {
      throw BuildException('Invalid Windows signing certificate thumbprint');
    }
    return WindowsSigning(rootDir: rootDir, thumbprint: thumbprint);
  }

  String get script => p.join(rootDir, 'scripts', 'windows', 'sign.ps1');

  List<String> get inputs => [configPath(rootDir), script];

  Future<void> sign(String executable) async {
    final certificate = thumbprint;
    if (certificate == null) return;
    await _command(script, executable, certificate);
  }

  static Future<void> _sign(
    String script,
    String executable,
    String thumbprint,
  ) => runCommandStream(
    'powershell.exe',
    ['-NoProfile', '-NonInteractive', '-File', script, '-Path', executable],
    environment: {'PO0_WINDOWS_SIGN_CERT_SHA1': thumbprint},
  );
}
