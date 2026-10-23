import 'dart:io';

import 'package:dio/dio.dart';
import 'package:fl_clash/common/app_localizations.dart';
import 'package:fl_clash/core/desktop/helper_client.dart';
import 'package:fl_clash/core/desktop/launch_policy.dart';
import 'package:fl_clash/core/desktop/model.dart';
import 'package:fl_clash/core/method.dart';
import 'package:fl_clash/l10n/l10n.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppLocalizations appLocalizations;

  setUpAll(() async {
    appLocalizations = await AppLocalizations.load(const Locale('en'));
  });

  test('maps badResponse DioException to the network exception message', () {
    final message = networkErrorMessage(
      DioException(
        requestOptions: RequestOptions(path: '/'),
        type: DioExceptionType.badResponse,
      ),
      appLocalizations,
    );
    expect(message, appLocalizations.networkException);
  });

  test(
    'maps other DioException types to the unknown network error message',
    () {
      final message = networkErrorMessage(
        DioException(
          requestOptions: RequestOptions(path: '/'),
          type: DioExceptionType.connectionError,
        ),
        appLocalizations,
      );
      expect(message, appLocalizations.unknownNetworkError);
    },
  );

  test('returns null for non-Dio exceptions', () {
    expect(networkErrorMessage(StateError('boom'), appLocalizations), isNull);
  });

  test('maps Core request failures using the same network categories', () {
    expect(
      networkErrorMessage(
        const CoreMethodException(
          code: 'request_bad_response',
          message: '503 Service Unavailable',
        ),
        appLocalizations,
      ),
      appLocalizations.networkException,
    );
    expect(
      networkErrorMessage(
        const CoreMethodException(
          code: 'request_error',
          message: 'request timed out',
        ),
        appLocalizations,
      ),
      appLocalizations.unknownNetworkError,
    );
  });

  test('uses the Core message for non-request failures', () {
    expect(
      userFacingErrorMessage(
        const CoreMethodException(
          code: 'provider_update_error',
          message: 'proxy 0: unsupported type',
        ),
        appLocalizations,
      ),
      'proxy 0: unsupported type',
    );
  });

  group('policy-blocked Core launch', () {
    const blocked = DesktopCoreFailure(
      code: 'start_failed',
      phase: DesktopCorePhase.starting,
      revision: 1,
      cause: HelperException(
        code: 'processLaunchFailed',
        message: 'spawn failed',
        details: {'osError': 577},
      ),
    );

    tearDown(() {
      smartAppControlStateReader = readSmartAppControlState;
    });

    test('adds Smart App Control context only when it is enforcing', () {
      smartAppControlStateReader = () => SmartAppControlState.on;

      expect(
        userFacingErrorMessage(blocked, appLocalizations),
        appLocalizations.coreBlockedBySmartAppControlTip(577),
      );
    });

    for (final state in [
      SmartAppControlState.off,
      SmartAppControlState.evaluation,
      SmartAppControlState.unknown,
    ]) {
      test('does not blame Smart App Control in ${state.name} mode', () {
        smartAppControlStateReader = () => state;

        expect(
          userFacingErrorMessage(blocked, appLocalizations),
          appLocalizations.coreSignatureInvalidTip(577),
        );
      });
    }

    for (final state in SmartAppControlState.values) {
      for (final code in [225, 226, 1260]) {
        test('keeps error $code distinct in ${state.name} mode', () {
          smartAppControlStateReader = () => state;
          final error = ProcessException(
            'Po0ClashCore.exe',
            [],
            'blocked',
            code,
          );

          expect(
            userFacingErrorMessage(error, appLocalizations),
            code == 1260
                ? appLocalizations.coreBlockedByPolicyTip(code)
                : appLocalizations.coreBlockedByAntivirusTip(code),
          );
        });
      }
    }

    test('leaves other start failures on the raw description', () {
      smartAppControlStateReader = () => SmartAppControlState.on;
      const timedOut = DesktopCoreFailure(
        code: 'start_failed',
        phase: DesktopCorePhase.starting,
        revision: 1,
        cause: HelperException(
          code: 'transportError',
          message: 'Helper start request failed',
        ),
      );

      expect(
        userFacingErrorMessage(timedOut, appLocalizations),
        timedOut.toString(),
      );
    });
  });
}
