import 'package:fl_clash/common/common.dart';
import 'package:material_ui/material_ui.dart';

class SkeletonPill extends StatelessWidget {
  const SkeletonPill({super.key, required this.width, required this.height});
  final double width;
  final double height;
  @override
  Widget build(BuildContext context) => SizedBox(
    width: width,
    height: height,
    child: DecoratedBox(
      decoration: ShapeDecoration(
        color: context.colorScheme.onSurface.withValues(alpha: 0.08),
        shape: AppShape.full,
      ),
    ),
  );
}

class SkeletonText extends StatelessWidget {
  const SkeletonText({super.key, required this.width, this.style});
  final double width;
  final TextStyle? style;
  @override
  Widget build(BuildContext context) => SkeletonPill(
    width: width,
    height: MediaQuery.textScalerOf(context).scale(style?.fontSize ?? 14),
  );
}
