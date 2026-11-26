import 'dart:io';
import 'package:flutter/material.dart';
import '../models/chat_models.dart';

/// Displays an image with optional Mirage 0..1000 bounding-box overlays.
class AnnotatedImagePreview extends StatelessWidget {
  const AnnotatedImagePreview({
    super.key,
    required this.imagePath,
    this.boxes = const [],
    this.showBoxes = false,
  });

  final String imagePath;
  final List<DetectedBox> boxes;
  final bool showBoxes;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxHeight: 260, maxWidth: 280),
        child: Stack(
          fit: StackFit.passthrough,
          children: [
            Image.file(
              File(imagePath),
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Container(
                height: 140,
                color: const Color(0xFF2F2F2F),
                alignment: Alignment.center,
                child: const Icon(Icons.broken_image_outlined, color: Colors.white54),
              ),
            ),
            if (showBoxes && boxes.isNotEmpty)
              Positioned.fill(
                child: CustomPaint(
                  painter: _MirageBoxPainter(boxes),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _MirageBoxPainter extends CustomPainter {
  _MirageBoxPainter(this.boxes);

  final List<DetectedBox> boxes;

  @override
  void paint(Canvas canvas, Size size) {
    for (final box in boxes) {
      if (box.bbox.length != 4) continue;
      final left = (box.bbox[0] / 1000.0) * size.width;
      final top = (box.bbox[1] / 1000.0) * size.height;
      final right = (box.bbox[2] / 1000.0) * size.width;
      final bottom = (box.bbox[3] / 1000.0) * size.height;

      final color = box.isText ? const Color(0xFF38BDF8) : const Color(0xFF10A37F);
      final rect = Rect.fromLTRB(left, top, right, bottom);

      final strokePaint = Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0;

      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, const Radius.circular(4)),
        strokePaint,
      );

      final textPainter = TextPainter(
        text: TextSpan(
          text: ' ${box.label} ',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 10,
            fontWeight: FontWeight.w600,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout(maxWidth: size.width);

      final labelRect = Rect.fromLTWH(
        left,
        (top - textPainter.height - 2).clamp(0.0, size.height - textPainter.height),
        textPainter.width,
        textPainter.height + 2,
      );
      canvas.drawRect(labelRect, Paint()..color = color.withOpacity(0.85));
      textPainter.paint(canvas, Offset(labelRect.left, labelRect.top + 1));
    }
  }

  @override
  bool shouldRepaint(covariant _MirageBoxPainter oldDelegate) =>
      oldDelegate.boxes != boxes;
}
