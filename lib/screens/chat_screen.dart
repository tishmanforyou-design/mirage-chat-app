import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../models/chat_models.dart';
import '../services/mirage_service.dart';
import '../widgets/chat_message_bubble.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final MirageService _mirageService = MirageService();
  final ImagePicker _picker = ImagePicker();
  final TextEditingController _promptController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  final List<ChatMessageItem> _messages = [];
  String? _pendingImagePath;
  String? _lastImagePath;
  bool _isModelInitializing = true;
  bool _isInferring = false;
  String _modelStatus = 'Initializing Mirage (21.6 MB)…';
  double? _modelProgress;
  String? _initError;

  @override
  void initState() {
    super.initState();
    _initModel();
  }

  Future<void> _initModel() async {
    setState(() {
      _isModelInitializing = true;
      _initError = null;
      _modelStatus = 'Initializing Mirage (21.6 MB)…';
    });

    try {
      await _mirageService.initialize(
        onProgress: (status, progress) {
          if (!mounted) return;
          setState(() {
            _modelStatus = status;
            _modelProgress = progress;
          });
        },
      );
      if (!mounted) return;
      setState(() {
        _isModelInitializing = false;
        _modelStatus = 'Mirage 2-bit • Offline Ready';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isModelInitializing = false;
        _initError = e.toString();
        _modelStatus = 'Model Load Failed';
      });
    }
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final picked = await _picker.pickImage(
        source: source,
        maxWidth: 1600,
        maxHeight: 1600,
        imageQuality: 92,
      );
      if (picked == null) return;
      setState(() {
        _pendingImagePath = picked.path;
        _lastImagePath = picked.path;
      });
    } catch (e) {
      _showSnack('Could not access image: $e');
    }
  }

  Future<void> _sendMessage({MiragePreset? preset}) async {
    if (_isInferring) return;

    final promptText = (preset?.prompt ?? _promptController.text).trim();
    final imagePath = _pendingImagePath ?? _lastImagePath;

    if (imagePath == null) {
      _showSnack('Select or capture a photo first so Mirage can analyze it.');
      return;
    }

    final effectivePrompt =
        promptText.isEmpty ? MiragePreset.describeScene.prompt : promptText;

    final userMsg = ChatMessageItem(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      sender: MessageSender.user,
      text: effectivePrompt,
      imagePath: _pendingImagePath,
      timestamp: DateTime.now(),
    );

    setState(() {
      _messages.add(userMsg);
      _pendingImagePath = null;
      _promptController.clear();
      _isInferring = true;
    });
    _scrollToBottom();

    try {
      final result = await _mirageService.analyzeImage(
        imagePath: imagePath,
        prompt: effectivePrompt,
        preset: preset,
      );

      if (!mounted) return;
      setState(() {
        _messages.add(
          ChatMessageItem(
            id: '${DateTime.now().microsecondsSinceEpoch}_ai',
            sender: MessageSender.assistant,
            text: result.formattedResponse,
            imagePath: result.boxes.isNotEmpty ? imagePath : null,
            latencyMs: result.latencyMs,
            boxes: result.boxes,
            rawJson: result.rawJson,
            isError: result.hasError,
            timestamp: DateTime.now(),
          ),
        );
        _isInferring = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _messages.add(
          ChatMessageItem(
            id: '${DateTime.now().microsecondsSinceEpoch}_err',
            sender: MessageSender.assistant,
            text: 'On-device inference failed: $e',
            isError: true,
            timestamp: DateTime.now(),
          ),
        );
        _isInferring = false;
      });
    }
    _scrollToBottom();
  }

  void _clearChat() {
    setState(() {
      _messages.clear();
      _pendingImagePath = null;
      _lastImagePath = null;
    });
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent + 120,
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOut,
      );
    });
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), behavior: SnackBarBehavior.floating),
    );
  }

  @override
  void dispose() {
    _promptController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF212121),
      appBar: AppBar(
        backgroundColor: const Color(0xFF171717),
        elevation: 0,
        centerTitle: false,
        title: Row(
          children: [
            const Text(
              'Mirage Chat',
              style: TextStyle(
                color: Color(0xFFECECEC),
                fontSize: 17,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(width: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: _initError != null
                    ? const Color(0xFFEF4444).withOpacity(0.18)
                    : const Color(0xFF10A37F).withOpacity(0.16),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: _initError != null
                          ? const Color(0xFFEF4444)
                          : _isModelInitializing
                              ? const Color(0xFFF59E0B)
                              : const Color(0xFF10A37F),
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 5),
                  Text(
                    _isModelInitializing
                        ? 'Loading…'
                        : (_initError != null ? 'Offline Error' : '22 MB Offline'),
                    style: const TextStyle(
                      color: Color(0xFFD1D5DB),
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'New chat',
            onPressed: _messages.isEmpty ? null : _clearChat,
            icon: const Icon(Icons.edit_square, color: Color(0xFFD1D5DB), size: 20),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            if (_isModelInitializing || _initError != null) _buildStatusBanner(),
            Expanded(
              child: _messages.isEmpty
                  ? _buildEmptyState()
                  : ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.only(top: 12, bottom: 16),
                      itemCount: _messages.length + (_isInferring ? 1 : 0),
                      itemBuilder: (context, index) {
                        if (index == _messages.length) {
                          return _buildInferenceLoadingRow();
                        }
                        return ChatMessageBubble(message: _messages[index]);
                      },
                    ),
            ),
            _buildPresetChipsBar(),
            _buildBottomInputBar(),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusBanner() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      color: const Color(0xFF1A1A1A),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (_isModelInitializing)
                const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Color(0xFF10A37F),
                  ),
                )
              else
                const Icon(Icons.warning_amber_rounded,
                    size: 16, color: Color(0xFFEF4444)),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  _initError ?? _modelStatus,
                  style: TextStyle(
                    color: _initError != null
                        ? const Color(0xFFFCA5A5)
                        : const Color(0xFFD1D5DB),
                    fontSize: 12.5,
                  ),
                ),
              ),
              if (_initError != null)
                TextButton(
                  onPressed: _initModel,
                  child: const Text('Retry'),
                ),
            ],
          ),
          if (_isModelInitializing && _modelProgress != null) ...[
            const SizedBox(height: 6),
            LinearProgressIndicator(
              value: _modelProgress,
              backgroundColor: const Color(0xFF2F2F2F),
              color: const Color(0xFF10A37F),
              minHeight: 3,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: const Color(0xFF10A37F).withOpacity(0.14),
                shape: BoxShape.circle,
                border: Border.all(
                  color: const Color(0xFF10A37F).withOpacity(0.45),
                ),
              ),
              child: const Icon(
                Icons.visibility_rounded,
                color: Color(0xFF10A37F),
                size: 28,
              ),
            ),
            const SizedBox(height: 18),
            const Text(
              'What would you like to analyze?',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Color(0xFFECECEC),
                fontSize: 22,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Cactus Mirage runs 100% offline on-device (21.6 MB 2-bit VLM). '
              'Capture or pick a photo to describe scenes, extract OCR text, or detect objects.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Color(0xFF9CA3AF),
                fontSize: 13.5,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 22),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                OutlinedButton.icon(
                  onPressed: () => _pickImage(ImageSource.camera),
                  icon: const Icon(Icons.camera_alt_outlined, size: 18),
                  label: const Text('Camera'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFFECECEC),
                    side: const BorderSide(color: Color(0xFF3F3F3F)),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                OutlinedButton.icon(
                  onPressed: () => _pickImage(ImageSource.gallery),
                  icon: const Icon(Icons.photo_library_outlined, size: 18),
                  label: const Text('Gallery'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFFECECEC),
                    side: const BorderSide(color: Color(0xFF3F3F3F)),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInferenceLoadingRow() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Container(
            width: 30,
            height: 30,
            margin: const EdgeInsets.only(right: 12),
            decoration: BoxDecoration(
              color: const Color(0xFF10A37F).withOpacity(0.16),
              shape: BoxShape.circle,
            ),
            child: const Padding(
              padding: EdgeInsets.all(7),
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Color(0xFF10A37F),
              ),
            ),
          ),
          const Text(
            'Running Mirage on-device…',
            style: TextStyle(
              color: Color(0xFF9CA3AF),
              fontSize: 14,
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPresetChipsBar() {
    return SizedBox(
      height: 44,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
        itemCount: MiragePreset.values.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final preset = MiragePreset.values[index];
          return ActionChip(
            label: Text(
              preset.label,
              style: const TextStyle(
                color: Color(0xFFE5E7EB),
                fontSize: 12.5,
                fontWeight: FontWeight.w500,
              ),
            ),
            backgroundColor: const Color(0xFF2B2B2B),
            side: const BorderSide(color: Color(0xFF3D3D3D)),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            onPressed: _isInferring
                ? null
                : () {
                    if (_pendingImagePath != null || _lastImagePath != null) {
                      _sendMessage(preset: preset);
                    } else {
                      _promptController.text = preset.prompt;
                      _showSnack('Now attach a photo to run "${preset.label}".');
                    }
                  },
          );
        },
      ),
    );
  }

  Widget _buildBottomInputBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 6, 12, 12),
      color: const Color(0xFF212121),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_pendingImagePath != null)
            Padding(
              padding: const EdgeInsets.only(left: 4, bottom: 8),
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.file(
                      File(_pendingImagePath!),
                      width: 68,
                      height: 68,
                      fit: BoxFit.cover,
                    ),
                  ),
                  Positioned(
                    top: -6,
                    right: -6,
                    child: GestureDetector(
                      onTap: () => setState(() => _pendingImagePath = null),
                      child: Container(
                        width: 22,
                        height: 22,
                        decoration: const BoxDecoration(
                          color: Color(0xFF171717),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.close,
                          size: 14,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          Container(
            decoration: BoxDecoration(
              color: const Color(0xFF2F2F2F),
              borderRadius: BorderRadius.circular(26),
              border: Border.all(color: const Color(0xFF3E3E3E)),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                IconButton(
                  tooltip: 'Capture photo',
                  onPressed: _isInferring
                      ? null
                      : () => _pickImage(ImageSource.camera),
                  icon: const Icon(
                    Icons.camera_alt_outlined,
                    color: Color(0xFFD1D5DB),
                    size: 22,
                  ),
                ),
                IconButton(
                  tooltip: 'Pick from gallery',
                  onPressed: _isInferring
                      ? null
                      : () => _pickImage(ImageSource.gallery),
                  icon: const Icon(
                    Icons.image_outlined,
                    color: Color(0xFFD1D5DB),
                    size: 22,
                  ),
                ),
                Expanded(
                  child: TextField(
                    controller: _promptController,
                    minLines: 1,
                    maxLines: 4,
                    style: const TextStyle(
                      color: Color(0xFFECECEC),
                      fontSize: 15,
                    ),
                    textInputAction: TextInputAction.send,
                    onSubmitted: (_) => _sendMessage(),
                    decoration: const InputDecoration(
                      hintText: 'Ask Mirage about an image…',
                      hintStyle: TextStyle(color: Color(0xFF9CA3AF)),
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 12,
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(right: 4, bottom: 4),
                  child: CircleAvatar(
                    radius: 19,
                    backgroundColor: _isInferring
                        ? const Color(0xFF4B5563)
                        : const Color(0xFFECECEC),
                    child: IconButton(
                      padding: EdgeInsets.zero,
                      icon: Icon(
                        _isInferring ? Icons.hourglass_top : Icons.arrow_upward_rounded,
                        size: 20,
                        color: const Color(0xFF171717),
                      ),
                      onPressed: _isInferring ? null : () => _sendMessage(),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
