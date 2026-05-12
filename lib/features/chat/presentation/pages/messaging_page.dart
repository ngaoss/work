import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'chat_detail_screen.dart';
import '../../../../core/api_service.dart';
import '../../../../core/security.dart';
import '../../../../core/utils/notification_helper.dart';

class MessagingPage extends StatefulWidget {
  final VoidCallback? onBack;
  final String? initialChatId;
  const MessagingPage({super.key, this.onBack, this.initialChatId});

  @override
  State<MessagingPage> createState() => _MessagingPageState();
}

class _MessagingPageState extends State<MessagingPage> {
  final List<Map<String, dynamic>> _chats = [];
  final Set<String> _mutedChatIds = {};
  int _currentTab = 0;

  List<dynamic> _realUsers = [];
  StreamSubscription? _chatSubscription;

  @override
  void initState() {
    super.initState();
    _initializeData().then((_) {
      if (widget.initialChatId != null) {
        _openChatById(widget.initialChatId!);
      }
    });
    _chatSubscription = ApiService.newChatStream.listen(_handleNewMessage);
  }

  void _openChatById(String id) {
    final chat = _chats.firstWhere(
      (c) => c["id"]?.toString() == id,
      orElse: () => {},
    );
    if (chat.isNotEmpty) {
      _openChatDetailScreen(chat);
    }
  }

  Future<void> _initializeData() async {
    await _fetchUsers();
    await _fetchMutedChats();
  }

  Future<void> _fetchMutedChats() async {
    final prefs = await SharedPreferences.getInstance();
    final mutedList = prefs.getStringList('muted_chats') ?? [];
    if (mounted) {
      setState(() {
        _mutedChatIds.clear();
        _mutedChatIds.addAll(mutedList);
      });
      _fetchChats(); // Refresh to show icons
    }
  }

  void _handleNewMessage(Map<String, dynamic> data) {
    if (!mounted) return;

    // Skip typing indicators for chat preview updates
    if (data['type'] == 'typing') return;

    // Handle new or updated conversation events
    if (data['isNewConversation'] == true ||
        data['isUpdateConversation'] == true ||
        data['socketEventType'] == 'chat_updated') {
      _fetchChats();
      return;
    }

    final dynamic rawChatId =
        data["chatId"] ??
        data["chat"]?["_id"] ??
        data["chat"] ??
        data["conversationId"];
    final String? chatId = rawChatId?.toString();
    if (chatId == null) return;

    setState(() {
      final index = _chats.indexWhere((c) => c["id"]?.toString() == chatId);
      if (index != -1) {
        // Prepend sender name
        final dynamic senderObj = data["sender"] ?? data["message"]?["sender"];
        final senderId =
            (senderObj is Map
                ? (senderObj["_id"] ?? senderObj["id"])
                : senderObj) ??
            data["senderId"] ??
            data["message"]?["senderId"];

        final myId =
            (AuthService().userProfile.value?["_id"] ??
                    AuthService().userProfile.value?["id"])
                ?.toString();

        final String? senderName = senderObj is Map
            ? (senderObj["fullName"] ?? senderObj["name"])?.toString()
            : null;

        // Update existing chat with smart preview
        final String text =
            data["text"]?.toString() ??
            data["content"]?.toString() ??
            data["message"]?["text"]?.toString() ??
            data["message"]?["content"]?.toString() ??
            "";

        final dynamic media = data["media"] ?? data["message"]?["media"];
        String preview;
        if (text.isNotEmpty) {
          preview = text;
        } else if (media is List && media.isNotEmpty) {
          final firstMedia = media[0];
          final type =
              (firstMedia is Map ? (firstMedia['type'] ?? 'image') : 'image')
                  .toString()
                  .toLowerCase();
          preview = type == 'video' ? '📹 Đã gửi 1 video' : '📸 Đã gửi 1 ảnh';
        } else {
          preview = '📎 Đã gửi 1 tệp đính kèm';
        }

        if (senderId?.toString() == myId) {
          preview = "Bạn: $preview";
        } else if (senderName != null && _chats[index]["isGroup"] == true) {
          preview = "$senderName: $preview";
        }

        _chats[index]["lastMsg"] = preview;
        _chats[index]["time"] = "Vừa xong";

        if (senderId?.toString() != myId) {
          _chats[index]["hasUnread"] = true;
          _chats[index]["unreadCount"] =
              (_chats[index]["unreadCount"] ?? 0) + 1;
          ApiService.unreadChatCount.value++;
        }

        // Move to top
        final item = _chats.removeAt(index);
        _chats.insert(0, item);
      } else {
        // It's a message for a chat not in the current list, refresh the whole list
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
    final myId =
        (AuthService().userProfile.value?["_id"] ??
                AuthService().userProfile.value?["id"])
            ?.toString();

    if (mounted) {
      setState(() {
        _realUsers = users.where((u) {
          final uId = (u["_id"] ?? u["id"])?.toString();
          return uId != null && uId != myId;
        }).toList();
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

          bool online = false;
          if (chat["isGroup"] == true) {
            online = participants.any((participant) {
              if (participant.containsKey('isOnline')) {
                return participant["isOnline"] == true;
              }
              final status = participant["status"]?.toString().toLowerCase();
              return status == "online";
            });
          } else {
            // For 1:1 chats, status depends on the OTHER person
            final other = _findOtherParticipant(participants);
            if (other != null) {
              if (other.containsKey('isOnline')) {
                online = other["isOnline"] == true;
              } else {
                final status = other["status"]?.toString().toLowerCase();
                online = status == "online";
              }
            }
          }

          final String name =
              chat["name"] ?? _resolveChatName(chat, participants);
          final String statusText = chat["isGroup"] == true
              ? (online
                    ? "ĐANG HOẠT ĐỘNG"
                    : "${participants.length} thành viên")
              : (online ? "ĐANG HOẠT ĐỘNG" : "NGOẠI TUYẾN");
          final String? avatarPath = _extractAvatarForChat(chat, participants);
          // debugPrint("Extracted Avatar for [${chat['name'] ?? chat['_id']}]: $avatarPath");

          final String colorHex = (chat["themeColor"] ?? "#2563eb")
              .toString()
              .replaceFirst('#', '');
          Color displayColor = const Color(0xFF3B82F6);
          if (colorHex.length == 6) {
            try {
              displayColor = Color(int.parse('FF$colorHex', radix: 16));
            } catch (e) {
              debugPrint("Error parsing themeColor: $e");
            }
          }

          _chats.add({
            "id": chat["_id"]?.toString(),
            "name": name,
            "status": statusText,
            "lastMsg": _resolveLastMsgPreview(
              chat["lastMessage"],
              isGroup: chat["isGroup"] == true,
            ),
            "time": _formatTime(chat["lastMessage"]?["createdAt"]),
            "isOnline": online,
            "initials": _getInitials(chat, participants),
            "color": displayColor,
            "isGroup": chat["isGroup"] ?? false,
            "hasUnread": (chat["unreadCount"] ?? 0) > 0,
            "unreadCount": chat["unreadCount"] ?? 0,
            "messages": [],
            "participants": participants,
            "avatarPath": avatarPath,
            "themeColor": chat["themeColor"] ?? "#2563eb",
            "createdBy": chat["createdBy"],
            "isMuted": _mutedChatIds.contains(chat["_id"]?.toString() ?? ""),
          });
        }

        int totalUnread = 0;
        for (var c in _chats) {
          totalUnread += (c["unreadCount"] as num? ?? 0).toInt();
        }
        ApiService.unreadChatCount.value = totalUnread;
      });
    }
  }

  /// Returns a human-friendly preview string for the last message in a chat.
  String _resolveLastMsgPreview(dynamic lastMessage, {bool isGroup = false}) {
    if (lastMessage == null) return 'Bắt đầu trò chuyện...';

    String previewText = "";
    final String text = lastMessage['text']?.toString() ?? '';
    final media = lastMessage['media'];
    final attachments = lastMessage['attachments'];

    if (text.isNotEmpty) {
      previewText = text;
    } else if (media is List && media.isNotEmpty) {
      final type = (media[0]['type'] ?? 'image').toString().toLowerCase();
      previewText = type == 'video' ? '📹 Đã gửi 1 video' : '📸 Đã gửi 1 ảnh';
    } else if (attachments is List && attachments.isNotEmpty) {
      previewText = '📎 Đã gửi 1 tệp đính kèm';
    } else {
      return 'Bắt đầu trò chuyện...';
    }

    // Prepend sender name or "Bạn: "
    final myId =
        (AuthService().userProfile.value?["_id"] ??
                AuthService().userProfile.value?["id"])
            ?.toString();
    final sender = lastMessage['sender'];
    final senderId = (sender is Map ? (sender["_id"] ?? sender["id"]) : sender)
        ?.toString();

    if (senderId == myId && myId != null) {
      return "Bạn: $previewText";
    }

    if (isGroup && sender is Map) {
      final senderName = (sender["fullName"] ?? sender["name"])?.toString();
      if (senderName != null) {
        return "$senderName: $previewText";
      }
    }

    return previewText;
  }

  Map<String, dynamic>? _findOtherParticipant(List<dynamic> participants) {
    if (participants.isEmpty) return null;

    final currentUserId = AuthService().userProfile.value?["_id"]?.toString();
    final candidate = participants.firstWhere((p) {
      if (p is Map<String, dynamic>) {
        final participantId = p["_id"]?.toString();
        return participantId != null && participantId != currentUserId;
      }
      return false;
    }, orElse: () => participants.isNotEmpty ? participants.first : {});

    if (candidate is Map<String, dynamic>) {
      return candidate;
    }
    return null;
  }

  String _resolveChatName(
    Map<String, dynamic> chat,
    List<dynamic> participants,
  ) {
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
      final name = (chat["name"] ?? chat["topic"] ?? "Group").toString();
      return name.length >= 2
          ? name.substring(0, 2).toUpperCase()
          : name.toUpperCase();
    }

    final otherParticipant =
        _findOtherParticipant(participants) ??
        (participants.isNotEmpty
            ? participants.first as Map<String, dynamic>
            : null);
    if (otherParticipant != null) {
      final name =
          otherParticipant["fullName"] ?? otherParticipant["name"] ?? "";
      return name.length >= 2
          ? name.substring(0, 2).toUpperCase()
          : name.toUpperCase();
    }
    return "CH";
  }

  String? _extractAvatarForChat(
    Map<String, dynamic> chat,
    List<dynamic> participants,
  ) {
    // If it's a group, only use group-level avatars. Do NOT fall back to participants.
    if (chat["isGroup"] == true) {
      if (chat["groupAvatar"] != null) {
        final val = _resolveAvatarValue(chat["groupAvatar"]);
        if (val != null && val.isNotEmpty) return val;
      }
      if (chat["avatar"] != null) {
        final val = _resolveAvatarValue(chat["avatar"]);
        if (val != null && val.isNotEmpty) return val;
      }
      return null;
    }

    final otherParticipant = _findOtherParticipant(participants);
    if (otherParticipant != null) {
      return _resolveAvatarValue(
        otherParticipant["profilePicture"] ?? otherParticipant["avatar"],
      );
    }

    if (participants.isNotEmpty) {
      final firstParticipant = participants.first;
      if (firstParticipant is Map<String, dynamic>) {
        return _resolveAvatarValue(
          firstParticipant["profilePicture"] ?? firstParticipant["avatar"],
        );
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
      return _resolveAvatarValue(
        avatar['url'] ??
            avatar['path'] ??
            avatar['value'] ??
            avatar['id'] ??
            avatar.toString(),
      );
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

  Future<void> _createChat(List<Map<String, dynamic>> selectedUsers) async {
    if (selectedUsers.isEmpty) return;

    // Show loading? or just do it.
    final myProfile = AuthService().userProfile.value;
    final List<String> userIds = selectedUsers
        .map((u) => (u["_id"] ?? u["id"]).toString())
        .toList();

    Map<String, dynamic>? result;
    if (selectedUsers.length == 1) {
      final user = selectedUsers.first;
      final name = user["fullName"] ?? user["name"] ?? "Người dùng";

      // Check if already exists in local list
      final existingIndex = _chats.indexWhere(
        (c) =>
            (c["isGroup"] == false || c["isGroup"] == null) &&
            c["name"] == name,
      );

      if (existingIndex != -1 &&
          ApiService.isObjectId(_chats[existingIndex]["id"])) {
        _openChatDetailScreen(_chats[existingIndex]);
        return;
      }

      // Try creating on server
      result = await ApiService.createChat([userIds.first]);
    } else {
      // Group
      result = await ApiService.createChat(userIds, isGroup: true);
    }

    if (result != null) {
      // Backend returned chat object
      final String realId =
          (result["_id"] ?? result["id"] ?? result["data"]?["_id"] ?? "")
              .toString();

      if (ApiService.isObjectId(realId)) {
        final participants = result["participants"] ?? result["users"] ?? [];
        final isGroup = result["isGroup"] == true;
        final chatName = isGroup
            ? (result["name"] ?? "Nhóm mới")
            : (selectedUsers.first["fullName"] ??
                  selectedUsers.first["name"] ??
                  "Chat");

        final newChat = {
          "id": realId,
          "name": chatName,
          "status": isGroup
              ? "${(participants as List).length} thành viên"
              : (selectedUsers.first["position"] ?? "Nhân viên"),
          "lastMsg": "Bắt đầu cuộc trò chuyện",
          "time":
              "${DateTime.now().hour}:${DateTime.now().minute.toString().padLeft(2, '0')}",
          "isOnline": !isGroup,
          "initials": chatName
              .substring(0, math.min(2, chatName.length))
              .toUpperCase(),
          "color": isGroup ? Colors.orange : Colors.blue,
          "isGroup": isGroup,
          "hasUnread": false,
          "messages": result["messages"] ?? [],
          "participants": participants,
          "avatarPath": isGroup
              ? result["avatar"]
              : (selectedUsers.first["profilePicture"] ??
                    selectedUsers.first["avatar"]),
        };

        setState(() {
          _chats.insert(0, newChat);
        });
        _openChatDetailScreen(newChat);
      } else {
        debugPrint("Error: Created chat has no valid ObjectId: $result");
        _showError("Không thể tạo ID hội thoại hợp lệ.");
      }
    }
  }

  void _showError(String msg) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    }
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
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              margin: const EdgeInsets.only(top: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            ListTile(
              leading: Icon(
                chat["isMuted"] == true
                    ? Icons.notifications_active_outlined
                    : Icons.notifications_off_outlined,
                color: Colors.black87,
              ),
              title: Text(
                chat["isMuted"] == true ? 'Bật thông báo' : 'Tắt thông báo',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              onTap: () async {
                await _toggleMute(chat);
                Navigator.pop(context);
              },
            ),
            if (chat["isGroup"] == true)
              ListTile(
                leading: const Icon(Icons.edit_outlined, color: Colors.blue),
                title: const Text(
                  "Sửa thông tin nhóm",
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                onTap: () {
                  Navigator.pop(context);
                  _showGroupSheet(existingChat: chat);
                },
              ),
            ListTile(
              leading: const Icon(Icons.delete_outline, color: Colors.red),
              title: Text(
                chat["isGroup"] == true ? "Xóa nhóm" : "Xóa hội thoại",
                style: const TextStyle(
                  color: Colors.red,
                  fontWeight: FontWeight.w600,
                ),
              ),
              onTap: () {
                Navigator.pop(context);
                _deleteGroup(chat["id"]);
              },
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: RefreshIndicator(
        onRefresh: () async {
          await _fetchChats();
          await _fetchUsers();
        },
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    if (widget.onBack != null)
                      Padding(
                        padding: const EdgeInsets.only(right: 16),
                        child: GestureDetector(
                          onTap: widget.onBack,
                          child: const Icon(
                            Icons.arrow_back_ios_new,
                            size: 24,
                            color: Colors.black87,
                          ),
                        ),
                      ),
                    const Text(
                      "TIN NHẮN",
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 32,
                        letterSpacing: -1,
                      ),
                    ),
                  ],
                ),
                GestureDetector(
                  onTap: () => _showUserSelectionSheet(),
                  child: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: const Color(0xFFEFF6FF),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.add,
                      color: Color(0xFF3B82F6),
                      size: 22,
                    ),
                  ),
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
            const SizedBox(height: 16),
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
                          chat: chat,
                          onNavigate: (c) => _openChatDetailScreen(c),
                          onLongPress: () => _showChatOptions(chat),
                        ),
                      )
                      .toList(),
                );
              },
            ),
            const SizedBox(height: 100),
          ],
        ),
      ),
    );
  }

  Future<void> _toggleMute(Map<String, dynamic> chat) async {
    final chatId = chat["id"]?.toString();
    if (chatId == null) return;

    final isCurrentlyMuted = chat["isMuted"] ?? false;
    final newMutedStatus = !isCurrentlyMuted;

    await NotificationHelper.setMuted(chatId, newMutedStatus);

    if (mounted) {
      setState(() {
        if (newMutedStatus) {
          _mutedChatIds.add(chatId);
        } else {
          _mutedChatIds.remove(chatId);
        }
        chat["isMuted"] = newMutedStatus;
      });

      // ScaffoldMessenger.of(context).showSnackBar(
      //   SnackBar(
      //     content: Text(
      //       // newMutedStatus ? "Đã tắt thông báo" : "Đã bật thông báo",
      //     ),
      //     duration: const Duration(seconds: 1),
      //   ),
      // );
    }
  }

  Future<void> _openChatDetailScreen(Map<String, dynamic> chat) async {
    setState(() {
      final index = _chats.indexWhere((c) => c["id"] == chat["id"]);
      if (index != -1) {
        final count = (chat["unreadCount"] as num? ?? 0).toInt();
        _chats[index]["hasUnread"] = false;
        _chats[index]["unreadCount"] = 0;
        if (count > 0) {
          ApiService.unreadChatCount.value =
              (ApiService.unreadChatCount.value - count).clamp(0, 9999);
        }
      }
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
          createdBy: chat["createdBy"] is Map
              ? chat["createdBy"]["_id"]?.toString()
              : chat["createdBy"]?.toString(),
          isMuted: chat["isMuted"] ?? false,
          onMuteToggle: (muted) async {
            final chatId = chat["id"]?.toString();
            if (chatId != null) {
              await NotificationHelper.setMuted(chatId, muted);
              if (mounted) {
                setState(() {
                  if (muted)
                    _mutedChatIds.add(chatId);
                  else
                    _mutedChatIds.remove(chatId);
                  final index = _chats.indexWhere((c) => c["id"] == chat["id"]);
                  if (index != -1) _chats[index]["isMuted"] = muted;
                });
              }
            }
          },
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

      final index = _chats.indexWhere((c) => c["id"] == chat["id"]);
      if (index != -1) {
        setState(() {
          _chats[index]["lastMsg"] =
              result["lastMsg"] ?? _chats[index]["lastMsg"];
          _chats[index]["time"] = result["time"] ?? _chats[index]["time"];

          if (result["isMuted"] != null) {
            final muted = result["isMuted"] as bool;
            final chatId = _chats[index]["id"]?.toString();
            if (chatId != null) {
              if (muted)
                _mutedChatIds.add(chatId);
              else
                _mutedChatIds.remove(chatId);
            }
            _chats[index]["isMuted"] = muted;
          }

          if (result["name"] != null) _chats[index]["name"] = result["name"];
          if (result["color"] != null) _chats[index]["color"] = result["color"];
          if (result["initials"] != null)
            _chats[index]["initials"] = result["initials"];
          if (result["messages"] != null)
            _chats[index]["messages"] = result["messages"];
          if (result["members"] != null)
            _chats[index]["members"] = result["members"];
          if (result["avatarPath"] != null)
            _chats[index]["avatarPath"] = result["avatarPath"];

          if (result["conversationId"] != null &&
              result["conversationId"] != chat["id"]) {
            _chats[index]["id"] = result["conversationId"];
          }
        });
      }
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
      child: Row(
        children: [
          const Icon(Icons.search, size: 18, color: Colors.grey),
          const SizedBox(width: 12),
          Text(
            "Tìm cuộc trò chuyện...",
            style: TextStyle(color: Colors.grey.shade400, fontSize: 13),
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
  final Map<String, dynamic> chat;
  final Function(Map<String, dynamic>) onNavigate;
  final VoidCallback? onLongPress;

  const _ChatItem({
    super.key,
    required this.chat,
    required this.onNavigate,
    this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final String name = chat["name"] ?? "";
    final String status = chat["status"] ?? "";
    final String lastMsg = chat["lastMsg"] ?? "";
    final String time = chat["time"] ?? "";
    final bool isOnline = chat["isOnline"] ?? false;
    final String? initials = chat["initials"];
    final String? avatarPath = chat["avatarPath"];
    final Color? color = chat["color"];
    final bool hasUnread = chat["hasUnread"] ?? false;
    final int unreadCount = chat["unreadCount"] ?? 0;
    final String? avatarSource = avatarPath?.trim();

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => onNavigate(chat),
          onLongPress: onLongPress,
          borderRadius: BorderRadius.circular(20),
          splashColor: color?.withOpacity(0.1) ?? Colors.blue.withOpacity(0.1),
          highlightColor:
              color?.withOpacity(0.05) ?? Colors.blue.withOpacity(0.05),
          child: Ink(
            decoration: BoxDecoration(
              color: hasUnread ? const Color(0xFFF1F5F9) : Colors.white,
              borderRadius: BorderRadius.circular(20),
            ),
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
            child: Row(
              children: [
                Stack(
                  alignment: Alignment.bottomRight,
                  children: [
                    Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        color:
                            color?.withOpacity(0.12) ?? Colors.blueGrey.shade50,
                        shape: BoxShape.circle,
                      ),
                      child: ClipOval(
                        child: avatarSource != null && avatarSource.isNotEmpty
                            ? Image.network(
                                avatarSource,
                                key: ValueKey(avatarSource),
                                headers: AuthService().authToken.value != null
                                    ? {
                                        'Authorization':
                                            'Bearer ${AuthService().authToken.value}',
                                      }
                                    : null,
                                fit: BoxFit.cover,
                                height: double.infinity,
                                width: double.infinity,
                                errorBuilder: (context, error, stackTrace) {
                                  return Center(
                                    child: initials != null
                                        ? Text(
                                            initials.toUpperCase(),
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
                                        initials.toUpperCase(),
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
                      Positioned(
                        right: 2,
                        bottom: 2,
                        child: Container(
                          width: 14,
                          height: 14,
                          decoration: BoxDecoration(
                            color: const Color(0xFF22C55E),
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 2.5),
                          ),
                        ),
                      ),
                    if (hasUnread && unreadCount > 0)
                      Positioned(
                        right: -2,
                        top: -2,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: const Color(0xFFEF4444),
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 2),
                          ),
                          constraints: const BoxConstraints(
                            minWidth: 20,
                            minHeight: 20,
                          ),
                          child: Center(
                            child: Text(
                              unreadCount > 99 ? "99+" : unreadCount.toString(),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
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
                                fontWeight: hasUnread
                                    ? FontWeight.bold
                                    : FontWeight.w600,
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
                              color: hasUnread
                                  ? const Color(0xFF2563EB)
                                  : Colors.grey.shade500,
                              fontSize: 11,
                              fontWeight: hasUnread
                                  ? FontWeight.bold
                                  : FontWeight.w500,
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
                                color: isOnline
                                    ? const Color(0xFF16A34A)
                                    : Colors.grey.shade500,
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
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              lastMsg,
                              style: TextStyle(
                                color: hasUnread
                                    ? Colors.black87
                                    : Colors.blueGrey.shade600,
                                fontSize: 13,
                                fontWeight: hasUnread
                                    ? FontWeight.w700
                                    : FontWeight.w400,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (chat["isMuted"] == true)
                            Padding(
                              padding: const EdgeInsets.only(left: 8),
                              child: Icon(
                                Icons.notifications_off_rounded,
                                size: 16,
                                color: Colors.grey.shade700,
                              ),
                            ),
                        ],
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
