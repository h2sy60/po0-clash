import 'dart:math' as math;

import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/widgets/widgets.dart';
import 'package:material_ui/material_ui.dart';

import 'tracker_info_item.dart';

class TrackerInfoTable extends StatefulWidget {
  const TrackerInfoTable({
    super.key,
    required this.trackerInfos,
    required this.detailTitle,
    this.onClose,
  });

  final List<TrackerInfo> trackerInfos;
  final String detailTitle;
  final ValueChanged<String>? onClose;

  @override
  State<TrackerInfoTable> createState() => _TrackerInfoTableState();
}

class _TrackerInfoTableState extends State<TrackerInfoTable> {
  final _horizontal = ScrollController();
  final _vertical = ScrollController();
  int _sortColumn = 6;
  bool _ascending = false;
  List<TrackerInfo>? _sortedRows;

  @override
  void didUpdateWidget(covariant TrackerInfoTable oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.trackerInfos, widget.trackerInfos)) {
      _sortedRows = null;
    }
  }

  @override
  void dispose() {
    _horizontal.dispose();
    _vertical.dispose();
    super.dispose();
  }

  int _compare(TrackerInfo a, TrackerInfo b, Map<String, String>? textKeys) {
    final result = textKeys != null
        ? textKeys[a.id]!.compareTo(textKeys[b.id]!)
        : switch (_sortColumn) {
            2 => a.rule.compareTo(b.rule),
            4 => a.upload.compareTo(b.upload),
            5 => a.download.compareTo(b.download),
            _ => a.start.compareTo(b.start),
          };
    return result == 0
        ? a.id.compareTo(b.id)
        : _ascending
        ? result
        : -result;
  }

  List<TrackerInfo> _sortRows() {
    final rows = List<TrackerInfo>.of(widget.trackerInfos);
    final textKey = switch (_sortColumn) {
      0 => (TrackerInfo info) => info.desc,
      1 => (TrackerInfo info) => info.progressText,
      3 => (TrackerInfo info) => info.chains.join(' → '),
      _ => null,
    };
    final textKeys = textKey == null
        ? null
        : {for (final info in rows) info.id: textKey(info)};
    rows.sort((a, b) => _compare(a, b, textKeys));
    return rows;
  }

  void _sort(int column) {
    setState(() {
      _ascending = _sortColumn == column ? !_ascending : column < 4;
      _sortColumn = column;
      _sortedRows = null;
    });
  }

  Widget _cell(String text, int flex, {bool numeric = false}) {
    return Expanded(
      flex: flex,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: TooltipText(
          text: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: numeric ? TextAlign.end : TextAlign.start,
            style: context.textTheme.bodySmall?.copyWith(
              fontFeatures: numeric
                  ? const [FontFeature.tabularFigures()]
                  : null,
            ),
          ),
        ),
      ),
    );
  }

  void _open(TrackerInfo info) {
    showExtend(
      context,
      builder: (_) => AdaptiveSheetScaffold(
        title: widget.detailTitle,
        body: TrackerInfoDetailView(trackerInfo: info),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final strings = context.appLocalizations;
    final labels = [
      strings.destination,
      strings.process,
      strings.rule,
      strings.currentProxy,
      strings.upload,
      strings.download,
      strings.time,
    ];
    const flexes = [26, 14, 16, 22, 10, 10, 18];
    final rows = _sortedRows ??= _sortRows();
    final height = math.max(
      48.0,
      MediaQuery.textScalerOf(context).scale(20) + 20,
    );
    return Padding(
      padding: EdgeInsets.fromLTRB(
        16,
        0,
        16,
        16 + BottomInsetScope.of(context),
      ),
      child: SurfaceCard(
        child: LayoutBuilder(
          builder: (_, constraints) => Scrollbar(
            controller: _horizontal,
            notificationPredicate: (notification) =>
                notification.metrics.axis == Axis.horizontal,
            child: SingleChildScrollView(
              controller: _horizontal,
              scrollDirection: Axis.horizontal,
              child: SizedBox(
                width: math.max(1160, constraints.maxWidth),
                height: constraints.maxHeight,
                child: Column(
                  children: [
                    Material(
                      color: context.glass.fill,
                      child: SizedBox(
                        height: height,
                        child: Row(
                          children: [
                            for (final (index, label) in labels.indexed)
                              Expanded(
                                flex: flexes[index],
                                child: TextButton(
                                  onPressed: () => _sort(index),
                                  child: Row(
                                    children: [
                                      Flexible(
                                        child: Text(
                                          label,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      if (_sortColumn == index) ...[
                                        const SizedBox(width: 4),
                                        GlyphIcon(
                                          _ascending
                                              ? AppGlyphs.chevronUp
                                              : AppGlyphs.chevronDown,
                                          size: 14,
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                              ),
                            if (widget.onClose != null)
                              const SizedBox(width: 48),
                          ],
                        ),
                      ),
                    ),
                    Expanded(
                      child: ListView.builder(
                        controller: _vertical,
                        itemExtent: height,
                        itemCount: rows.length,
                        itemBuilder: (_, index) {
                          final info = rows[index];
                          return InkWell(
                            key: ValueKey(info.id),
                            onTap: () => _open(info),
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                border: Border(
                                  bottom: BorderSide(
                                    color: context.colorScheme.outlineVariant
                                        .withValues(alpha: 0.4),
                                  ),
                                ),
                              ),
                              child: Row(
                                children: [
                                  _cell(info.desc, flexes[0]),
                                  _cell(info.progressText, flexes[1]),
                                  _cell(info.rule, flexes[2]),
                                  _cell(info.chains.join(' → '), flexes[3]),
                                  _cell(
                                    info.upload.traffic.show,
                                    flexes[4],
                                    numeric: true,
                                  ),
                                  _cell(
                                    info.download.traffic.show,
                                    flexes[5],
                                    numeric: true,
                                  ),
                                  _cell(info.start.showFull, flexes[6]),
                                  if (widget.onClose case final close?)
                                    SizedBox(
                                      width: 48,
                                      child: IconButton(
                                        tooltip: strings.blockConnection,
                                        onPressed: () => close(info.id),
                                        icon: const GlyphIcon(
                                          AppGlyphs.block,
                                          size: 18,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
