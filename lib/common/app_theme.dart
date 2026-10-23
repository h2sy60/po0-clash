import 'package:fl_clash/models/config.dart';
import 'package:material_ui/material_ui.dart';
import 'package:fl_clash/widgets/glyphs/glyphs.dart';

import 'glass.dart';
import 'upstream_color.dart' as upstream;
import 'shape.dart';
import 'typography.dart';

ThemeData buildAppTheme({
  required Brightness brightness,
  required ColorScheme materialScheme,
  required PageTransitionsTheme pageTransitionsTheme,
  required ThemeProps themeProps,
}) {
  final pureBlack = brightness == Brightness.dark && themeProps.pureBlack;
  final scheme = upstream.ColorSchemeExtension(
    materialScheme,
  ).toPureBlack(pureBlack);
  final surfaces = GlassStyle.of(scheme, pureBlack: pureBlack);
  final base = ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    pageTransitionsTheme: pageTransitionsTheme,
    actionIconTheme: ActionIconThemeData(
      backButtonIconBuilder: (context) =>
          GlyphIcon(AppGlyphs.backFor(Theme.of(context).platform)),
      closeButtonIconBuilder: (_) => const GlyphIcon(AppGlyphs.close),
    ),
    extensions: [surfaces],
  ).withAppShapes.withAppTypography;
  final text = base.textTheme;
  return base.copyWith(
    scaffoldBackgroundColor: surfaces.background,
    canvasColor: surfaces.background,
    dividerColor: scheme.outlineVariant,
    appBarTheme: AppBarThemeData(
      backgroundColor: surfaces.background,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleTextStyle: AppTextStyle.pageTitle
          .ofTheme(text)
          .copyWith(color: scheme.onSurface, fontWeight: FontWeight.w600),
    ),
    cardTheme: CardThemeData(
      color: surfaces.card,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: AppShape.medium,
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: surfaces.card,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      indicatorColor: surfaces.fill,
      iconTheme: WidgetStateProperty.resolveWith(
        (states) => IconThemeData(
          color: states.contains(WidgetState.selected)
              ? scheme.primary
              : scheme.onSurfaceVariant,
          size: 24,
        ),
      ),
      labelTextStyle: WidgetStateProperty.resolveWith(
        (states) => text.labelSmall?.copyWith(
          fontSize: 10,
          height: 1.45,
          color: states.contains(WidgetState.selected)
              ? scheme.primary
              : scheme.onSurfaceVariant,
          fontWeight: states.contains(WidgetState.selected)
              ? FontWeight.w600
              : FontWeight.w400,
        ),
      ),
    ),
    navigationRailTheme: NavigationRailThemeData(
      backgroundColor: surfaces.background,
      indicatorColor: scheme.secondaryContainer,
      useIndicator: true,
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: surfaces.glassStrong,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      shape: AppShape.all(AppCorner.alert),
      barrierColor: scheme.modalScrim,
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: surfaces.glass,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      modalElevation: 0,
      modalBarrierColor: scheme.modalScrim,
      shape: AppShape.top(AppCorner.extraLarge),
    ),
    dividerTheme: DividerThemeData(color: scheme.outlineVariant, thickness: 1),
    inputDecorationTheme: InputDecorationThemeData(
      filled: true,
      fillColor: scheme.surfaceContainer,
      border: AppShape.input.copyWith(borderSide: BorderSide.none),
      enabledBorder: AppShape.input.copyWith(borderSide: BorderSide.none),
      focusedBorder: AppShape.input.copyWith(
        borderSide: BorderSide(color: scheme.primary, width: 2),
      ),
      errorBorder: AppShape.input.copyWith(
        borderSide: BorderSide(color: scheme.error),
      ),
      focusedErrorBorder: AppShape.input.copyWith(
        borderSide: BorderSide(color: scheme.error, width: 2),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    ),
    filledButtonTheme: const FilledButtonThemeData(
      style: ButtonStyle(
        shape: WidgetStatePropertyAll(AppShape.full),
        elevation: WidgetStatePropertyAll(0),
        padding: WidgetStatePropertyAll(
          EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        ),
      ),
    ),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: scheme.primaryContainer,
      foregroundColor: scheme.onPrimaryContainer,
      elevation: 0,
      focusElevation: 0,
      hoverElevation: 0,
      highlightElevation: 0,
      shape: AppShape.large,
    ),
    menuTheme: MenuThemeData(
      style: MenuStyle(
        backgroundColor: WidgetStatePropertyAll(surfaces.glassStrong),
        surfaceTintColor: const WidgetStatePropertyAll(Colors.transparent),
        elevation: const WidgetStatePropertyAll(0),
        shape: WidgetStatePropertyAll(
          AppShape.medium.copyWith(
            side: BorderSide(color: scheme.outlineVariant),
          ),
        ),
      ),
    ),
    popupMenuTheme: PopupMenuThemeData(
      color: surfaces.glassStrong,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      shape: AppShape.medium.copyWith(
        side: BorderSide(color: scheme.outlineVariant),
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: scheme.inverseSurface,
      contentTextStyle: text.bodyMedium?.copyWith(
        color: scheme.onInverseSurface,
      ),
      elevation: 0,
      shape: AppShape.small,
    ),
    listTileTheme: ListTileThemeData(iconColor: scheme.onSurfaceVariant),
    progressIndicatorTheme: ProgressIndicatorThemeData(
      linearTrackColor: scheme.surfaceContainerHighest,
      borderRadius: AppRadius.full,
    ),
    scrollbarTheme: const ScrollbarThemeData(
      thickness: WidgetStatePropertyAll(6),
      radius: Radius.circular(AppCorner.full),
    ),
    tabBarTheme: TabBarThemeData(
      labelColor: scheme.primary,
      unselectedLabelColor: scheme.onSurfaceVariant,
      dividerColor: scheme.outlineVariant,
      indicatorColor: scheme.primary,
      labelStyle: text.titleSmall,
    ),
  );
}

ColorScheme seededColorScheme(
  Color seed,
  Brightness brightness,
  DynamicSchemeVariant variant,
) {
  return upstream.seededColorScheme(
    seedColor: seed,
    brightness: brightness,
    style: switch (variant) {
      DynamicSchemeVariant.tonalSpot => upstream.ColorStyle.soft,
      DynamicSchemeVariant.monochrome => upstream.ColorStyle.monochrome,
      DynamicSchemeVariant.expressive => upstream.ColorStyle.tinted,
      _ => upstream.ColorStyle.vivid,
    },
  );
}
