import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

class ChatDetailScreen extends StatefulWidget {
  final String name;
  final bool isOnline;
  final String? initials;
  final Color? color;
  final List<Map<String, dynamic>>? initialMessages;

  const ChatDetailScreen({
    super.key,
    required this.name,
    required this.isOnline,
    this.initials,
    this.color,
    this.initialMessages,
  });

  @override
  State<ChatDetailScreen> createState() => _ChatDetailScreenState();
}

class _ChatDetailScreenState extends State<ChatDetailScreen> {
  final TextEditingController _controller = TextEditingController();
  final ImagePicker _picker = ImagePicker();
  final FocusNode _focusNode = FocusNode();

  bool _showEmoji = false;
  late List<Map<String, dynamic>> _messages;

  int? _editingMessageId;

  @override
  void initState() {
    super.initState();
    _messages = List.from(widget.initialMessages ?? []);
    _focusNode.addListener(() {
      if (_focusNode.hasFocus) {
        setState(() => _showEmoji = false);
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _pickMedia(ImageSource source) async {
    try {
      final XFile? file = await _picker.pickImage(source: source);
      if (file != null) {
        setState(() {
          _messages.add({
            "id": DateTime.now().millisecondsSinceEpoch,
            "text": "",
            "imagePath": file.path,
            "isSender": true,
            "isEdited": false,
          });
        });
      }
    } catch (e) {
      debugPrint("Error picking image: $e");
    }
  }

  void _insertEmoji(String emoji) {
    final text = _controller.text;
    final selection = _controller.selection;
    int start = selection.start;
    if (start < 0) start = text.length;

    final newText = text.replaceRange(
      start,
      selection.end < 0 ? start : selection.end,
      emoji,
    );
    setState(() {
      _controller.text = newText;
      _controller.selection = TextSelection.fromPosition(
        TextPosition(offset: start + emoji.length),
      );
    });
  }

  void _toggleEmoji() {
    if (_showEmoji) {
      _focusNode.requestFocus();
    } else {
      _focusNode.unfocus();
    }
    setState(() => _showEmoji = !_showEmoji);
  }

  void _sendMessage() {
    final text = _controller.text.trim();
    if (text.isEmpty) return;

    setState(() {
      if (_editingMessageId != null) {
        final index = _messages.indexWhere((m) => m["id"] == _editingMessageId);
        if (index != -1) {
          _messages[index]["text"] = text;
          _messages[index]["isEdited"] = true;
        }
        _editingMessageId = null;
      } else {
        _messages.add({
          "id": DateTime.now().millisecondsSinceEpoch,
          "text": text,
          "isSender": true,
          "isEdited": false,
        });
      }
      _controller.clear();
      _showEmoji = false;
    });
  }

  void _deleteMessage(int id) {
    setState(() {
      _messages.removeWhere((m) => m["id"] == id);
    });
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text("Đã xóa tin nhắn")));
  }

  void _startEditing(Map<String, dynamic> msg) {
    if (msg["imagePath"] != null) return;
    setState(() {
      _editingMessageId = msg["id"];
      _controller.text = msg["text"] ?? "";
      _showEmoji = false;
    });
    _focusNode.requestFocus();
  }

  void _showOptions(BuildContext context, Map<String, dynamic> msg) {
    if (!msg["isSender"]) return;

    showModalBottomSheet(
      context: context,
      builder: (context) => Wrap(
        children: [
          if (msg["imagePath"] == null)
            ListTile(
              leading: const Icon(Icons.edit_outlined, color: Colors.blue),
              title: const Text(
                "Chỉnh sửa tin nhắn",
                style: TextStyle(color: Colors.blue),
              ),
              onTap: () {
                Navigator.pop(context);
                _startEditing(msg);
              },
            ),
          ListTile(
            leading: const Icon(Icons.delete_outline, color: Colors.red),
            title: const Text(
              "Xóa tin nhắn",
              style: TextStyle(color: Colors.red),
            ),
            onTap: () {
              Navigator.pop(context);
              _deleteMessage(msg["id"]);
            },
          ),
          ListTile(
            leading: const Icon(Icons.copy_outlined),
            title: const Text("Sao chép"),
            onTap: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios,
            color: Colors.black87,
            size: 20,
          ),
          onPressed: () {
            final lastRecord = _messages.isNotEmpty ? _messages.last : null;
            String preview = "";
            if (lastRecord != null) {
              if (lastRecord["imagePath"] != null) {
                preview = lastRecord["isSender"]
                    ? "Bạn: [Đã gửi một ảnh]"
                    : "[Đã gửi một ảnh]";
              } else {
                final txt = lastRecord["text"] ?? "";
                preview = lastRecord["isSender"] ? "Bạn: $txt" : txt;
              }
            }
            Navigator.pop(context, {
              "lastMsg": preview,
              "time": "Vừa xong",
              "messages": _messages,
            });
          },
        ),
        title: Row(
          children: [
            _HeaderAvatar(
              isOnline: widget.isOnline,
              initials: widget.initials,
              color: widget.color,
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.name,
                  style: const TextStyle(
                    color: Colors.black87,
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  widget.isOnline ? "Đang hoạt động" : "Ngoại tuyến",
                  style: TextStyle(
                    color: widget.isOnline ? Colors.green : Colors.grey,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
      body: WillPopScope(
        onWillPop: () {
          if (_showEmoji) {
            setState(() => _showEmoji = false);
            return Future.value(false);
          }
          final lastRecord = _messages.isNotEmpty ? _messages.last : null;
          String preview = "";
          if (lastRecord != null) {
            if (lastRecord["imagePath"] != null) {
              preview = lastRecord["isSender"]
                  ? "Bạn: [Đã gửi một ảnh]"
                  : "[Đã gửi một ảnh]";
            } else {
              final txt = lastRecord["text"] ?? "";
              preview = lastRecord["isSender"] ? "Bạn: $txt" : txt;
            }
          }
          Navigator.pop(context, {
            "lastMsg": preview,
            "time": "Vừa xong",
            "messages": _messages,
          });
          return Future.value(false);
        },
        child: Column(
          children: [
            Expanded(
              child: ListView.builder(
                reverse: true,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 24,
                ),
                itemCount: _messages.length,
                itemBuilder: (context, index) {
                  final msg = _messages[_messages.length - 1 - index];
                  return GestureDetector(
                    onLongPress: () => _showOptions(context, msg),
                    child: _ChatBubble(
                      message: msg["text"] ?? "",
                      isSender: msg["isSender"],
                      isEdited: msg["isEdited"] ?? false,
                      imagePath: msg["imagePath"],
                    ),
                  );
                },
              ),
            ),
            if (_editingMessageId != null)
              _EditingBanner(
                onCancel: () => setState(() {
                  _editingMessageId = null;
                  _controller.clear();
                }),
              ),

            _ChatInputArea(
              controller: _controller,
              focusNode: _focusNode,
              onSend: _sendMessage,
              onCamera: () => _pickMedia(ImageSource.camera),
              onGallery: () => _pickMedia(ImageSource.gallery),
              onEmoji: _toggleEmoji,
              isEmojiVisible: _showEmoji,
            ),

            if (_showEmoji) _EmojiPickerSheet(onSelected: _insertEmoji),
          ],
        ),
      ),
    );
  }
}

class _EmojiPickerSheet extends StatelessWidget {
  final Function(String) onSelected;
  const _EmojiPickerSheet({required this.onSelected});

  final List<String> emojis = const [
    "😀",
    "😃",
    "😄",
    "😁",
    "😆",
    "😅",
    "😂",
    "🤣",
    "😊",
    "😇",
    "🙂",
    "🙃",
    "😉",
    "😌",
    "😍",
    "🥰",
    "😘",
    "😗",
    "😙",
    "😚",
    "😋",
    "😛",
    "😝",
    "😜",
    "🤪",
    "🤨",
    "🧐",
    "🤓",
    "😎",
    "🤩",
    "🥳",
    "😏",
    "👍",
    "👎",
    "👌",
    "🤟",
    "✌️",
    "🤞",
    "🤝",
    "🙏",
    "💪",
    "🔥",
    "✨",
    "❤️",
    "💙",
    "✅",
    "❌",
    "💯",
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 250,
      color: const Color(0xFFF1F5F9),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      child: GridView.builder(
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 7,
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
        ),
        itemCount: emojis.length,
        itemBuilder: (context, index) => GestureDetector(
          onTap: () => onSelected(emojis[index]),
          child: Center(
            child: Text(emojis[index], style: const TextStyle(fontSize: 24)),
          ),
        ),
      ),
    );
  }
}

class _ChatBubble extends StatelessWidget {
  final String message;
  final bool isSender;
  final bool isEdited;
  final String? imagePath;
  const _ChatBubble({
    required this.message,
    required this.isSender,
    this.isEdited = false,
    this.imagePath,
  });

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: isSender ? Alignment.centerRight : Alignment.centerLeft,
      child: Column(
        crossAxisAlignment: isSender
            ? CrossAxisAlignment.end
            : CrossAxisAlignment.start,
        children: [
          if (imagePath != null)
            Container(
              margin: const EdgeInsets.only(bottom: 8),
              constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width * 0.7,
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: Image.file(File(imagePath!), fit: BoxFit.cover),
              ),
            )
          else
            Container(
              margin: const EdgeInsets.only(bottom: 2),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width * 0.7,
              ),
              decoration: BoxDecoration(
                color: isSender
                    ? const Color(0xFF3B82F6)
                    : const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(20),
                  topRight: const Radius.circular(20),
                  bottomLeft: Radius.circular(isSender ? 20 : 4),
                  bottomRight: Radius.circular(isSender ? 4 : 20),
                ),
              ),
              child: Text(
                message,
                style: TextStyle(
                  color: isSender ? Colors.white : Colors.black87,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          if (isEdited && imagePath == null)
            Padding(
              padding: const EdgeInsets.only(bottom: 14, right: 6, left: 6),
              child: Text(
                "Đã sửa",
                style: TextStyle(
                  color: Colors.blueGrey.withOpacity(0.6),
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            )
          else
            const SizedBox(height: 14),
        ],
      ),
    );
  }
}

class _ChatInputArea extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final VoidCallback onSend;
  final VoidCallback onCamera;
  final VoidCallback onGallery;
  final VoidCallback onEmoji;
  final bool isEmojiVisible;

  const _ChatInputArea({
    required this.controller,
    required this.focusNode,
    required this.onSend,
    required this.onCamera,
    required this.onGallery,
    required this.onEmoji,
    required this.isEmojiVisible,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(
        8,
        12,
        16,
        isEmojiVisible ? 12 : MediaQuery.of(context).padding.bottom + 12,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Colors.grey.withOpacity(0.1))),
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: () {},
            icon: const Icon(Icons.add_circle, color: Color(0xFF3B82F6)),
          ),
          IconButton(
            onPressed: onCamera,
            icon: const Icon(Icons.camera_alt, color: Color(0xFF3B82F6)),
          ),
          IconButton(
            onPressed: onGallery,
            icon: const Icon(Icons.image, color: Color(0xFF3B82F6)),
          ),
          Expanded(
            child: Container(
              height: 48,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(24),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: controller,
                      focusNode: focusNode,
                      onSubmitted: (_) => onSend(),
                      decoration: const InputDecoration(
                        hintText: "Aa",
                        border: InputBorder.none,
                        hintStyle: TextStyle(color: Colors.grey),
                        contentPadding: EdgeInsets.symmetric(vertical: 10),
                      ),
                    ),
                  ),
                  GestureDetector(
                    onTap: onEmoji,
                    child: Icon(
                      isEmojiVisible
                          ? Icons.keyboard
                          : Icons.emoji_emotions_outlined,
                      size: 20,
                      color: isEmojiVisible ? Colors.blue : Colors.blueGrey,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            onPressed: onSend,
            icon: const Icon(Icons.send_rounded, color: Color(0xFF3B82F6)),
          ),
        ],
      ),
    );
  }
}

class _EditingBanner extends StatelessWidget {
  final VoidCallback onCancel;
  const _EditingBanner({required this.onCancel});
  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.blue.withOpacity(0.05),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          const Icon(Icons.edit_outlined, size: 16, color: Colors.blue),
          const SizedBox(width: 8),
          const Expanded(
            child: Text(
              "Đang chỉnh sửa tin nhắn...",
              style: TextStyle(
                color: Colors.blue,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ),
          GestureDetector(
            onTap: onCancel,
            child: const Icon(Icons.close, size: 16, color: Colors.blueGrey),
          ),
        ],
      ),
    );
  }
}

class _HeaderAvatar extends StatelessWidget {
  final bool isOnline;
  final String? initials;
  final Color? color;
  const _HeaderAvatar({required this.isOnline, this.initials, this.color});

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.bottomRight,
      children: [
        CircleAvatar(
          radius: 18,
          backgroundColor: color?.withOpacity(0.2) ?? Colors.blueGrey.shade50,
          child: initials != null
              ? Text(
                  initials!,
                  style: TextStyle(
                    color: color ?? Colors.blueGrey,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                )
              : const Icon(Icons.person, size: 20, color: Colors.blueGrey),
        ),
        if (isOnline)
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              color: Colors.green,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 2),
            ),
          ),
      ],
    );
  }
}
