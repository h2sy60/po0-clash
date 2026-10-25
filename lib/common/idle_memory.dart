import 'dart:async';

const activeGpuCacheBytes = 8 * 1024 * 1024;

class IdleMemoryTrimmer {
  IdleMemoryTrimmer({
    required this.setCacheLimit,
    required this.clearCaches,
    required this.releaseCore,
    required this.releaseAllocator,
    required this.onError,
    this.delay = const Duration(seconds: 3),
    this.activeCacheBytes = activeGpuCacheBytes,
  });

  final Future<void> Function(int bytes) setCacheLimit;
  final void Function() clearCaches;
  final Future<void> Function() releaseCore;
  final void Function() releaseAllocator;
  final void Function(Object error, StackTrace stack) onError;
  final Duration delay;
  final int activeCacheBytes;
  Timer? _timer;
  bool? _visible;
  bool _disposed = false;
  int _revision = 0;

  void setVisible(bool visible) {
    if (_disposed || _visible == visible) return;
    final wasHidden = _visible == false;
    _visible = visible;
    _revision++;
    _timer?.cancel();
    _timer = null;
    if (visible) {
      if (wasHidden) unawaited(_restore());
      return;
    }
    final revision = _revision;
    _timer = Timer(delay, () => unawaited(_trim(revision)));
  }

  bool _isCurrent(int revision) =>
      !_disposed && _visible == false && revision == _revision;

  Future<void> _restore() async {
    try {
      await setCacheLimit(activeCacheBytes);
    } catch (error, stack) {
      onError(error, stack);
    }
  }

  Future<void> _trim(int revision) async {
    _timer = null;
    if (!_isCurrent(revision)) return;
    try {
      await setCacheLimit(0);
      if (!_isCurrent(revision)) return;
      clearCaches();
      await releaseCore();
      if (_isCurrent(revision)) releaseAllocator();
    } catch (error, stack) {
      onError(error, stack);
    }
  }

  void dispose() {
    _disposed = true;
    _revision++;
    _timer?.cancel();
    _timer = null;
  }
}
