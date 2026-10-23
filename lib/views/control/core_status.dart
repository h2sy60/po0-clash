import 'dart:async';

import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/providers/providers.dart';
import 'package:fl_clash/widgets/widgets.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class CoreStatusButton extends ConsumerStatefulWidget {
  const CoreStatusButton({super.key});

  @override
  ConsumerState<CoreStatusButton> createState() => _CoreStatusButtonState();
}

class _CoreStatusButtonState extends ConsumerState<CoreStatusButton> {
  static const _holdDuration = Duration(milliseconds: 600);

  Timer? _holdTimer;
  CoreStatus _status = CoreStatus.disconnected;

  @override
  void initState() {
    super.initState();
    _status = ref.read(coreStatusProvider);
    ref.listenManual(coreStatusProvider, (_, next) {
      _onStatusChanged(next);
    });
  }

  @override
  void dispose() {
    _holdTimer?.cancel();
    super.dispose();
  }

  void _onStatusChanged(CoreStatus next) {
    setState(() {
      _status = next;
      switch (next) {
        case CoreStatus.connecting:
          _holdTimer ??= Timer(_holdDuration, () {
            if (mounted) {
              setState(() {
                _holdTimer = null;
              });
            }
          });
          break;
        case CoreStatus.disconnected:
          _holdTimer?.cancel();
          _holdTimer = null;
          break;
        case CoreStatus.connected:
          break;
      }
    });
  }

  Future<void> _handleConnection() async {
    if (_holdTimer != null) {
      return;
    }
    final coreStatus = ref.read(coreStatusProvider);
    if (coreStatus == CoreStatus.connecting) {
      return;
    }
    final tip = coreStatus == CoreStatus.connected
        ? context.appLocalizations.forceRestartCoreTip
        : context.appLocalizations.restartCoreTip;
    final res = await dialogs.showMessage(message: TextSpan(text: tip));
    if (res != true) {
      return;
    }
    try {
      await ref.read(coreActionProvider.notifier).restartCore();
    } catch (error) {
      dialogs.showNotifier(error.toString(), level: MessageLevel.error);
    }
  }

  @override
  Widget build(BuildContext context) {
    final coreStatus = _holdTimer != null ? CoreStatus.connecting : _status;
    final appLocalizations = context.appLocalizations;
    final tone = switch (coreStatus) {
      CoreStatus.connecting => GlassTone.accent,
      CoreStatus.connected => GlassTone.success,
      CoreStatus.disconnected => GlassTone.danger,
    };
    final color = context.toneColor(tone);
    final label = switch (coreStatus) {
      CoreStatus.connecting => appLocalizations.connecting,
      CoreStatus.connected => appLocalizations.connected,
      CoreStatus.disconnected => appLocalizations.disconnected,
    };
    return Tooltip(
      message: '$label · ${appLocalizations.coreStatus}',
      child: Semantics(
        label: label,
        button: true,
        child: SizedBox.square(
          dimension: 44,
          child: GlassButton(
            key: ValueKey(coreStatus),
            circle: true,
            color: color.withValues(alpha: context.glass.isDark ? 0.22 : 0.2),
            onTap: _handleConnection,
            child: coreStatus == CoreStatus.connecting
                ? Padding(
                    padding: const EdgeInsets.all(14),
                    child: CommonCircleLoading(color: color),
                  )
                : Icon(
                    coreStatus == CoreStatus.connected
                        ? Icons.check
                        : Icons.restart_alt_sharp,
                    size: 22,
                    color: color,
                  ),
          ),
        ),
      ),
    );
  }
}
