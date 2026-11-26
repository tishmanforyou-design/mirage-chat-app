import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../models/chat_models.dart';
import 'cactus_mirage_ffi.dart';

typedef ModelProgressCallback = void Function(String status, double? progress);

/// High-level offline Mirage VLM service.
///
/// Offline strategy:
/// 1. Checks local app storage for cached `mirage.cact`.
/// 2. If missing, copies bundled `assets/models/mirage.cact` (100% offline, zero network).
/// 3. If not bundled in assets, downloads `mirage.cact` (21.6 MB) once from
///    Hugging Face (`Cactus-Compute/mirage`) and caches it locally for offline use.
class MirageService {
  static const String modelFileName = 'mirage.cact';
  static const String assetModelPath = 'assets/models/mirage.cact';
  static const String huggingFaceModelUrl =
      'https://huggingface.co/Cactus-Compute/mirage/resolve/main/mirage.cact';

  String? _cachedModelPath;
  bool _initialized = false;

  bool get isReady => _initialized;

  Future<void> initialize({ModelProgressCallback? onProgress}) async {
    if (_initialized) return;

    onProgress?.call('Checking local Mirage weights…', null);
    final modelFile = await _ensureModelCached(onProgress: onProgress);
    _cachedModelPath = modelFile.path;

    onProgress?.call('Loading Mirage 2-bit weights into memory…', null);
    final loadCode = await Isolate.run(() {
      final bindings = CactusMirageBindings.instance;
      // 4 threads avoids barrier contention on mobile CPUs (Cactus 4.1.0+)
      bindings.setThreads(4);
      return bindings.loadModelFromFile(modelFile.path);
    });

    if (loadCode != 0) {
      throw Exception(
        'Failed to initialize Mirage runtime (error code $loadCode). '
        'Verify mirage.cact is intact and matches Cactus 4.x.',
      );
    }

    _initialized = true;
    onProgress?.call('Mirage (21.6 MB) ready offline', 1.0);
  }

  Future<File> _ensureModelCached({ModelProgressCallback? onProgress}) async {
    final docsDir = await getApplicationDocumentsDirectory();
    final modelDir = Directory(p.join(docsDir.path, 'cactus_models'));
    if (!await modelDir.exists()) {
      await modelDir.create(recursive: true);
    }

    final targetFile = File(p.join(modelDir.path, modelFileName));
    if (await targetFile.exists() && await targetFile.length() > 10 * 1024 * 1024) {
      return targetFile;
    }

    // Step 1: Try extracting bundled asset (100% offline)
    try {
      onProgress?.call('Unpacking bundled Mirage weights (21.6 MB)…', 0.2);
      final byteData = await rootBundle.load(assetModelPath);
      final bytes = byteData.buffer.asUint8List(
        byteData.offsetInBytes,
        byteData.lengthInBytes,
      );
      if (bytes.length > 10 * 1024 * 1024) {
        await targetFile.writeAsBytes(bytes, flush: true);
        onProgress?.call('Mirage weights cached locally', 0.9);
        return targetFile;
      }
    } catch (_) {
      // Asset not bundled — fall back to one-time Hugging Face download
    }

    // Step 2: Automatic first-launch download + local caching
    onProgress?.call('Downloading Mirage (21.6 MB) for offline use…', 0.0);
    final client = http.Client();
    try {
      final request = http.Request('GET', Uri.parse(huggingFaceModelUrl));
      final response = await client.send(request);
      if (response.statusCode != 200) {
        throw Exception(
          'Could not download mirage.cact (HTTP ${response.statusCode}). '
          'Bundle assets/models/mirage.cact for fully air-gapped installs.',
        );
      }

      final totalBytes = response.contentLength ?? (22 * 1024 * 1024);
      final sink = targetFile.openWrite();
      int received = 0;

      await for (final chunk in response.stream) {
        sink.add(chunk);
        received += chunk.length;
        onProgress?.call(
          'Downloading Mirage (${(received / (1024 * 1024)).toStringAsFixed(1)} MB)…',
          (received / totalBytes).clamp(0.0, 0.99),
        );
      }
      await sink.flush();
      await sink.close();
      return targetFile;
    } finally {
      client.close();
    }
  }

  /// Runs Mirage on-device in a background Isolate so the UI stays at 60 fps.
  Future<MirageInferenceResult> analyzeImage({
    required String imagePath,
    required String prompt,
    MiragePreset? preset,
    String language = 'en',
  }) async {
    if (!_initialized || _cachedModelPath == null) {
      await initialize();
    }

    final sections = _resolveSections(prompt, preset);
    final fields = preset?.fields ?? const ['bbox', 'score'];
    final optionsJson = jsonEncode({
      'sections': sections,
      'fields': fields,
      'conf': 0.35,
      'text_conf': 0.35,
      'max_objects': 25,
      'max_text_lines': 40,
    });

    final stopwatch = Stopwatch()..start();
    final modelPath = _cachedModelPath!;

    final rawJson = await Isolate.run(() {
      final fileBytes = File(imagePath).readAsBytesSync();
      final decoded = img.decodeImage(fileBytes);
      if (decoded == null) {
        return '{"error":"Unable to decode selected image file"}';
      }

      // Bake EXIF orientation & cap longest edge to 1024px for fast mobile decode
      var oriented = img.bakeOrientation(decoded);
      if (oriented.width > 1024 || oriented.height > 1024) {
        oriented = img.copyResize(
          oriented,
          width: oriented.width >= oriented.height ? 1024 : null,
          height: oriented.height > oriented.width ? 1024 : null,
        );
      }

      final rgbBytes = _toPackedRgb24(oriented);
      final bindings = CactusMirageBindings.instance;
      if (!bindings.isLoaded) {
        bindings.setThreads(4);
        final rc = bindings.loadModelFromFile(modelPath);
        if (rc != 0) {
          return '{"error":"Failed to load Mirage in worker isolate (code $rc)"}';
        }
      }

      return bindings.describeRgb(
        rgbBytes: rgbBytes,
        width: oriented.width,
        height: oriented.height,
        optionsJson: optionsJson,
        language: language,
      );
    });

    stopwatch.stop();
    return MirageInferenceResult.fromRawJson(
      rawJson: rawJson,
      userPrompt: prompt,
      latencyMs: stopwatch.elapsedMilliseconds,
    );
  }

  List<String> _resolveSections(String prompt, MiragePreset? preset) {
    if (preset != null) return preset.sections;

    final lower = prompt.toLowerCase();
    final sections = <String>{};
    if (lower.contains('ocr') ||
        lower.contains('text') ||
        lower.contains('read') ||
        lower.contains('sign') ||
        lower.contains('word')) {
      sections.add('text');
    }
    if (lower.contains('object') ||
        lower.contains('detect') ||
        lower.contains('find') ||
        lower.contains('count') ||
        lower.contains('what is')) {
      sections.add('objects');
    }
    if (lower.contains('where') ||
        lower.contains('relation') ||
        lower.contains('next to') ||
        lower.contains('spatial')) {
      sections.addAll(['objects', 'relations']);
    }
    if (lower.contains('describe') ||
        lower.contains('scene') ||
        lower.contains('summary') ||
        sections.isEmpty) {
      sections.addAll(['scene', 'objects', 'text', 'relations']);
    }
    return sections.toList();
  }

  static Uint8List _toPackedRgb24(img.Image image) {
    final width = image.width;
    final height = image.height;
    final out = Uint8List(width * height * 3);
    int offset = 0;
    for (int y = 0; y < height; y++) {
      for (int x = 0; x < width; x++) {
        final pixel = image.getPixel(x, y);
        out[offset++] = pixel.r.toInt();
        out[offset++] = pixel.g.toInt();
        out[offset++] = pixel.b.toInt();
      }
    }
    return out;
  }
}
