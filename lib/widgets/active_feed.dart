import 'dart:async';

import 'package:fl_clash/common/print.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:flutter/widgets.dart';

import 'inherited.dart';

mixin ActiveFeedMixin<T extends StatefulWidget>
    on State<T>, WidgetsBindingObserver {
  Timer? _feedTimer;
  bool _isForeground = false;
  bool _isPageActive = true;
  bool _dirty = false;
  bool _refreshing = false;

  Duration get feedRefreshInterval;

  bool get feedVisible => true;

  bool get _canRefresh =>
      mounted && _isForeground && _isPageActive && feedVisible;

  void refreshFeed();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    final lifecycle = WidgetsBinding.instance.lifecycleState;
    _isForeground = lifecycle == null || lifecycle == AppLifecycleState.resumed;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _isPageActive =
        PageActivityScope.isActiveOf(context) &&
        TickerMode.valuesOf(context).enabled;
    syncFeedVisibility();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    _isForeground = state == AppLifecycleState.resumed;
    syncFeedVisibility();
  }

  void requestFeedRefresh() {
    _dirty = true;
    if (_canRefresh && !_refreshing) {
      _feedTimer ??= Timer(feedRefreshInterval, _flushFeed);
    }
  }

  void syncFeedVisibility() {
    _feedTimer?.cancel();
    _feedTimer = null;
    if (_canRefresh && _dirty && !_refreshing) {
      _feedTimer = Timer(Duration.zero, _flushFeed);
    }
  }

  void _flushFeed() {
    _feedTimer = null;
    if (!_canRefresh || !_dirty) return;
    _dirty = false;
    _refreshing = true;
    var refreshed = false;
    try {
      refreshFeed();
      refreshed = true;
    } catch (error) {
      commonPrint.log(
        '$runtimeType feed refresh error: $error',
        logLevel: LogLevel.warning,
      );
    } finally {
      _refreshing = false;
      if (refreshed && _dirty && _canRefresh) {
        _feedTimer ??= Timer(feedRefreshInterval, _flushFeed);
      }
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _isForeground = false;
    _feedTimer?.cancel();
    _feedTimer = null;
    super.dispose();
  }
}
