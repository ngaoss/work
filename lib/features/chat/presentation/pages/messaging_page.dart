import 'dart:io';
import 'dart:async';
import 'package:flutter/material.dart';
import 'chat_detail_screen.dart';
import '../../../../core/api_service.dart';
import '../../../../core/security.dart';

class MessagingPage extends StatefulWidget {
  const MessagingPage({super.key});

  @override
  State<MessagingPage> createState() => _MessagingPageState();
}

class _MessagingPageState extends State<MessagingPage> {
  final List<Map<String, dynamic>> _chats = [];
  int _currentTab = 0;

  List<dynamic> _realUsers = [];
  StreamSubscription? _chatSubscription;

  @override
  void initState() {
    super.initState();
    _fetchUsers();
    _fetchChats();
    _chatSubscription = ApiService.newChatStream.listen(_handleNewMessage);
  }

  void _handleNewMessage(Map<String, dynamic> data) {
    if (!mounted) return;
    
    final chatId = data["chatId"]?.toString() ?? data["chat"]?["_id"]?.toString() ?? data["chat"]?.toString();
    if (chatId == null) return;

    setState(() {
      final index = _chats.indexWhere((c) => c["id"]?.toString() == chatId);
      if (index != -1) {
        // Update existing chat
        _chats[index]["lastMsg"] = data["text"] ?? data["content"] ?? "";
        _chats[index]["time"] = "Vừa xong";
        
        // Mark as unread if not sent by us
        final senderId = data["sender"]?["_id"] ?? data["senderId"] ?? data["sender"];
        final myId = (AuthService().userProfile.value?["_id"] ?? AuthService().userProfile.value?["id"])?.toString();
        if (senderId?.toString() != myId) {
          _chats[index]["hasUnread"] = true;
        }

        // Move to top
        final item = _chats.removeAt(index);
        _chats.insert(0, item);
      } else {
        // It's a message for a chat not in the current top list, maybe fetch again
        _fetchChats();
      }
    });
  }

  @override
  void dispose() {
    _chatSubscription?.cancel();
    super.dispose();
  }

  Future<void> _fetchUsers() async {
    final users = await ApiService.getUsers();
    if (mounted) {
      setState(() {
        _realUsers = users;
      });
    }
  }

  Future<void> _fetchChats() async {
    final chats = await ApiService.getChats();
    if (mounted) {
      setState(() {
        _chats.clear();
        for (var chat in chats) {
          final participants = List<dynamic>.from(chat["participants"] ?? []);
          final bool online = participants.any((participant) {
            final status = participant["status"]?.toString().toLowerCase();
            return participant["isOnline"] == true || status == "online";
          });
          final String name = chat["name"] ?? _resolveChatName(chat, participants);
          final String statusText = chat["isGroup"] == true
              ? (online ? "ĐANG HOẠT ĐỘNG" : "${participants.length} thành viên")
              : (online ? "ĐANG HOẠT ĐỘNG" : "NGOẠI TUYẾN");
          final String? avatarPath = _extractAvatarForChat(chat, participants);
          // debugPrint("Extracted Avatar for [${chat['name'] ?? chat['_id']}]: $avatarPath");

          _chats.add({
            "id": chat["_id"]?.toString(),
            "name": name,
            "status": statusText,
            "lastMsg": chat["lastMessage"]?["text"] ?? "",
            "time": _formatTime(chat["lastMessage"]?["createdAt"]),
            "isOnline": online,
            "initials": _getInitials(chat, participants),
            "color": Colors.blue,
            "isGroup": chat["isGroup"] ?? false,
            "hasUnread": (chat["unreadCount"] ?? 0) > 0,
            "messages": [],
            "participants": participants,
            "avatarPath": avatarPath,
            "themeColor": chat["themeColor"] ?? "#2563eb",
          });
        }
      });
    }
  }

  Map<String, dynamic>? _findOtherParticipant(List<dynamic> participants) {
    if (participants.isEmpty) return null;

    final currentUserId = AuthService().userProfile.value?["_id"]?.toString();
    final candidate = participants.firstWhere(
      (p) {
        if (p is Map<String, dynamic>) {
          final participantId = p["_id"]?.toString();
          return participantId != null && participantId != currentUserId;
        }
        return false;
      },
      orElse: () => participants.isNotEmpty ? participants.first : {},
    );

    if (candidate is Map<String, dynamic>) {
      return candidate;
    }
    return null;
  }

  String _resolveChatName(Map<String, dynamic> chat, List<dynamic> participants) {
    if (chat["isGroup"] == true) {
      return chat["name"] ?? "Nhóm";
    }
    final other = _findOtherParticipant(participants);
    if (other != null) {
      return other["fullName"] ?? other["name"] ?? "Chat";
    }
    return "Chat";
  }

  String _getInitials(Map<String, dynamic> chat, List<dynamic> participants) {
    if (chat["isGroup"] == true) {
      return chat["name"]?.substring(0, 2).toUpperCase() ?? "GR";
    }

    final otherParticipant = _findOtherParticipant(participants) ?? (participants.isNotEmpty ? participants.first as Map<String, dynamic> : null);
    if (otherParticipant != null) {
      final name = otherParticipant["fullName"] ?? otherParticipant["name"] ?? "";
      return name.length >= 2 ? name.substring(0, 2).toUpperCase() : name.toUpperCase();
    }
    return "CH";
  }

  String? _extractAvatarForChat(Map<String, dynamic> chat, List<dynamic> participants) {
    if (chat["groupAvatar"] != null) {
      final val = _resolveAvatarValue(chat["groupAvatar"]);
      if (val != null && val.isNotEmpty) return val;
    }
    if (chat["avatar"] != null) {
      final val = _resolveAvatarValue(chat["avatar"]);
      if (val != null && val.isNotEmpty) return val;
    }

    final otherParticipant = _findOtherParticipant(participants);
    if (otherParticipant != null) {
      return _resolveAvatarValue(otherParticipant["profilePicture"] ?? otherParticipant["avatar"]);
    }

    if (participants.isNotEmpty) {
      final firstParticipant = participants.first;
      if (firstParticipant is Map<String, dynamic>) {
        return _resolveAvatarValue(firstParticipant["profilePicture"] ?? firstParticipant["avatar"]);
      }
    }
    return null;
  }

  String _formatTime(String? dateString) {
    if (dateString == null) return "";
    try {
      final date = DateTime.parse(dateString).toLocal();
      final now = DateTime.now();
      final difference = now.difference(date);

      if (difference.inDays > 30) {
        final day = date.day.toString().padLeft(2, '0');
        final month = date.month.toString().padLeft(2, '0');
        final year = date.year.toString();
        final hour = date.hour.toString().padLeft(2, '0');
        final minute = date.minute.toString().padLeft(2, '0');
        return "$day/$month/$year $hour:$minute";
      } else if (difference.inDays >= 30) {
        return "1 tháng trước";
      } else if (difference.inDays > 0) {
        return "${difference.inDays} ngày trước";
      } else if (difference.inHours > 0) {
        return "${difference.inHours}h trước";
      } else if (difference.inMinutes > 0) {
        return "${difference.inMinutes} phút trước";
      } else {
        return "Vừa xong";
      }
    } catch (e) {
      return "";
    }
  }

  String? _resolveAvatarValue(dynamic avatar) {
    if (avatar == null) return null;
    if (avatar is Map<String, dynamic>) {
      return _resolveAvatarValue(avatar['url'] ?? avatar['path'] ?? avatar['value'] ?? avatar['id'] ?? avatar.toString());
    }
    if (avatar is List && avatar.isNotEmpty) {
      return _resolveAvatarValue(avatar.first);
    }
    final raw = avatar.toString().trim();
    if (raw.isEmpty) return null;
    return ApiService.resolveImageUrl(raw);
  }

  void _upsertGroup({int? id, required String name}) {
    setState(() {
      if (id != null) {
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
        final user = selectedUsers.first;
        final name = user["fullName"] ?? user["name"] ?? "Người dùng";
        final existingIndex = _chats.indexWhere(
          (c) =>
              (c["isGroup"] == false || c["isGroup"] == null) &&
              c["name"] == name,
        );

        if (existingIndex != -1) {
          _openChatDetailScreen(_chats[existingIndex]);
          return;
        }

        final newChat = {
          "id": DateTime.now().millisecondsSinceEpoch,
          "name": name,
          "status": user["position"] ?? user["role"] ?? "Nhân viên",
          "lastMsg": "Bắt đầu cuộc trò chuyện",
          "time":
              "${DateTime.now().hour}:${DateTime.now().minute.toString().padLeft(2, '0')}",
          "isOnline": true,
          "initials": name.substring(0, 2).toUpperCase(),
          "color": Colors.blue,
          "isGroup": false,
          "hasUnread": false,
          "messages": [],
          "avatarPath": user["profilePicture"] ?? user["avatar"],
        };
        _chats.insert(0, newChat);
        _openChatDetailScreen(newChat);
      } else {
        List<Map<String, String>> initialMembers = selectedUsers
            .map(
              (u) => {
                "name": (u["fullName"] ?? u["name"] ?? "Người dùng") as String,
                "role": ((u["position"] ?? u["role"] ?? "Nhân viên") as String)
                    .toUpperCase(),
                "isOwner": "false",
              },
            )
            .toList();

        initialMembers.insert(0, {
          "name": "Tôi",
          "role": "CHỦ NHÓM",
          "isOwner": "true",
        });

        final newGroup = {
          "id": DateTime.now().millisecondsSinceEpoch,
          "name": "Nhóm mới",
          "status": "${selectedUsers.length + 1} thành viên",
          "lastMsg": "Bạn đã tạo nhóm mới",
          "time":
              "${DateTime.now().hour}:${DateTime.now().minute.toString().padLeft(2, '0')}",
          "isOnline": false,
          "initials": "NM",
          "color": Colors.orange,
          "isGroup": true,
          "hasUnread": false,
          "messages": [],
          "members": initialMembers,
        };
        _chats.insert(0, newGroup);
        _openChatDetailScreen(newGroup);
      }
    });
  }

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
                    itemCount: _realUsers.length,
                    itemBuilder: (context, index) {
                      final user = _realUsers[index];
                      final name =
                          user["fullName"] ?? user["name"] ?? "Người dùng";
                      final isSelected = selectedUsers.contains(user);
                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: CircleAvatar(
                          backgroundColor: Colors.blueGrey.shade50,
                          backgroundImage:
                              (user["profilePicture"] != null ||
                                  user["avatar"] != null)
                              ? NetworkImage(
                                  ApiService.resolveImageUrl(
                                    user["profilePicture"] ?? user["avatar"],
                                  ),
                                )
                              : null,
                          child:
                              (user["profilePicture"] == null &&
                                  user["avatar"] == null)
                              ? Text(
                                  name.substring(0, 1),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                  ),
                                )
                              : null,
                        ),
                        title: Text(
                          name,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Text(
                          user["position"] ?? user["role"] ?? "Nhân viên",
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
            const Text(
              "Sửa thông tin",
              style: TextStyle(fontWeight: FontWeight.w900, fontSize: 20),
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
                  style: TextStyle(
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
          _Tabs(
            selectedIndex: _currentTab,
            onChanged: (index) => setState(() => _currentTab = index),
          ),
          const SizedBox(height: 24),
          Builder(
            builder: (context) {
              final filteredChats = _chats.where((c) {
                if (_currentTab == 1) return c["hasUnread"] == true;
                if (_currentTab == 2) return c["isGroup"] == true;
                return true;
              }).toList();

              if (filteredChats.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 40),
                  child: Center(
                    child: Column(
                      children: [
                        Icon(
                          Icons.question_answer_outlined,
                          color: Colors.grey.shade300,
                          size: 60,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          "Chưa có tin nhắn nào",
                          style: TextStyle(
                            color: Colors.grey.shade500,
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }

              return Column(
                children: filteredChats
                    .map(
                      (chat) => _ChatItem(
                        key: ValueKey(chat["id"]),
                        name: chat["name"],
                        status: chat["status"],
                        lastMsg: chat["lastMsg"],
                        time: chat["time"],
                        isOnline: chat["isOnline"],
                        initials: chat["initials"],
                        color: chat["color"],
                        hasUnread: chat["hasUnread"] ?? false,
                        onLongPress: () => _showChatOptions(chat),
                        onTap: () => _openChatDetailScreen(chat),
                        avatarPath: chat["avatarPath"],
                      ),
                    )
                    .toList(),
              );
            },
          ),
          const SizedBox(height: 100),
        ],
      ),
    );
  }

  Future<void> _openChatDetailScreen(Map<String, dynamic> chat) async {
    setState(() {
      final index = _chats.indexWhere((c) => c["id"] == chat["id"]);
      if (index != -1) _chats[index]["hasUnread"] = false;
    });

    if (!mounted) return;
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChatDetailScreen(
          name: chat["name"],
          isOnline: chat["isOnline"],
          initials: chat["initials"],
          color: chat["color"],
          isGroup: chat["isGroup"] ?? false,
          avatarPath: chat["avatarPath"],
          initialMessages: (chat["messages"] as List?)
              ?.cast<Map<String, dynamic>>(),
          initialMembers: (chat["participants"] as List?)
              ?.map((e) {
                if (e is Map<String, dynamic>) {
                  return <String, String>{
                    '_id': (e['_id'] ?? '').toString(),
                    'profilePicture': (e['profilePicture'] ?? '').toString(),
                    'avatar': (e['avatar'] ?? '').toString(),
                    'fullName': (e['fullName'] ?? '').toString(),
                    'name': (e['name'] ?? e['fullName'] ?? '').toString(),
                    'role': (e['role'] ?? '').toString(),
                    'isOwner': (e['isOwner'] ?? 'false').toString(),
                  };
                }
                return <String, String>{};
              })
              .where((m) => m.isNotEmpty)
              .toList()
              .cast<Map<String, String>>(),
          conversationId: chat["id"]?.toString(),
        ),
      ),
    );

    if (result != null && result is Map<String, dynamic>) {
      if (result["action"] == 'leave' || result["action"] == 'disband') {
        setState(() {
          _chats.removeWhere((c) => c["id"] == chat["id"]);
        });
        return;
      }
      setState(() {
        final index = _chats.indexWhere((c) => c["id"] == chat["id"]);
        if (index != -1) {
          _chats[index]["lastMsg"] = result["lastMsg"];
          _chats[index]["time"] = result["time"];
          if (result["name"] != null) _chats[index]["name"] = result["name"];
          if (result["color"] != null) _chats[index]["color"] = result["color"];
          if (result["initials"] != null) _chats[index]["initials"] = result["initials"];
          if (result["messages"] != null) _chats[index]["messages"] = result["messages"];
          if (result["members"] != null) _chats[index]["members"] = result["members"];
          if (result["avatarPath"] != null) _chats[index]["avatarPath"] = result["avatarPath"];
          if (result["conversationId"] != null && result["conversationId"] != chat["id"]) {
            _chats[index]["id"] = result["conversationId"];
          }
        }
      });
    }
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
  final int selectedIndex;
  final ValueChanged<int> onChanged;
  const _Tabs({required this.selectedIndex, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: Colors.grey.withOpacity(0.1))),
      ),
      child: Row(
        children: [
          _TabItem(
            label: "TẤT CẢ",
            isActive: selectedIndex == 0,
            onTap: () => onChanged(0),
          ),
          const SizedBox(width: 24),
          _TabItem(
            label: "CHƯA ĐỌC",
            isActive: selectedIndex == 1,
            onTap: () => onChanged(1),
          ),
          const SizedBox(width: 24),
          _TabItem(
            label: "NHÓM",
            isActive: selectedIndex == 2,
            onTap: () => onChanged(2),
          ),
        ],
      ),
    );
  }
}

class _TabItem extends StatelessWidget {
  final String label;
  final bool isActive;
  final VoidCallback onTap;
  const _TabItem({
    required this.label,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Text(
            label,
            style: TextStyle(
              fontWeight: FontWeight.w900,
              fontSize: 13,
              color: isActive ? const Color(0xFF3B82F6) : Colors.grey.shade400,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 8),
          if (isActive)
            Container(
              width: 40,
              height: 3,
              decoration: BoxDecoration(
                color: const Color(0xFF3B82F6),
                borderRadius: BorderRadius.circular(2),
              ),
            )
          else
            const SizedBox(height: 9),
        ],
      ),
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
  final String? avatarPath;
  final Color? color;
  final bool hasUnread;
  final VoidCallback onLongPress;
  final VoidCallback onTap;

  const _ChatItem({
    super.key,
    required this.name,
    required this.status,
    required this.lastMsg,
    required this.time,
    required this.isOnline,
    this.initials,
    this.avatarPath,
    this.color,
    required this.hasUnread,
    required this.onLongPress,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final String? avatarSource = avatarPath?.trim();

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          onLongPress: onLongPress,
          borderRadius: BorderRadius.circular(20),
          splashColor: color?.withOpacity(0.1) ?? Colors.blue.withOpacity(0.1),
          highlightColor: color?.withOpacity(0.05) ?? Colors.blue.withOpacity(0.05),
          child: Ink(
            decoration: BoxDecoration(
              color: hasUnread ? const Color(0xFFF1F5F9) : Colors.white,
              borderRadius: BorderRadius.circular(20),
            ),
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
            child: Row(
              children: [
                Stack(
                  alignment: Alignment.bottomRight,
                  children: [
                    Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        color: color?.withOpacity(0.12) ?? Colors.blueGrey.shade50,
                        shape: BoxShape.circle,
                      ),
                      child: ClipOval(
                        child: avatarSource != null && avatarSource.isNotEmpty
                            ? Image.network(
                                avatarSource,
                                key: ValueKey(avatarSource),
                                headers: AuthService().authToken.value != null ? {'Authorization': 'Bearer ${AuthService().authToken.value}'} : null,
                                fit: BoxFit.cover,
                                height: double.infinity,
                                width: double.infinity,
                                errorBuilder: (context, error, stackTrace) {
                                  // debugPrint("Avatar Load Error [$name] - URL: $avatarSource => Error: $error");
                                  return Center(
                                    child: initials != null
                                        ? Text(
                                            initials!.toUpperCase(),
                                            style: TextStyle(
                                              color: color ?? Colors.blueGrey,
                                              fontWeight: FontWeight.bold,
                                              fontSize: 18,
                                            ),
                                          )
                                        : const Icon(
                                            Icons.person,
                                            color: Colors.blueGrey,
                                            size: 26,
                                          ),
                                  );
                                },
                              )
                            : Center(
                                child: initials != null
                                    ? Text(
                                        initials!.toUpperCase(),
                                        style: TextStyle(
                                          color: color ?? Colors.blueGrey,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 18,
                                        ),
                                      )
                                    : const Icon(
                                        Icons.person,
                                        color: Colors.blueGrey,
                                        size: 26,
                                      ),
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
                          Expanded(
                            child: Text(
                              name.toUpperCase(),
                              style: TextStyle(
                                fontWeight: hasUnread ? FontWeight.bold : FontWeight.w600,
                                fontSize: 13,
                                color: const Color(0xFF0F172A),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Text(
                            time,
                            style: TextStyle(
                              color: hasUnread ? const Color(0xFF2563EB) : Colors.grey.shade500,
                              fontSize: 11,
                              fontWeight: hasUnread ? FontWeight.bold : FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          if (isOnline)
                            Container(
                              width: 8,
                              height: 8,
                              decoration: const BoxDecoration(
                                color: Color(0xFF22C55E),
                                shape: BoxShape.circle,
                              ),
                            ),
                          if (isOnline) const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              status,
                              style: TextStyle(
                                color: isOnline ? const Color(0xFF16A34A) : Colors.grey.shade500,
                                fontWeight: FontWeight.w700,
                                fontSize: 11,
                                letterSpacing: 0.5,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        lastMsg,
                        style: TextStyle(
                          color: Colors.blueGrey.shade700,
                          fontSize: 13,
                          fontWeight: hasUnread ? FontWeight.w600 : FontWeight.w400,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
