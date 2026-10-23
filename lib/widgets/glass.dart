import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:material_ui/material_ui.dart';

class AppFloor extends StatelessWidget {
  const AppFloor({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(color: context.glass.background, child: child);
  }
}

enum GlassKind { panel, tile, chrome }

class GlassSurface extends StatelessWidget {
  const GlassSurface({
    super.key,
    this.kind = GlassKind.tile,
    this.borderRadius,
    this.padding = EdgeInsets.zero,
    this.selected = false,
    this.color,
    this.rimColor,
    this.elevated,
    this.clip = true,
    this.circle = false,
    this.plain = false,
    required this.child,
  });

  final GlassKind kind;
  final BorderRadius? borderRadius;
  final EdgeInsetsGeometry padding;
  final bool selected;
  final Color? color;
  final Color? rimColor;
  final bool? elevated;
  final bool clip;
  final bool circle;
  final bool plain;
  final Widget child;

  static BorderRadius radiusOf(GlassKind kind) => switch (kind) {
    GlassKind.panel => AppRadius.extraLarge,
    GlassKind.tile => AppRadius.large,
    GlassKind.chrome => AppRadius.large,
  };

  static OutlinedBorder shapeOf({
    required GlassKind kind,
    BorderRadius? borderRadius,
    bool circle = false,
  }) => circle
      ? const CircleBorder()
      : RoundedRectangleBorder(borderRadius: borderRadius ?? radiusOf(kind));

  @override
  Widget build(BuildContext context) {
    final scheme = context.colorScheme;
    final shape = shapeOf(
      kind: kind,
      borderRadius: borderRadius,
      circle: circle,
    );
    final fill =
        color ??
        (selected
            ? scheme.secondaryContainer
            : kind == GlassKind.tile
            ? context.glass.card
            : context.glass.glass);
    final border = rimColor ?? Colors.transparent;
    return Material(
      type: plain ? MaterialType.transparency : MaterialType.canvas,
      color: plain ? null : fill,
      elevation: elevated == true ? 1 : 0,
      surfaceTintColor: Colors.transparent,
      shape: shape.copyWith(
        side: plain || border == Colors.transparent
            ? BorderSide.none
            : BorderSide(color: border),
      ),
      clipBehavior: clip ? Clip.antiAlias : Clip.none,
      child: Padding(padding: padding, child: child),
    );
  }
}

class GlassButton extends StatelessWidget {
  const GlassButton({
    super.key,
    this.onTap,
    this.onLongPress,
    this.onSecondaryTap,
    this.kind = GlassKind.tile,
    this.borderRadius,
    this.padding = EdgeInsets.zero,
    this.selected = false,
    this.color,
    this.rimColor,
    this.elevated,
    this.focusNode,
    this.autofocus = false,
    this.tooltip,
    this.circle = false,
    this.plain = false,
    required this.child,
  });

  final bool circle;
  final bool plain;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final VoidCallback? onSecondaryTap;
  final GlassKind kind;
  final BorderRadius? borderRadius;
  final EdgeInsetsGeometry padding;
  final bool selected;
  final Color? color;
  final Color? rimColor;
  final bool? elevated;
  final FocusNode? focusNode;
  final bool autofocus;
  final String? tooltip;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final colorScheme = context.colorScheme;
    final button = GlassSurface(
      kind: kind,
      borderRadius: borderRadius,
      circle: circle,
      plain: plain,
      selected: selected,
      color: color,
      rimColor: rimColor,
      elevated: elevated,
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        onSecondaryTap: onSecondaryTap,
        focusNode: focusNode,
        autofocus: autofocus,
        customBorder: GlassSurface.shapeOf(
          kind: kind,
          borderRadius: borderRadius,
          circle: circle,
        ),
        overlayColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.pressed)) {
            return colorScheme.onSurface.withValues(alpha: 0.08);
          }
          if (states.contains(WidgetState.focused)) {
            return colorScheme.primary.withValues(alpha: 0.12);
          }
          if (states.contains(WidgetState.hovered)) {
            return colorScheme.onSurface.withValues(alpha: 0.04);
          }
          return null;
        }),
        child: Padding(padding: padding, child: child),
      ),
    );
    final tooltip = this.tooltip;
    return tooltip == null ? button : Tooltip(message: tooltip, child: button);
  }
}

class GlassIconBadge extends StatelessWidget {
  const GlassIconBadge({
    super.key,
    required this.icon,
    this.color,
    this.size = 30,
  });

  final IconData icon;
  final Color? color;
  final double size;

  @override
  Widget build(BuildContext context) {
    final accent = color ?? context.colorScheme.primary;
    return DecoratedBox(
      decoration: ShapeDecoration(
        color: accent.withValues(alpha: 0.12),
        shape: RoundedRectangleBorder(borderRadius: AppRadius.all(size * 0.28)),
      ),
      child: SizedBox.square(
        dimension: size,
        child: Icon(icon, size: size * 0.6, color: accent),
      ),
    );
  }
}

class GlassSectionLabel extends StatelessWidget {
  const GlassSectionLabel(
    this.label, {
    super.key,
    this.trailing,
    this.padding = const EdgeInsets.fromLTRB(16, 22, 12, 8),
  });

  final String label;
  final Widget? trailing;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final trailing = this.trailing;
    return Padding(
      padding: padding,
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: context.textTheme.bodySmall?.copyWith(
                color: context.glass.secondaryLabel,
                fontSize: 13,
              ),
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }
}

/// A tinted capsule for short states: delays, results, counts.
class GlassPill extends StatelessWidget {
  const GlassPill({
    super.key,
    required this.label,
    this.color,
    this.icon,
    this.monospace = false,
  });

  final String label;
  final Color? color;
  final IconData? icon;
  final bool monospace;

  @override
  Widget build(BuildContext context) {
    final accent = color ?? context.colorScheme.primary;
    final icon = this.icon;
    return DecoratedBox(
      decoration: ShapeDecoration(
        color: accent.withValues(alpha: context.glass.isDark ? 0.22 : 0.12),
        shape: AppShape.full,
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 14, color: accent),
              const SizedBox(width: 4),
            ],
            Text(
              label,
              maxLines: 1,
              style: context.textTheme.labelMedium?.copyWith(
                color: accent,
                fontWeight: FontWeight.w600,
                fontFamily: monospace ? FontFamily.jetBrainsMono.value : null,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class GlassIconButton extends StatelessWidget {
  const GlassIconButton({
    super.key,
    required this.icon,
    required this.onPressed,
    this.tooltip,
    this.size = 32,
    this.color,
  });

  final IconData icon;
  final VoidCallback? onPressed;
  final String? tooltip;
  final double size;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: tooltip,
      onPressed: onPressed,
      icon: Icon(icon, size: size * 0.56),
      style: IconButton.styleFrom(
        fixedSize: Size.square(size),
        minimumSize: Size.square(size),
        padding: EdgeInsets.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        visualDensity: VisualDensity.standard,
        foregroundColor: color ?? context.glass.secondaryLabel,
      ),
    );
  }
}
