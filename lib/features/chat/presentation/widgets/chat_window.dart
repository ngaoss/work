import 'package:flutter/material.dart';
import 'package:animate_do/animate_do.dart';
import 'package:google_fonts/google_fonts.dart';

class ChatWindow extends StatefulWidget {
  final VoidCallback onToggleTheme;
  final String channelName;
  final bool isMobile;

  const ChatWindow({
    super.key,
    required this.onToggleTheme,
    required this.channelName,
    required this.isMobile,
  });

  @override
  State<ChatWindow> createState() => _ChatWindowState();
}

class _ChatWindowState extends State<ChatWindow> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  final List<Map<String, dynamic>> _messages = [];

  void _sendMessage() {
    if (_messageController.text.trim().isEmpty) return;
    setState(() {
      _messages.add({
        "sender": "John Doe",
        "text": _messageController.text,
        "isAi": false,
        "time": "Now",
      });
      _messageController.clear();
    });
    // Scroll to bottom
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

    return Column(
      children: [
        // 1. Header
        Container(
          height: 64,
          padding: const EdgeInsets.symmetric(horizontal: 24),
          decoration: BoxDecoration(
            color: theme.scaffoldBackgroundColor,
            border: Border(
              bottom: BorderSide(
                color: isDark ? Colors.white.withOpacity(0.05) : Colors.black12,
              ),
            ),
          ),
          child: Row(
            children: [
              if (widget.isMobile)
                IconButton(
                  icon: const Icon(Icons.menu),
                  onPressed: () => Scaffold.of(context).openDrawer(),
                ),

              Text(
                widget.channelName,
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  color: Colors.green,
                  shape: BoxShape.circle,
                ),
              ),
              const Spacer(),
              _HeaderAction(icon: Icons.search, onTap: () {}),
              _HeaderAction(icon: Icons.videocam_outlined, onTap: () {}),
              _HeaderAction(icon: Icons.info_outline, onTap: () {}),
              IconButton(
                icon: Icon(
                  isDark ? Icons.light_mode_outlined : Icons.dark_mode_outlined,
                ),
                onPressed: widget.onToggleTheme,
                iconSize: 20,
              ),
            ],
          ),
        ),

        // 2. Message List
        Expanded(
          child: ListView.builder(
            controller: _scrollController,
            padding: const EdgeInsets.all(24),
            itemCount: _messages.length,
            itemBuilder: (context, index) {
              final msg = _messages[index];
              return _MessageTile(
                sender: msg['sender'],
                text: msg['text'],
                isAi: msg['isAi'],
                time: msg['time'],
              );
            },
          ),
        ),

        // 3. Message Input (Fixed Width on Desktop)
        Container(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 900),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E293B) : Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isDark
                        ? Colors.white.withOpacity(0.05)
                        : Colors.black12,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(isDark ? 0.3 : 0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextField(
                            controller: _messageController,
                            style: theme.textTheme.bodyLarge,
                            maxLines: null,
                            onSubmitted: (_) => _sendMessage(),
                            decoration: InputDecoration(
                              hintText:
                                  "Send a message to ${widget.channelName}...",
                              border: InputBorder.none,
                              hintStyle: TextStyle(
                                color: isDark
                                    ? Colors.grey
                                    : Colors.grey.shade400,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        _InputTool(
                          icon: Icons.bolt,
                          color: Colors.amber,
                          label: "AI",
                        ),
                        _InputTool(
                          icon: Icons.attach_file,
                          color: Colors.blueGrey,
                          label: "Attach",
                        ),
                        _InputTool(
                          icon: Icons.emoji_emotions_outlined,
                          color: Colors.orange,
                          label: "Emoji",
                        ),
                        const Spacer(),
                        _SendButton(onTap: _sendMessage),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _HeaderAction extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _HeaderAction({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 12),
      child: InkWell(
        onTap: onTap,
        child: Icon(icon, size: 20, color: Colors.grey.shade500),
      ),
    );
  }
}

class _InputTool extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  const _InputTool({
    required this.icon,
    required this.color,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(right: 12),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: color,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}

class _SendButton extends StatelessWidget {
  final VoidCallback onTap;
  const _SendButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: Colors.indigo,
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Icon(Icons.arrow_upward, color: Colors.white, size: 20),
      ),
    );
  }
}

class _MessageTile extends StatelessWidget {
  final String sender;
  final String text;
  final bool isAi;
  final String time;

  const _MessageTile({
    required this.sender,
    required this.text,
    required this.isAi,
    required this.time,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.only(bottom: 24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 14,
                backgroundColor: isAi
                    ? Colors.indigo.shade600
                    : Colors.blueGrey,
                child: Icon(
                  isAi ? Icons.auto_fix_high : Icons.person,
                  size: 14,
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: 10),
              Text(
                sender,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                time,
                style: TextStyle(color: Colors.grey.shade500, fontSize: 11),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.only(left: 38),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isAi
                    ? (isDark
                          ? Colors.indigo.withOpacity(0.05)
                          : Colors.indigo.shade50.withOpacity(0.5))
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(12),
                border: isAi
                    ? Border.all(color: Colors.indigo.withOpacity(0.1))
                    : null,
              ),
              child: Text(
                text,
                style: theme.textTheme.bodyLarge?.copyWith(
                  height: 1.5,
                  color: isDark
                      ? Colors.grey.shade200
                      : Colors.blueGrey.shade900,
                  fontFamily: text.contains('```')
                      ? GoogleFonts.firaCode().fontFamily
                      : null,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
