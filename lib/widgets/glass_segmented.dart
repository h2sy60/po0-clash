import 'package:fl_clash/common/shape.dart';
import 'package:material_ui/material_ui.dart';

class GlassSegmented<T> extends StatelessWidget {
  const GlassSegmented({
    super.key,
    required this.values,
    required this.selected,
    required this.labelOf,
    required this.onChanged,
    this.iconOf,
    this.height = 40,
  });

  final List<T> values;
  final T selected;
  final String Function(T value) labelOf;
  final IconData Function(T value)? iconOf;
  final ValueChanged<T> onChanged;
  final double height;

  @override
  Widget build(BuildContext context) {
    if (values.isEmpty) return const SizedBox.shrink();
    final scheme = Theme.of(context).colorScheme;
    final index = values.indexOf(selected);
    final duration = MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : Durations.medium1;
    return Container(
      height: height,
      padding: const EdgeInsets.all(4),
      decoration: ShapeDecoration(
        color: scheme.brightness == Brightness.dark
            ? scheme.surfaceContainerHigh
            : scheme.surfaceContainer,
        shape: AppShape.full,
      ),
      child: Stack(
        children: [
          if (index >= 0)
            AnimatedAlign(
              duration: duration,
              curve: Easing.standardDecelerate,
              alignment: AlignmentDirectional(
                values.length == 1 ? 0 : index * 2 / (values.length - 1) - 1,
                0,
              ),
              child: FractionallySizedBox(
                widthFactor: 1 / values.length,
                heightFactor: 1,
                child: DecoratedBox(
                  decoration: ShapeDecoration(
                    color: scheme.primary,
                    shape: AppShape.full,
                  ),
                ),
              ),
            ),
          Row(
            children: [
              for (final value in values)
                Expanded(
                  child: Semantics(
                    selected: value == selected,
                    child: TextButton(
                      onPressed: () {
                        if (value != selected) onChanged(value);
                      },
                      style: TextButton.styleFrom(
                        foregroundColor: value == selected
                            ? scheme.onPrimary
                            : scheme.onSurfaceVariant,
                        padding: const EdgeInsets.symmetric(horizontal: 6),
                        minimumSize: Size(0, height - 8),
                        shape: AppShape.full,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        textStyle: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          if (iconOf != null) ...[
                            Icon(iconOf!(value), size: 18),
                            const SizedBox(width: 6),
                          ],
                          Flexible(
                            child: Text(
                              labelOf(value),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
