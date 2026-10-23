import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/models/models.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

ThemeData _build({
  Brightness brightness = Brightness.light,
  ThemeProps themeProps = const ThemeProps(),
}) {
  return buildAppTheme(
    brightness: brightness,
    materialScheme: ColorScheme.fromSeed(
      seedColor: Colors.teal,
      brightness: brightness,
    ),
    pageTransitionsTheme: const PageTransitionsTheme(),
    themeProps: themeProps,
  );
}

void main() {
  group('buildAppTheme', () {
    test('preserves the chosen accent and surface colors', () {
      final theme = _build();
      expect(theme.useMaterial3, isTrue);
      expect(
        theme.colorScheme.primary,
        ColorScheme.fromSeed(seedColor: Colors.teal).primary,
      );
    });

    test('pure black only reaches the dark theme', () {
      final dark = _build(
        brightness: Brightness.dark,
        themeProps: const ThemeProps(pureBlack: true),
      );
      expect(dark.colorScheme.surface, Colors.black);
      final light = _build(themeProps: const ThemeProps(pureBlack: true));
      expect(light.colorScheme.surface, isNot(Colors.black));
    });

    test('text fields use a continuous filled surface', () {
      final theme = _build();
      final border = theme.inputDecorationTheme.border;
      expect(theme.inputDecorationTheme.filled, isTrue);
      expect(border, isA<AppInputBorder>());
      expect((border! as AppInputBorder).borderRadius, AppRadius.medium);
    });

    test('content and navigation retain the upstream surface hierarchy', () {
      final theme = _build();
      final glass = theme.extension<GlassStyle>()!;
      expect(theme.scaffoldBackgroundColor, theme.colorScheme.surfaceContainer);
      expect(glass.card, theme.colorScheme.surfaceBright);
      expect(glass.glass.a, 1);
      expect(glass.glassStrong.a, 1);
      expect(theme.cardTheme.color, glass.card);
      expect(theme.cardTheme.shape, isA<RoundedSuperellipseBorder>());
    });

    test('standard controls retain Material touch targets', () {
      expect(_build().materialTapTargetSize, MaterialTapTargetSize.padded);
    });

    test('dark surfaces rise in tone while retaining the accent', () {
      final dark = _build(brightness: Brightness.dark);
      expect(
        dark.colorScheme.primary,
        ColorScheme.fromSeed(
          seedColor: Colors.teal,
          brightness: Brightness.dark,
        ).primary,
      );
      expect(
        dark.extension<GlassStyle>()!.background,
        dark.colorScheme.surface,
      );
      expect(
        dark.extension<GlassStyle>()!.card,
        dark.colorScheme.surfaceContainer,
      );
      expect(dark.extension<GlassStyle>()!.isDark, isTrue);
      expect(dark.cardTheme.elevation, 0);
    });
  });

  group('seededColorScheme', () {
    test('the default accent is blue in both themes', () {
      for (final brightness in Brightness.values) {
        final scheme = seededColorScheme(
          const Color(defaultPrimaryColor),
          brightness,
          DynamicSchemeVariant.fidelity,
        );
        expect(
          HSLColor.fromColor(scheme.primary).hue,
          inInclusiveRange(200, 240),
        );
      }
    });

    test('color styles retain distinct accents on neutral surfaces', () {
      final vivid = seededColorScheme(
        Colors.teal,
        Brightness.light,
        DynamicSchemeVariant.fidelity,
      );
      final soft = seededColorScheme(
        Colors.teal,
        Brightness.light,
        DynamicSchemeVariant.tonalSpot,
      );
      expect(vivid.primary, isNot(soft.primary));
      expect(vivid.brightness, Brightness.light);
    });
  });
}
