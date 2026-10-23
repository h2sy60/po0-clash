import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/models/common.dart';
import 'package:fl_clash/providers/providers.dart';
import 'package:fl_clash/widgets/widgets.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'shell.dart';

class HomePage extends ConsumerWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hasViewSize = ref.watch(
      viewSizeProvider.select((size) => !size.isEmpty),
    );
    if (!hasViewSize) {
      return const SizedBox.shrink();
    }
    return HomeBackScopeContainer(
      child: _MaterialShell(
        child: Consumer(
          builder: (_, ref, _) {
            final navigationItems = ref
                .watch(currentNavigationItemsStateProvider)
                .value;
            final isMobile = ref.watch(isMobileViewProvider);
            return _HomePageView(
              navigationItems: navigationItems,
              pageBuilder: (_, index) {
                final navigationItem = navigationItems[index];
                return _NavigationPage(
                  key: ValueKey(navigationItem.label),
                  item: navigationItem,
                  isMobile: isMobile,
                  view: navigationItem.builder(context),
                );
              },
            );
          },
        ),
      ),
    );
  }
}

class _MaterialShell extends ConsumerStatefulWidget {
  const _MaterialShell({required this.child});
  final Widget child;
  @override
  ConsumerState<_MaterialShell> createState() => _MaterialShellState();
}

class _MaterialShellState extends ConsumerState<_MaterialShell> {
  var _collapsed = false;
  void _handleToPage(WidgetRef ref, PageLabel pageLabel) {
    ref.read(currentPageLabelProvider.notifier).toPage(pageLabel);
  }

  void _updateSideWidth(WidgetRef ref, double contentWidth) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.read(sideWidthProvider.notifier).value =
          ref.read(viewSizeProvider.select((state) => state.width)) -
          contentWidth;
    });
  }

  Widget _buildWorkspace(WidgetRef ref) {
    return LayoutBuilder(
      builder: (_, constraints) {
        _updateSideWidth(ref, constraints.maxWidth);
        return FocusTraversalGroup(
          policy: PageTraversalPolicy(),
          child: widget.child,
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(navigationStateProvider);
    final items = state.navigationItems;
    final currentIndex = state.currentIndex;
    void onSelected(PageLabel label) => _handleToPage(ref, label);
    if (state.viewMode == ViewMode.mobile) {
      return Column(
        children: [
          Expanded(
            child: BottomInsetScope(
              inset: 0,
              child: FocusTraversalGroup(
                policy: PageTraversalPolicy(),
                child: widget.child,
              ),
            ),
          ),
          GlassDock(
            items: items,
            currentIndex: currentIndex,
            onSelected: onSelected,
          ),
        ],
      );
    }
    final showsHeader = showsWindowHeader(
      isDesktop: system.isDesktop,
      isMacOS: system.isMacOS,
      version: ref.watch(versionProvider),
      isMobileView: false,
    );
    final topInset = system.isMacOS && !showsHeader ? 24.0 : 0.0;
    final navigation = state.viewMode == ViewMode.desktop && !_collapsed
        ? ControlSidebar(
            items: items,
            currentIndex: currentIndex,
            onSelected: onSelected,
            topInset: topInset,
            onToggle: () => setState(() => _collapsed = true),
          )
        : Padding(
            padding: EdgeInsets.only(top: topInset),
            child: GlassRail(
              onToggle: state.viewMode == ViewMode.desktop
                  ? () => setState(() => _collapsed = false)
                  : null,
              items: items,
              currentIndex: currentIndex,
              onSelected: onSelected,
            ),
          );
    return Material(
      color: context.colorScheme.surface,
      child: SafeArea(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            navigation,
            const VerticalDivider(width: 1),
            Expanded(child: _buildWorkspace(ref)),
          ],
        ),
      ),
    );
  }
}

class _NavigationPage extends StatelessWidget {
  const _NavigationPage({
    super.key,
    required this.item,
    required this.isMobile,
    required this.view,
  });

  final NavigationItem item;
  final bool isMobile;
  final Widget view;

  @override
  Widget build(BuildContext context) {
    final scopedView = PageFocusScope(child: view);
    final keptView = KeepScope(
      key: ValueKey(item.label),
      keep: item.keep,
      child: isMobile
          ? scopedView
          : Navigator(
              key: ValueKey('${item.label.name}_navigator'),
              pages: [MaterialPage(child: scopedView)],
              onDidRemovePage: (_) {},
            ),
    );
    return Consumer(
      builder: (_, ref, child) {
        final isActive = ref.watch(
          currentPageLabelProvider.select((label) => label == item.label),
        );
        final animateEntrance =
            ref.watch(appSettingProvider.select((it) => it.isAnimateToPage)) &&
            !context.disableAnimations;
        return PageActivityScope(
          isActive: isActive,
          child: ExcludeFocus(
            excluding: !isActive,
            child: PageEntrance(
              active: isActive,
              enabled: animateEntrance,
              child: child!,
            ),
          ),
        );
      },
      child: keptView,
    );
  }
}

/// The incoming 65% of the fade-through: the page rises and clears into
/// place. It stays in the tree when disabled.
class PageEntrance extends StatefulWidget {
  const PageEntrance({
    super.key,
    required this.active,
    required this.enabled,
    required this.child,
  });

  static const duration = Duration(milliseconds: 195);

  final bool active;
  final bool enabled;
  final Widget child;

  @override
  State<PageEntrance> createState() => _PageEntranceState();
}

class _PageEntranceState extends State<PageEntrance>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _opacity;
  late final Animation<double> _scale;
  late final Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: PageEntrance.duration,
      value: 1,
    );
    final curve = CurvedAnimation(
      parent: _controller,
      curve: Easing.emphasizedDecelerate,
    );
    _opacity = curve;
    _scale = Tween(begin: 0.97, end: 1.0).animate(curve);
    _slide = Tween(
      begin: const Offset(0, 0.02),
      end: Offset.zero,
    ).animate(curve);
    if (widget.enabled && widget.active) {
      _controller.forward(from: 0);
    }
  }

  @override
  void didUpdateWidget(covariant PageEntrance oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.enabled && widget.active && !oldWidget.active) {
      _controller.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _opacity,
      child: SlideTransition(
        position: _slide,
        child: ScaleTransition(scale: _scale, child: widget.child),
      ),
    );
  }
}

class _HomePageView extends ConsumerStatefulWidget {
  final IndexedWidgetBuilder pageBuilder;
  final List<NavigationItem> navigationItems;

  const _HomePageView({
    required this.pageBuilder,
    required this.navigationItems,
  });

  @override
  ConsumerState createState() => _HomePageViewState();
}

class _HomePageViewState extends ConsumerState<_HomePageView>
    with SingleTickerProviderStateMixin {
  /// Outgoing 35% of the 300 ms fade-through, before the page view jumps.
  static const _fadeOutDuration = Duration(milliseconds: 105);

  late PageController _pageController;
  late final AnimationController _outgoing = AnimationController(
    vsync: this,
    duration: _fadeOutDuration,
    value: 1,
  );
  int _switchVersion = 0;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: _pageIndex);
    ref.listenManual(currentPageLabelProvider, (prev, next) {
      if (prev != next) {
        _toPage(next);
      }
    });
  }

  @override
  void didUpdateWidget(covariant _HomePageView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.navigationItems.length != widget.navigationItems.length) {
      _updatePageController();
    }
  }

  int get _pageIndex {
    final pageLabel = ref.read(currentPageLabelProvider);
    final index = widget.navigationItems.indexWhere(
      (item) => item.label == pageLabel,
    );
    return index == -1 ? 0 : index;
  }

  Future<void> _toPage(
    PageLabel pageLabel, [
    bool ignoreAnimateTo = false,
  ]) async {
    if (!mounted) {
      return;
    }
    final index = widget.navigationItems.indexWhere(
      (item) => item.label == pageLabel,
    );
    if (index == -1) {
      return;
    }
    final version = ++_switchVersion;
    final animate =
        ref.read(appSettingProvider).isAnimateToPage &&
        !context.disableAnimations &&
        !ignoreAnimateTo;
    if (animate) {
      await _outgoing.animateTo(0, curve: Easing.standardAccelerate);
      if (!mounted || version != _switchVersion) {
        return;
      }
    }
    _pageController.jumpToPage(index);
    _outgoing.value = 1;
  }

  void _updatePageController() {
    final pageLabel = ref.read(currentPageLabelProvider);
    final isShown = widget.navigationItems.any(
      (item) => item.label == pageLabel,
    );
    if (!isShown) {
      if (_pageController.hasClients) {
        _pageController.jumpToPage(0);
      }
      return;
    }
    _toPage(pageLabel, true);
  }

  @override
  void dispose() {
    _outgoing.dispose();
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final itemCount = ref.watch(
      currentNavigationItemsStateProvider.select((state) => state.value.length),
    );
    final pageView = PageView.builder(
      controller: _pageController,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: itemCount,
      findChildIndexCallback: (key) {
        if (key is! ValueKey<PageLabel>) {
          return null;
        }
        final index = widget.navigationItems.indexWhere(
          (item) => item.label == key.value,
        );
        return index == -1 ? null : index;
      },
      itemBuilder: (context, index) {
        return widget.pageBuilder(context, index);
      },
    );
    return FadeTransition(opacity: _outgoing, child: pageView);
  }
}

class HomeBackScopeContainer extends ConsumerWidget {
  final Widget child;

  const HomeBackScopeContainer({super.key, required this.child});

  @override
  Widget build(BuildContext context, ref) {
    return CommonPopScope(
      onPop: (context) async {
        final pageLabel = ref.read(currentPageLabelProvider);
        final realContext =
            GlobalObjectKey(pageLabel).currentContext ?? context;
        final canPop = Navigator.canPop(realContext);
        if (canPop) {
          Navigator.of(realContext).pop();
        } else {
          await ref.read(systemActionProvider.notifier).handleClose();
        }
        return false;
      },
      child: child,
    );
  }
}
