import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/models/models.dart';
import 'package:material_ui/material_ui.dart';

typedef OnDestinationSelected = void Function(PageLabel label);

class GlassDock extends StatelessWidget {
  const GlassDock({
    super.key,
    required this.items,
    required this.currentIndex,
    required this.onSelected,
  });

  static const height = 80.0;

  final List<NavigationItem> items;
  final int currentIndex;
  final OnDestinationSelected onSelected;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const SizedBox.shrink();
    return NavigationBar(
      height: height,
      selectedIndex: currentIndex,
      onDestinationSelected: (index) => onSelected(items[index].label),
      destinations: [
        for (final item in items)
          NavigationDestination(icon: item.icon, label: item.label.label),
      ],
    );
  }
}

class GlassRail extends StatelessWidget {
  const GlassRail({
    super.key,
    required this.items,
    required this.currentIndex,
    required this.onSelected,
  });

  static const width = 88.0;

  final List<NavigationItem> items;
  final int currentIndex;
  final OnDestinationSelected onSelected;

  @override
  Widget build(BuildContext context) => _NavigationRail(
    items: items,
    currentIndex: currentIndex,
    onSelected: onSelected,
    extended: false,
  );
}

class ControlSidebar extends StatelessWidget {
  const ControlSidebar({
    super.key,
    required this.items,
    required this.currentIndex,
    required this.onSelected,
    this.topInset = 0,
  });

  static const width = 216.0;

  final List<NavigationItem> items;
  final int currentIndex;
  final OnDestinationSelected onSelected;
  final double topInset;

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.only(top: topInset),
    child: _NavigationRail(
      items: items,
      currentIndex: currentIndex,
      onSelected: onSelected,
      extended: true,
    ),
  );
}

class _NavigationRail extends StatelessWidget {
  const _NavigationRail({
    required this.items,
    required this.currentIndex,
    required this.onSelected,
    required this.extended,
  });

  final List<NavigationItem> items;
  final int currentIndex;
  final OnDestinationSelected onSelected;
  final bool extended;

  @override
  Widget build(BuildContext context) {
    final width = extended ? ControlSidebar.width : GlassRail.width;
    if (items.isEmpty) return SizedBox(width: width);
    final scheme = context.colorScheme;
    return Material(
      color: scheme.surfaceContainerLow,
      child: SizedBox(
        width: width,
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 28),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Row(
                  mainAxisAlignment: extended
                      ? MainAxisAlignment.start
                      : MainAxisAlignment.center,
                  children: [
                    ClipRRect(
                      borderRadius: AppRadius.small,
                      child: Image.asset(
                        'assets/images/icon.png',
                        width: 30,
                        height: 30,
                      ),
                    ),
                    if (extended) ...[
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          appName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: context.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 36),
              for (final (index, item) in items.indexed)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: extended
                      ? ListTile(
                          selected: index == currentIndex,
                          selectedTileColor: scheme.primary.withValues(
                            alpha: 0.08,
                          ),
                          selectedColor: scheme.primary,
                          iconColor: scheme.onSurfaceVariant,
                          shape: AppShape.medium,
                          minTileHeight: 48,
                          leading: IconTheme.merge(
                            data: const IconThemeData(size: 20),
                            child: item.icon,
                          ),
                          title: Text(
                            item.label.label,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          onTap: () => onSelected(item.label),
                        )
                      : Semantics(
                          selected: index == currentIndex,
                          button: true,
                          child: InkWell(
                            borderRadius: AppRadius.medium,
                            onTap: () => onSelected(item.label),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              child: Column(
                                children: [
                                  IconTheme(
                                    data: IconThemeData(
                                      size: 22,
                                      color: index == currentIndex
                                          ? scheme.primary
                                          : scheme.onSurfaceVariant,
                                    ),
                                    child: item.icon,
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    item.label.label,
                                    style: context.textTheme.labelSmall
                                        ?.copyWith(
                                          color: index == currentIndex
                                              ? scheme.primary
                                              : scheme.onSurfaceVariant,
                                        ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
