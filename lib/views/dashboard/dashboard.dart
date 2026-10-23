import 'dart:math' as math;
import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/core/core.dart';
import 'package:fl_clash/providers/providers.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/widgets/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import '../control/core_status.dart';
import 'layout.dart';
import 'style.dart';
import 'widgets/widgets.dart';

const _memoryColumnMin = 290.0;
const _maxColumnWidth = 440.0;

class DashboardView extends ConsumerStatefulWidget {
  const DashboardView({super.key, this.platform});
  final SupportPlatform? platform;
  @override
  ConsumerState<DashboardView> createState() => _DashboardViewState();
}

class _DashboardViewState extends ConsumerState<DashboardView> {
  var _editing = false;
  late List<int> _order = List.generate(10, (i) => i);
  @override
  void initState() {
    super.initState();
    preferences.sharedPreferencesCompleter.future.then((prefs) {
      final saved = prefs?.getStringList('dashboardOrder');
      if (mounted && saved != null) {
        final order = saved
            .map(int.tryParse)
            .whereType<int>()
            .where((i) => i >= 0 && i < 10)
            .toSet()
            .toList();
        if (order.length == 10) setState(() => _order = order);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final scale = math.max(1.0, MediaQuery.textScalerOf(context).scale(1));
    final strings = context.appLocalizations;
    final platform = widget.platform ?? SupportPlatform.currentPlatform;
    final editable =
        (ref.watch(viewSizeProvider).width - ref.watch(sideWidthProvider)) /
            scale <
        640;
    return CommonScaffold(
      title: _editing ? strings.editDashboard : strings.dashboard,
      backgroundColor: DashboardColors.of(context).page,
      actions: [
        if (coreLib == null) const CoreStatusButton(),
        if (editable)
          IconButton(
            tooltip: _editing ? strings.done : strings.editDashboard,
            onPressed: () => setState(() => _editing = !_editing),
            icon: GlyphIcon(_editing ? AppGlyphs.check : AppGlyphs.edit),
          ),
      ],
      body: LayoutBuilder(
        builder: (context, constraints) {
          final room = constraints.biggest / scale;
          final density = DashboardDensity.of(room);
          final gap = density.isDesktop ? 16.0 : 8.0;
          final cards = <Widget>[
            const CurrentOutboundCard(),
            const NetworkSpeedCard(),
            const OutboundModeCard(),
            platform == SupportPlatform.Android
                ? const VpnCard()
                : const NetworkTakeoverCard(),
            const IntranetIpCard(),
            const ProfilesCard(),
            const ServiceStatusCard(),
            const ProxyGroupsCard(),
            const ConnectionStatsCard(),
            const WhitelistCard(),
          ];
          return DashboardDensityScope(
            density: density,
            scale: scale,
            child: density.isDesktop
                ? _DesktopDashboard(
                    platform: platform,
                    columns: dashboardColumnsOf(room.width),
                    gap: gap,
                  )
                : _editing
                ? ReorderableListView(
                    padding: const EdgeInsets.all(16),
                    onReorderItem: (from, to) {
                      setState(() {
                        _order.insert(to, _order.removeAt(from));
                      });
                      preferences.sharedPreferencesCompleter.future.then((
                        prefs,
                      ) async {
                        if (prefs != null) {
                          await prefs.setStringList(
                            'dashboardOrder',
                            _order.map((i) => '$i').toList(),
                          );
                        }
                      });
                    },
                    children: [
                      for (final index in _order)
                        Padding(
                          key: ValueKey(index),
                          padding: EdgeInsets.only(bottom: gap),
                          child: IgnorePointer(child: cards[index]),
                        ),
                    ],
                  )
                : SingleChildScrollView(
                    padding: EdgeInsets.fromLTRB(
                      dashboardMobileSideOf(constraints.maxWidth),
                      4,
                      dashboardMobileSideOf(constraints.maxWidth),
                      16 + BottomInsetScope.of(context),
                    ),
                    child: Column(
                      spacing: gap,
                      children: [
                        for (final index in _order)
                          RepaintBoundary(child: cards[index]),
                      ],
                    ),
                  ),
          );
        },
      ),
    );
  }
}

class _DesktopDashboard extends StatelessWidget {
  const _DesktopDashboard({
    required this.platform,
    required this.columns,
    required this.gap,
  });

  final SupportPlatform platform;
  final int columns;
  final double gap;

  @override
  Widget build(BuildContext context) {
    final density = DashboardDensityScope.of(context);
    final compact = density.isCompact;
    final scale = DashboardDensityScope.scaleOf(context);
    final base = EdgeInsetsDirectional.fromSTEB(
      16,
      MediaQuery.paddingOf(context).top,
      24,
      24 + MediaQuery.paddingOf(context).bottom,
    );
    final topHeight = (compact ? 176 : 208) * scale;
    final controlHeight = (compact ? 56 : 64) * scale;
    final middleHeight = (compact ? 152 : 176) * scale;
    final tablesHeight = connectionsTableMinHeight(density, scale);
    final summaryHeight = (compact ? 112 : 120) * scale;
    return LayoutBuilder(
      builder: (context, constraints) {
        final room =
            constraints.maxWidth - base.horizontal - gap * (columns - 1);
        final column = math.min(room / columns, _maxColumnWidth * scale);
        final inset = (room - column * columns) / 2;
        final padding = base.copyWith(
          start: base.start + inset,
          end: base.end + inset,
        );
        double span(int columns) => column * columns + gap * (columns - 1);
        Widget row(List<(int, Widget)> cards) => Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: gap,
          children: [
            for (final (columns, card) in cards)
              SizedBox(
                width: span(columns),
                child: RepaintBoundary(child: card),
              ),
          ],
        );
        Widget sized(double height, Widget child) =>
            SizedBox(height: height, child: child);
        final switches = system.isDesktop
            ? const [
                (1, NetworkTakeoverTile(TakeoverSwitch.systemProxy)),
                (1, NetworkTakeoverTile(TakeoverSwitch.tun)),
              ]
            : const [(2, VpnTile())];
        final half = columns ~/ 2;
        final summaries = row([
          (half, const ConnectionStatsCard()),
          (half, const ProxyGroupsSummaryCard()),
        ]);
        if (columns == 2) {
          return SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: padding,
            child: Column(
              spacing: gap,
              children: [
                sized(
                  topHeight,
                  const RepaintBoundary(child: CurrentOutboundCard()),
                ),
                sized(
                  topHeight,
                  row(const [
                    (1, SpeedCard(direction: TrafficDirection.upload)),
                    (1, SpeedCard(direction: TrafficDirection.download)),
                  ]),
                ),
                sized(
                  controlHeight,
                  const RepaintBoundary(child: OutboundModeBar()),
                ),
                sized(controlHeight, row(switches)),
                sized(
                  middleHeight,
                  row(const [(1, IntranetIpCard()), (1, ProfilesCard())]),
                ),
                sized(
                  middleHeight,
                  row(const [(1, ServiceStatusCard()), (1, MemoryInfo())]),
                ),
                sized(summaryHeight, summaries),
              ],
            ),
          );
        }
        final rows = [
          sized(
            topHeight,
            row(const [
              (2, CurrentOutboundCard()),
              (1, SpeedCard(direction: TrafficDirection.upload)),
              (1, SpeedCard(direction: TrafficDirection.download)),
            ]),
          ),
          sized(
            controlHeight,
            row([(2, const OutboundModeBar()), ...switches]),
          ),
          sized(
            middleHeight,
            row([
              (1, const IntranetIpCard()),
              (1, const ProfilesCard()),
              if (column >= _memoryColumnMin * scale) ...[
                (1, const ServiceStatusCard()),
                (1, const MemoryInfo()),
              ] else
                (2, const ServiceStatusCard()),
            ]),
          ),
        ];
        final rowsHeight =
            padding.vertical +
            topHeight +
            controlHeight +
            middleHeight +
            gap * 3;
        final tablesFit = constraints.maxHeight >= rowsHeight + tablesHeight;
        final fills = constraints.maxHeight >= rowsHeight + summaryHeight;
        return SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: SizedBox(
            height: fills ? constraints.maxHeight : null,
            child: Padding(
              padding: padding,
              child: Column(
                spacing: gap,
                children: [
                  ...rows,
                  if (tablesFit)
                    Expanded(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        spacing: gap,
                        children: const [
                          Expanded(
                            flex: 3,
                            child: RepaintBoundary(
                              child: ConnectionsTableCard(),
                            ),
                          ),
                          Expanded(
                            flex: 2,
                            child: RepaintBoundary(child: ProxyGroupsCard()),
                          ),
                        ],
                      ),
                    )
                  else if (fills)
                    Expanded(child: summaries)
                  else
                    sized(summaryHeight, summaries),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
