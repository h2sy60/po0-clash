import 'package:material_ui/material_ui.dart';

abstract final class AppCorner {
  static const double none = 0;
  static const double extraSmall = 4;
  static const double small = 8;
  static const double medium = 12;
  static const double large = 16;
  static const double largeIncreased = 20;
  static const double extraLarge = 28;
  static const double full = 1000;
}

abstract final class AppRadius {
  static const BorderRadius none = BorderRadius.zero;
  static const BorderRadius extraSmall = BorderRadius.all(
    Radius.circular(AppCorner.extraSmall),
  );
  static const BorderRadius small = BorderRadius.all(
    Radius.circular(AppCorner.small),
  );
  static const BorderRadius medium = BorderRadius.all(
    Radius.circular(AppCorner.medium),
  );
  static const BorderRadius large = BorderRadius.all(
    Radius.circular(AppCorner.large),
  );
  static const BorderRadius extraLarge = BorderRadius.all(
    Radius.circular(AppCorner.extraLarge),
  );
  static const BorderRadius full = BorderRadius.all(
    Radius.circular(AppCorner.full),
  );

  static BorderRadius all(double corner) => BorderRadius.circular(corner);

  static BorderRadius top(double corner) =>
      BorderRadius.vertical(top: Radius.circular(corner));

  static BorderRadius vertical({
    double top = AppCorner.none,
    double bottom = AppCorner.none,
  }) => BorderRadius.vertical(
    top: Radius.circular(top),
    bottom: Radius.circular(bottom),
  );
}

abstract final class AppShape {
  static const RoundedRectangleBorder none = RoundedRectangleBorder();
  static const RoundedRectangleBorder extraSmall = RoundedRectangleBorder(
    borderRadius: AppRadius.extraSmall,
  );
  static const RoundedRectangleBorder small = RoundedRectangleBorder(
    borderRadius: AppRadius.small,
  );
  static const RoundedRectangleBorder medium = RoundedRectangleBorder(
    borderRadius: AppRadius.medium,
  );
  static const RoundedRectangleBorder large = RoundedRectangleBorder(
    borderRadius: AppRadius.large,
  );
  static const RoundedRectangleBorder extraLarge = RoundedRectangleBorder(
    borderRadius: AppRadius.extraLarge,
  );
  static const StadiumBorder full = StadiumBorder();
  static const CircleBorder circle = CircleBorder();
  static const OutlineInputBorder input = OutlineInputBorder(
    borderRadius: AppRadius.small,
    borderSide: BorderSide.none,
  );

  static RoundedRectangleBorder all(double corner) =>
      RoundedRectangleBorder(borderRadius: AppRadius.all(corner));

  static RoundedRectangleBorder top(double corner) =>
      RoundedRectangleBorder(borderRadius: AppRadius.top(corner));

  static RoundedRectangleBorder vertical({
    double top = AppCorner.none,
    double bottom = AppCorner.none,
  }) => RoundedRectangleBorder(
    borderRadius: AppRadius.vertical(top: top, bottom: bottom),
  );

  static RoundedRectangleBorder of(BorderRadius borderRadius) =>
      RoundedRectangleBorder(borderRadius: borderRadius);
}
