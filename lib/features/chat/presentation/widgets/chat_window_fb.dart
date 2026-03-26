import 'package:flutter/material.dart';
import 'package:animate_do/animate_do.dart';

class ChatWindowFB extends StatefulWidget {
  final String userName;
  final VoidCallback? onBack;
  final VoidCallback onToggleTheme;

  const ChatWindowFB({
    super.key,
    required this.userName,
    this.onBack,
    required this.onToggleTheme,
  });

  @override
  State<ChatWindowFB> createState() => _ChatWindowFBState();
}

class _ChatWindowFBState extends State<ChatWindowFB> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  final List<Map<String, dynamic>> _messages = [
    {
      "text": "Hello! How can I help you with your development today?",
      "isMe": false,
      "time": "10:15 AM",
    },
    {
      "text": "I'm looking for some advice on Flutter state management.",
      "isMe": true,
      "time": "10:16 AM",
    },
    {
      "text":
          "Sure, for large apps we recommend Riverpod or Bloc. For simpler ones, Provider works great!",
      "isMe": false,
      "time": "10:17 AM",
    },
    {
      "text": "Got it. What about Clean Architecture?",
      "isMe": true,
      "time": "10:18 AM",
    },
  ];

  void _sendMessage() {
    if (_controller.text.isEmpty) return;
    setState(() {
      _messages.add({"text": _controller.text, "isMe": true, "time": "Now"});
      _controller.clear();
    });
    Future.delayed(const Duration(milliseconds: 100), () {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            if (widget.onBack != null)
              IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: widget.onBack,
              ),
            CircleAvatar(
              radius: 16,
              backgroundColor: Colors.indigo.shade600,
              child: Text(
                widget.userName[0],
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  widget.userName,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Text(
                  "Active Now",
                  style: TextStyle(fontSize: 11, color: Colors.green),
                ),
              ],
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.phone, size: 20),
            color: Colors.indigo,
            onPressed: () {},
          ),
          IconButton(
            icon: const Icon(Icons.videocam, size: 20),
            color: Colors.indigo,
            onPressed: () {},
          ),
          IconButton(
            icon: const Icon(Icons.info, size: 20),
            color: Colors.indigo,
            onPressed: () {},
          ),
          IconButton(
            icon: Icon(isDark ? Icons.light_mode : Icons.dark_mode, size: 18),
            onPressed: widget.onToggleTheme,
          ),
        ],
        elevation: 1,
        backgroundColor: theme.scaffoldBackgroundColor,
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final msg = _messages[index];
                return _ChatBubble(
                  text: msg['text'],
                  isMe: msg['isMe'],
                  time: msg['time'],
                );
              },
            ),
          ),

          // Messenger Input Area
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: theme.scaffoldBackgroundColor,
              border: Border(
                top: BorderSide(
                  color: isDark
                      ? Colors.white.withOpacity(0.05)
                      : Colors.black12,
                ),
              ),
            ),
            child: Row(
              children: [
                const Icon(Icons.add_circle, color: Colors.indigo),
                const SizedBox(width: 8),
                const Icon(Icons.camera_alt, color: Colors.indigo),
                const SizedBox(width: 8),
                const Icon(Icons.photo, color: Colors.indigo),
                const SizedBox(width: 8),
                const Icon(Icons.mic, color: Colors.indigo),
                const SizedBox(width: 12),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    height: 36,
                    decoration: BoxDecoration(
                      color: isDark
                          ? Colors.white.withOpacity(0.05)
                          : Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: TextField(
                      controller: _controller,
                      style: const TextStyle(fontSize: 14),
                      onSubmitted: (_) => _sendMessage(),
                      decoration: const InputDecoration(
                        hintText: "Aa",
                        border: InputBorder.none,
                        isDense: true,
                        contentPadding: EdgeInsets.only(top: 8),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                IconButton(
                  icon: const Icon(Icons.send, color: Colors.indigo),
                  onPressed: _sendMessage,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ChatBubble extends StatelessWidget {
  final String text;
  final bool isMe;
  final String time;

  const _ChatBubble({
    required this.text,
    required this.isMe,
    required this.time,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Column(
        crossAxisAlignment: isMe
            ? CrossAxisAlignment.end
            : CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: isMe
                ? MainAxisAlignment.end
                : MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (!isMe)
                CircleAvatar(
                  radius: 12,
                  backgroundColor: Colors.indigo.shade600,
                  child: const Text(
                    "D",
                    style: TextStyle(color: Colors.white, fontSize: 10),
                  ),
                ),
              const SizedBox(width: 8),
              Flexible(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: isMe
                        ? (isDark
                              ? Colors.indigo.shade600
                              : Colors.indigo.shade500)
                        : (isDark
                              ? Colors.white.withOpacity(0.05)
                              : Colors.grey.shade200),
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(18),
                      topRight: const Radius.circular(18),
                      bottomLeft: Radius.circular(isMe ? 18 : 4),
                      bottomRight: Radius.circular(isMe ? 4 : 18),
                    ),
                  ),
                  child: Text(
                    text,
                    style: TextStyle(
                      color: isMe
                          ? Colors.white
                          : (isDark ? Colors.white : Colors.black87),
                      fontSize: 14,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
        ],
      ),
    );
  }
}
