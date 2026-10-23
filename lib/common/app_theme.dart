import 'package:fl_clash/models/config.dart';
import 'package:material_ui/material_ui.dart';

import 'glass.dart';
import 'shape.dart';

ThemeData buildAppTheme({
  required Brightness brightness,
  required ColorScheme materialScheme,
  required PageTransitionsTheme pageTransitionsTheme,
  required ThemeProps themeProps,
}) {
  final pureBlack = brightness == Brightness.dark && themeProps.pureBlack;
  final dark = brightness == Brightness.dark;
  final scheme = materialScheme.copyWith(
    surface: pureBlack ? Colors.black : Color(dark ? 0xFF101012 : 0xFFF5F5F7),
    surfaceContainerLowest: Color(dark ? 0xFF171719 : 0xFFFFFFFF),
    surfaceContainerLow: Color(dark ? 0xFF1C1C1E : 0xFFFFFFFF),
    surfaceContainer: Color(dark ? 0xFF232325 : 0xFFEFEFF2),
    surfaceContainerHigh: Color(dark ? 0xFF2C2C2E : 0xFFE8E8ED),
    surfaceContainerHighest: Color(dark ? 0xFF363638 : 0xFFE2E2E7),
    onSurface: Color(dark ? 0xFFF5F5F7 : 0xFF1D1D1F),
    onSurfaceVariant: Color(dark ? 0xFFABABB0 : 0xFF6E6E73),
    outline: const Color(0xFF86868B),
    outlineVariant: Color(dark ? 0xFF38383A : 0xFFD2D2D7),
  );
  final surfaces = GlassStyle.of(scheme, pureBlack: pureBlack);
  final base = ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    pageTransitionsTheme: pageTransitionsTheme,
    extensions: [surfaces],
  );
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
      titleTextStyle: text.titleLarge?.copyWith(
        color: scheme.onSurface,
        fontWeight: FontWeight.w600,
      ),
    ),
    cardTheme: CardThemeData(
      color: surfaces.card,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: AppShape.extraLarge,
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: scheme.surfaceContainerLow,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      indicatorColor: Colors.transparent,
      iconTheme: WidgetStateProperty.resolveWith(
        (states) => IconThemeData(
          color: states.contains(WidgetState.selected)
              ? scheme.primary
              : scheme.onSurfaceVariant,
          size: 22,
        ),
      ),
      labelTextStyle: WidgetStateProperty.resolveWith(
        (states) => text.labelSmall?.copyWith(
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
      shape: AppShape.extraLarge,
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
      border: AppShape.input,
      enabledBorder: AppShape.input,
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

extension AppSchemeExt on ColorScheme {
  Color get modalScrim => scrim.withValues(alpha: 0.32);
}

ColorScheme seededColorScheme(
  Color seed,
  Brightness brightness,
  DynamicSchemeVariant variant,
) {
  final scheme = ColorScheme.fromSeed(
    seedColor: seed,
    brightness: brightness,
    dynamicSchemeVariant: variant,
  );
  if (seed.toARGB32() != 0xFF007AFF) return scheme;
  return scheme.copyWith(
    primary: Color(brightness == Brightness.dark ? 0xFF2997FF : 0xFF0071E3),
    onPrimary: brightness == Brightness.dark
        ? const Color(0xFF001B3D)
        : Colors.white,
  );
}
