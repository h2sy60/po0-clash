import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/core/core.dart';
import 'package:fl_clash/widgets/widgets.dart';
import 'package:material_ui/material_ui.dart';

import 'connect_orb.dart';
import 'core_status.dart';
import 'tiles.dart';

class ControlCenterView extends StatelessWidget {
  const ControlCenterView({super.key});

  @override
  Widget build(BuildContext context) {
    final bottom = BottomInsetScope.of(context);
    return Material(
      type: MaterialType.transparency,
      child: SafeArea(
        bottom: false,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final wide = constraints.maxWidth >= 760;
            return SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(
                wide ? 40 : 20,
                wide ? 28 : 16,
                wide ? 40 : 20,
                bottom + 32,
              ),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1080),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const BrandHeader(),
                      SizedBox(height: wide ? 32 : 24),
                      const _ConnectionCard(),
                      const SizedBox(height: 20),
                      if (wide)
                        const Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(flex: 5, child: TrafficCard()),
                            SizedBox(width: 20),
                            Expanded(
                              flex: 4,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  CurrentNodeCard(),
                                  SizedBox(height: 20),
                                  CurrentProfileCard(),
                                ],
                              ),
                            ),
                          ],
                        )
                      else ...[
                        const CurrentNodeCard(),
                        const SizedBox(height: 16),
                        const TrafficCard(),
                        const SizedBox(height: 16),
                        const CurrentProfileCard(),
                      ],
                      const SizedBox(height: 20),
                      if (wide)
                        const Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(flex: 5, child: WhitelistStatusCard()),
                            SizedBox(width: 20),
                            Expanded(flex: 4, child: _NetworkDetails()),
                          ],
                        )
                      else ...[
                        const WhitelistStatusCard(),
                        const SizedBox(height: 20),
                        const _NetworkDetails(),
                      ],
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _NetworkDetails extends StatelessWidget {
  const _NetworkDetails();

  @override
  Widget build(BuildContext context) => const Column(
    children: [
      IpDetectionChip(),
      SizedBox(height: 12),
      Row(
        children: [
          Expanded(child: NetworkCard()),
          SizedBox(width: 12),
          Expanded(child: MemoryInfo()),
        ],
      ),
    ],
  );
}

class BrandHeader extends StatelessWidget {
  const BrandHeader({super.key, this.dense = false});

  final bool dense;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        if (context.isMobileView) ...[
          ClipRRect(
            borderRadius: AppRadius.small,
            child: Image.asset('assets/images/icon.png', width: 28, height: 28),
          ),
          const SizedBox(width: 10),
        ],
        Expanded(
          child: Text(
            context.isMobileView ? appName : context.appLocalizations.home,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: context.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w600,
              letterSpacing: -0.4,
            ),
          ),
        ),
        if (coreLib == null) const CoreStatusButton(),
      ],
    );
  }
}

class _ConnectionCard extends StatelessWidget {
  const _ConnectionCard();

  @override
  Widget build(BuildContext context) {
    return GlassSurface(
      kind: GlassKind.panel,
      padding: EdgeInsets.all(context.isMobileView ? 24 : 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const ConnectOrb(),
          const SizedBox(height: 32),
          const Divider(height: 1),
          const SizedBox(height: 24),
          LayoutBuilder(
            builder: (_, constraints) => constraints.maxWidth >= 660
                ? const Row(
                    children: [
                      Expanded(child: OutboundModeSwitch()),
                      SizedBox(width: 32),
                      Expanded(child: QuickToggles()),
                    ],
                  )
                : const Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      OutboundModeSwitch(),
                      SizedBox(height: 16),
                      QuickToggles(),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}
