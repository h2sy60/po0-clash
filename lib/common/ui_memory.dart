import 'package:fl_clash/common/idle_memory.dart';
import 'package:flutter/services.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_svg/flutter_svg.dart';

Future<void> configureUiMemory() async {
  PaintingBinding.instance.imageCache
    ..maximumSize = 128
    ..maximumSizeBytes = 8 * 1024 * 1024;
  svg.cache.maximumSize = 32;
  await setGpuCacheLimit(activeGpuCacheBytes);
}

Future<void> setGpuCacheLimit(int bytes) async {
  try {
    await SystemChannels.skia.invokeMethod<void>(
      'Skia.setResourceCacheMaxBytes',
      bytes,
    );
  } on MissingPluginException {
    return;
  }
}

void clearUiMemoryCaches() {
  PaintingBinding.instance.imageCache
    ..clear()
    ..clearLiveImages();
  svg.cache.clear();
  rootBundle.clear();
}
