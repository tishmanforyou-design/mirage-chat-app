import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/chat_models.dart';
import 'annotated_image_preview.dart';

class ChatMessageBubble extends StatefulWidget {
  const ChatMessageBubble({super.key, required this.message});

  final ChatMessageItem message;

  @override
  State<ChatMessageBubble> createState() => _ChatMessageBubbleState();
}

class _ChatMessageBubbleState extends State<ChatMessageBubble> {
  bool _showBoxes = true;
  bool _showRawJson = false;

  @override
  Widget build(BuildContext context) {
    final isUser = widget.message.sender == MessageSender.user;

    if (isUser) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Align(
          alignment: Alignment.centerRight,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width * 0.80,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                if (widget.message.imagePath != null) ...[
                  AnnotatedImagePreview(imagePath: widget.message.imagePath!),
                  const SizedBox(height: 6),
                ],
                if (widget.message.text.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFF2F2F2F),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      widget.message.text,
                      style: const TextStyle(
                        color: Color(0xFFECECEC),
                        fontSize: 15,
                        height: 1.45,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      );
    }

    // Assistant (ChatGPT-style full-width dark response row)
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 30,
            height: 30,
            margin: const EdgeInsets.only(top: 2, right: 12),
            decoration: BoxDecoration(
              color: widget.message.isError
                  ? const Color(0xFFEF4444).withOpacity(0.18)
                  : const Color(0xFF10A37F).withOpacity(0.18),
              shape: BoxShape.circle,
              border: Border.all(
                color: widget.message.isError
                    ? const Color(0xFFEF4444)
                    : const Color(0xFF10A37F),
                width: 1.2,
              ),
            ),
            child: Icon(
              widget.message.isError ? Icons.error_outline : Icons.visibility_outlined,
              size: 16,
              color: widget.message.isError
                  ? const Color(0xFFEF4444)
                  : const Color(0xFF10A37F),
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Text(
                      'Mirage',
                      style: TextStyle(
                        color: Color(0xFFECECEC),
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                    if (widget.message.latencyMs != null) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 7,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFF2A2A2A),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          '${widget.message.latencyMs} ms • On-device',
                          style: const TextStyle(
                            color: Color(0xFF9CA3AF),
                            fontSize: 11,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 6),
                if (widget.message.imagePath != null &&
                    widget.message.boxes.isNotEmpty) ...[
                  AnnotatedImagePreview(
                    imagePath: widget.message.imagePath!,
                    boxes: widget.message.boxes,
                    showBoxes: _showBoxes,
                  ),
                  const SizedBox(height: 8),
                ],
                SelectableText(
                  _showRawJson && widget.message.rawJson != null
                      ? widget.message.rawJson!
                      : widget.message.text,
                  style: TextStyle(
                    color: widget.message.isError
                        ? const Color(0xFFFCA5A5)
                        : const Color(0xFFE5E7EB),
                    fontSize: _showRawJson ? 12.5 : 15,
                    fontFamily: _showRawJson ? 'monospace' : null,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: [
                    _ActionIconChip(
                      icon: Icons.copy_rounded,
                      label: 'Copy',
                      onTap: () {
                        Clipboard.setData(
                          ClipboardData(text: widget.message.text),
                        );
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Copied response to clipboard'),
                            duration: Duration(seconds: 1),
                          ),
                        );
                      },
                    ),
                    if (widget.message.boxes.isNotEmpty)
                      _ActionIconChip(
                        icon: _showBoxes
                            ? Icons.layers_clear_outlined
                            : Icons.layers_outlined,
                        label: _showBoxes ? 'Hide Boxes' : 'Show Boxes',
                        onTap: () => setState(() => _showBoxes = !_showBoxes),
                      ),
                    if (widget.message.rawJson != null)
                      _ActionIconChip(
                        icon: Icons.data_object_rounded,
                        label: _showRawJson ? 'Formatted' : 'JSON',
                        onTap: () => setState(() => _showRawJson = !_showRawJson),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionIconChip extends StatelessWidget {
  const _ActionIconChip({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: const Color(0xFF9CA3AF)),
            const SizedBox(width: 4),
            Text(
              label,
              style: const TextStyle(
                color: Color(0xFF9CA3AF),
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
