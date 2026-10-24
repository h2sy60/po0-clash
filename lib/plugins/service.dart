import 'dart:async';
import 'dart:convert';

import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/core/event.dart';
import 'package:fl_clash/core/method.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/models/models.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

abstract mixin class ServiceListener {
  void onServiceEvent(CoreEvent event) {}
}

class Service {
  static Service? _instance;
  late MethodChannel methodChannel;

  final ObserverList<ServiceListener> _listeners =
      ObserverList<ServiceListener>();
  List<ServiceListener>? _listenerSnapshot;

  factory Service() {
    _instance ??= Service._internal();
    return _instance!;
  }

  Service._internal() {
    methodChannel = const MethodChannel('$packageName/service');
    methodChannel.setMethodCallHandler((call) async {
      switch (call.method) {
        case 'event':
          final data = call.arguments as String? ?? '';
          final methodCall = CoreMethodCall.fromJson(
            json.decode(data) as Map<String, Object?>,
          );
          for (final event in coreEventsFromData(methodCall.arguments)) {
            final listeners = _listenerSnapshot ??= List.of(
              _listeners,
              growable: false,
            );
            for (final listener in listeners) {
              try {
                listener.onServiceEvent(event);
              } catch (error) {
                commonPrint.log(
                  'Unable to dispatch Android Core event '
                  '${event.type.name}: $error',
                  logLevel: LogLevel.error,
                );
              }
            }
          }
          break;
        default:
          throw MissingPluginException();
      }
    });
  }

  Future<CoreMethodResponse?> invokeMethod(CoreMethodCall call) async {
    final data = await methodChannel.invokeMethod<String>(
      'invokeMethod',
      json.encode(call),
    );
    if (data == null) {
      return null;
    }
    final dataJson = await data.decodeJson<dynamic>();
    return CoreMethodResponse.fromJson(dataJson);
  }

  Future<bool> start() async {
    return await methodChannel.invokeMethod<bool>('start') ?? false;
  }

  Future<bool> stop() async {
    return await methodChannel.invokeMethod<bool>('stop') ?? false;
  }

  Future<String> init() async {
    return await methodChannel.invokeMethod<String>('init') ?? '';
  }

  Future<String> syncState(SharedState state) async {
    return await methodChannel.invokeMethod<String>(
          'syncState',
          json.encode(state),
        ) ??
        '';
  }

  Future<bool> shutdown() async {
    return await methodChannel.invokeMethod<bool>('shutdown') ?? true;
  }

  Future<DateTime?> getRunTime() async {
    final ms = await methodChannel.invokeMethod<int>('getRunTime') ?? 0;
    if (ms == 0) {
      return null;
    }
    return DateTime.fromMillisecondsSinceEpoch(ms);
  }

  bool get hasListeners {
    return _listeners.isNotEmpty;
  }

  void addListener(ServiceListener listener) {
    _listeners.add(listener);
    _listenerSnapshot = null;
  }

  void removeListener(ServiceListener listener) {
    _listeners.remove(listener);
    _listenerSnapshot = null;
  }
}

Service? get service => system.isAndroid ? Service() : null;
