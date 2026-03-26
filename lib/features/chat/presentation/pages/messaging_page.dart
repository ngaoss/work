import 'package:flutter/material.dart';
import 'chat_detail_screen.dart';

class MessagingPage extends StatefulWidget {
  const MessagingPage({super.key});

  @override
  State<MessagingPage> createState() => _MessagingPageState();
}

class _MessagingPageState extends State<MessagingPage> {
  final List<Map<String, dynamic>> _chats = [];

  void _upsertGroup({int? id, required String name}) {
    setState(() {
      if (id != null) {
        // Edit existing group/chat name
        final index = _chats.indexWhere((c) => c["id"] == id);
        if (index != -1) {
          _chats[index]["name"] = name;
          _chats[index]["initials"] = name.length >= 2
              ? name.substring(0, 2).toUpperCase()
              : name.toUpperCase();
        }
      }
    });
  }

  void _createChat(List<Map<String, dynamic>> selectedUsers) {
    if (selectedUsers.isEmpty) return;

    setState(() {
      if (selectedUsers.length == 1) {
        // Direct format
        final user = selectedUsers.first;
        _chats.insert(0, {
          "id": DateTime.now().millisecondsSinceEpoch,
          "name": user["name"],
          "status": user["role"],
          "lastMsg": "Bắt đầu cuộc trò chuyện",
          "time": "Vừa xong",
          "isOnline": true,
          "initials": user["name"].substring(0, 2).toUpperCase(),
          "color": Colors.blue,
          "isGroup": false,
          "messages": [],
        });
      } else {
        // Group format
        _chats.insert(0, {
          "id": DateTime.now().millisecondsSinceEpoch,
          "name": "Nhóm mới",
          "status": "${selectedUsers.length + 1} thành viên",
          "lastMsg": "Bạn đã tạo nhóm mới",
          "time": "Vừa xong",
          "isOnline": false,
          "initials": "NM",
          "color": Colors.orange,
          "isGroup": true,
          "messages": [],
        });
      }
    });
  }

  final List<Map<String, dynamic>> _dummyUsers = [
    {"id": 1, "name": "Nguyên Tuấn", "role": "Developer"},
    {"id": 2, "name": "Mai Anh", "role": "Designer"},
    {"id": 3, "name": "Hoàng Nam", "role": "Manager"},
    {"id": 4, "name": "Bảo Ngọc", "role": "Tester"},
    {"id": 5, "name": "Viết Lâm", "role": "HR"},
  ];

  void _showUserSelectionSheet() {
    List<Map<String, dynamic>> selectedUsers = [];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) {
          return Container(
            height: MediaQuery.of(context).size.height * 0.75,
            padding: const EdgeInsets.all(24),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      "Tạo tin nhắn mới",
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 20,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                TextField(
                  decoration: InputDecoration(
                    hintText: "Tìm kiếm người liên hệ...",
                    prefixIcon: const Icon(Icons.search, color: Colors.grey),
                    filled: true,
                    fillColor: const Color(0xFFF1F5F9),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: ListView.builder(
                    itemCount: _dummyUsers.length,
                    itemBuilder: (context, index) {
                      final user = _dummyUsers[index];
                      final isSelected = selectedUsers.contains(user);
                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: CircleAvatar(
                          backgroundColor: Colors.blueGrey.shade100,
                          child: Text(
                            user["name"].substring(0, 1),
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                        title: Text(
                          user["name"],
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Text(
                          user["role"],
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.grey,
                          ),
                        ),
                        trailing: Icon(
                          isSelected
                              ? Icons.check_circle
                              : Icons.circle_outlined,
                          color: isSelected
                              ? Colors.blue
                              : Colors.grey.shade300,
                          size: 28,
                        ),
                        onTap: () {
                          setModalState(() {
                            if (isSelected) {
                              selectedUsers.remove(user);
                            } else {
                              selectedUsers.add(user);
                            }
                          });
                        },
                      );
                    },
                  ),
                ),
                if (selectedUsers.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 16),
                    child: SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.pop(context);
                          _createChat(selectedUsers);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF3B82F6),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: Text(
                          selectedUsers.length == 1
                              ? "NHẮN TIN"
                              : "TẠO NHÓM (${selectedUsers.length})",
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  void _deleteGroup(int id) {
    setState(() {
      _chats.removeWhere((c) => c["id"] == id);
    });
  }

  void _showGroupSheet({Map<String, dynamic>? existingChat}) {
    final TextEditingController groupNameController = TextEditingController(
      text: existingChat?["name"],
    );
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: EdgeInsets.fromLTRB(
          24,
          24,
          24,
          MediaQuery.of(context).viewInsets.bottom + 24,
        ),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Sửa thông tin",
              style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 20),
            ),
            const SizedBox(height: 24),
            TextField(
              controller: groupNameController,
              decoration: InputDecoration(
                hintText: "Tên nhóm",
                filled: true,
                fillColor: const Color(0xFFF1F5F9),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              "Thành viên nhóm",
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 13,
                color: Colors.blueGrey,
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 50,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  const CircleAvatar(
                    backgroundColor: Color(0xFFEFF6FF),
                    child: Icon(Icons.add, color: Color(0xFF3B82F6)),
                  ),
                  const SizedBox(width: 8),
                  CircleAvatar(
                    backgroundColor: Colors.orange.shade100,
                    child: const Text(
                      "L",
                      style: TextStyle(
                        color: Colors.orange,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: () {
                  if (groupNameController.text.isNotEmpty) {
                    _upsertGroup(
                      id: existingChat?["id"],
                      name: groupNameController.text,
                    );
                    Navigator.pop(context);
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF3B82F6),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: const Text(
                  "LƯU THAY ĐỔI",
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showChatOptions(Map<String, dynamic> chat) {
    showModalBottomSheet(
      context: context,
      builder: (context) => Wrap(
        children: [
          if (chat["isGroup"])
            ListTile(
              leading: const Icon(Icons.edit_outlined, color: Colors.blue),
              title: const Text(
                "Sửa thông tin nhóm",
                style: TextStyle(color: Colors.blue),
              ),
              onTap: () {
                Navigator.pop(context);
                _showGroupSheet(existingChat: chat);
              },
            ),
          ListTile(
            leading: const Icon(Icons.delete_outline, color: Colors.red),
            title: Text(
              chat["isGroup"] ? "Xóa nhóm" : "Xóa hội thoại",
              style: const TextStyle(color: Colors.red),
            ),
            onTap: () {
              Navigator.pop(context);
              _deleteGroup(chat["id"]);
            },
          ),
          ListTile(
            leading: const Icon(Icons.notifications_off_outlined),
            title: const Text("Tắt thông báo"),
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
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                "TIN NHẮN",
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 32,
                  letterSpacing: -1,
                ),
              ),
              IconButton(
                icon: const Icon(
                  Icons.add_comment_outlined,
                  color: Color(0xFF3B82F6),
                ),
                onPressed: () => _showUserSelectionSheet(),
                tooltip: "Tạo tin nhắn mới",
              ),
            ],
          ),
          const SizedBox(height: 24),
          _SearchBar(),
          const SizedBox(height: 32),
          _Tabs(),
          const SizedBox(height: 24),
          ..._chats.map(
            (chat) => _ChatItem(
              name: chat["name"],
              status: chat["status"],
              lastMsg: chat["lastMsg"],
              time: chat["time"],
              isOnline: chat["isOnline"],
              initials: chat["initials"],
              color: chat["color"],
              onLongPress: () => _showChatOptions(chat),
              onTap: () async {
                final result = await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ChatDetailScreen(
                      name: chat["name"],
                      isOnline: chat["isOnline"],
                      initials: chat["initials"],
                      color: chat["color"],
                      initialMessages: (chat["messages"] as List?)
                          ?.cast<Map<String, dynamic>>(),
                    ),
                  ),
                );
                if (result != null && result is Map<String, dynamic>) {
                  setState(() {
                    final index = _chats.indexWhere(
                      (c) => c["id"] == chat["id"],
                    );
                    if (index != -1) {
                      _chats[index]["lastMsg"] = result["lastMsg"];
                      _chats[index]["time"] = result["time"];
                      if (result["messages"] != null) {
                        _chats[index]["messages"] = result["messages"];
                      }
                    }
                  });
                }
              },
            ),
          ),
          const SizedBox(height: 100),
        ],
      ),
    );
  }
}

class _SearchBar extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(16),
      ),
      child: const Row(
        children: [
          Icon(Icons.search, size: 18, color: Colors.grey),
          SizedBox(width: 12),
          Text(
            "Tìm kiếm hội thoại...",
            style: TextStyle(color: Colors.grey, fontSize: 13),
          ),
        ],
      ),
    );
  }
}

class _Tabs extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: Colors.grey.withOpacity(0.1))),
      ),
      child: Row(
        children: [
          _TabItem(label: "TẤT CẢ", isActive: true),
          const SizedBox(width: 24),
          _TabItem(label: "CHƯA ĐỌC", isActive: false),
          const SizedBox(width: 24),
          _TabItem(label: "NHÓM", isActive: false),
        ],
      ),
    );
  }
}

class _TabItem extends StatelessWidget {
  final String label;
  final bool isActive;
  const _TabItem({required this.label, required this.isActive});
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          label,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 13,
            color: isActive ? const Color(0xFF3B82F6) : Colors.grey,
          ),
        ),
        if (isActive) ...[
          const SizedBox(height: 6),
          Container(
            width: 40,
            height: 3,
            decoration: BoxDecoration(
              color: const Color(0xFF3B82F6),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ],
      ],
    );
  }
}

class _ChatItem extends StatelessWidget {
  final String name;
  final String status;
  final String lastMsg;
  final String time;
  final bool isOnline;
  final String? initials;
  final Color? color;
  final VoidCallback onLongPress;
  final VoidCallback onTap;

  const _ChatItem({
    required this.name,
    required this.status,
    required this.lastMsg,
    required this.time,
    required this.isOnline,
    this.initials,
    this.color,
    required this.onLongPress,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      onLongPress: onLongPress,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Row(
          children: [
            Stack(
              alignment: Alignment.bottomRight,
              children: [
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    color: color?.withOpacity(0.2) ?? Colors.blueGrey.shade50,
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: initials != null
                        ? Text(
                            initials!,
                            style: TextStyle(
                              color: color ?? Colors.blueGrey,
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                            ),
                          )
                        : const Icon(
                            Icons.person,
                            color: Colors.blueGrey,
                            size: 30,
                          ),
                  ),
                ),
                if (isOnline)
                  Container(
                    width: 14,
                    height: 14,
                    decoration: BoxDecoration(
                      color: const Color(0xFF22C55E),
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                  ),
              ],
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        name,
                        style: const TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 13,
                          color: Color(0xFF1E293B),
                        ),
                      ),
                      Text(
                        time,
                        style: const TextStyle(
                          color: Colors.grey,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    status,
                    style: TextStyle(
                      color: isOnline ? const Color(0xFF22C55E) : Colors.grey,
                      fontWeight: FontWeight.w800,
                      fontSize: 9,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    lastMsg,
                    style: const TextStyle(
                      color: Colors.blueGrey,
                      fontSize: 12,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
