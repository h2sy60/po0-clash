import 'dart:ffi';
import 'dart:io';

typedef _TrimNative = Int32 Function(UintPtr);
typedef _Trim = int Function(int);
typedef _ZoneNative = Pointer<Void> Function();
typedef _Zone = Pointer<Void> Function();
typedef _ReliefNative = UintPtr Function(Pointer<Void>, UintPtr);
typedef _Relief = int Function(Pointer<Void>, int);
typedef _HeapMinNative = Int32 Function();
typedef _HeapMin = int Function();

final void Function() _trimAllocator = _loadAllocatorTrim();

void trimNativeAllocator() => _trimAllocator();

void Function() _loadAllocatorTrim() {
  try {
    if (Platform.isLinux) {
      final trim = DynamicLibrary.process().lookupFunction<_TrimNative, _Trim>(
        'malloc_trim',
      );
      return () {
        trim(0);
      };
    }
    if (Platform.isMacOS) {
      final library = DynamicLibrary.process();
      final zone = library.lookupFunction<_ZoneNative, _Zone>(
        'malloc_default_zone',
      );
      final relief = library.lookupFunction<_ReliefNative, _Relief>(
        'malloc_zone_pressure_relief',
      );
      return () {
        final currentZone = zone();
        if (currentZone != nullptr) relief(currentZone, 0);
      };
    }
    if (Platform.isWindows) {
      final trim = DynamicLibrary.open(
        'ucrtbase.dll',
      ).lookupFunction<_HeapMinNative, _HeapMin>('_heapmin');
      return () {
        trim();
      };
    }
  } on ArgumentError {
    return () {};
  }
  return () {};
}
