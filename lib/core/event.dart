import 'dart:async';

import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/models/models.dart';
import 'package:flutter/foundation.dart';

List<CoreEvent> coreEventsFromData(Object? data) {
  final items = data is List ? data : [data];
  final events = <CoreEvent>[];
  for (final item in items) {
    if (item is! Map) {
      continue;
    }
    try {
      events.add(
        CoreEvent.fromJson(
          item is Map<String, Object?> ? item : Map<String, Object?>.from(item),
        ),
      );
    } catch (error) {
      commonPrint.log(
        'Unable to parse Core event: $error',
        logLevel: LogLevel.error,
      );
    }
  }
  return events;
}

abstract mixin class CoreEventListener {
  void onLog(Log log) {}

  void onDelay(Delay delay) {}

  void onRequest(TrackerInfo connection) {}

  void onLoaded(String providerName) {}

  void onCrash(String message) {}

  void onGeoUpdate(
    String geoType,
    bool updating,
    bool skipped,
    String? error,
  ) {}
}

class CoreEventManager {
  final _controller = StreamController<CoreEvent>();

  CoreEventManager._() {
    _controller.stream.listen((event) {
      final listeners = _listenerSnapshot ??= List.of(
        _listeners,
        growable: false,
      );
      Log? log;
      Delay? delay;
      TrackerInfo? request;
      for (final listener in listeners) {
        try {
          switch (event.type) {
            case CoreEventType.log:
              listener.onLog(log ??= Log.fromJson(event.data));
              break;
            case CoreEventType.delay:
              listener.onDelay(delay ??= Delay.fromJson(event.data));
              break;
            case CoreEventType.request:
              listener.onRequest(request ??= TrackerInfo.fromJson(event.data));
              break;
            case CoreEventType.loaded:
              listener.onLoaded(event.data);
              break;
            case CoreEventType.crash:
              listener.onCrash(event.data);
              break;
            case CoreEventType.geoUpdate:
              final data = event.data as Map<String, dynamic>;
              listener.onGeoUpdate(
                data['type'] as String,
                data['updating'] as bool,
                data['skipped'] as bool? ?? false,
                data['error'] as String?,
              );
              break;
          }
        } catch (error) {
          commonPrint.log(
            'Unable to dispatch Core event ${event.type.name}: $error',
            logLevel: LogLevel.error,
          );
        }
      }
    });
  }

  static final CoreEventManager instance = CoreEventManager._();

  final ObserverList<CoreEventListener> _listeners =
      ObserverList<CoreEventListener>();
  List<CoreEventListener>? _listenerSnapshot;

  bool get hasListeners {
    return _listeners.isNotEmpty;
  }

  void sendEvent(CoreEvent event) {
    _controller.add(event);
  }

  void addListener(CoreEventListener listener) {
    _listeners.add(listener);
    _listenerSnapshot = null;
  }

  void removeListener(CoreEventListener listener) {
    _listeners.remove(listener);
    _listenerSnapshot = null;
  }
}

final coreEventManager = CoreEventManager.instance;
