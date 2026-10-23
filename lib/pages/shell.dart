import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/widgets/glyphs/glyphs.dart';
import 'package:material_ui/material_ui.dart';

typedef OnDestinationSelected = void Function(PageLabel label);

Glyph destinationGlyph(PageLabel label) => switch (label) {
  PageLabel.dashboard => AppGlyphs.dashboard,
  PageLabel.proxies => AppGlyphs.proxies,
  PageLabel.profiles => AppGlyphs.profiles,
  PageLabel.whitelist => AppGlyphs.vpn,
  PageLabel.activity || PageLabel.connections => AppGlyphs.connections,
  PageLabel.requests => AppGlyphs.requests,
  PageLabel.logs => AppGlyphs.logs,
  PageLabel.resources => AppGlyphs.resources,
  PageLabel.tools => AppGlyphs.tools,
};

class GlassDock extends StatelessWidget {
  const GlassDock({
    super.key,
    required this.items,
    required this.currentIndex,
    required this.onSelected,
  });

  static const height = 62.0;

  final List<NavigationItem> items;
  final int currentIndex;
  final OnDestinationSelected onSelected;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const SizedBox.shrink();
    return SafeArea(
      top: false,
      minimum: const EdgeInsets.fromLTRB(20, 8, 20, 16),
      child: DecoratedBox(
        decoration: ShapeDecoration(
          shape: AppShape.full,
          shadows: [
            BoxShadow(
              color: context.colorScheme.shadow.withValues(alpha: 0.12),
              blurRadius: 24,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: ClipPath(
          clipper: const ShapeBorderClipper(shape: AppShape.full),
          child: NavigationBar(
            height: height,
            selectedIndex: currentIndex,
            onDestinationSelected: (index) => onSelected(items[index].label),
            destinations: [
              for (final (index, item) in items.indexed)
                NavigationDestination(
                  icon: AnimatedGlyph(
                    glyph: destinationGlyph(item.label),
                    filled: index == currentIndex,
                  ),
                  label: item.label.label,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class GlassRail extends StatelessWidget {
  const GlassRail({
    super.key,
    required this.items,
    required this.currentIndex,
    required this.onSelected,
    this.onToggle,
  });
  static const width = 80.0;
  final List<NavigationItem> items;
  final int currentIndex;
  final OnDestinationSelected onSelected;
  final VoidCallback? onToggle;
  @override
  Widget build(BuildContext context) => _NavigationRail(
    items: items,
    currentIndex: currentIndex,
    onSelected: onSelected,
    extended: false,
    onToggle: onToggle,
  );
}

class ControlSidebar extends StatelessWidget {
  const ControlSidebar({
    super.key,
    required this.items,
    required this.currentIndex,
    required this.onSelected,
    this.topInset = 0,
    this.onToggle,
  });
  static const width = 224.0;
  final List<NavigationItem> items;
  final int currentIndex;
  final OnDestinationSelected onSelected;
  final double topInset;
  final VoidCallback? onToggle;
  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.only(top: topInset),
    child: _NavigationRail(
      items: items,
      currentIndex: currentIndex,
      onSelected: onSelected,
      extended: true,
      onToggle: onToggle,
    ),
  );
}

class _NavigationRail extends StatelessWidget {
  const _NavigationRail({
    required this.items,
    required this.currentIndex,
    required this.onSelected,
    required this.extended,
    this.onToggle,
  });
  final List<NavigationItem> items;
  final int currentIndex;
  final OnDestinationSelected onSelected;
  final bool extended;
  final VoidCallback? onToggle;
  @override
  Widget build(BuildContext context) {
    final scheme = context.colorScheme;
    return Material(
      color: scheme.brightness == Brightness.dark
          ? scheme.surfaceContainerLow
          : scheme.surfaceContainerHighest,
      child: SizedBox(
        width: extended ? ControlSidebar.width : GlassRail.width,
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 24),
          child: Column(
            crossAxisAlignment: extended
                ? CrossAxisAlignment.start
                : CrossAxisAlignment.center,
            children: [
              Padding(
                padding: const EdgeInsets.only(left: 4),
                child: IconButton(
                  tooltip: extended
                      ? context.appLocalizations.collapseNavigation
                      : context.appLocalizations.expandNavigation,
                  onPressed: onToggle,
                  icon: GlyphIcon(
                    AppGlyphs.sidebar(extended ? 1 : 0),
                    size: 22,
                  ),
                ),
              ),
              const SizedBox(height: 20),
              for (final (index, item) in items.indexed)
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Semantics(
                    selected: index == currentIndex,
                    child: extended
                        ? Stack(
                            children: [
                              ListTile(
                                selected: index == currentIndex,
                                selectedTileColor: scheme.onSurface.withValues(
                                  alpha: 0.08,
                                ),
                                selectedColor: scheme.onSurface,
                                iconColor: scheme.onSurfaceVariant,
                                shape: AppShape.md,
                                minTileHeight: 40,
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                ),
                                leading: AnimatedGlyph(
                                  glyph: destinationGlyph(item.label),
                                  filled: index == currentIndex,
                                ),
                                title: Text(
                                  item.label.label,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: AppTextStyle.footnote.of(
                                    context,
                                    emphasized: true,
                                  ),
                                ),
                                onTap: () => onSelected(item.label),
                              ),
                              if (index == currentIndex)
                                PositionedDirectional(
                                  start: 0,
                                  top: 10,
                                  bottom: 10,
                                  width: 3,
                                  child: DecoratedBox(
                                    decoration: ShapeDecoration(
                                      color: scheme.primary,
                                      shape: AppShape.full,
                                    ),
                                  ),
                                ),
                            ],
                          )
                        : InkWell(
                            borderRadius: AppRadius.md,
                            onTap: () => onSelected(item.label),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              child: Column(
                                children: [
                                  IconTheme(
                                    data: IconThemeData(
                                      size: 24,
                                      color: index == currentIndex
                                          ? scheme.primary
                                          : scheme.onSurfaceVariant,
                                    ),
                                    child: AnimatedGlyph(
                                      glyph: destinationGlyph(item.label),
                                      filled: index == currentIndex,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    item.label.label,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: context.textTheme.labelSmall,
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
