import 'dart:io';

import 'package:fl_clash/core/desktop/helper_client.dart';
import 'package:fl_clash/core/desktop/launch_policy.dart';
import 'package:fl_clash/core/desktop/model.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('reads the OS error the Helper reports in the response details', () {
    const error = HelperException(
      code: 'processLaunchFailed',
      message: 'spawn failed',
      details: {'osError': 577},
    );

    expect(launchOsError(error), 577);
    expect(coreLaunchBlockReason(error), CoreLaunchBlockReason.signature);
  });

  test('falls back to the code embedded in an older Helper message', () {
    const error = HelperException(
      code: 'processLaunchFailed',
      message: 'This program is blocked by group policy. (os error 1260)',
    );

    expect(launchOsError(error), 1260);
    expect(coreLaunchBlockReason(error), CoreLaunchBlockReason.policy);
  });

  test('ignores Helper failures that happened before the spawn', () {
    const error = HelperException(
      code: 'coreVerificationFailed',
      message: 'Core executable SHA256 mismatch (os error 577)',
    );

    expect(launchOsError(error), isNull);
    expect(coreLaunchBlockReason(error), isNull);
  });

  test('reads the OS error from a direct launch failure', () {
    const error = ProcessException('Po0ClashCore.exe', [], 'refused', 225);

    expect(launchOsError(error), 225);
    expect(coreLaunchBlockReason(error), CoreLaunchBlockReason.antivirus);
  });

  test('looks through the lifecycle failure to its cause', () {
    const failure = DesktopCoreFailure(
      code: 'start_failed',
      phase: DesktopCorePhase.starting,
      revision: 1,
      cause: ProcessException('Po0ClashCore.exe', [], 'refused', 577),
    );

    expect(launchOsError(failure), 577);
    expect(coreLaunchBlockReason(failure), CoreLaunchBlockReason.signature);
  });

  test('a missing file or a plain crash is not a policy block', () {
    expect(
      coreLaunchBlockReason(
        const ProcessException('Po0ClashCore.exe', [], 'not found', 2),
      ),
      isNull,
    );
    expect(
      coreLaunchBlockReason(
        const DesktopCoreFailure(
          code: 'start_failed',
          phase: DesktopCorePhase.starting,
          revision: 1,
          cause: 'receive timeout',
        ),
      ),
      isNull,
    );
    expect(coreLaunchBlockReason(null), isNull);
  });

  test('the registry state is unknown off Windows', () {
    if (Platform.isWindows) {
      return;
    }
    expect(readSmartAppControlState(), SmartAppControlState.unknown);
  });
}
