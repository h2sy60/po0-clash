import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/providers/providers.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class ConnectOrb extends ConsumerWidget {
  const ConnectOrb({super.key});

  void _handleTap(WidgetRef ref, bool hasProfile) {
    if (!hasProfile) {
      ref.read(currentPageLabelProvider.notifier).toPage(PageLabel.profiles);
      return;
    }
    ref.read(commonActionProvider.notifier).toggleRunning();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hasProfile = ref.watch(
      profilesProvider.select((state) => state.isNotEmpty),
    );
    final isStart = ref.watch(isStartProvider);
    final suspend = ref.watch(suspendProvider);
    final strings = context.appLocalizations;
    final title = !hasProfile
        ? strings.nullProfileDesc
        : isStart
        ? suspend
              ? strings.suspended
              : strings.proxyOn
        : strings.tapToConnect;
    final label = !hasProfile
        ? strings.addProfile
        : isStart
        ? strings.stop
        : strings.start;
    return LayoutBuilder(
      builder: (_, constraints) {
        final compact = constraints.maxWidth < 560;
        final status = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: context.textTheme.headlineLarge?.copyWith(
                fontSize: compact ? 32 : 42,
                fontWeight: FontWeight.w600,
                letterSpacing: -1,
                height: 1.2,
              ),
            ),
            if (isStart) ...[
              const SizedBox(height: 12),
              Consumer(
                builder: (_, ref, _) => Text(
                  getTimeText(ref.watch(runTimeProvider)),
                  style: context.textTheme.bodyLarge?.copyWith(
                    color: context.colorScheme.onSurfaceVariant,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ),
            ],
          ],
        );
        final action = FilledButton(
          onPressed: () => _handleTap(ref, hasProfile),
          style: FilledButton.styleFrom(
            minimumSize: const Size(112, 48),
            textStyle: context.textTheme.bodyLarge,
          ),
          child: Text(label),
        );
        return constraints.maxWidth < 280
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [status, const SizedBox(height: 24), action],
              )
            : Row(
                children: [
                  Expanded(child: status),
                  SizedBox(width: compact ? 16 : 32),
                  action,
                ],
              );
      },
    );
  }
}
