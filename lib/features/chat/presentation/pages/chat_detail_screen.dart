import 'dart:io';
import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import '../../../../core/widgets/full_screen_media_viewer.dart';
import '../../../../core/widgets/video_preview.dart';
import '../../../../core/api_service.dart';
import '../../../../core/security.dart';
import './chat_info_screen.dart';

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
  final bool isMuted;
  final Function(bool)? onMuteToggle;

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
    this.isMuted = false,
    this.onMuteToggle,
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
  Map<String, dynamic>? _replyingTo;
  bool _isOtherTyping = false;
  Timer? _typingDebounce;

  // Pagination states
  int _currentPage = 1;
  bool _isLoadingMore = false;
  bool _hasMoreMessages = true;

  StreamSubscription? _chatSubscription;
  Timer? _pollingTimer;
  String? _activeConversationId;
  late bool _isMuted;

  late ScrollController _scrollController;
  Color _themeColor = const Color(0xFF3B82F6);

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    _scrollController.addListener(_scrollListener);

    _currentName = widget.name;
    _currentInitials = widget.initials;
    _currentColor = widget.color;
    _currentAvatarPath = widget.avatarPath;
    _isMuted = widget.isMuted;
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

    // Fetch full conversation details (to get complete member list)
    if (_activeConversationId != null && _activeConversationId!.length < 25) {
      _loadChatDetails();
    }

    // Start 10-second polling fallback
    _startPolling();
  }

  Future<void> _loadChatDetails() async {
    if (_activeConversationId == null) return;

    final details = await ApiService.getChatDetails(_activeConversationId!);
    if (details != null && details["participants"] is List) {
      if (!mounted) return;
      setState(() {
        _members = (details["participants"] as List)
            .map((e) {
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
            .cast<Map<String, String>>();
      });
    }
  }

  void _scrollListener() {
    if (_scrollController.position.pixels >=
            _scrollController.position.maxScrollExtent - 200 &&
        !_isLoadingMore &&
        _hasMoreMessages) {
      _loadMoreMessages();
    }
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
    // debugPrint(
    //   "DEBUG: _handleNewChatEvent received data: ${msgData['text'] ?? msgData['content']}",
    // );

    // Check if message belongs to this conversation
    final rawChatId =
        msgData['chatId'] ??
        msgData['chat']?['_id'] ??
        msgData['chat'] ??
        msgData['conversationId'] ??
        msgData['id_conversation'];

    String? chatId = (rawChatId is Map)
        ? rawChatId['_id']?.toString()
        : rawChatId?.toString();

    // Safety: If we are in a "temporary" chat (numeric ID),
    // and we receive a message from a chat with our participation,
    // we should accept it and potentially update our ID.
    bool idMatch = chatId == _activeConversationId;
    if (!idMatch &&
        _activeConversationId != null &&
        _activeConversationId!.length > 10) {
      // Temporary IDs are usually long timestamps (milliseconds). String length > 10.
      // We accept the update if the message has a valid chatId and it's our first real message
      if (chatId != null &&
          _messages.where((m) => m["isSystem"] != true).length < 5) {
        idMatch = true;
        // Update active ID so future polls/fetches use the real one
        setState(() {
          _activeConversationId = chatId;
        });
      }
    }

    if (!idMatch && chatId != null) return;

    final senderId =
        msgData['sender']?['_id'] ?? msgData['senderId'] ?? msgData['sender'];
    final senderName =
        msgData['sender']?['fullName'] ??
        msgData['sender']?['name'] ??
        "Unknown";
    final avatarRaw =
        msgData['sender']?['profilePicture'] ?? msgData['sender']?['avatar'];
    final bool isSender =
        senderId?.toString() ==
            (AuthService().userProfile.value?['_id'] ??
                    AuthService().userProfile.value?['id'])
                ?.toString() ||
        msgData['isSender'] == true;

    final newMessage = {
      "id":
          (msgData["_id"] ??
                  msgData["id"] ??
                  DateTime.now().millisecondsSinceEpoch)
              .toString(),
      "text": msgData["text"] ?? msgData["content"] ?? "",
      "isSender": isSender,
      "isRecalled":
          msgData["isRecalled"] == true || msgData["status"] == "recalled",
      "replyTo": msgData["replyTo"] ?? msgData["parentMessage"],
      "imagePath":
          _extractMediaUrl(msgData["media"]) ??
          _extractMediaUrl(msgData["attachments"]) ??
          (msgData["imageUrl"] != null
              ? ApiService.resolveImageUrl(msgData["imageUrl"])
              : null) ??
          (msgData["image"] is String
              ? ApiService.resolveImageUrl(msgData["image"])
              : null),
      "fileName":
          _extractMediaName(msgData["attachments"]) ??
          _extractMediaName(msgData["media"]),
      "fileSize":
          _extractMediaSize(msgData["attachments"]) ??
          _extractMediaSize(msgData["media"]),
      "senderName": senderName,
      "senderInitials": senderName.isNotEmpty
          ? senderName[0].toUpperCase()
          : "?",
      "senderAvatarPath": ApiService.resolveImageUrl(avatarRaw),
      "time": _formatMessageTime(msgData["createdAt"] ?? msgData["timestamp"]),
      "isSystem": msgData["type"] == "system" || msgData["isSystem"] == true,
    };

    setState(() {
      bool replaced = false;
      if (newMessage["isSender"] == true) {
        final optIndex = _messages.indexWhere((m) {
          if (m["isSender"] != true) return false;
          final mId = m["id"]?.toString() ?? '';
          if (mId.length <= 10) return false;
          final sameText = (m["text"] ?? '') == (newMessage["text"] ?? '');
          final isUploadingImg =
              m["isUploading"] == true && newMessage["imagePath"] != null;
          return sameText || isUploadingImg;
        });
        if (optIndex != -1) {
          _messages[optIndex] = newMessage;
          replaced = true;
        }
      }

      final existingIndex = _messages.indexWhere(
        (m) => m["id"]?.toString() == newMessage["id"]?.toString(),
      );
      if (!replaced && existingIndex != -1) {
        _messages[existingIndex] = newMessage;
        replaced = true;
      }

      if (!replaced) {
        final text = (newMessage["text"] ?? '').toString().trim();
        if (text.isNotEmpty ||
            newMessage["imagePath"] != null ||
            newMessage["isSystem"] == true) {
          _messages.insert(0, newMessage);
        }
      }
    });

    if (_activeConversationId != null) {
      ApiService.markChatAsRead(_activeConversationId!);
    }
  }

  Future<void> _loadMoreMessages() async {
    if (_isLoadingMore || !_hasMoreMessages) return;
    _currentPage++;
    await _loadMessages();
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

      // Robustly extract message list
      final dynamic responseData = res;
      List<dynamic> rawMessages = [];
      int totalPages = 1;

      if (responseData is Map) {
        rawMessages =
            responseData["messages"] ??
            responseData["data"] ??
            responseData["docs"] ??
            responseData["results"] ??
            [];
        totalPages = responseData["totalPages"] ?? responseData["pages"] ?? 1;
      } else if (responseData is List) {
        rawMessages = responseData;
      }

      // Fallback: if totalPages is 1 but we got a full page of 20 items, assume there might be more.
      _hasMoreMessages =
          (totalPages > _currentPage) ||
          (totalPages == 1 && rawMessages.length == 20);

      final processed = rawMessages.map((m) => _parseMessage(m)).toList();

      // We want _messages to be [Newest, ..., Oldest] for ListView(reverse: true)
      List<Map<String, dynamic>> finalMessages = [];
      if (processed.isNotEmpty) {
        final firstTime = _parseDateTime(
          rawMessages.first["createdAt"] ?? rawMessages.first["timestamp"],
        );
        final lastTime = _parseDateTime(
          rawMessages.last["createdAt"] ?? rawMessages.last["timestamp"],
        );

        if (firstTime != null &&
            lastTime != null &&
            firstTime.isBefore(lastTime)) {
          // API returned Oldest-first, reverse to get Newest-first
          finalMessages = processed.reversed.toList();
        } else {
          // Already Newest-first or could not determine, keep it
          finalMessages = processed;
        }
      }

      if (mounted) {
        setState(() {
          if (isPolling) {
            // Merge new messages (usually from page 1) into the Newest-first list
            for (var msg in finalMessages) {
              if (!_messages.any(
                (existing) => existing["id"].toString() == msg["id"].toString(),
              )) {
                _messages.insert(0, msg);
              }
            }
            // Sort to ensure correct Newest-first order [Newest ... Oldest]
            _messages.sort((a, b) {
              DateTime? tA = _parseDateTime(a["rawCreatedAt"] ?? a["time"]);
              DateTime? tB = _parseDateTime(b["rawCreatedAt"] ?? b["time"]);
              if (tA == null || tB == null) return 0;
              return tB.compareTo(tA);
            });
          } else {
            if (_currentPage == 1) {
              _messages = finalMessages;
            } else {
              // Append older messages to the end
              _messages.addAll(finalMessages);
            }
          }
          _isLoadingMore = false;
        });
      }
    } catch (e) {
      debugPrint("Error loading messages: $e");
      if (mounted)
        setState(() {
          _isLoadingMore = false;
          if (!isPolling && _currentPage > 1) _currentPage--;
        });
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
    final senderId =
        msgData['sender']?['_id'] ?? msgData['senderId'] ?? msgData['sender'];
    final senderName =
        msgData['sender']?['fullName'] ??
        msgData['sender']?['name'] ??
        "Unknown";
    final avatarRaw =
        msgData['sender']?['profilePicture'] ?? msgData['sender']?['avatar'];

    final senderIdStr = senderId?.toString();
    final bool isSender =
        senderIdStr ==
            (AuthService().userProfile.value?['_id'] ??
                    AuthService().userProfile.value?['id'])
                ?.toString() ||
        msgData['isSender'] == true;
    return {
      "id":
          (msgData["_id"] ??
                  msgData["id"] ??
                  DateTime.now().millisecondsSinceEpoch)
              .toString(),
      "text": msgData["text"] ?? msgData["content"] ?? "",
      "isSender": isSender,
      "isRecalled":
          msgData["isRecalled"] == true || msgData["status"] == "recalled",
      "replyTo": msgData["replyTo"] ?? msgData["parentMessage"],
      "imagePath":
          _extractMediaUrl(msgData["media"]) ??
          _extractMediaUrl(msgData["attachments"]) ??
          (msgData["imageUrl"] != null
              ? ApiService.resolveImageUrl(msgData["imageUrl"])
              : null) ??
          (msgData["image"] is String
              ? ApiService.resolveImageUrl(msgData["image"])
              : null),
      "fileName":
          _extractMediaName(msgData["attachments"]) ??
          _extractMediaName(msgData["media"]),
      "senderName": senderName,
      "senderAvatarPath": ApiService.resolveImageUrl(avatarRaw),
      "rawCreatedAt": msgData["createdAt"] ?? msgData["timestamp"],
      "time": _formatMessageTime(msgData["createdAt"] ?? msgData["timestamp"]),
      "isSystem": msgData["type"] == "system" || msgData["isSystem"] == true,
    };
  }

  /// Safely extracts an image URL from a media list which may contain
  /// either Map objects {url, path} or plain URL Strings.
  String? _extractMediaUrl(dynamic mediaList) {
    if (mediaList is! List || mediaList.isEmpty) return null;
    final item = mediaList[0];
    if (item is String) return ApiService.resolveImageUrl(item);
    if (item is Map) {
      final url =
          item["url"] ?? item["path"] ?? item["imageUrl"] ?? item["src"];
      if (url != null) return ApiService.resolveImageUrl(url);
    }
    return null;
  }

  String? _extractMediaName(dynamic mediaList) {
    if (mediaList is! List || mediaList.isEmpty) return null;
    final item = mediaList[0];
    if (item is Map)
      return item["name"]?.toString() ?? item["fileName"]?.toString();
    return null;
  }

  String? _extractMediaSize(dynamic mediaList) {
    if (mediaList is! List || mediaList.isEmpty) return null;
    final item = mediaList[0];
    if (item is Map && item["size"] != null) {
      if (item["size"] is int) return _formatFileSize(item["size"]);
      if (item["size"] is String)
        return _formatFileSize(int.tryParse(item["size"]));
    }
    return null;
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
    _typingDebounce?.cancel();
    _scrollController.dispose();
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
          ? await _picker.pickImage(source: source, imageQuality: 85)
          : await _picker.pickVideo(source: source);

      if (file == null) return;

      // Optimistic local preview
      final tempId = DateTime.now().millisecondsSinceEpoch.toString();
      setState(() {
        _messages.insert(0, {
          "id": tempId,
          "imagePath": file.path,
          "isSender": true,
          "isUploading": true,
          "time":
              "${DateTime.now().hour}:${DateTime.now().minute.toString().padLeft(2, '0')}",
        });
      });

      // Upload to server
      final bytes = await file.readAsBytes();
      final fileName = file.name.isNotEmpty
          ? file.name
          : 'media_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final imageId = await ApiService.uploadImage(bytes, fileName);

      if (imageId != null && _activeConversationId != null) {
        final imageUrl = ApiService.resolveImageUrl(imageId);
        // Send message with image via socket/REST
        final success = await ApiService.sendMediaMessage(
          _activeConversationId!,
          imageId: imageId,
          imageUrl: imageUrl,
          type: mediaType,
        );
        if (success) {
          // Update local message with server URL
          setState(() {
            final idx = _messages.indexWhere((m) => m["id"] == tempId);
            if (idx != -1) {
              _messages[idx]["imagePath"] = imageUrl;
              _messages[idx]["isUploading"] = false;
            }
          });
        } else {
          // Remove failed message
          setState(() => _messages.removeWhere((m) => m["id"] == tempId));
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text("Gửi ảnh thất bại. Vui lòng thử lại."),
              ),
            );
          }
        }
      } else {
        // Upload failed
        setState(() => _messages.removeWhere((m) => m["id"] == tempId));
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("Tải ảnh lên thất bại. Vui lòng thử lại."),
            ),
          );
        }
      }
    } catch (e) {
      debugPrint("Error picking/sending media: $e");
    }
  }

  Future<void> _pickFile() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles();

      if (result != null) {
        PlatformFile file = result.files.first;
        setState(() {
          _messages.insert(0, {
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
        final replyMsg = _replyingTo;
        final replyToId = replyMsg?["id"]?.toString();

        // Optimistic update
        final tempId = DateTime.now().millisecondsSinceEpoch.toString();
        setState(() {
          _messages.insert(0, {
            "id": tempId,
            "text": text,
            "isSender": true,
            "isEdited": false,
            "replyTo": replyMsg != null
                ? {
                    "_id": replyMsg["id"],
                    "text": replyMsg["text"],
                    "sender": {"fullName": replyMsg["senderName"]},
                  }
                : null,
            "time":
                "${DateTime.now().hour}:${DateTime.now().minute.toString().padLeft(2, '0')}",
            "senderName": "Bạn",
          });
          _controller.clear();
          _replyingTo = null;
          _showEmoji = false;
        });

        final success = await ApiService.sendMessage(
          _activeConversationId!,
          text,
          replyTo: replyToId,
        );
        if (!success) {
          // Rollback or show error
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text("Gửi tin nhắn thất bại. Vui lòng thử lại."),
              ),
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

  void _recallMessage(Map<String, dynamic> msg) async {
    final msgId = msg["id"]?.toString();
    if (msgId == null || _activeConversationId == null) return;

    // Optimistic update
    setState(() {
      final index = _messages.indexWhere((m) => m["id"].toString() == msgId);
      if (index != -1) {
        _messages[index]["isRecalled"] = true;
        _messages[index]["text"] = "Tin nhắn đã được thu hồi";
        _messages[index]["imagePath"] = null;
        _messages[index]["fileName"] = null;
      }
    });

    final success = await ApiService.recallMessage(
      _activeConversationId!,
      msgId,
    );
    if (!success && mounted) {
      // Rollback on failure
      setState(() {
        final index = _messages.indexWhere((m) => m["id"].toString() == msgId);
        if (index != -1) {
          _messages[index]["isRecalled"] = false;
          _messages[index]["text"] = msg["text"] ?? "";
          _messages[index]["imagePath"] = msg["imagePath"];
          _messages[index]["fileName"] = msg["fileName"];
        }
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Thu hồi tin nhắn thất bại")),
      );
    }
  }

  void _startReplying(Map<String, dynamic> msg) {
    setState(() {
      _replyingTo = msg;
      _editingMessageId = null;
      _controller.clear();
    });
    _focusNode.requestFocus();
  }

  void _startEditing(Map<String, dynamic> msg) {
    if (msg["imagePath"] != null) return;
    setState(() {
      _editingMessageId = msg["id"];
      _replyingTo = null;
      _controller.text = msg["text"] ?? "";
      _showEmoji = false;
    });
    _focusNode.requestFocus();
  }

  void _showOptions(BuildContext context, Map<String, dynamic> msg) {
    final bool isRecalled = msg["isRecalled"] == true;
    if (isRecalled) return;

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Wrap(
        children: [
          ListTile(
            leading: const Icon(Icons.reply_outlined, color: Colors.blueGrey),
            title: const Text("Phản hồi"),
            onTap: () {
              Navigator.pop(context);
              _startReplying(msg);
            },
          ),
          if (msg["isSender"] == true) ...[
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
              leading: const Icon(Icons.undo_outlined, color: Colors.orange),
              title: const Text(
                "Thu hồi tin nhắn",
                style: TextStyle(color: Colors.orange),
              ),
              onTap: () {
                Navigator.pop(context);
                _recallMessage(msg);
              },
            ),
          ],
          ListTile(
            leading: const Icon(Icons.copy_outlined),
            title: const Text("Sao chép"),
            onTap: () async {
              Navigator.pop(context);
              if (msg["text"] != null && msg["text"].toString().isNotEmpty) {
                await Clipboard.setData(ClipboardData(text: msg["text"]));
              }
            },
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
            icon: Icon(Icons.more_horiz, color: _themeColor),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => ChatInfoScreen(
                    name: _currentName,
                    avatarPath: _currentAvatarPath,
                    conversationId: _activeConversationId,
                    isGroup: widget.isGroup,
                    isMuted: _isMuted,
                    themeColor: _themeColor,
                    initialMembers: _members,
                    onMuteToggle: (muted) {
                      setState(() => _isMuted = muted);
                      widget.onMuteToggle?.call(muted);
                    },
                    onThemeChanged: (newColor) {
                      setState(() => _themeColor = newColor);
                    },
                  ),
                ),
              );
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
          final lastRecord = _messages.isNotEmpty ? _messages.first : null;
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
            "isMuted": _isMuted,
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
                child: ListView.builder(
                  controller: _scrollController,
                  reverse: true,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 24,
                  ),
                  itemCount: _messages.length + (_isLoadingMore ? 1 : 0),
                  itemBuilder: (context, index) {
                    // Show loading spinner at the end of the list (which is the top when reverse: true)
                    if (_isLoadingMore && index == _messages.length) {
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

                    if (index >= _messages.length)
                      return const SizedBox.shrink();

                    final msg = _messages[index];
                    // Build replyTo preview if present
                    Map<String, dynamic>? replyData;
                    final rawReply = msg["replyTo"];
                    if (rawReply is Map) {
                      final replyText =
                          (rawReply["text"] ?? rawReply["content"] ?? "")
                              .toString();
                      final replySender =
                          (rawReply["sender"]?["fullName"] ??
                                  rawReply["sender"]?["name"] ??
                                  "")
                              .toString();
                      replyData = {
                        "id": (rawReply["_id"] ?? rawReply["id"])?.toString(),
                        "text": replyText,
                        "senderName": replySender,
                      };
                    }
                    return GestureDetector(
                      onLongPress: () => _showOptions(context, msg),
                      child: _ChatBubble(
                        message: msg["isRecalled"] == true
                            ? "Tin nhắn đã được thu hồi"
                            : (msg["text"] ?? ""),
                        isSender: msg["isSender"],
                        isSystem: msg["isSystem"] ?? false,
                        isEdited: msg["isEdited"] ?? false,
                        isRecalled: msg["isRecalled"] == true,
                        imagePath: msg["isRecalled"] == true
                            ? null
                            : msg["imagePath"],
                        fileName: msg["isRecalled"] == true
                            ? null
                            : msg["fileName"],
                        fileSize: msg["fileSize"],
                        replyTo: replyData,
                        senderName: msg["isSender"]
                            ? "Bạn"
                            : (msg["senderName"] ?? _currentName),
                        senderInitials: msg["isSender"]
                            ? "ME"
                            : (msg["senderInitials"] ??
                                  (widget.initials ??
                                      _currentName.substring(0, 1))),
                        senderAvatarPath: msg["isSender"]
                            ? ApiService.resolveImageUrl(
                                AuthService()
                                        .userProfile
                                        .value?["profilePicture"] ??
                                    AuthService().userProfile.value?["avatar"],
                              )
                            : msg["senderAvatarPath"],
                        bubbleColor: _currentColor ?? _themeColor,
                        time: msg["time"] ?? "Vừa xong",
                      ),
                    );
                  },
                ),
              ),
            ),
            if (_editingMessageId != null)
              _EditingBanner(
                themeColor: _themeColor,
                onCancel: () => setState(() {
                  _editingMessageId = null;
                  _controller.clear();
                }),
              ),
            if (_replyingTo != null)
              _ReplyBanner(
                themeColor: _themeColor,
                replyToName: _replyingTo!["senderName"] ?? "Người dùng",
                replyToText: _replyingTo!["text"] ?? "",
                onCancel: () => setState(() => _replyingTo = null),
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
              themeColor: _themeColor,
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
  final bool isRecalled;
  final String? imagePath;
  final String? fileName;
  final String? fileSize;
  final Map<String, dynamic>? replyTo;
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
    this.isRecalled = false,
    this.imagePath,
    this.fileName,
    this.fileSize,
    this.replyTo,
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
                      color: isRecalled
                          ? Colors.grey.shade100
                          : (isSender ? bubbleColor : Colors.white),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: isRecalled
                            ? Colors.grey.shade300
                            : (isSender
                                  ? Colors.transparent
                                  : Colors.grey.shade200),
                      ),
                      boxShadow: (isSender || isRecalled)
                          ? null
                          : [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.04),
                                blurRadius: 14,
                                offset: const Offset(0, 3),
                              ),
                            ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (replyTo != null && !isRecalled)
                          Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: isSender
                                  ? Colors.white.withOpacity(0.2)
                                  : Colors.grey.shade100,
                              borderRadius: BorderRadius.circular(10),
                              border: Border(
                                left: BorderSide(
                                  color: isSender
                                      ? Colors.white.withOpacity(0.7)
                                      : bubbleColor,
                                  width: 3,
                                ),
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  replyTo!["senderName"] ?? "",
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: isSender
                                        ? Colors.white.withOpacity(0.9)
                                        : bubbleColor,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  replyTo!["text"] ?? "",
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: isSender
                                        ? Colors.white.withOpacity(0.75)
                                        : Colors.grey.shade600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        Text(
                          message,
                          style: TextStyle(
                            color: isRecalled
                                ? Colors.grey.shade500
                                : (isSender ? Colors.white : Colors.black87),
                            fontSize: 14,
                            fontWeight: isRecalled
                                ? FontWeight.w400
                                : FontWeight.w500,
                            fontStyle: isRecalled
                                ? FontStyle.italic
                                : FontStyle.normal,
                            fontFamily: 'sans-serif',
                            height: 1.5,
                          ),
                        ),
                      ],
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

class _ChatInputArea extends StatefulWidget {
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
  State<_ChatInputArea> createState() => _ChatInputAreaState();
}

class _ChatInputAreaState extends State<_ChatInputArea> {
  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.of(context).size.width > 600;

    return Container(
      padding: EdgeInsets.fromLTRB(
        8,
        12,
        16,
        widget.isEmojiVisible ? 12 : MediaQuery.of(context).padding.bottom + 12,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Colors.grey.withOpacity(0.1))),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          IconButton(
            onPressed: widget.onPlus,
            icon: Icon(Icons.add_circle, color: widget.themeColor),
          ),
          IconButton(
            onPressed: widget.onCamera,
            icon: Icon(Icons.camera_alt, color: widget.themeColor),
          ),
          IconButton(
            onPressed: widget.onGallery,
            icon: Icon(Icons.image, color: widget.themeColor),
          ),
          Expanded(
            child: Container(
              constraints: const BoxConstraints(maxHeight: 120),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(24),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: Focus(
                      onKeyEvent: isDesktop
                          ? (FocusNode node, KeyEvent event) {
                              if (event is KeyDownEvent ||
                                  event is KeyRepeatEvent) {
                                final isEnter =
                                    event.logicalKey ==
                                    LogicalKeyboardKey.enter;
                                if (!isEnter) return KeyEventResult.ignored;

                                final isShift =
                                    HardwareKeyboard.instance.isShiftPressed;

                                if (isShift) {
                                  // Shift+Enter → insert newline
                                  final text = widget.controller.text;
                                  final selection = widget.controller.selection;
                                  final newText = text.replaceRange(
                                    selection.start,
                                    selection.end,
                                    '\n',
                                  );
                                  widget.controller.value = TextEditingValue(
                                    text: newText,
                                    selection: TextSelection.collapsed(
                                      offset: selection.start + 1,
                                    ),
                                  );
                                } else {
                                  // Enter → send message
                                  widget.onSend();
                                }
                                return KeyEventResult.handled;
                              }
                              return KeyEventResult.ignored;
                            }
                          : null,
                      child: TextField(
                        controller: widget.controller,
                        focusNode: widget.focusNode,
                        maxLines: null,
                        keyboardType: TextInputType.multiline,
                        textInputAction: isDesktop
                            ? TextInputAction
                                  .none // Prevent double newlines
                            : TextInputAction.send,
                        onSubmitted: isDesktop ? null : (_) => widget.onSend(),

                        decoration: const InputDecoration(
                          hintText: "Aa",
                          border: InputBorder.none,
                          hintStyle: TextStyle(color: Colors.grey),
                          contentPadding: EdgeInsets.symmetric(vertical: 10),
                        ),
                      ),
                    ),
                  ),
                  GestureDetector(
                    onTap: widget.onEmoji,
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Icon(
                        widget.isEmojiVisible
                            ? Icons.keyboard
                            : Icons.emoji_emotions_outlined,
                        size: 20,
                        color: widget.isEmojiVisible
                            ? widget.themeColor
                            : Colors.blueGrey,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            onPressed: widget.onSend,
            icon: Icon(Icons.send_rounded, color: widget.themeColor),
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

class _ReplyBanner extends StatelessWidget {
  final VoidCallback onCancel;
  final Color themeColor;
  final String replyToName;
  final String replyToText;
  const _ReplyBanner({
    required this.onCancel,
    required this.themeColor,
    required this.replyToName,
    required this.replyToText,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: themeColor.withOpacity(0.05),
        border: Border(left: BorderSide(color: themeColor, width: 3)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Icon(Icons.reply_outlined, size: 16, color: themeColor),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  replyToName,
                  style: TextStyle(
                    color: themeColor,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  replyToText.isNotEmpty ? replyToText : "[Ảnh hoặc tệp]",
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 11),
                ),
              ],
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
