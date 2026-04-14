import 'dart:io';
import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import '../../../../core/widgets/full_screen_media_viewer.dart';
import '../../../../core/widgets/video_preview.dart';
import '../../../../core/api_service.dart';
import '../../../../core/security.dart';
import '../widgets/chat_settings_sheet.dart';

class ChatDetailScreen extends StatefulWidget {
  final String name;
  final bool isOnline;
  final String? initials;
  final Color? color;
  final bool isGroup;
  final String? avatarPath;
  final List<Map<String, dynamic>>? initialMessages;
  final List<Map<String, String>>? initialMembers;
  final String? conversationId;

  const ChatDetailScreen({
    super.key,
    required this.name,
    required this.isOnline,
    this.initials,
    this.color,
    this.isGroup = false,
    this.avatarPath,
    this.initialMessages,
    this.initialMembers,
    this.conversationId,
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
  late List<Map<String, String>> _members;

  late String _currentName;
  late String? _currentInitials;
  late Color? _currentColor;
  String? _currentAvatarPath; // Added _currentAvatarPath state

  int? _editingMessageId;

  // Pagination states
  int _currentPage = 1;
  bool _isLoadingMore = false;
  bool _hasMoreMessages = true;

  StreamSubscription? _chatSubscription;
  Timer? _pollingTimer;
  String? _activeConversationId;

  @override
  void initState() {
    super.initState();
    _currentName = widget.name;
    _currentInitials = widget.initials;
    _currentColor = widget.color;
    _currentAvatarPath = widget.avatarPath;
    _messages = List.from(widget.initialMessages ?? []);
    _members = List.from(widget.initialMembers ?? []);
    _focusNode.addListener(() {
      if (_focusNode.hasFocus) {
        setState(() => _showEmoji = false);
      }
    });
    _activeConversationId = widget.conversationId;
    if (_activeConversationId != null) {
      _loadMessages();
      ApiService.markChatAsRead(_activeConversationId!);
    }
    _chatSubscription = ApiService.newChatStream.listen(_handleNewChatEvent);
    
    // Start 10-second polling fallback
    _startPolling();
  }

  void _startPolling() {
    _pollingTimer?.cancel();
    _pollingTimer = Timer.periodic(const Duration(seconds: 10), (timer) {
      if (_activeConversationId != null) {
        _loadMessages(isPolling: true);
      }
    });
  }

  void _handleNewChatEvent(Map<String, dynamic> msgData) {
    if (!mounted) return;
    
    // Check if message belongs to this conversation
    final rawChatId = msgData['chat'] ?? msgData['chatId'];
    String? chatId = (rawChatId is Map) ? rawChatId['_id']?.toString() : rawChatId?.toString();
    
    // Safety: If we are in a "temporary" chat (numeric ID), 
    // and we receive a message from a chat with our participation, 
    // we should accept it and potentially update our ID.
    bool idMatch = chatId == _activeConversationId;
    if (!idMatch && _activeConversationId != null && _activeConversationId!.length > 10) {
      // Temporary IDs are usually long timestamps (milliseconds). String length > 10.
      // We accept the update if the message has a valid chatId and it's our first real message
      if (chatId != null && _messages.where((m) => m["isSystem"] != true).length < 5) {
         idMatch = true;
         // Update active ID so future polls/fetches use the real one
         setState(() {
           _activeConversationId = chatId;
         });
      }
    }
    
    if (!idMatch && chatId != null) return;

    final senderId = msgData['sender']?['_id'] ?? msgData['senderId'] ?? msgData['sender'];
    final senderName = msgData['sender']?['fullName'] ?? msgData['sender']?['name'] ?? "Unknown";
    final avatarRaw = msgData['sender']?['profilePicture'] ?? msgData['sender']?['avatar'];
    final bool isSender = senderId?.toString() == (AuthService().userProfile.value?['_id'] ?? AuthService().userProfile.value?['id'])?.toString() || 
                        msgData['isSender'] == true;
    
    final newMessage = {
      "id": (msgData["_id"] ?? msgData["id"] ?? DateTime.now().millisecondsSinceEpoch).toString(),
      "text": msgData["text"] ?? msgData["content"] ?? "",
      "isSender": isSender,
      "imagePath": (msgData["media"] is List && (msgData["media"] as List).isNotEmpty)
          ? ApiService.resolveImageUrl(msgData["media"][0]["url"] ?? msgData["media"][0]["path"])
          : (msgData["attachments"] is List && (msgData["attachments"] as List).isNotEmpty)
              ? ApiService.resolveImageUrl(msgData["attachments"][0]["url"] ?? msgData["attachments"][0]["path"])
              : null,
      "fileName": (msgData["attachments"] is List && (msgData["attachments"] as List).isNotEmpty)
          ? msgData["attachments"][0]["name"]
          : (msgData["media"] is List && (msgData["media"] as List).isNotEmpty)
              ? msgData["media"][0]["name"]
              : null,
      "fileSize": (msgData["attachments"] is List && msgData["attachments"].isNotEmpty)
          ? _formatFileSize(msgData["attachments"][0]["size"])
          : null,
      "senderName": senderName,
      "senderInitials": senderName.isNotEmpty ? senderName[0].toUpperCase() : "?",
      "senderAvatarPath": ApiService.resolveImageUrl(avatarRaw),
      "time": _formatMessageTime(msgData["createdAt"] ?? msgData["timestamp"]),
      "isSystem": msgData["type"] == "system" || msgData["isSystem"] == true,
    };

    setState(() {
      // Check if this message from server is a confirmation of our optimistic message
      bool replaced = false;
      if (newMessage["isSender"] == true) {
        final optIndex = _messages.indexWhere((m) => 
          m["isSender"] == true && 
          m["text"] == newMessage["text"] &&
          m["id"].toString().length > 10 // tempId is long timestamp string
        );
        if (optIndex != -1) {
          _messages[optIndex] = newMessage;
          replaced = true;
        }
      }

      // If not replaced and not a duplicate by ID, add it
      if (!replaced && !_messages.any((m) => m["id"] == newMessage["id"])) {
        // Ignore empty messages that might be system events
        if ((newMessage["text"] as String).trim().isNotEmpty || 
            newMessage["mediaUrl"] != null || 
            newMessage["isSystem"] == true) {
          _messages.add(newMessage);
        }
      }
    });

    if (_activeConversationId != null) {
      ApiService.markChatAsRead(_activeConversationId!);
    }
  }

  Future<void> _loadMessages({bool isPolling = false}) async {
    if (_activeConversationId == null) return;
    
    // For polling, we don't show loading indicator and only fetch the latest page
    if (!isPolling) {
      if (_isLoadingMore) return;
      setState(() => _isLoadingMore = true);
    }

    try {
      final res = await ApiService.getMessages(
        _activeConversationId!,
        page: isPolling ? 1 : _currentPage,
        limit: 20,
      );
      
      // Mark as read after loading messages
      ApiService.markChatAsRead(_activeConversationId!);
      // debugPrint("DEBUG: ChatDetailScreen API Response: $res");

      // Robustly extract message list from various potential response formats
      final dynamic responseData = res;
      List<dynamic> rawMessages = [];
      if (responseData is Map) {
        rawMessages = responseData["messages"] ?? responseData["data"] ?? responseData["docs"] ?? responseData["results"] ?? [];
      } else if (responseData is List) {
        rawMessages = responseData;
      }
      
      _hasMoreMessages = (responseData is Map && (responseData["totalPages"] ?? 1) > _currentPage);

      final processed = rawMessages.map((m) => _parseMessage(m)).toList();
      // debugPrint("DEBUG: Extracted ${rawMessages.length} raw, processed ${processed.length} messages");

      // Auto-detect if API returns oldest-first or newest-first
      // We want _messages to end up as [Oldest, ..., Newest] because ListView(reverse: true) 
      // shows the last element at the bottom.
      List<Map<String, dynamic>> finalMessages = [];
      if (processed.isNotEmpty) {
        DateTime? firstTime = _parseDateTime(rawMessages.first["createdAt"]);
        DateTime? lastTime = _parseDateTime(rawMessages.last["createdAt"]);
        
        if (firstTime != null && lastTime != null && firstTime.isAfter(lastTime)) {
          // It's newest-first (descending): Newest is at index 0. 
          // Reverse it to get ascending order [Oldest, ..., Newest]
          finalMessages = processed.reversed.toList();
        } else {
          // It's oldest-first (ascending): Oldest is at index 0. Keep it.
          finalMessages = processed;
        }
      }

      if (mounted) {
        setState(() {
          if (isPolling) {
            // Merge new messages (usually from page 1)
            for (var msg in finalMessages) {
              if (!_messages.any((existing) => existing["id"].toString() == msg["id"].toString())) {
                _messages.add(msg);
              }
            }
            // Sort to ensure correct order
            _messages.sort((a,b) {
               DateTime? tA = _parseDateTime(a["rawCreatedAt"]);
               DateTime? tB = _parseDateTime(b["rawCreatedAt"]);
               if (tA == null || tB == null) return 0;
               return tA.compareTo(tB);
            });
          } else {
            if (_currentPage == 1) {
              _messages = finalMessages;
            } else {
              _messages.insertAll(0, finalMessages);
            }
          }
          _isLoadingMore = false;
        });
      }
    } catch (e) {
      debugPrint("Error loading messages: $e");
      if (mounted) setState(() => _isLoadingMore = false);
    }
  }

  DateTime? _parseDateTime(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    try {
      return DateTime.parse(value.toString());
    } catch (_) {
      return null;
    }
  }

  Map<String, dynamic> _parseMessage(dynamic msgData) {
    final senderId = msgData['sender']?['_id'] ?? msgData['senderId'] ?? msgData['sender'];
    final senderName = msgData['sender']?['fullName'] ?? msgData['sender']?['name'] ?? "Unknown";
    final avatarRaw = msgData['sender']?['profilePicture'] ?? msgData['sender']?['avatar'];
    
    final senderIdStr = senderId?.toString();
    final bool isSender = senderIdStr == (AuthService().userProfile.value?['_id'] ?? AuthService().userProfile.value?['id'])?.toString() || 
                        msgData['isSender'] == true;
    return {
      "id": (msgData["_id"] ?? msgData["id"] ?? DateTime.now().millisecondsSinceEpoch).toString(),
      "text": msgData["text"] ?? msgData["content"] ?? "",
      "isSender": isSender,
      "imagePath": (msgData["media"] is List && (msgData["media"] as List).isNotEmpty)
          ? ApiService.resolveImageUrl(msgData["media"][0]["url"] ?? msgData["media"][0]["path"])
          : (msgData["attachments"] is List && (msgData["attachments"] as List).isNotEmpty)
              ? ApiService.resolveImageUrl(msgData["attachments"][0]["url"] ?? msgData["attachments"][0]["path"])
              : null,
      "fileName": (msgData["attachments"] is List && (msgData["attachments"] as List).isNotEmpty)
          ? msgData["attachments"][0]["name"]
          : (msgData["media"] is List && (msgData["media"] as List).isNotEmpty)
              ? msgData["media"][0]["name"]
              : null,
      "senderName": senderName,
      "senderAvatarPath": ApiService.resolveImageUrl(avatarRaw),
      "rawCreatedAt": msgData["createdAt"] ?? msgData["timestamp"],
      "time": _formatMessageTime(msgData["createdAt"] ?? msgData["timestamp"]),
      "isSystem": msgData["type"] == "system" || msgData["isSystem"] == true,
    };
  }
  Future<void> _loadMoreMessages() async {
    if (_isLoadingMore || !_hasMoreMessages) return;
    _currentPage++;
    await _loadMessages();
  }

  String _getSenderInitials(dynamic sender) {
    if (sender is Map<String, dynamic>) {
      final name = sender["fullName"] ?? sender["name"] ?? "";
      return name.isNotEmpty ? name[0].toUpperCase() : "?";
    }
    return "?";
  }

  String _formatFileSize(int? bytes) {
    if (bytes == null) return "";
    if (bytes < 1024) return "$bytes B";
    if (bytes < 1024 * 1024) return "${(bytes / 1024).round()} KB";
    return "${(bytes / (1024 * 1024)).round()} MB";
  }

  String _formatMessageTime(String? dateString) {
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

  @override
  void dispose() {
    _chatSubscription?.cancel();
    _pollingTimer?.cancel();
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _pickMedia(ImageSource source) async {
    // Show dialog to choose between image and video
    final mediaType = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Chọn loại phương tiện"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, "image"),
            child: const Text("Ảnh"),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, "video"),
            child: const Text("Video"),
          ),
        ],
      ),
    );

    if (mediaType == null) return;

    try {
      final XFile? file = mediaType == "image"
          ? await _picker.pickImage(source: source)
          : await _picker.pickVideo(source: source);

      if (file != null) {
        setState(() {
          _messages.add({
            "id": DateTime.now().millisecondsSinceEpoch,
            "imagePath": file.path,
            "isSender": true,
            "time":
                "${DateTime.now().hour}:${DateTime.now().minute.toString().padLeft(2, '0')}",
          });
        });
      }
    } catch (e) {
      debugPrint("Error picking media: $e");
    }
  }

  Future<void> _pickFile() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles();

      if (result != null) {
        PlatformFile file = result.files.first;
        setState(() {
          _messages.add({
            "id": DateTime.now().millisecondsSinceEpoch,
            "fileName": file.name,
            "fileSize": _formatBytes(file.size),
            "filePath": file.path,
            "isSender": true,
            "time":
                "${DateTime.now().hour}:${DateTime.now().minute.toString().padLeft(2, '0')}",
          });
        });
      }
    } catch (e) {
      debugPrint("Error picking file: $e");
    }
  }

  String _formatBytes(int bytes) {
    if (bytes <= 0) return "0 B";
    const suffixes = ["B", "KB", "MB", "GB", "TB"];
    var i = (math.log(bytes) / math.log(1024)).floor();
    return "${(bytes / math.pow(1024, i)).toStringAsFixed(1)} ${suffixes[i]}";
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

  void _sendMessage() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    final convId = widget.conversationId;

    if (_editingMessageId != null) {
      // Handle Edit (if API supports it, otherwise just local for now)
      setState(() {
        final index = _messages.indexWhere((m) => m["id"] == _editingMessageId);
        if (index != -1) {
          _messages[index]["text"] = text;
          _messages[index]["isEdited"] = true;
        }
        _editingMessageId = null;
        _controller.clear();
      });
    } else {
      // Handle New Message
      if (_activeConversationId != null) {
        // Optimistic update
        final tempId = DateTime.now().millisecondsSinceEpoch.toString();
        setState(() {
          _messages.add({
            "id": tempId,
            "text": text,
            "isSender": true,
            "isEdited": false,
            "time": "${DateTime.now().hour}:${DateTime.now().minute.toString().padLeft(2, '0')}",
            "senderName": "Bạn",
          });
          _controller.clear();
          _showEmoji = false;
        });

        final success = await ApiService.sendMessage(_activeConversationId!, text);
        if (!success) {
          // Rollback or show error
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text("Gửi tin nhắn thất bại. Vui lòng thử lại.")),
            );
            setState(() {
              _messages.removeWhere((m) => m["id"] == tempId);
            });
          }
        }
      } else {
        // Conversation ID is null - this shouldn't happen in detail screen normally
        debugPrint("Error: conversationId is null");
      }
    }
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
            String updatedTime =
                "${DateTime.now().hour}:${DateTime.now().minute.toString().padLeft(2, '0')}";
            if (lastRecord != null) {
              updatedTime = lastRecord["time"] ?? updatedTime;
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
              "time": updatedTime,
              "messages": _messages,
              "members": _members,
              "name": _currentName,
              "color": _currentColor,
              "initials": _currentInitials,
              "avatarPath": _currentAvatarPath,
              "conversationId": _activeConversationId,
            });
          },
        ),
        title: Row(
          children: [
            _HeaderAvatar(
              isOnline: widget.isOnline,
              initials: _currentInitials,
              color: _currentColor,
              avatarPath: _currentAvatarPath,
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _currentName,
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
        actions: [
          IconButton(
            icon: const Icon(Icons.more_horiz, color: Colors.blueAccent),
            onPressed: () async {
              final result = await showModalBottomSheet(
                context: context,
                isScrollControlled: true,
                backgroundColor: Colors.transparent,
                builder: (_) => ChatSettingsSheet(
                  name: _currentName,
                  initials: _currentInitials ?? "",
                  color: _currentColor ?? Colors.blue,
                  isGroup: widget.isGroup,
                  avatarPath: _currentAvatarPath,
                  initialMembers: _members,
                  onUpdate: (newName, newColor, newAvatar) {
                    if (!mounted) return;
                    final nowStr =
                        "${DateTime.now().hour}:${DateTime.now().minute.toString().padLeft(2, '0')}";
                    setState(() {
                      if (widget.isGroup) {
                        if (newName != _currentName) {
                          _messages.add({
                            "id": DateTime.now().millisecondsSinceEpoch,
                            "text":
                                "Bạn đã thay đổi tên nhóm thành \"$newName\"",
                            "isSender": false,
                            "isSystem": true,
                            "time": nowStr,
                          });
                        }
                        if (newAvatar != _currentAvatarPath) {
                          _messages.add({
                            "id": DateTime.now().millisecondsSinceEpoch + 1,
                            "text": "Bạn đã thay đổi ảnh đại diện nhóm",
                            "isSender": false,
                            "isSystem": true,
                            "time": nowStr,
                          });
                        }
                      }

                      _currentName = newName;
                      _currentColor = newColor;
                      _currentAvatarPath = newAvatar;
                      _currentInitials = newName.length >= 2
                          ? newName.substring(0, 2).toUpperCase()
                          : newName.toUpperCase();
                    });
                  },
                  onUpdateMembers: (newMembers) {
                    if (!mounted) return;
                    final nowStr =
                        "${DateTime.now().hour}:${DateTime.now().minute.toString().padLeft(2, '0')}";
                    setState(() {
                      // Compare and notify about removals
                      for (var oldMember in _members) {
                        final String? name = oldMember["name"];
                        if (name != null) {
                          final stillActive = newMembers.any(
                            (m) => m["name"] == name,
                          );
                          if (!stillActive) {
                            _messages.add({
                              "id": DateTime.now().millisecondsSinceEpoch,
                              "text":
                                  "Phùng Hoàng Long đã mời $name rời khỏi nhóm",
                              "isSender": false,
                              "isSystem": true,
                              "time": nowStr,
                            });
                          }
                        }
                      }
                      _members = newMembers;
                    });
                  },
                ),
              );
              if (result == 'leave' || result == 'disband') {
                Navigator.pop(context, {"action": result});
              }
            },
          ),
          const SizedBox(width: 8),
        ],
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
            "name": _currentName,
            "avatarPath": _currentAvatarPath,
            "conversationId": _activeConversationId,
          });
          return Future.value(false);
        },
        child: Column(
          children: [
            Expanded(
              child: RefreshIndicator(
                onRefresh: () async {
                  // Reset to page 1 and reload
                  _currentPage = 1;
                  _hasMoreMessages = true;
                  await _loadMessages();
                },
                child: NotificationListener<ScrollNotification>(
                  onNotification: (ScrollNotification scrollInfo) {
                    if (scrollInfo.metrics.pixels >=
                            scrollInfo.metrics.maxScrollExtent - 100 &&
                        !_isLoadingMore &&
                        _hasMoreMessages) {
                      _loadMoreMessages();
                    }
                    return true;
                  },
                  child: ListView.builder(
                    reverse: true,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 24,
                    ),
                    itemCount: _messages.length + (_isLoadingMore ? 1 : 0),
                    itemBuilder: (context, index) {
                      // Show loading indicator at the top (index 0 when reversed)
                      if (_isLoadingMore && index == 0) {
                        return const Padding(
                          padding: EdgeInsets.symmetric(vertical: 16),
                          child: Center(
                            child: SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  Colors.blue,
                                ),
                              ),
                            ),
                          ),
                        );
                      }

                      final msgIndex = _isLoadingMore ? index - 1 : index;
                      final msg = _messages[_messages.length - 1 - msgIndex];
                      return GestureDetector(
                        onLongPress: () => _showOptions(context, msg),
                        child: _ChatBubble(
                          message: msg["text"] ?? "",
                          isSender: msg["isSender"],
                          isSystem: msg["isSystem"] ?? false,
                          isEdited: msg["isEdited"] ?? false,
                          imagePath: msg["imagePath"],
                          fileName: msg["fileName"],
                          fileSize: msg["fileSize"],
                          senderName: msg["isSender"]
                              ? "Bạn"
                              : (msg["senderName"] ?? _currentName),
                          senderInitials: msg["isSender"]
                              ? "ME"
                              : (msg["senderInitials"] ??
                                    (widget.initials ??
                                        _currentName.substring(0, 1))),
                          senderAvatarPath: msg["isSender"]
                              ? ApiService.resolveImageUrl(AuthService().userProfile.value?["profilePicture"] ?? AuthService().userProfile.value?["avatar"])
                              : msg["senderAvatarPath"],
                          bubbleColor: _currentColor ?? Colors.blue,
                          time: msg["time"] ?? "Vừa xong",
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
            if (_editingMessageId != null)
              _EditingBanner(
                themeColor: _currentColor ?? const Color(0xFF3B82F6),
                onCancel: () => setState(() {
                  _editingMessageId = null;
                  _controller.clear();
                }),
              ),

            _ChatInputArea(
              controller: _controller,
              focusNode: _focusNode,
              isEmojiVisible: _showEmoji,
              onEmoji: _toggleEmoji,
              onSend: _sendMessage,
              onCamera: () => _pickMedia(ImageSource.camera),
              onGallery: () => _pickMedia(ImageSource.gallery),
              onPlus: _pickFile,
              themeColor: _currentColor ?? const Color(0xFF3B82F6),
            ),
            if (_showEmoji)
              _EmojiPickerSheet(
                onSelected: (emoji) {
                  _insertEmoji(emoji);
                },
              ),
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
  final bool isSystem;
  final String? imagePath;
  final String? fileName;
  final String? fileSize;
  final String? senderName;
  final String? senderInitials;
  final String? senderAvatarPath;
  final Color bubbleColor;
  final String time;
  const _ChatBubble({
    required this.message,
    required this.isSender,
    this.isSystem = false,
    this.isEdited = false,
    this.imagePath,
    this.fileName,
    this.fileSize,
    this.senderName,
    this.senderInitials,
    this.senderAvatarPath,
    this.bubbleColor = const Color(0xFF3B82F6),
    required this.time,
  });

  @override
  Widget build(BuildContext context) {
    if (isSystem) {
      return Center(
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 8),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.grey.shade100,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            message,
            style: TextStyle(
              fontSize: 11,
              color: Colors.blueGrey.shade400,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment: isSender
            ? MainAxisAlignment.end
            : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isSender) ...[
            CircleAvatar(
              radius: 14,
              backgroundColor: Colors.blueGrey.shade100,
              backgroundImage: _getAvatarImageProvider(senderAvatarPath),
              child:
                  (senderAvatarPath == null ||
                      senderAvatarPath!.isEmpty ||
                      _getAvatarImageProvider(senderAvatarPath) == null)
                  ? Text(
                      senderInitials ??
                          (senderName?.isNotEmpty == true
                              ? senderName![0]
                              : "?"),
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: Colors.blueGrey,
                      ),
                    )
                  : null,
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Column(
              crossAxisAlignment: isSender
                  ? CrossAxisAlignment.end
                  : CrossAxisAlignment.start,
              children: [
                if (!isSender && senderName != null)
                  Padding(
                    padding: const EdgeInsets.only(left: 4, bottom: 4),
                    child: Text(
                      senderName!,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: Colors.blueGrey.shade600,
                      ),
                    ),
                  ),
                if (imagePath != null && imagePath!.isNotEmpty)
                  GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => FullScreenMediaViewer(
                            mediaList: [imagePath!],
                            initialIndex: 0,
                          ),
                        ),
                      );
                    },
                    child: Container(
                      constraints: BoxConstraints(
                        maxWidth: MediaQuery.of(context).size.width * 0.65,
                      ),
                      child: Hero(
                        tag: imagePath!,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: _isNetworkUrl(imagePath!)
                              ? (imagePath!.toLowerCase().endsWith('.mp4') ||
                                        imagePath!.toLowerCase().endsWith(
                                          '.mov',
                                        )
                                    ? VideoPreview(videoUrl: imagePath!)
                                    : Image.network(
                                        imagePath!,
                                        fit: BoxFit.cover,
                                      ))
                              : (imagePath!.toLowerCase().endsWith('.mp4') ||
                                        imagePath!.toLowerCase().endsWith(
                                          '.mov',
                                        )
                                    ? VideoPreview(file: File(imagePath!))
                                    : Image.file(
                                        File(imagePath!),
                                        fit: BoxFit.cover,
                                      )),
                        ),
                      ),
                    ),
                  )
                else if (fileName != null)
                  Container(
                    padding: const EdgeInsets.all(12),
                    constraints: BoxConstraints(
                      maxWidth: MediaQuery.of(context).size.width * 0.7,
                    ),
                    decoration: BoxDecoration(
                      color: isSender ? bubbleColor : const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.only(
                        topLeft: const Radius.circular(16),
                        topRight: const Radius.circular(16),
                        bottomLeft: Radius.circular(isSender ? 16 : 4),
                        bottomRight: Radius.circular(isSender ? 4 : 16),
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: isSender
                                ? Colors.white.withOpacity(0.2)
                                : Colors.grey.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(
                            Icons.insert_drive_file,
                            color: isSender ? Colors.white : Colors.blueGrey,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                fileName!,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: isSender
                                      ? Colors.white
                                      : Colors.black87,
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              if (fileSize != null)
                                Text(
                                  fileSize!,
                                  style: TextStyle(
                                    color: isSender
                                        ? Colors.white70
                                        : Colors.grey.shade600,
                                    fontSize: 10,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  )
                else
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                    constraints: BoxConstraints(
                      maxWidth: MediaQuery.of(context).size.width * 0.72,
                    ),
                    decoration: BoxDecoration(
                      color: isSender ? bubbleColor : Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: isSender
                            ? Colors.transparent
                            : Colors.grey.shade200,
                      ),
                      boxShadow: isSender
                          ? null
                          : [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.04),
                                blurRadius: 14,
                                offset: const Offset(0, 3),
                              ),
                            ],
                    ),
                    child: Text(
                      message,
                      style: TextStyle(
                        color: isSender ? Colors.white : Colors.black87,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        fontFamily: 'sans-serif',
                        height: 1.5,
                      ),
                    ),
                  ),
                Padding(
                  padding: const EdgeInsets.only(top: 6, right: 4, left: 4),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        time,
                        style: TextStyle(
                          color: Colors.grey.shade500,
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (isEdited &&
                          imagePath == null &&
                          fileName == null) ...[
                        const SizedBox(width: 6),
                        Text(
                          "• Đã sửa",
                          style: TextStyle(
                            color: Colors.blueGrey.withOpacity(0.6),
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (isSender) ...[
            const SizedBox(width: 8),
            CircleAvatar(
              radius: 14,
              backgroundColor: Colors.blue.shade50,
              backgroundImage: _getAvatarImageProvider(senderAvatarPath),
              child: _getAvatarImageProvider(senderAvatarPath) == null 
                ? const Text(
                    "ME",
                    style: TextStyle(
                      fontSize: 8,
                      fontWeight: FontWeight.bold,
                      color: Colors.blue,
                    ),
                  )
                : null,
            ),
          ],
        ],
      ),
    );
  }

  bool _isNetworkUrl(String url) {
    return url.startsWith('http://') || url.startsWith('https://');
  }

  ImageProvider? _getAvatarImageProvider(String? avatarPath) {
    if (avatarPath != null && avatarPath.isNotEmpty) {
      if (avatarPath.startsWith('http')) {
        // debugPrint('Avatar Provider: Using network URL directly: $avatarPath');
        return NetworkImage(avatarPath);
      } else {
        final resolvedUrl = ApiService.resolveImageUrl(avatarPath);
        // debugPrint('Avatar Provider: Resolved $avatarPath -> $resolvedUrl');
        if (resolvedUrl != null && resolvedUrl.isNotEmpty) {
          // debugPrint('Avatar Provider: Creating NetworkImage for $resolvedUrl');
          return NetworkImage(resolvedUrl);
        }
      }
    }
    // debugPrint('Avatar Provider: No valid avatar path, returning null');
    return null;
  }
}

class _ChatInputArea extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final VoidCallback onSend;
  final VoidCallback onEmoji;
  final bool isEmojiVisible;
  final VoidCallback onCamera;
  final VoidCallback onGallery;
  final VoidCallback onPlus;
  final Color themeColor;

  const _ChatInputArea({
    required this.controller,
    required this.focusNode,
    required this.onSend,
    required this.onEmoji,
    required this.isEmojiVisible,
    required this.onCamera,
    required this.onGallery,
    required this.onPlus,
    this.themeColor = const Color(0xFF3B82F6),
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
            onPressed: onPlus,
            icon: Icon(Icons.add_circle, color: themeColor),
          ),
          IconButton(
            onPressed: onCamera,
            icon: Icon(Icons.camera_alt, color: themeColor),
          ),
          IconButton(
            onPressed: onGallery,
            icon: Icon(Icons.image, color: themeColor),
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
                      color: isEmojiVisible ? themeColor : Colors.blueGrey,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            onPressed: onSend,
            icon: Icon(Icons.send_rounded, color: themeColor),
          ),
        ],
      ),
    );
  }
}

class _EditingBanner extends StatelessWidget {
  final VoidCallback onCancel;
  final Color themeColor;
  const _EditingBanner({required this.onCancel, required this.themeColor});
  @override
  Widget build(BuildContext context) {
    return Container(
      color: themeColor.withOpacity(0.05),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Icon(Icons.edit_outlined, size: 16, color: themeColor),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              "Đang chỉnh sửa tin nhắn...",
              style: TextStyle(
                color: themeColor,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, size: 16),
            constraints: const BoxConstraints(),
            padding: EdgeInsets.zero,
            onPressed: onCancel,
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
  final String? avatarPath;
  const _HeaderAvatar({
    required this.isOnline,
    this.initials,
    this.color,
    this.avatarPath,
  });

  @override
  Widget build(BuildContext context) {
    ImageProvider? avatarImage;
    if (avatarPath != null && avatarPath!.isNotEmpty) {
      if (avatarPath!.startsWith('http://') ||
          avatarPath!.startsWith('https://')) {
        avatarImage = NetworkImage(avatarPath!);
      } else if (File(avatarPath!).existsSync()) {
        avatarImage = FileImage(File(avatarPath!));
      } else {
        final resolved = ApiService.resolveImageUrl(avatarPath!);
        if (resolved.startsWith('http://') || resolved.startsWith('https://')) {
          avatarImage = NetworkImage(resolved);
        } else if (File(resolved).existsSync()) {
          avatarImage = FileImage(File(resolved));
        }
      }
    }

    return Stack(
      alignment: Alignment.bottomRight,
      children: [
        CircleAvatar(
          radius: 18,
          backgroundColor: color?.withOpacity(0.2) ?? Colors.blueGrey.shade50,
          backgroundImage: avatarImage,
          child: avatarImage != null
              ? null
              : (initials != null
                    ? Text(
                        initials!,
                        style: TextStyle(
                          color: color ?? Colors.blueGrey,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      )
                    : const Icon(
                        Icons.person,
                        size: 20,
                        color: Colors.blueGrey,
                      )),
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
