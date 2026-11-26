import 'dart:convert';

enum MessageSender { user, assistant, system }

enum MiragePreset {
  describeScene(
    label: 'Describe Scene',
    prompt: 'Describe this scene in detail.',
    sections: ['scene', 'objects', 'relations'],
    fields: ['bbox', 'score'],
  ),
  extractText(
    label: 'Extract Text (OCR)',
    prompt: 'Extract all visible text from this image.',
    sections: ['text'],
    fields: ['bbox', 'score'],
  ),
  detectObjects(
    label: 'Detect Objects',
    prompt: 'Detect and list all objects in this image.',
    sections: ['objects'],
    fields: ['bbox', 'score'],
  ),
  spatialRelations(
    label: 'Spatial Relations',
    prompt: 'Analyze spatial relationships between objects.',
    sections: ['objects', 'relations'],
    fields: ['bbox', 'score'],
  ),
  fullAnalysis(
    label: 'Full Analysis',
    prompt: 'Run full vision analysis (scene, objects, OCR, relations).',
    sections: ['scene', 'objects', 'text', 'relations'],
    fields: ['bbox', 'score'],
  );

  const MiragePreset({
    required this.label,
    required this.prompt,
    required this.sections,
    required this.fields,
  });

  final String label;
  final String prompt;
  final List<String> sections;
  final List<String> fields;
}

class DetectedBox {
  const DetectedBox({
    required this.label,
    required this.bbox,
    this.score,
    this.isText = false,
  });

  final String label;
  /// Normalized 0..1000 coordinates: [x1, y1, x2, y2]
  final List<double> bbox;
  final double? score;
  final bool isText;
}

class MirageInferenceResult {
  const MirageInferenceResult({
    required this.rawJson,
    required this.formattedResponse,
    required this.latencyMs,
    required this.boxes,
    this.error,
  });

  final String rawJson;
  final String formattedResponse;
  final int latencyMs;
  final List<DetectedBox> boxes;
  final String? error;

  bool get hasError => error != null && error!.isNotEmpty;

  factory MirageInferenceResult.fromRawJson({
    required String rawJson,
    required String userPrompt,
    required int latencyMs,
  }) {
    try {
      final dynamic decoded = jsonDecode(rawJson);
      if (decoded is! Map<String, dynamic>) {
        return MirageInferenceResult(
          rawJson: rawJson,
          formattedResponse: rawJson,
          latencyMs: latencyMs,
          boxes: const [],
        );
      }

      if (decoded['error'] != null) {
        return MirageInferenceResult(
          rawJson: rawJson,
          formattedResponse: 'Error: ${decoded['error']}',
          latencyMs: latencyMs,
          boxes: const [],
          error: decoded['error'].toString(),
        );
      }

      final boxes = <DetectedBox>[];
      final buffer = StringBuffer();

      // 1. Scene description
      final scene = decoded['scene'] ?? decoded['description'];
      if (scene is String && scene.trim().isNotEmpty) {
        buffer.writeln('**Scene**');
        buffer.writeln(scene.trim());
        buffer.writeln();
      } else if (scene is Map<String, dynamic>) {
        final summary = scene['description'] ?? scene['summary'] ?? scene['setting'];
        if (summary != null && summary.toString().trim().isNotEmpty) {
          buffer.writeln('**Scene**');
          buffer.writeln(summary.toString().trim());
          buffer.writeln();
        }
      }

      // 2. Detected Objects
      final objects = decoded['objects'];
      if (objects is List && objects.isNotEmpty) {
        buffer.writeln('**Detected Objects (${objects.length})**');
        for (final obj in objects) {
          if (obj is Map<String, dynamic>) {
            final name = (obj['name'] ?? obj['label'] ?? obj['id'] ?? 'object').toString();
            final score = (obj['score'] is num) ? (obj['score'] as num).toDouble() : null;
            final attrs = obj['attributes'];
            final attrText = (attrs is List && attrs.isNotEmpty)
                ? ' — ${attrs.join(', ')}'
                : '';
            final scoreText = score != null ? ' (${(score * 100).round()}%)' : '';
            buffer.writeln('• $name$scoreText$attrText');

            final rawBbox = obj['bbox'];
            if (rawBbox is List && rawBbox.length == 4) {
              boxes.add(
                DetectedBox(
                  label: name,
                  bbox: rawBbox.map((e) => (e as num).toDouble()).toList(),
                  score: score,
                ),
              );
            }
          }
        }
        buffer.writeln();
      }

      // 3. Extracted Text (OCR)
      final textItems = decoded['text'];
      if (textItems is List && textItems.isNotEmpty) {
        buffer.writeln('**Extracted Text (OCR)**');
        for (final item in textItems) {
          if (item is Map<String, dynamic>) {
            final content = (item['text'] ?? item['content'] ?? '').toString().trim();
            if (content.isEmpty) continue;
            final score = (item['score'] is num) ? (item['score'] as num).toDouble() : null;
            final scoreText = score != null ? ' (${(score * 100).round()}%)' : '';
            buffer.writeln('• "$content"$scoreText');

            final rawBbox = item['bbox'];
            if (rawBbox is List && rawBbox.length == 4) {
              boxes.add(
                DetectedBox(
                  label: content,
                  bbox: rawBbox.map((e) => (e as num).toDouble()).toList(),
                  score: score,
                  isText: true,
                ),
              );
            }
          } else if (item is String && item.trim().isNotEmpty) {
            buffer.writeln('• "${item.trim()}"');
          }
        }
        buffer.writeln();
      }

      // 4. Spatial Relations
      final relations = decoded['relations'];
      if (relations is List && relations.isNotEmpty) {
        buffer.writeln('**Spatial Relations**');
        for (final rel in relations) {
          if (rel is Map<String, dynamic>) {
            final subj = rel['subject'] ?? rel['from'] ?? '';
            final pred = rel['predicate'] ?? rel['relation'] ?? '';
            final obj = rel['object'] ?? rel['to'] ?? '';
            final line = '$subj $pred $obj'.trim();
            if (line.isNotEmpty) buffer.writeln('• $line');
          } else if (rel is String && rel.trim().isNotEmpty) {
            buffer.writeln('• ${rel.trim()}');
          }
        }
        buffer.writeln();
      }

      // 5. Fallback if Mirage returned custom/form fields only
      var formatted = buffer.toString().trim();
      if (formatted.isEmpty) {
        formatted = const JsonEncoder.withIndent('  ').convert(decoded);
      }

      return MirageInferenceResult(
        rawJson: rawJson,
        formattedResponse: formatted,
        latencyMs: latencyMs,
        boxes: boxes,
      );
    } catch (_) {
      return MirageInferenceResult(
        rawJson: rawJson,
        formattedResponse: rawJson,
        latencyMs: latencyMs,
        boxes: const [],
      );
    }
  }
}

class ChatMessageItem {
  const ChatMessageItem({
    required this.id,
    required this.sender,
    required this.text,
    required this.timestamp,
    this.imagePath,
    this.latencyMs,
    this.boxes = const [],
    this.rawJson,
    this.isError = false,
  });

  final String id;
  final MessageSender sender;
  final String text;
  final DateTime timestamp;
  final String? imagePath;
  final int? latencyMs;
  final List<DetectedBox> boxes;
  final String? rawJson;
  final bool isError;
}
