import 'package:material_ui/material_ui.dart';

@immutable
class GlassStyle extends ThemeExtension<GlassStyle> {
  const GlassStyle({
    required this.brightness,
    required this.background,
    required this.card,
    required this.fill,
    required this.thumb,
    required this.glass,
    required this.glassStrong,
    required this.separator,
    required this.selected,
    required this.secondaryLabel,
  });

  final Brightness brightness;
  final Color background;
  final Color card;
  final Color fill;
  final Color thumb;
  final Color glass;
  final Color glassStrong;
  final Color separator;
  final Color selected;
  final Color secondaryLabel;

  bool get isDark => brightness == Brightness.dark;

  factory GlassStyle.of(ColorScheme scheme, {bool pureBlack = false}) {
    final black = pureBlack && scheme.brightness == Brightness.dark;
    return GlassStyle(
      brightness: scheme.brightness,
      background: black
          ? Colors.black
          : scheme.brightness == Brightness.dark
          ? scheme.surface
          : scheme.surfaceContainer,
      card: scheme.brightness == Brightness.dark
          ? scheme.surfaceContainer
          : scheme.surfaceBright,
      fill: scheme.surfaceContainerHighest,
      thumb: scheme.brightness == Brightness.dark
          ? scheme.surfaceContainerHighest
          : scheme.surfaceBright,
      glass: scheme.brightness == Brightness.dark
          ? scheme.surfaceContainerHigh
          : scheme.surfaceBright,
      glassStrong: scheme.brightness == Brightness.dark
          ? scheme.surfaceContainerHigh
          : scheme.surfaceBright,
      separator: scheme.outlineVariant,
      selected: scheme.secondaryContainer,
      secondaryLabel: scheme.onSurfaceVariant,
    );
  }

  @override
  GlassStyle copyWith({Color? background, Color? card}) {
    return GlassStyle(
      brightness: brightness,
      background: background ?? this.background,
      card: card ?? this.card,
      fill: fill,
      thumb: thumb,
      glass: glass,
      glassStrong: glassStrong,
      separator: separator,
      selected: selected,
      secondaryLabel: secondaryLabel,
    );
  }

  @override
  GlassStyle lerp(covariant GlassStyle? other, double t) {
    if (other == null) return this;
    Color mix(Color a, Color b) => Color.lerp(a, b, t)!;
    return GlassStyle(
      brightness: t < 0.5 ? brightness : other.brightness,
      background: mix(background, other.background),
      card: mix(card, other.card),
      fill: mix(fill, other.fill),
      thumb: mix(thumb, other.thumb),
      glass: mix(glass, other.glass),
      glassStrong: mix(glassStrong, other.glassStrong),
      separator: mix(separator, other.separator),
      selected: mix(selected, other.selected),
      secondaryLabel: mix(secondaryLabel, other.secondaryLabel),
    );
  }
}

extension GlassContextExt on BuildContext {
  GlassStyle get glass =>
      Theme.of(this).extension<GlassStyle>() ??
      GlassStyle.of(Theme.of(this).colorScheme);
}

enum GlassTone {
  accent,
  success,
  warning,
  danger,
  neutral,
  indigo,
  teal,
  pink;

  (Color, Color) get lightAndDark => switch (this) {
    GlassTone.accent => (const Color(0xFF007AFF), const Color(0xFF0A84FF)),
    GlassTone.success => (const Color(0xFF34C759), const Color(0xFF30D158)),
    GlassTone.warning => (const Color(0xFFFF9500), const Color(0xFFFF9F0A)),
    GlassTone.danger => (const Color(0xFFFF3B30), const Color(0xFFFF453A)),
    GlassTone.neutral => (const Color(0xFF8E8E93), const Color(0xFF8E8E93)),
    GlassTone.indigo => (const Color(0xFF5856D6), const Color(0xFF5E5CE6)),
    GlassTone.teal => (const Color(0xFF30B0C7), const Color(0xFF40C8E0)),
    GlassTone.pink => (const Color(0xFFFF2D55), const Color(0xFFFF375F)),
  };

  Color on(Brightness brightness) {
    final (light, dark) = lightAndDark;
    return brightness == Brightness.dark ? dark : light;
  }
}

extension GlassToneExt on BuildContext {
  Color toneColor(GlassTone tone) {
    final colorScheme = Theme.of(this).colorScheme;
    if (tone == GlassTone.accent) {
      return colorScheme.primary;
    }
    return tone.on(colorScheme.brightness);
  }
}
