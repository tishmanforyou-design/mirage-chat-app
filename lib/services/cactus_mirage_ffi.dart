import 'dart:ffi';
import 'dart:io';
import 'dart:typed_data';
import 'package:ffi/ffi.dart';

typedef _SetThreadsNative = Void Function(Int32 threads);
typedef _SetThreadsDart = void Function(int threads);

typedef _LoadFileNative = Int32 Function(Pointer<Utf8> modelPath);
typedef _LoadFileDart = int Function(Pointer<Utf8> modelPath);

typedef _DescribeRgbNative = Pointer<Utf8> Function(
  Pointer<Uint8> rgbBytes,
  Int32 width,
  Int32 height,
  Pointer<Utf8> optionsJson,
  Pointer<Utf8> language,
  Pointer<Utf8> keywords,
);
typedef _DescribeRgbDart = Pointer<Utf8> Function(
  Pointer<Uint8> rgbBytes,
  int width,
  int height,
  Pointer<Utf8> optionsJson,
  Pointer<Utf8> language,
  Pointer<Utf8> keywords,
);

typedef _FreeStringNative = Void Function(Pointer<Utf8> ptr);
typedef _FreeStringDart = void Function(Pointer<Utf8> ptr);

typedef _IsLoadedNative = Int32 Function();
typedef _IsLoadedDart = int Function();

/// Low-level dart:ffi bindings to the Cactus 4.x Mirage native wrapper
/// (`libmirage_ffi.so` on Android, statically linked into Runner on iOS).
class CactusMirageBindings {
  CactusMirageBindings._(DynamicLibrary lib)
      : _setThreads = lib.lookupFunction<_SetThreadsNative, _SetThreadsDart>(
          'mirage_set_threads',
        ),
        _loadFile = lib.lookupFunction<_LoadFileNative, _LoadFileDart>(
          'mirage_load_file',
        ),
        _describeRgb = lib.lookupFunction<_DescribeRgbNative, _DescribeRgbDart>(
          'mirage_describe_rgb',
        ),
        _freeString = lib.lookupFunction<_FreeStringNative, _FreeStringDart>(
          'mirage_free_string',
        ),
        _isLoaded = lib.lookupFunction<_IsLoadedNative, _IsLoadedDart>(
          'mirage_is_loaded',
        );

  static CactusMirageBindings? _instance;

  static CactusMirageBindings get instance {
    if (_instance != null) return _instance!;
    final DynamicLibrary lib;
    if (Platform.isAndroid) {
      lib = DynamicLibrary.open('libmirage_ffi.so');
    } else if (Platform.isIOS || Platform.isMacOS) {
      lib = DynamicLibrary.process();
    } else {
      throw UnsupportedError(
        'Cactus Mirage FFI is supported on Android, iOS, and macOS.',
      );
    }
    _instance = CactusMirageBindings._(lib);
    return _instance!;
  }

  final _SetThreadsDart _setThreads;
  final _LoadFileDart _loadFile;
  final _DescribeRgbDart _describeRgb;
  final _FreeStringDart _freeString;
  final _IsLoadedDart _isLoaded;

  void setThreads(int threads) => _setThreads(threads);

  bool get isLoaded => _isLoaded() == 1;

  int loadModelFromFile(String path) {
    final pathPtr = path.toNativeUtf8();
    try {
      return _loadFile(pathPtr);
    } finally {
      calloc.free(pathPtr);
    }
  }

  String describeRgb({
    required Uint8List rgbBytes,
    required int width,
    required int height,
    String? optionsJson,
    String language = 'en',
    String? keywords,
  }) {
    final pixelPtr = calloc<Uint8>(rgbBytes.length);
    pixelPtr.asTypedList(rgbBytes.length).setAll(0, rgbBytes);

    final optionsPtr =
        optionsJson != null ? optionsJson.toNativeUtf8() : nullptr;
    final langPtr = language.toNativeUtf8();
    final keywordsPtr = keywords != null ? keywords.toNativeUtf8() : nullptr;

    Pointer<Utf8> resultPtr = nullptr;
    try {
      resultPtr = _describeRgb(
        pixelPtr,
        width,
        height,
        optionsPtr,
        langPtr,
        keywordsPtr,
      );
      if (resultPtr == nullptr) {
        return '{"error":"Native Mirage inference returned null"}';
      }
      return resultPtr.toDartString();
    } finally {
      if (resultPtr != nullptr) {
        _freeString(resultPtr);
      }
      calloc.free(pixelPtr);
      if (optionsPtr != nullptr) calloc.free(optionsPtr);
      calloc.free(langPtr);
      if (keywordsPtr != nullptr) calloc.free(keywordsPtr);
    }
  }
}
