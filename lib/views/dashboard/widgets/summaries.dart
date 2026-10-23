import 'dart:async';
import 'dart:io';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:fl_clash/state.dart';
import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/features/features.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/providers/providers.dart';
import 'package:fl_clash/views/activity.dart';
import 'package:fl_clash/views/po0_firewall.dart';
import 'package:fl_clash/widgets/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import '../layout.dart';
import '../style.dart';
import 'card.dart';
import 'profile_usage.dart';

void _openPage(WidgetRef ref, PageLabel label) =>
    ref.read(currentPageLabelProvider.notifier).toPage(label);

class ProfilesCard extends ConsumerWidget {
  const ProfilesCard({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(currentProfileProvider);
    final info = profile?.subscriptionInfo;
    final used = (info?.upload ?? 0) + (info?.download ?? 0);
    final total = info?.total ?? 0;
    final share = total <= 0 ? 0.0 : (used / total).clamp(0.0, 1.0);
    final mobile = !DashboardDensityScope.of(context).isDesktop;
    final strings = context.appLocalizations;
    return DashboardCard(
      onTap: () => _openPage(ref, PageLabel.profiles),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: mobile ? MainAxisSize.min : MainAxisSize.max,
        children: [
          DashboardCardHeader(
            glyph: AppGlyphs.profiles,
            title: strings.profile,
            chevron: true,
            trailing: [
              if (profile != null && profile.type == ProfileType.url)
                DashboardIconButton(
                  glyph: AppGlyphs.sync,
                  tooltip: strings.update,
                  onPressed: () => unawaited(
                    globalState.safeRun(
                      () => ref
                          .read(profilesActionProvider.notifier)
                          .updateProfile(profile, showLoading: true),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            spacing: 8,
            children: [
              Expanded(
                child: EmojiText(
                  profile?.realLabel ?? strings.addProfile,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyle.headline.of(context, emphasized: true),
                ),
              ),
              if ((info?.expire ?? 0) > 0)
                Text(
                  strings.profileDaysLeft(
                    ((DateTime.fromMillisecondsSinceEpoch(
                      info!.expire * 1000,
                    ).difference(DateTime.now()).inDays).clamp(0, 9999)),
                  ),
                  style: DashboardText.label(context),
                ),
            ],
          ),
          if (mobile) const SizedBox(height: 20) else const Spacer(),
          if (info != null)
            ProfileUsageMeter(
              usage: (used: used, total: total, share: share.toDouble()),
              figure: AppTextStyle.callout,
              gap: 6,
            )
          else
            Text(
              profile == null
                  ? strings.nullProfileDesc
                  : profile.type == ProfileType.url
                  ? strings.remote
                  : strings.local,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: DashboardText.label(context),
            ),
        ],
      ),
    );
  }
}

class WhitelistCard extends ConsumerWidget {
  const WhitelistCard({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summary = ref.watch(whitelistSummaryProvider);
    final overview = whitelistOverviewOf(
      context.appLocalizations,
      summary: summary,
    );
    return DashboardCard(
      onTap: () => _openPage(ref, PageLabel.whitelist),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          DashboardCardHeader(
            glyph: AppGlyphs.vpn,
            title: context.appLocalizations.whitelistNav,
            chevron: true,
          ),
          const SizedBox(height: 12),
          Text(overview.title, style: DashboardText.rowTitle(context)),
        ],
      ),
    );
  }
}

class ProxyGroupsCard extends ConsumerWidget {
  const ProxyGroupsCard({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final groups = ref.watch(currentGroupsStateProvider).value;
    final desktop = DashboardDensityScope.of(context).isDesktop;
    final body = ListView.separated(
      primary: false,
      shrinkWrap: !desktop,
      physics: desktop ? null : const NeverScrollableScrollPhysics(),
      itemCount: groups.length,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (_, index) {
        final group = groups[index];
        return Consumer(
          builder: (_, ref, _) {
            final selected = ref.watch(selectedProxyNameProvider(group.name));
            final delay = ref.watch(
              delayProvider(
                proxyName: selected ?? group.name,
                testUrl: group.testUrl,
              ),
            );
            return DashboardBlock(
              radius: DashboardCorner.block,
              padding: const EdgeInsets.all(10),
              onTap: () {
                ref
                    .read(proxiesActionProvider.notifier)
                    .updateCurrentGroupName(group.name);
                _openPage(ref, PageLabel.proxies);
              },
              child: Row(
                spacing: 12,
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    alignment: Alignment.center,
                    decoration: ShapeDecoration(
                      color: DashboardColors.of(context).tone2,
                      shape: AppShape.md,
                    ),
                    child: Text(
                      group.name.isEmpty ? 'P' : group.name.characters.first,
                      style: DashboardText.rowTitle(context),
                    ),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        EmojiText(
                          group.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: DashboardText.label(context),
                        ),
                        EmojiText(
                          selected ?? '—',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: DashboardText.rowTitle(context),
                        ),
                      ],
                    ),
                  ),
                  if (delay != null)
                    Text(
                      delay > 0
                          ? '$delay ms'
                          : context.appLocalizations.timeout,
                      style: DashboardText.label(
                        context,
                        color: context.colorScheme.delayColor(delay),
                      ),
                    ),
                ],
              ),
            );
          },
        );
      },
    );
    return DashboardCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: desktop ? MainAxisSize.max : MainAxisSize.min,
        children: [
          DashboardCardHeader(
            glyph: AppGlyphs.layers,
            title: context.appLocalizations.proxyGroup,
            leading: [DashboardChip(label: '${groups.length}')],
            chevron: true,
          ),
          const SizedBox(height: 16),
          if (desktop) Expanded(child: body) else body,
        ],
      ),
    );
  }
}

class ProxyGroupsSummaryCard extends ConsumerWidget {
  const ProxyGroupsSummaryCard({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) => DashboardCard(
    onTap: () => _openPage(ref, PageLabel.proxies),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DashboardCardHeader(
          glyph: AppGlyphs.layers,
          title: context.appLocalizations.proxyGroup,
          chevron: true,
        ),
        const SizedBox(height: 10),
        Text(
          '${ref.watch(currentGroupsStateProvider).value.length}',
          style: DashboardText.figure(context, AppTextStyle.title2),
        ),
      ],
    ),
  );
}

double connectionsTableMinHeight(DashboardDensity density, double scale) =>
    220 * scale;

class ConnectionStatsCard extends ConnectionsTableCard {
  const ConnectionStatsCard({super.key}) : super(summary: true);
}

class ConnectionsTableCard extends ConsumerStatefulWidget {
  const ConnectionsTableCard({super.key, this.summary = false});
  final bool summary;
  @override
  ConsumerState<ConnectionsTableCard> createState() =>
      _ConnectionsTableCardState();
}

class _ConnectionsTableCardState extends ConsumerState<ConnectionsTableCard>
    with WidgetsBindingObserver, ActivePollingMixin<ConnectionsTableCard> {
  List<TrackerInfo> _connections = const [];
  List<TrackerInfo> _requests = const [];
  bool _showRequests = false;
  @override
  Duration get pollInterval => const Duration(seconds: 1);
  @override
  bool get canPoll =>
      super.canPoll &&
      ref.read(uiVisibleProvider) &&
      ref.read(coreStatusProvider) == CoreStatus.connected;
  @override
  void initState() {
    super.initState();
    ref.listenManual(coreStatusProvider, (_, _) => restartPolling());
    ref.listenManual(uiVisibleProvider, (_, _) => restartPolling());
  }

  @override
  Future<void> poll(PollGuard isCurrent) async {
    final connections = await ref.read(coreHandlerProvider).getConnections();
    if (!isCurrent()) return;
    setState(() {
      _connections = List.of(connections)
        ..sort(
          (a, b) => (b.upload + b.download).compareTo(a.upload + a.download),
        );
      _requests = ref.read(requestsProvider).list.reversed.toList();
    });
  }

  void _openActivity() {
    if (context.isMobileView) {
      BaseNavigator.push(context, const ActivityView());
    } else {
      _openPage(ref, PageLabel.activity);
    }
  }

  @override
  Widget build(BuildContext context) {
    final strings = context.appLocalizations;
    if (widget.summary) {
      return DashboardCard(
        onTap: _openActivity,
        child: Row(
          children: [
            for (final (count, label) in [
              (_connections.length, strings.connections),
              (_requests.length, strings.requests),
            ])
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label, style: DashboardText.label(context)),
                    const SizedBox(height: 8),
                    Text(
                      dashboardCount(count),
                      style: DashboardText.figure(context, AppTextStyle.title2),
                    ),
                  ],
                ),
              ),
          ],
        ),
      );
    }
    final rows = _showRequests ? _requests : _connections;
    Widget cell(String value, int flex, {bool figure = false}) => Expanded(
      flex: flex,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: figure
              ? DashboardText.label(context)
              : AppTextStyle.caption1.of(context, emphasized: true),
        ),
      ),
    );
    return DashboardCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            spacing: 4,
            children: [
              for (final (requests, count, label) in [
                (false, _connections.length, strings.connections),
                (true, _requests.length, strings.requests),
              ])
                Flexible(
                  child: FilledButton(
                    onPressed: () => setState(() => _showRequests = requests),
                    style: FilledButton.styleFrom(
                      backgroundColor: _showRequests == requests
                          ? context.colorScheme.primary
                          : DashboardColors.of(context).tone,
                      foregroundColor: _showRequests == requests
                          ? context.colorScheme.onPrimary
                          : context.colorScheme.onSurfaceVariant,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      minimumSize: const Size(0, 36),
                    ),
                    child: Text(
                      '${dashboardCount(count)} $label',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          DashboardBlock(
            radius: DashboardCorner.tableHeader,
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              children: [
                cell(strings.source, 18),
                cell(strings.destination, 32),
                cell(strings.currentProxy, 24),
                cell(strings.download, 13),
                cell(strings.upload, 13),
              ],
            ),
          ),
          const SizedBox(height: 6),
          Expanded(
            child: rows.isEmpty
                ? Center(
                    child: Text(
                      strings.nullTip(
                        _showRequests ? strings.requests : strings.connections,
                      ),
                      style: DashboardText.label(context),
                    ),
                  )
                : ListView.builder(
                    primary: false,
                    itemExtent: 38,
                    itemCount: rows.length,
                    itemBuilder: (_, i) {
                      final info = rows[i];
                      return InkWell(
                        key: ValueKey(info.id),
                        onTap: () => showExtend(
                          context,
                          builder: (_) => AdaptiveSheetScaffold(
                            title: strings.details(strings.connection),
                            body: TrackerInfoDetailView(trackerInfo: info),
                          ),
                        ),
                        child: Row(
                          children: [
                            cell(
                              info.progressText.isEmpty
                                  ? info.metadata.network.toUpperCase()
                                  : info.progressText,
                              18,
                            ),
                            cell(
                              '${info.title}:${info.metadata.destinationPort}',
                              32,
                            ),
                            cell(
                              info.chains.isEmpty
                                  ? 'DIRECT'
                                  : info.chains.first,
                              24,
                            ),
                            cell(
                              dashboardTraffic(info.download),
                              13,
                              figure: true,
                            ),
                            cell(
                              dashboardTraffic(info.upload),
                              13,
                              figure: true,
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

final _services = [
  ('Google', 'https://www.gstatic.com/generate_204', AppGlyphs.proxies),
  ('GitHub', 'https://github.com', AppGlyphs.code),
  ('YouTube', 'https://www.youtube.com', AppGlyphs.proxies),
  ('ChatGPT', 'https://chatgpt.com', AppGlyphs.sparkle),
];

class ServiceStatusCard extends ConsumerStatefulWidget {
  const ServiceStatusCard({super.key});
  @override
  ConsumerState<ServiceStatusCard> createState() => _ServiceStatusCardState();
}

class _ServiceStatusCardState extends ConsumerState<ServiceStatusCard>
    with WidgetsBindingObserver, ActivePollingMixin<ServiceStatusCard> {
  @override
  Duration get pollInterval => const Duration(minutes: 1);
  @override
  bool get canPoll =>
      super.canPoll &&
      ref.read(uiVisibleProvider) &&
      ref.read(isStartProvider) &&
      ref.read(coreStatusProvider) == CoreStatus.connected;
  @override
  void initState() {
    super.initState();
    ref.listenManual(coreStatusProvider, (_, _) => restartPolling());
    ref.listenManual(isStartProvider, (_, _) => restartPolling());
    ref.listenManual(uiVisibleProvider, (_, _) => restartPolling());
  }

  Future<void> _refresh() async {
    if (!canPoll) return;
    final groups = ref.read(currentGroupsStateProvider).value;
    final proxy = Proxy(
      name: groups.firstOrNull?.name ?? 'DIRECT',
      type: 'Selector',
    );
    await Future.wait([
      for (final service in _services)
        ref
            .read(proxiesActionProvider.notifier)
            .proxyDelayTest(proxy, service.$2),
    ]);
  }

  @override
  Future<void> poll(PollGuard isCurrent) => _refresh();
  @override
  Widget build(BuildContext context) {
    final mobile = !DashboardDensityScope.of(context).isDesktop;
    final groups = ref.watch(currentGroupsStateProvider).value;
    final name = groups.firstOrNull?.name ?? 'DIRECT';
    Widget service(int index) {
      final target = _services[index];
      final delay = ref.watch(
        delayProvider(proxyName: name, testUrl: target.$2),
      );
      final pending = ref.watch(
        delayTestPendingProvider(proxyName: name, testUrl: target.$2),
      );
      return DashboardBlock(
        radius: DashboardCorner.badge,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        child: Row(
          spacing: 8,
          children: [
            SvgPicture.asset(
              'assets/images/services/${const ['google', 'github', 'youtube', 'openai'][index]}.svg',
              width: 22,
              height: 22,
              excludeFromSemantics: true,
              theme: SvgTheme(
                currentColor: context.colorScheme.onSurfaceVariant,
              ),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    target.$1,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyle.footnote.of(context, emphasized: true),
                  ),
                  Row(
                    spacing: 5,
                    children: [
                      Container(
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: pending
                              ? context.colorScheme.primary
                              : delay == null
                              ? context.colorScheme.outline
                              : context.colorScheme.delayColor(delay),
                        ),
                      ),
                      Text(
                        pending
                            ? '…'
                            : delay == null
                            ? '—'
                            : delay > 0
                            ? '$delay ms'
                            : context.appLocalizations.timeout,
                        style: DashboardText.label(context),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return DashboardCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: mobile ? MainAxisSize.min : MainAxisSize.max,
        children: [
          DashboardCardHeader(
            glyph: AppGlyphs.verified,
            title: context.appLocalizations.serviceStatus,
            trailing: [
              DashboardIconButton(
                glyph: AppGlyphs.bolt,
                tooltip: context.appLocalizations.delayTest,
                onPressed: () => unawaited(_refresh()),
              ),
            ],
          ),
          if (mobile) const SizedBox(height: 14) else const Spacer(),
          Row(
            spacing: 8,
            children: [
              Expanded(child: service(0)),
              Expanded(child: service(1)),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            spacing: 8,
            children: [
              Expanded(child: service(2)),
              Expanded(child: service(3)),
            ],
          ),
        ],
      ),
    );
  }
}

class MemoryInfo extends ConsumerStatefulWidget {
  const MemoryInfo({super.key, this.memoryReader});
  final Future<num> Function()? memoryReader;
  @override
  ConsumerState<MemoryInfo> createState() => _MemoryInfoState();
}

class _MemoryInfoState extends ConsumerState<MemoryInfo>
    with WidgetsBindingObserver, ActivePollingMixin<MemoryInfo> {
  num _memory = 0;
  final List<Point> _history = [];
  @override
  Duration get pollInterval => const Duration(seconds: 2);
  @override
  Future<void> poll(PollGuard isCurrent) async {
    final reader = widget.memoryReader;
    final memory = reader != null
        ? await reader()
        : ProcessInfo.currentRss +
              (ref.read(coreStatusProvider) == CoreStatus.connected
                  ? await ref.read(coreHandlerProvider).getMemory()
                  : 0);
    if (isCurrent()) {
      setState(() {
        _memory = memory;
        _history.add(Point(_history.length.toDouble(), memory.toDouble()));
        if (_history.length > 30) _history.removeAt(0);
      });
    }
  }

  @override
  Widget build(BuildContext context) => DashboardCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DashboardCardHeader(
          glyph: AppGlyphs.memory,
          title: context.appLocalizations.memoryInfo,
        ),
        const SizedBox(height: 20),
        Text(
          dashboardTraffic(_memory),
          style: DashboardText.figure(context, AppTextStyle.title1),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 28,
          child: LineChart(
            color: context.colorScheme.primary,
            points: [
              for (final (i, point) in _history.indexed)
                Point(i.toDouble(), point.y),
            ],
          ),
        ),
      ],
    ),
  );
}
