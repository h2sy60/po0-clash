import 'package:fl_clash/common/common.dart';
import 'package:material_ui/material_ui.dart';

class SurfaceCard extends StatelessWidget {
  const SurfaceCard({
    super.key,
    this.padding = EdgeInsets.zero,
    required this.child,
  });

  final EdgeInsetsGeometry padding;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final glass = context.glass;
    return Material(
      color: glass.card,
      shape: AppShape.large,
      clipBehavior: Clip.antiAlias,
      child: Padding(padding: padding, child: child),
    );
  }
}
