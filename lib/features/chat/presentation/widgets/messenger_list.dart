import 'package:flutter/material.dart';

class MessengerList extends StatelessWidget {
  final Function(String userId, String userName) onChatSelected;
  final int selectedIndex;
  final VoidCallback onToggleTheme;

  const MessengerList({
    super.key,
    required this.onChatSelected,
    required this.selectedIndex,
    required this.onToggleTheme,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Column(
      children: [
        // 1. Messenger Header
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 48, 16, 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "Chats",
                style: theme.textTheme.headlineLarge?.copyWith(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Row(
                children: [
                  _HeaderAction(
                    icon: Icons.camera_alt,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                  const SizedBox(width: 8),
                  _HeaderAction(
                    icon: Icons.edit,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: onToggleTheme,
                    child: _HeaderAction(
                      icon: isDark ? Icons.light_mode : Icons.dark_mode,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),

        // 2. Search Box (Messenger Style)
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            height: 40,
            decoration: BoxDecoration(
              color: isDark
                  ? Colors.white.withOpacity(0.05)
                  : Colors.grey.shade200,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              children: [
                Icon(Icons.search, size: 18, color: Colors.grey.shade500),
                const SizedBox(width: 8),
                Text(
                  "Search",
                  style: TextStyle(color: Colors.grey.shade500, fontSize: 13),
                ),
              ],
            ),
          ),
        ),

        // 3. Active Users Row (Messenger Style)
        SizedBox(
          height: 100,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            children: [
              const _ActiveUserItem(
                name: "Your Story",
                isStory: true,
                isActive: false,
                color: Colors.blueAccent,
              ),
              _ActiveUserItem(
                name: "DeepCode AI",
                isActive: true,
                color: Colors.indigo.shade600,
              ),
              const _ActiveUserItem(
                name: "Jane Smith",
                isActive: true,
                color: Colors.green,
              ),
              const _ActiveUserItem(
                name: "Mark Z",
                isActive: false,
                color: Colors.blue,
              ),
              const _ActiveUserItem(
                name: "Sarah Parker",
                isActive: true,
                color: Colors.purple,
              ),
              const _ActiveUserItem(
                name: "Michael B",
                isActive: true,
                color: Colors.amber,
              ),
            ],
          ),
        ),

        // 4. Conversation List
        Expanded(
          child: ListView(
            padding: const EdgeInsets.only(top: 8),
            children: [
              _ChatTile(
                name: "DeepCode AI",
                message: "How can I help you today?",
                time: "10:15 AM",
                isActive: true,
                unread: 2,
                color: Colors.indigo.shade600,
                onTap: () => onChatSelected("ai_1", "DeepCode AI"),
              ),
              _ChatTile(
                name: "Jane Smith",
                message: "Sent a photo",
                time: "9:30 AM",
                isActive: true,
                unread: 0,
                color: Colors.green,
                onTap: () => onChatSelected("jane_1", "Jane Smith"),
              ),
              _ChatTile(
                name: "Mark Z",
                message: "You: Yeah, that sounds good",
                time: "Yesterday",
                isActive: false,
                unread: 0,
                color: Colors.blue,
                onTap: () => onChatSelected("mark_1", "Mark Z"),
              ),
              _ChatTile(
                name: "Sarah Parker",
                message: "Can we talk about the UI?",
                time: "2 days ago",
                isActive: true,
                unread: 0,
                color: Colors.purple,
                onTap: () => onChatSelected("sarah_1", "Sarah Parker"),
              ),
              _ChatTile(
                name: "Michael B",
                message: "See you later!",
                time: "Sunday",
                isActive: true,
                unread: 0,
                color: Colors.amber,
                onTap: () => onChatSelected("mike_1", "Michael B"),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _HeaderAction extends StatelessWidget {
  final IconData icon;
  final Color color;
  const _HeaderAction({required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        color: color.withOpacity(0.05),
        shape: BoxShape.circle,
      ),
      child: Icon(icon, size: 18, color: color),
    );
  }
}

class _ActiveUserItem extends StatelessWidget {
  final String name;
  final bool isActive;
  final bool isStory;
  final Color color;

  const _ActiveUserItem({
    required this.name,
    required this.isActive,
    this.isStory = false,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 16),
      child: Column(
        children: [
          Stack(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: isStory
                      ? Border.all(color: Colors.blue, width: 2)
                      : null,
                ),
                padding: const EdgeInsets.all(2),
                child: CircleAvatar(
                  backgroundColor: color,
                  child: isStory
                      ? Icon(Icons.add, color: Colors.blue.shade900)
                      : Text(
                          name[0],
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
              ),
              if (isActive)
                Positioned(
                  right: 2,
                  bottom: 2,
                  child: Container(
                    width: 14,
                    height: 14,
                    decoration: BoxDecoration(
                      color: Colors.green,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Theme.of(context).scaffoldBackgroundColor,
                        width: 2,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: 60,
            child: Text(
              name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 11),
            ),
          ),
        ],
      ),
    );
  }
}

class _ChatTile extends StatelessWidget {
  final String name;
  final String message;
  final String time;
  final bool isActive;
  final int unread;
  final Color color;
  final VoidCallback onTap;

  const _ChatTile({
    required this.name,
    required this.message,
    required this.time,
    required this.isActive,
    required this.unread,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          children: [
            Stack(
              children: [
                CircleAvatar(
                  radius: 28,
                  backgroundColor: color,
                  child: Text(
                    name[0],
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                if (isActive)
                  Positioned(
                    right: 4,
                    bottom: 4,
                    child: Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        color: Colors.green,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Theme.of(context).scaffoldBackgroundColor,
                          width: 2,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: TextStyle(
                      fontWeight: unread > 0
                          ? FontWeight.bold
                          : FontWeight.w500,
                      fontSize: 15,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    message,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: unread > 0
                          ? (isDark ? Colors.white : Colors.black)
                          : Colors.grey.shade500,
                      fontWeight: unread > 0
                          ? FontWeight.bold
                          : FontWeight.normal,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  time,
                  style: TextStyle(color: Colors.grey.shade500, fontSize: 11),
                ),
                if (unread > 0)
                  Container(
                    margin: const EdgeInsets.only(top: 8),
                    padding: const EdgeInsets.all(6),
                    decoration: const BoxDecoration(
                      color: Colors.indigo,
                      shape: BoxShape.circle,
                    ),
                    child: Text(
                      unread.toString(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
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
}
