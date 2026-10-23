import 'dart:io';

import 'package:fl_clash/core/desktop/helper_client.dart';
import 'package:fl_clash/core/desktop/model.dart';
import 'package:win32_registry/win32_registry.dart';

enum CoreLaunchBlockReason { antivirus, signature, policy }

enum SmartAppControlState { off, on, evaluation, unknown }

typedef SmartAppControlStateReader = SmartAppControlState Function();

SmartAppControlStateReader smartAppControlStateReader =
    readSmartAppControlState;

SmartAppControlState readSmartAppControlState() {
  if (!Platform.isWindows) {
    return SmartAppControlState.unknown;
  }
  try {
    final key = LOCAL_MACHINE.open(
      r'SYSTEM\CurrentControlSet\Control\CI\Policy',
    );
    try {
      return switch (key.getInt('VerifiedAndReputablePolicyState')) {
        0 => SmartAppControlState.off,
        1 => SmartAppControlState.on,
        2 => SmartAppControlState.evaluation,
        _ => SmartAppControlState.unknown,
      };
    } finally {
      key.close();
    }
  } catch (_) {
    return SmartAppControlState.unknown;
  }
}

/// The OS error behind a failed Core launch, whether the Helper spawned it
/// (the code travels in the response details, older Helpers only in the
/// message) or the app did (dart:io keeps it on the exception).
int? launchOsError(Object? error) {
  return switch (error) {
    DesktopCoreFailure(:final cause) => launchOsError(cause),
    ProcessException(:final errorCode) => errorCode == 0 ? null : errorCode,
    HelperException(code: 'processLaunchFailed') => _helperOsError(error),
    _ => null,
  };
}

CoreLaunchBlockReason? coreLaunchBlockReason(Object? error) {
  return switch (launchOsError(error)) {
    225 || 226 => CoreLaunchBlockReason.antivirus,
    577 => CoreLaunchBlockReason.signature,
    1260 => CoreLaunchBlockReason.policy,
    _ => null,
  };
}

int? _helperOsError(HelperException error) {
  final details = error.details;
  if (details is Map && details['osError'] is int) {
    return details['osError'] as int;
  }
  final match = RegExp(r'os error (\d+)').firstMatch(error.message);
  return match == null ? null : int.tryParse(match.group(1)!);
}
