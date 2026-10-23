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
    test('preserves the chosen accent on neutral surfaces', () {
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

    test('text fields use a filled Material surface with the small corner', () {
      final theme = _build();
      final border = theme.inputDecorationTheme.border;
      expect(theme.inputDecorationTheme.filled, isTrue);
      expect(border, isA<OutlineInputBorder>());
      expect((border! as OutlineInputBorder).borderRadius, AppRadius.small);
    });

    test('content and navigation use opaque neutral surfaces', () {
      final theme = _build();
      final glass = theme.extension<GlassStyle>()!;
      expect(theme.scaffoldBackgroundColor, theme.colorScheme.surface);
      expect(theme.colorScheme.surface, const Color(0xFFF5F5F7));
      expect(theme.colorScheme.onSurface, const Color(0xFF1D1D1F));
      expect(glass.glass.a, 1);
      expect(glass.glassStrong.a, 1);
      expect(theme.cardTheme.color, glass.card);
      expect(theme.cardTheme.shape, isA<RoundedRectangleBorder>());
    });

    test('standard controls retain Material touch targets', () {
      expect(_build().materialTapTargetSize, MaterialTapTargetSize.padded);
    });

    test('dark mode uses neutral surfaces without changing the accent', () {
      final dark = _build(brightness: Brightness.dark);
      expect(
        dark.colorScheme.primary,
        ColorScheme.fromSeed(
          seedColor: Colors.teal,
          brightness: Brightness.dark,
        ).primary,
      );
      expect(dark.colorScheme.surface, const Color(0xFF101012));
      expect(dark.colorScheme.onSurface, const Color(0xFFF5F5F7));
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
          scheme.primary,
          Color(brightness == Brightness.dark ? 0xFF2997FF : 0xFF0071E3),
        );
      }
    });

    test('any other seed is a plain seeded scheme', () {
      expect(
        seededColorScheme(
          Colors.teal,
          Brightness.light,
          DynamicSchemeVariant.tonalSpot,
        ),
        ColorScheme.fromSeed(
          seedColor: Colors.teal,
          dynamicSchemeVariant: DynamicSchemeVariant.tonalSpot,
        ),
      );
    });
  });
}
