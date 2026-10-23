import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/physics.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:material_ui/material_ui.dart';

const _maxPressGrowth = 16.0;
const _pullStretch = 0.5;
const _pressGrowth = 1 / 8;
const _pullLimit = 7 / 32;
const _liftSnap = 0.975;
final _pressSpring = SpringDescription.withDampingRatio(
  mass: 1,
  stiffness: 311,
  ratio: 0.593,
);
final _trackSpring = SpringDescription.withDurationAndBounce(
  duration: const Duration(milliseconds: 120),
);
double _rubberBand(double overshoot, double limit) {
  final pull = 1 - 1 / (overshoot.abs() * 0.55 / limit + 1);
  return limit * pull * overshoot.sign;
}

class _Spring extends ChangeNotifier implements ValueListenable<double> {
  _Spring(TickerProvider vsync, this._value) {
    _ticker = vsync.createTicker(_tick);
  }

  late final Ticker _ticker;
  double _value;
  double _target = 0;
  SpringSimulation? _simulation;
  SpringDescription? _spring;
  double _now = 0;
  double _start = 0;

  @override
  double get value => _value;

  double get target => _simulation == null ? _value : _target;

  double get velocity => _simulation?.dx(_now - _start) ?? 0;

  double get acceleration {
    final spring = _spring;
    if (_simulation == null || spring == null) {
      return 0;
    }
    return (spring.stiffness * (_target - _value) - spring.damping * velocity) /
        spring.mass;
  }

  void springTo(double target, SpringDescription spring) {
    _simulation = SpringSimulation(spring, _value, target, velocity);
    _spring = spring;
    _target = target;
    if (_ticker.isActive) {
      _start = _now;
      return;
    }
    _now = _start = 0;
    _ticker.start();
  }

  void jumpTo(double value) {
    _simulation = null;
    _ticker.stop();
    _value = value;
    notifyListeners();
  }

  void _tick(Duration elapsed) {
    _now = elapsed.inMicroseconds / Duration.microsecondsPerSecond;
    final simulation = _simulation!;
    final time = _now - _start;
    if (simulation.isDone(time)) {
      _value = _target;
      _simulation = null;
      _ticker.stop();
    } else {
      _value = simulation.x(time);
    }
    notifyListeners();
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }
}

class ElasticPress extends StatefulWidget {
  const ElasticPress({
    super.key,
    this.enabled = true,
    this.pullPastEdges = false,
    this.maxGrowth = _maxPressGrowth,
    this.maxPull,
    this.panelOf,
    required this.child,
  });

  /// Leaves a press on the button inside to the swell alone.
  static const buttonStyle = ButtonStyle(
    splashFactory: NoSplash.splashFactory,
    overlayColor: WidgetStateMapper<Color?>({
      WidgetState.pressed: Colors.transparent,
    }),
  );

  final bool enabled;
  final bool pullPastEdges;
  final double maxGrowth;
  final double? maxPull;

  /// Where the pressed panel lies in this box, when the box is larger.
  final Rect Function(RenderBox box)? panelOf;

  final Widget child;

  static ElasticPressHandle? maybeOf(BuildContext context) =>
      context.findAncestorStateOfType<_ElasticPressState>();

  /// Where [box] paints under the presses around it, in its own coordinates.
  static Rect paintBoundsOf(RenderBox box) {
    final bounds = Offset.zero & box.size;
    var painted = Matrix4.identity();
    RenderObject from = box;
    for (var node = box.parent; node != null; node = node.parent) {
      if (node is _RenderPressTransform && node.hasSize) {
        painted = node._transform.multiplied(
          from.getTransformTo(node).multiplied(painted),
        );
        from = node;
      }
    }
    final rest = Matrix4.tryInvert(box.getTransformTo(from));
    if (identical(from, box) || rest == null) {
      return bounds;
    }
    return MatrixUtils.transformRect(rest.multiplied(painted), bounds);
  }

  @override
  State<ElasticPress> createState() => _ElasticPressState();
}

/// Drives an [ElasticPress] with a press it does not hear, at global positions.
abstract interface class ElasticPressHandle {
  void press(Offset position);

  void drag(Offset position);

  void release();
}

class _ElasticPressState extends State<ElasticPress>
    with TickerProviderStateMixin
    implements ElasticPressHandle {
  late final _Spring _lift = _Spring(this, 0);
  late final _Spring _pullX = _Spring(this, 0);
  late final _Spring _pullY = _Spring(this, 0);
  late final Listenable _motion = Listenable.merge([_lift, _pullX, _pullY]);
  int? _pointer;
  Offset _origin = Offset.zero;
  bool _releasing = false;

  @override
  void initState() {
    super.initState();
    _lift.addListener(_settle);
  }

  @override
  void dispose() {
    _lift.dispose();
    _pullX.dispose();
    _pullY.dispose();
    super.dispose();
  }

  void _swell(Offset origin) {
    _origin = origin;
    _releasing = false;
    _lift.springTo(1, _pressSpring);
  }

  void _handlePointerDown(PointerDownEvent event) {
    if (!widget.enabled ||
        _pointer != null ||
        event.buttons & kPrimaryButton == 0) {
      return;
    }
    _pointer = event.pointer;
    _swell(event.localPosition);
  }

  // A pointer's events keep reaching the hit-test path recorded at its down,
  // so a press removed mid-gesture still hears its moves and release.
  void _handlePointerMove(PointerMoveEvent event) {
    if (!mounted || event.pointer != _pointer) {
      return;
    }
    _pullToward(event.localPosition);
  }

  void _pullToward(Offset position) {
    final box = context.findRenderObject()! as RenderBox;
    final panel = widget.panelOf?.call(box) ?? Offset.zero & box.size;
    final limit = widget.maxPull ?? panel.shortestSide * _pullLimit;
    final pull = widget.pullPastEdges
        ? position -
              Offset(
                position.dx.clamp(panel.left, panel.right),
                position.dy.clamp(panel.top, panel.bottom),
              )
        : position - _origin;
    _pullX.springTo(_rubberBand(pull.dx, limit), _trackSpring);
    _pullY.springTo(_rubberBand(pull.dy, limit), _trackSpring);
  }

  void _handlePointerEnd(PointerEvent event) {
    if (!mounted || event.pointer != _pointer) {
      return;
    }
    _release();
  }

  void _release() {
    _pointer = null;
    _pullX.springTo(0, _pressSpring);
    _pullY.springTo(0, _pressSpring);
    _releasing = true;
    _settle();
  }

  // A tap lets go before the swell has risen; it rises all the way first, as
  // UIKit lifts the tab bar's lens all the way on a tap.
  void _settle() {
    if (!_releasing || _lift.value < _liftSnap) {
      return;
    }
    _releasing = false;
    _lift.springTo(0, _pressSpring);
  }

  Offset _localOf(Offset position) =>
      (context.findRenderObject()! as RenderBox).globalToLocal(position);

  @override
  void press(Offset position) {
    if (!widget.enabled) {
      return;
    }
    _swell(_localOf(position));
  }

  @override
  void drag(Offset position) => _pullToward(_localOf(position));

  @override
  void release() => _release();

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerDown: _handlePointerDown,
      onPointerMove: _handlePointerMove,
      onPointerUp: _handlePointerEnd,
      onPointerCancel: _handlePointerEnd,
      child: AnimatedBuilder(
        animation: _motion,
        builder: (_, child) => _PressTransform(
          lift: _lift.value,
          pull: Offset(_pullX.value, _pullY.value),
          maxGrowth: widget.maxGrowth,
          panelOf: widget.panelOf,
          child: child,
        ),
        child: widget.child,
      ),
    );
  }
}

/// Leaves a press on the filled button inside to [ElasticPress]; one whose
/// style sets a foreground color merges [ElasticPress.buttonStyle].
class ElasticButton extends StatelessWidget {
  const ElasticButton({super.key, this.enabled = true, required this.child});

  final bool enabled;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ElasticPress(
      enabled: enabled,
      child: Theme(
        data: theme.copyWith(
          splashFactory: NoSplash.splashFactory,
          highlightColor: Colors.transparent,
        ),
        child: IconTheme(
          data: IconTheme.of(context),
          child: IconButtonTheme(
            data: IconButtonThemeData(
              style: ElasticPress.buttonStyle.merge(
                IconButtonTheme.of(context).style,
              ),
            ),
            child: FilledButtonTheme(
              data: FilledButtonThemeData(
                style: ElasticPress.buttonStyle.merge(
                  FilledButtonTheme.of(context).style,
                ),
              ),
              child: child,
            ),
          ),
        ),
      ),
    );
  }
}

class _PressTransform extends SingleChildRenderObjectWidget {
  const _PressTransform({
    required this.lift,
    required this.pull,
    this.maxGrowth = _maxPressGrowth,
    this.panelOf,
    super.child,
  });

  final double lift;
  final Offset pull;
  final double maxGrowth;
  final Rect Function(RenderBox box)? panelOf;

  @override
  RenderObject createRenderObject(BuildContext context) {
    return _RenderPressTransform(lift: lift, pull: pull)
      ..maxGrowth = maxGrowth
      ..panelOf = panelOf;
  }

  @override
  void updateRenderObject(
    BuildContext context,
    _RenderPressTransform renderObject,
  ) {
    renderObject
      ..lift = lift
      ..pull = pull
      ..maxGrowth = maxGrowth
      ..panelOf = panelOf;
  }
}

class _RenderPressTransform extends RenderProxyBox {
  _RenderPressTransform({required double lift, required Offset pull})
    : _lift = lift,
      _pull = pull;

  double _lift;
  Offset _pull;
  double maxGrowth = _maxPressGrowth;
  Rect Function(RenderBox box)? panelOf;

  set lift(double value) {
    if (value == _lift) {
      return;
    }
    _lift = value;
    markNeedsPaint();
  }

  set pull(Offset value) {
    if (value == _pull) {
      return;
    }
    _pull = value;
    markNeedsPaint();
  }

  Matrix4 get _transform {
    final panel = panelOf?.call(this) ?? Offset.zero & size;
    final swell =
        1 + _lift * math.min(_pressGrowth * 2, maxGrowth / panel.longestSide);
    final scaleX = swell * (1 + _pull.dx.abs() / panel.width * _pullStretch);
    final scaleY = swell * (1 + _pull.dy.abs() / panel.height * _pullStretch);
    final center = panel.center;
    return Matrix4.diagonal3Values(scaleX, scaleY, 1)..setTranslationRaw(
      center.dx * (1 - scaleX) + _pull.dx,
      center.dy * (1 - scaleY) + _pull.dy,
      0,
    );
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    if (child == null || size.isEmpty || (_lift == 0 && _pull == .zero)) {
      layer = null;
      super.paint(context, offset);
      return;
    }
    layer = context.pushTransform(
      needsCompositing,
      offset,
      _transform,
      super.paint,
      oldLayer: layer is TransformLayer ? layer as TransformLayer? : null,
    );
  }
}

/// A floating pill of destinations whose selection is a lens that springs
/// between them, after iOS's tab bar. Pressing swells the bar as
/// [ElasticPress] does and lifts the lens under the finger; dragging slides
/// the lens across the bar, selecting where it is let go, and stretches the
/// bar past either end.
