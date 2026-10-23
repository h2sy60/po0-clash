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
    return SizedBox(
      height: height,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainer,
          borderRadius: AppRadius.medium,
        ),
        child: SegmentedButton<T>(
          segments: [
            for (final value in values)
              ButtonSegment(
                value: value,
                label: Text(
                  labelOf(value),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                icon: iconOf == null ? null : Icon(iconOf!(value), size: 18),
              ),
          ],
          selected: {selected},
          onSelectionChanged: (selection) {
            if (selection.single != selected) onChanged(selection.single);
          },
          showSelectedIcon: false,
          expandedInsets: EdgeInsets.zero,
          style: ButtonStyle(
            side: const WidgetStatePropertyAll(BorderSide.none),
            shape: const WidgetStatePropertyAll(AppShape.medium),
            backgroundColor: WidgetStateProperty.resolveWith(
              (states) => states.contains(WidgetState.selected)
                  ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.1)
                  : Colors.transparent,
            ),
            foregroundColor: WidgetStateProperty.resolveWith(
              (states) => states.contains(WidgetState.selected)
                  ? Theme.of(context).colorScheme.primary
                  : Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            visualDensity: VisualDensity.standard,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            minimumSize: WidgetStatePropertyAll(Size(0, height)),
          ),
        ),
      ),
    );
  }
}
