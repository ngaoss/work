import 'dart:io';
import 'dart:ui';
import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../../core/widgets/full_screen_media_viewer.dart';
import '../../../../core/widgets/video_preview.dart';
import '../../../../core/api_service.dart';
import '../../../../core/security.dart';
import 'package:url_launcher/url_launcher.dart';
import './chat_info_screen.dart';
import 'package:flutter_highlight/flutter_highlight.dart';
import 'package:flutter_highlight/themes/atom-one-dark.dart';
import 'package:flutter/gestures.dart';

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
  final String? createdBy;
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
    this.createdBy,
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
  final List<String> _reactionEmojis = ['👍', '❤️', '😂', '😮', '😢', '🔥'];

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
    _themeColor = widget.color ?? const Color(0xFF3B82F6);
    _currentColor = _themeColor;
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
      ApiService.activeChatId = _activeConversationId;
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

    // Handle survey update event separately if needed
    if (msgData['socketEventType'] == 'survey_updated') {
      final updatedMsgId =
          (msgData['messageId'] ?? msgData['_id'] ?? msgData['id'])?.toString();
      if (updatedMsgId != null) {
        setState(() {
          final idx = _messages.indexWhere(
            (m) => m["id"]?.toString() == updatedMsgId,
          );
          if (idx != -1) {
            // Update only the survey part to keep other metadata
            _messages[idx] = {..._messages[idx], "survey": msgData["survey"]};
          }
        });
      }
      return;
    }

    if (msgData['socketEventType'] == 'message_reaction_updated') {
      // debugPrint('RECEIVED message_reaction_updated: $msgData');
      final updatedMsgId =
          (msgData['messageId'] ?? msgData['_id'] ?? msgData['id'])?.toString();
      if (updatedMsgId != null) {
        setState(() {
          final idx = _messages.indexWhere(
            (m) => m["id"]?.toString() == updatedMsgId,
          );
          if (idx != -1) {
            _messages[idx] = {
              ..._messages[idx],
              "reactions": msgData["reactions"],
            };
          }
        });
      }
      return;
    }

    if (msgData['socketEventType'] == 'chat_updated') {
      if ((msgData['_id'] ?? msgData['id'])?.toString() ==
          _activeConversationId) {
        setState(() {
          if (msgData['name'] != null)
            _currentName = msgData['name'].toString();
          if (msgData['themeColor'] != null) {
            final colorStr = msgData['themeColor'].toString().replaceFirst(
              '#',
              '',
            );
            if (colorStr.length == 6) {
              _themeColor = Color(int.parse('FF$colorStr', radix: 16));
            }
          }
          if (msgData['groupAvatar'] != null) {
            _currentAvatarPath = msgData['groupAvatar'].toString();
          }
        });
      }
      return;
    }

    if (msgData['socketEventType'] == 'messages_read_updated') {
      final reader = msgData['reader'];
      if (reader != null) {
        final readerId = (reader['_id'] ?? reader['id'])?.toString();
        setState(() {
          for (var i = 0; i < _messages.length; i++) {
            final msg = _messages[i];
            final List<dynamic> readBy = List.from(msg["readBy"] ?? []);
            final alreadyRead = readBy.any((u) {
              final id = (u is Map ? (u["_id"] ?? u["id"]) : u)?.toString();
              return id == readerId;
            });
            if (!alreadyRead) {
              _messages[i] = {
                ...msg,
                "readBy": [...readBy, reader],
              };
            }
          }
        });
      }
      return;
    }

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
      if (chatId != null &&
          _messages.where((m) => m["isSystem"] != true).length < 5) {
        idMatch = true;
        setState(() {
          _activeConversationId = chatId;
        });
      }
    }

    if (!idMatch && chatId != null) return;

    final newMessage = _parseMessage(msgData);

    setState(() {
      bool replaced = false;
      // 1. Try to replace temporary local message (sent by me, has long numeric ID)
      if (newMessage["isSender"] == true) {
        final optIndex = _messages.indexWhere((m) {
          if (m["isSender"] != true) return false;
          final mId = m["id"]?.toString() ?? '';

          // ID length check: Server IDs are usually short or specific format,
          // temp IDs generated by us are typically long timestamps.
          if (mId.length <= 10 &&
              !mId.startsWith('temp_') &&
              !mId.startsWith('file_'))
            return false;

          final mText = (m["text"] ?? '').toString().trim();
          final nText = (newMessage["text"] ?? '').toString().trim();

          final sameText = mText.isNotEmpty && mText == nText;

          bool sameSurvey = false;
          if (newMessage["survey"] != null && m["survey"] != null) {
            sameSurvey =
                newMessage["survey"]["question"] == m["survey"]["question"];
          }

          final isUploadingMedia =
              m["isUploading"] == true &&
              (newMessage["imagePath"] != null ||
                  newMessage["fileName"] != null);

          return sameText || isUploadingMedia || sameSurvey;
        });
        if (optIndex != -1) {
          _messages[optIndex] = newMessage;
          replaced = true;
        }
      }

      // 2. Try to replace message by real server ID if it already exists
      if (!replaced) {
        final existingIndex = _messages.indexWhere(
          (m) => m["id"]?.toString() == newMessage["id"]?.toString(),
        );
        if (existingIndex != -1) {
          _messages[existingIndex] = newMessage;
          replaced = true;
        }
      }

      // 3. Insert as new if not replaced
      if (!replaced) {
        final text = (newMessage["text"] ?? '').toString().trim();
        if (text.isNotEmpty ||
            newMessage["imagePath"] != null ||
            newMessage["fileName"] != null ||
            newMessage["survey"] != null ||
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
    final String? topFileUrl =
        msgData["fileUrl"]?.toString() ?? msgData["url"]?.toString();
    final String? topFileName =
        msgData["fileName"]?.toString() ?? msgData["name"]?.toString();

    // Decide if the top-level URL is a visual media or a generic file
    final String? imagePreview =
        (topFileUrl != null && _isVisualUrl(topFileUrl))
        ? ApiService.resolveImageUrl(topFileUrl)
        : null;

    final String msgText = (msgData["text"] ?? msgData["content"] ?? "")
        .toString();
    String? finalFileName =
        topFileName ??
        _extractMediaName(msgData["attachments"]) ??
        _extractMediaName(msgData["media"]);

    // Fallback: Extract from text if it's a file message from Web (e.g. "📎 Đã gửi tài liệu: file.ext")
    if (finalFileName == null && msgText.contains("📎 Đã gửi tài liệu:")) {
      finalFileName = msgText.split("📎 Đã gửi tài liệu:").last.trim();
    }

    return {
      "id":
          (msgData["_id"] ??
                  msgData["id"] ??
                  DateTime.now().millisecondsSinceEpoch)
              .toString(),
      "text": msgText,
      "isSender": isSender,
      "isRecalled":
          msgData["isRecalled"] == true || msgData["status"] == "recalled",
      "reactions": msgData["reactions"] ?? [],
      "readBy": msgData["readBy"] ?? [],
      "replyTo": msgData["replyTo"] ?? msgData["parentMessage"],
      "images": _extractAllMediaUrls(
        msgData["media"] ?? msgData["attachments"],
      ),
      "imagePath": _getFilteredImagePath(
        imagePreview ??
            _extractMediaUrl(msgData["media"], filterVisual: true) ??
            _extractMediaUrl(msgData["attachments"], filterVisual: true) ??
            (msgData["imageUrl"] != null
                ? ApiService.resolveImageUrl(msgData["imageUrl"])
                : null) ??
            (msgData["image"] is String
                ? ApiService.resolveImageUrl(msgData["image"])
                : null),
      ),
      "fileName": finalFileName,
      "fileUrl":
          _extractMediaUrl(msgData["media"]) ??
          _extractMediaUrl(msgData["attachments"]),
      "fileSize":
          _extractMediaSize(msgData["attachments"]) ??
          _extractMediaSize(msgData["media"]),
      "senderName": senderName,
      "senderAvatarPath": ApiService.resolveImageUrl(avatarRaw),
      "rawCreatedAt": msgData["createdAt"] ?? msgData["timestamp"],
      "time": _formatMessageTime(msgData["createdAt"] ?? msgData["timestamp"]),
      "isSystem": msgData["type"] == "system" || msgData["isSystem"] == true,
      "survey": msgData["survey"],
    };
  }

  List<String> _extractAllMediaUrls(dynamic mediaList) {
    if (mediaList is! List || mediaList.isEmpty) return [];
    List<String> urls = [];
    for (var item in mediaList) {
      String? url;
      if (item is Map) {
        url = (item["url"] ?? item["fileUrl"] ?? item["path"] ?? "").toString();
      } else if (item is String) {
        url = item;
      }
      if (url != null && url.isNotEmpty) {
        final resolved = ApiService.resolveImageUrl(url);
        if (_isVisualUrl(resolved)) {
          urls.add(resolved);
        }
      }
    }
    return urls;
  }

  String? _getFilteredImagePath(String? path) {
    if (path == null || path.isEmpty) return null;
    return _isVisualUrl(path) ? path : null;
  }

  /// Safely extracts an image URL from a media list which may contain
  /// either Map objects {url, path} or plain URL Strings.
  String? _extractMediaUrl(dynamic mediaList, {bool filterVisual = false}) {
    if (mediaList is! List || mediaList.isEmpty) return null;
    final item = mediaList[0];

    if (item is Map) {
      final url =
          (item["url"] ??
                  item["fileUrl"] ??
                  item["path"] ??
                  item["imageUrl"] ??
                  item["src"] ??
                  "")
              .toString();
      if (url.isEmpty) return null;

      if (filterVisual) {
        final type = (item["type"] ?? "").toString().toLowerCase();
        final lowerUrl = url.toLowerCase();
        final isVisualExt =
            lowerUrl.endsWith('.jpg') ||
            lowerUrl.endsWith('.jpeg') ||
            lowerUrl.endsWith('.png') ||
            lowerUrl.endsWith('.gif') ||
            lowerUrl.endsWith('.webp') ||
            lowerUrl.endsWith('.mp4') ||
            lowerUrl.endsWith('.mov');

        if (type == "file") {
          // Even if type is "file", if the URL has an image extension, treat it as visual
          if (!isVisualExt) return null;
        } else if (type != "image" && type != "video") {
          if (!isVisualExt) return null;
        }
      }
      return ApiService.resolveImageUrl(url);
    }

    if (item is String) return ApiService.resolveImageUrl(item);

    return null;
  }

  String? _extractMediaName(dynamic mediaList) {
    if (mediaList is! List || mediaList.isEmpty) return null;
    final item = mediaList[0];
    if (item is Map) {
      final name = item["name"]?.toString() ?? item["fileName"]?.toString();
      if (name != null && name.isNotEmpty) return name;

      // Last resort: extract from URL
      final url = (item["url"] ?? item["fileUrl"] ?? item["path"] ?? "")
          .toString();
      if (url.isNotEmpty && url.contains('/')) {
        return url.split('/').last;
      }
    }
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
    if (_activeConversationId != null &&
        ApiService.activeChatId == _activeConversationId) {
      ApiService.activeChatId = null;
    }
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
      // Pick multiple images
      List<XFile> files = [];
      if (mediaType == "image") {
        files = await _picker.pickMultiImage(imageQuality: 85);
      } else {
        final XFile? video = await _picker.pickVideo(source: source);
        if (video != null) files = [video];
      }

      if (files.isEmpty) return;

      // 1. Optimistic local preview (One message for all selected images)
      final tempId = "temp_${DateTime.now().millisecondsSinceEpoch}";
      final List<String> localPaths = files.map((f) => f.path).toList();

      setState(() {
        _messages.insert(0, {
          "id": tempId,
          "imagePath": localPaths.first,
          "images": localPaths,
          "isSender": true,
          "isUploading": true,
          "time":
              "${DateTime.now().hour}:${DateTime.now().minute.toString().padLeft(2, '0')}",
        });
      });

      // 2. Upload all files
      final List<Map<String, dynamic>> uploadedMedia = [];
      for (var file in files) {
        final bytes = await file.readAsBytes();
        final fileName = file.name.isNotEmpty
            ? file.name
            : 'media_${DateTime.now().millisecondsSinceEpoch}.jpg';
        final imageId = await ApiService.uploadImage(bytes, fileName);
        if (imageId != null) {
          uploadedMedia.add({
            "url": imageId,
            "type": mediaType,
            "_id": imageId,
          });
        }
      }

      // 3. Send single message with all media
      if (uploadedMedia.isNotEmpty && _activeConversationId != null) {
        final success = await ApiService.sendMessage(
          _activeConversationId!,
          "",
          type: mediaType,
          media: uploadedMedia,
        );

        if (success) {
          // Note: The socket listener will replace the temporary message
          // when the server broadcasts it back.
          // Or we can manually update here to resolve "isUploading" immediately
        } else {
          setState(() => _messages.removeWhere((m) => m["id"] == tempId));
        }
      } else {
        setState(() => _messages.removeWhere((m) => m["id"] == tempId));
      }
    } catch (e) {
      debugPrint("Error picking/sending media: $e");
    }
  }

  Future<void> _pickFile() async {
    try {
      final result = await FilePicker.platform.pickFiles();
      if (result == null || result.files.single.path == null) return;

      final file = File(result.files.single.path!);
      final fileName = result.files.single.name;

      // Optimistic local preview
      final tempId = "file_${DateTime.now().millisecondsSinceEpoch}";
      final isVisual =
          file.path.toLowerCase().endsWith('.jpg') ||
          file.path.toLowerCase().endsWith('.jpeg') ||
          file.path.toLowerCase().endsWith('.png') ||
          file.path.toLowerCase().endsWith('.gif') ||
          file.path.toLowerCase().endsWith('.mp4');

      setState(() {
        _messages.insert(0, {
          "id": tempId,
          "type": "file",
          "text": "",
          "isSender": true,
          "fileName": fileName,
          "fileSize": _formatBytes(file.lengthSync()),
          "imagePath": isVisual
              ? file.path
              : null, // Chỉ hiện preview nếu là ảnh/video
          "isUploading": true,
          "time":
              "${DateTime.now().hour}:${DateTime.now().minute.toString().padLeft(2, '0')}",
          "senderName": "Bạn",
        });
      });

      // Upload to server
      final response = await ApiService.uploadDocument(
        file,
        conversationId: _activeConversationId,
      );

      if (response != null && _activeConversationId != null) {
        debugPrint(
          "DEBUG [_pickFile]: activeConversationId: $_activeConversationId",
        );
        debugPrint("DEBUG [_pickFile]: Upload response: $response");
        final doc = response['data'] ?? response['document'] ?? response;
        final fileUrl = doc['url'] ?? doc['fileUrl'] ?? doc['path'] ?? "";
        final docId = (doc['_id'] ?? doc['id'])?.toString();

        if (fileUrl.isNotEmpty) {
          final isImage =
              file.path.toLowerCase().endsWith('.jpg') ||
              file.path.toLowerCase().endsWith('.jpeg') ||
              file.path.toLowerCase().endsWith('.png') ||
              file.path.toLowerCase().endsWith('.gif') ||
              file.path.toLowerCase().endsWith('.webp');
          final isVideo =
              file.path.toLowerCase().endsWith('.mp4') ||
              file.path.toLowerCase().endsWith('.mov');

          final msgType = isImage ? "image" : (isVideo ? "video" : "file");

          final success = await ApiService.sendMessage(
            _activeConversationId!,
            isImage
                ? "🖼️ Đã gửi một ảnh"
                : (isVideo
                      ? "🎥 Đã gửi một video"
                      : "📎 Đã gửi tài liệu: $fileName"),
            type: msgType,
            media: [
              {
                "url": fileUrl,
                "type": msgType,
                "name": fileName,
                "documentId": docId,
                "size": file.lengthSync(),
              },
            ],
          );

          if (success) {
            setState(() {
              final idx = _messages.indexWhere((m) => m["id"] == tempId);
              if (idx != -1) {
                _messages[idx]["isUploading"] = false;
                _messages[idx]["id"] = docId ?? tempId;
              }
            });
          } else {
            throw Exception("Failed to send socket message");
          }
        }
      } else {
        throw Exception("Upload failed");
      }
    } catch (e) {
      debugPrint("File upload error: $e");
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Tải tệp lên thất bại: $e")));
        setState(() {
          _messages.removeWhere(
            (element) => element["id"].toString().startsWith("file_"),
          );
        });
      }
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

  void _reactToMessage(String messageId, String emoji) async {
    // debugPrint('Reacting to $messageId with $emoji...');
    final success = await ApiService.reactToMessage(messageId, emoji);
    if (!success) {
      debugPrint('Failed to react to message');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Không thể thả cảm xúc. Thử lại sau."),
            duration: Duration(seconds: 1),
          ),
        );
      }
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

  void _showSurveyCreator() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _SurveyBottomSheet(
        onSend: (question, options) async {
          final surveyData = {
            "question": question,
            "options": options
                .map((opt) => {"text": opt, "votes": []})
                .toList(),
            "multipleChoice": false,
            "closed": false,
          };

          final success = await ApiService.sendMessage(
            _activeConversationId!,
            "📊 Khảo sát: $question",
            type:
                "text", // Surveys are typically text-type messages with survey object
            survey: surveyData,
          );

          if (success && mounted) {
            Navigator.pop(context);
          }
        },
      ),
    );
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
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: _reactionEmojis.map((emoji) {
                return GestureDetector(
                  onTap: () {
                    Navigator.pop(context);
                    _reactToMessage(msg["id"].toString(), emoji);
                  },
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      shape: BoxShape.circle,
                    ),
                    child: Text(emoji, style: const TextStyle(fontSize: 26)),
                  ),
                );
              }).toList(),
            ),
          ),
          const Divider(height: 1),
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
              leading: const Icon(Icons.undo_outlined, color: Colors.red),
              title: const Text(
                "Thu hồi tin nhắn",
                style: TextStyle(color: Colors.red),
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
            final lastRecord = _messages.isNotEmpty ? _messages.first : null;
            String preview = "Bắt đầu trò chuyện...";
            String updatedTime =
                "${DateTime.now().hour}:${DateTime.now().minute.toString().padLeft(2, '0')}";
            if (lastRecord != null) {
              updatedTime = lastRecord["time"] ?? updatedTime;
              if (lastRecord["isRecalled"] == true) {
                preview = "Tin nhắn đã được thu hồi";
              } else if (lastRecord["imagePath"] != null) {
                preview = lastRecord["isSender"]
                    ? "Bạn: [Đã gửi một ảnh]"
                    : "[Đã gửi một ảnh]";
              } else {
                final txt = (lastRecord["text"] ?? "").toString();
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
              color: _themeColor,
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
                    createdBy: widget.createdBy,
                    onMuteToggle: (muted) {
                      setState(() => _isMuted = muted);
                      widget.onMuteToggle?.call(muted);
                    },
                    onThemeChanged: (newColor) {
                      setState(() {
                        _themeColor = newColor;
                        _currentColor = newColor;
                      });
                    },
                    onNameChanged: (newName) {
                      setState(() => _currentName = newName);
                    },
                  ),
                ),
              ).then((result) {
                if (result == "deleted") {
                  Navigator.pop(context, {
                    "deleted": true,
                    "conversationId": _activeConversationId,
                  });
                }
              });
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
          String preview = "Bắt đầu trò chuyện...";
          if (lastRecord != null) {
            if (lastRecord["isRecalled"] == true) {
              preview = "Tin nhắn đã được thu hồi";
            } else if (lastRecord["imagePath"] != null) {
              preview = lastRecord["isSender"]
                  ? "Bạn: [Đã gửi một ảnh]"
                  : "[Đã gửi một ảnh]";
            } else {
              final txt = (lastRecord["text"] ?? "").toString();
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
        child: Stack(
          children: [
            Column(
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
                            "id": (rawReply["_id"] ?? rawReply["id"])
                                ?.toString(),
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
                            images: msg["isRecalled"] == true
                                ? null
                                : (msg["images"] as List<dynamic>?)
                                      ?.map((e) => e.toString())
                                      .toList(),
                            fileName: msg["isRecalled"] == true
                                ? null
                                : msg["fileName"],
                            fileSize: msg["fileSize"],
                            fileUrl: msg["fileUrl"],
                            replyTo: replyData,
                            survey: msg["survey"],
                            reactions: msg["reactions"],
                            readBy: index == 0 ? msg["readBy"] : null,
                            onVote: (choiceIndex) async {
                              final success = await ApiService.voteSurvey(
                                msg["id"].toString(),
                                choiceIndex,
                              );
                              if (success) {
                                _loadMessages(isPolling: true);
                              }
                            },
                            onReact: (emoji) =>
                                _reactToMessage(msg["id"].toString(), emoji),
                            senderName: msg["isSender"]
                                ? "Bạn"
                                : (msg["senderName"] ?? _currentName),
                            senderInitials: msg["isSender"]
                                ? "ME"
                                : (msg["senderInitials"] ??
                                      (widget.initials ??
                                          (_currentName.isNotEmpty
                                              ? _currentName.substring(0, 1)
                                              : "?"))),
                            senderAvatarPath: msg["isSender"]
                                ? ApiService.resolveImageUrl(
                                    AuthService()
                                            .userProfile
                                            .value?["profilePicture"] ??
                                        AuthService()
                                            .userProfile
                                            .value?["avatar"],
                                  )
                                : msg["senderAvatarPath"],
                            bubbleColor: _themeColor,
                            time: msg["time"] ?? "Vừa xong",
                            onReply: () => _startReplying(msg),
                            onRecall: msg["isSender"] == true
                                ? () => _recallMessage(msg)
                                : null,
                            onMore: () => _showOptions(context, msg),
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
                  onGallery: () => _pickMedia(ImageSource.gallery),
                  onFile: _pickFile,
                  onSurvey: _showSurveyCreator,
                  onSend: _sendMessage,
                  themeColor: _themeColor,
                ),
                if (_showEmoji && MediaQuery.of(context).size.width <= 600)
                  _EmojiPickerSheet(onSelected: _insertEmoji),
              ],
            ),
            // Desktop floating emoji picker
            if (_showEmoji && MediaQuery.of(context).size.width > 600)
              Positioned(
                bottom: 64,
                right: 16,
                child: Material(
                  elevation: 12,
                  shadowColor: Colors.black26,
                  borderRadius: BorderRadius.circular(16),
                  clipBehavior: Clip.antiAlias,
                  child: Container(
                    width: 320,
                    height: 250,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: _EmojiPickerSheet(
                      onSelected: (emoji) {
                        _insertEmoji(emoji);
                        // keep picker open after selection
                      },
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _EmojiPickerSheet extends StatefulWidget {
  final Function(String) onSelected;
  const _EmojiPickerSheet({required this.onSelected});

  @override
  State<_EmojiPickerSheet> createState() => _EmojiPickerSheetState();
}

class _EmojiPickerSheetState extends State<_EmojiPickerSheet> {
  final ScrollController _scrollController = ScrollController();

  static const List<String> emojis = [
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
  ];

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 250, // Fixed height for mobile keyboard-like feel
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Color(0xFFF1F5F9))),
      ),
      child: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 450),
          padding: const EdgeInsets.fromLTRB(16, 8, 4, 8),
          child: ScrollConfiguration(
            behavior: ScrollConfiguration.of(context).copyWith(
              dragDevices: {PointerDeviceKind.touch, PointerDeviceKind.mouse},
            ),
            child: Scrollbar(
              controller: _scrollController,
              thumbVisibility: true,
              child: GridView.builder(
                controller: _scrollController,
                padding: const EdgeInsets.only(right: 12),
                physics: const AlwaysScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 8,
                  mainAxisSpacing: 6,
                  crossAxisSpacing: 6,
                ),
                itemCount: emojis.length,
                itemBuilder: (context, index) => _EmojiItem(
                  emoji: emojis[index],
                  onTap: () => widget.onSelected(emojis[index]),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _EmojiItem extends StatefulWidget {
  final String emoji;
  final VoidCallback onTap;
  const _EmojiItem({required this.emoji, required this.onTap});

  @override
  State<_EmojiItem> createState() => _EmojiItemState();
}

class _EmojiItemState extends State<_EmojiItem> {
  bool _hovered = false;
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() {
        _hovered = false;
        _pressed = false;
      }),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        onTapDown: (_) => setState(() => _pressed = true),
        onTapUp: (_) => setState(() => _pressed = false),
        onTapCancel: () => setState(() => _pressed = false),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 100),
          decoration: BoxDecoration(
            color: _pressed
                ? const Color(0xFFDCEAFE) // Blue tint on press
                : _hovered
                ? const Color(0xFFF1F5F9) // Light grey on hover
                : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Center(
            child: AnimatedScale(
              scale: _pressed ? 0.85 : 1.0,
              duration: const Duration(milliseconds: 100),
              child: Text(
                widget.emoji,
                style: const TextStyle(fontSize: 24, color: Colors.black87),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ChatBubble extends StatefulWidget {
  final String message;
  final bool isSender;
  final bool isEdited;
  final bool isSystem;
  final bool isRecalled;
  final String? imagePath;
  final String? fileName;
  final String? fileUrl;
  final String? fileSize;
  final Map<String, dynamic>? replyTo;
  final String? senderName;
  final String? senderInitials;
  final String? senderAvatarPath;
  final Color bubbleColor;
  final String time;
  final Map<String, dynamic>? survey;
  final Function(int)? onVote;
  final VoidCallback? onReply;
  final Function(String)? onReact;
  final VoidCallback? onRecall;
  final VoidCallback? onMore;
  final List<dynamic>? reactions;
  final List<dynamic>? readBy;
  final List<String>? images;

  const _ChatBubble({
    required this.message,
    required this.isSender,
    this.isSystem = false,
    this.isEdited = false,
    this.isRecalled = false,
    this.imagePath,
    this.fileName,
    this.fileUrl,
    this.fileSize,
    this.replyTo,
    this.senderName,
    this.senderInitials,
    this.senderAvatarPath,
    this.bubbleColor = const Color(0xFF3B82F6),
    this.survey,
    this.onVote,
    this.onReply,
    this.onReact,
    this.onRecall,
    this.onMore,
    this.reactions,
    this.readBy,
    this.images,
    required this.time,
  });

  @override
  State<_ChatBubble> createState() => _ChatBubbleState();
}

class _ChatBubbleState extends State<_ChatBubble> {
  bool _hovered = false;
  bool _showReactions = false;
  final List<String> _reactionEmojis = ['👍', '❤️', '😂', '😮', '😢', '🔥'];
  final LayerLink _layerLink = LayerLink();
  OverlayEntry? _overlayEntry;

  @override
  void dispose() {
    _overlayEntry?.remove();
    super.dispose();
  }

  void _toggleReactions() {
    if (_showReactions) {
      _hideReactions();
    } else {
      _showReactionsMenu();
    }
  }

  void _showReactionsMenu() {
    _overlayEntry = _createOverlayEntry();
    Overlay.of(context).insert(_overlayEntry!);
    setState(() => _showReactions = true);
  }

  void _hideReactions() {
    _overlayEntry?.remove();
    _overlayEntry = null;
    if (mounted) setState(() => _showReactions = false);
  }

  OverlayEntry _createOverlayEntry() {
    return OverlayEntry(
      builder: (context) => Stack(
        children: [
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onTap: _hideReactions,
              child: Container(color: Colors.transparent),
            ),
          ),
          CompositedTransformFollower(
            link: _layerLink,
            showWhenUnlinked: false,
            offset: Offset(isSender ? -160 : 0, -45),
            child: Material(
              color: Colors.transparent,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.15),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: _reactionEmojis.map((emoji) {
                    return _ReactionItem(
                      emoji: emoji,
                      onTap: () {
                        widget.onReact?.call(emoji);
                        _hideReactions();
                      },
                    );
                  }).toList(),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Shorthand getters
  String get message => widget.message;
  bool get isSender => widget.isSender;
  bool get isSystem => widget.isSystem;
  bool get isEdited => widget.isEdited;
  bool get isRecalled => widget.isRecalled;
  String? get imagePath => widget.imagePath;
  String? get fileName => widget.fileName;
  String? get fileUrl => widget.fileUrl;
  String? get fileSize => widget.fileSize;
  Map<String, dynamic>? get replyTo => widget.replyTo;
  String? get senderName => widget.senderName;
  String? get senderInitials => widget.senderInitials;
  String? get senderAvatarPath => widget.senderAvatarPath;
  Color get bubbleColor => widget.bubbleColor;
  String get time => widget.time;
  Map<String, dynamic>? get survey => widget.survey;
  Function(int)? get onVote => widget.onVote;

  Map<String, int> _getGroupedReactions() {
    final Map<String, int> grouped = {};
    if (widget.reactions != null) {
      for (var reaction in widget.reactions!) {
        String? emoji;
        if (reaction is Map) {
          emoji = reaction["emoji"]?.toString();
        } else if (reaction is String) {
          emoji = reaction;
        }

        if (emoji != null && emoji.isNotEmpty) {
          grouped[emoji] = (grouped[emoji] ?? 0) + 1;
        }
      }
    }
    return grouped;
  }

  Widget _buildReadBy() {
    final myProfile = AuthService().userProfile.value;
    final String? myId = (myProfile?['_id'] ?? myProfile?['id'])?.toString();

    final List<dynamic> readers = (widget.readBy ?? []).where((u) {
      if (u == null) return false;
      String? readerId;
      if (u is Map) {
        // Handle both direct ID and nested user object
        readerId = (u["_id"] ?? u["id"] ?? u["userId"])?.toString();
        if (readerId == null && u["user"] != null && u["user"] is Map) {
          readerId = (u["user"]["_id"] ?? u["user"]["id"])?.toString();
        }
      } else {
        readerId = u.toString();
      }

      if (readerId == null || myId == null) return true;
      return readerId != myId;
    }).toList();

    if (readers.isEmpty) return const SizedBox.shrink();

    const double avatarSize = 16.0;
    const double overlap = 6.0;
    final int displayCount = math.min(readers.length, 3);
    final int extraCount = readers.length - displayCount;

    return Padding(
      padding: const EdgeInsets.only(top: 4, left: 4, right: 4),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: displayCount * (avatarSize - overlap) + overlap,
            height: avatarSize,
            child: Stack(
              children: List.generate(displayCount, (i) {
                final reader = readers[i];
                String? avatarUrl;
                if (reader is Map) {
                  avatarUrl = (reader['profilePicture'] ?? reader['avatar'])
                      ?.toString();
                }
                return Positioned(
                  left: i * (avatarSize - overlap),
                  child: Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 1.5),
                    ),
                    child: CircleAvatar(
                      radius: (avatarSize / 2) - 1.5,
                      backgroundColor: Colors.grey.shade200,
                      backgroundImage:
                          (avatarUrl != null && avatarUrl.isNotEmpty)
                          ? NetworkImage(ApiService.resolveImageUrl(avatarUrl))
                          : null,
                      child: (avatarUrl == null || avatarUrl.isEmpty)
                          ? Icon(
                              Icons.person,
                              size: avatarSize * 0.6,
                              color: Colors.grey,
                            )
                          : null,
                    ),
                  ),
                );
              }),
            ),
          ),
          const SizedBox(width: 6),
          Text(
            extraCount > 0 ? "+$extraCount" : "Đã xem",
            style: TextStyle(
              fontSize: 10,
              color: const Color.fromARGB(255, 150, 148, 148),
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionBar() {
    if (isRecalled) return const SizedBox.shrink();
    return AnimatedOpacity(
      opacity: (_hovered || _showReactions) ? 1.0 : 0.0,
      duration: const Duration(milliseconds: 150),
      child: Container(
        margin: EdgeInsets.only(
          left: isSender ? 0 : 8,
          right: isSender ? 8 : 0,
        ),
        padding: const EdgeInsets.all(2),
        decoration: const BoxDecoration(color: Colors.transparent),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            CompositedTransformTarget(
              link: _layerLink,
              child: _ActionBtn(
                icon: Icons.sentiment_satisfied_alt_outlined,
                tooltip: 'Thả cảm xúc',
                onTap: _toggleReactions,
              ),
            ),
            if (isSender)
              _ActionBtn(
                icon: Icons.delete_outline,
                tooltip: 'Thu hồi',
                onTap: widget.onRecall,
                color: Colors.red.shade300,
              ),
            _ActionBtn(
              icon: Icons.reply_outlined,
              tooltip: 'Phản hồi',
              onTap: widget.onReply,
            ),
          ],
        ),
      ),
    );
  }

  bool _isCode(String text) {
    return RegExp(
      r'const |let |var |function |def |import |public |class |#include|print\(|=>|\{.*\}|\[.*\]|;\s*$',
      multiLine: true,
    ).hasMatch(text);
  }

  String _detectLanguage(String text) {
    if (text.contains('class ') || text.contains('void main()')) return 'dart';
    if (text.contains('def ') || text.contains('import ')) {
      if (text.contains('import React') || text.contains('from "react"'))
        return 'javascript';
      return 'python';
    }
    if (text.contains('function ') ||
        text.contains('const ') ||
        text.contains('let ') ||
        text.contains('=>')) {
      return 'javascript';
    }
    if (text.contains('#include')) return 'cpp';
    return 'javascript';
  }

  bool _isVisualUrl(String url) {
    final lower = url.toLowerCase();
    return lower.endsWith('.jpg') ||
        lower.endsWith('.jpeg') ||
        lower.endsWith('.png') ||
        lower.endsWith('.gif') ||
        lower.endsWith('.webp') ||
        lower.endsWith('.mp4') ||
        lower.endsWith('.mov');
  }

  bool _isNetworkUrl(String path) {
    return path.startsWith('http://') || path.startsWith('https://');
  }

  Widget _buildSingleImage(BuildContext context, String path) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) =>
                FullScreenMediaViewer(mediaList: [path], initialIndex: 0),
          ),
        );
      },
      onLongPress: widget.onMore,
      child: Container(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.65,
        ),
        child: Hero(
          tag: path,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: _isNetworkUrl(path)
                ? (path.toLowerCase().endsWith('.mp4') ||
                          path.toLowerCase().endsWith('.mov')
                      ? VideoPreview(videoUrl: path)
                      : CachedNetworkImage(
                          imageUrl: path,
                          fit: BoxFit.cover,
                          placeholder: (context, url) => Container(
                            height: 200,
                            color: Colors.grey.shade100,
                            child: const Center(
                              child: CircularProgressIndicator(),
                            ),
                          ),
                          errorWidget: (context, url, error) =>
                              const Icon(Icons.error),
                        ))
                : (path.toLowerCase().endsWith('.mp4') ||
                          path.toLowerCase().endsWith('.mov')
                      ? VideoPreview(file: File(path))
                      : Image.file(File(path), fit: BoxFit.cover)),
          ),
        ),
      ),
    );
  }

  Widget _buildImageGrid(BuildContext context) {
    final images = widget.images!;
    final int count = images.length;

    // Use a simpler grid for 2 or more images
    return Container(
      constraints: BoxConstraints(
        maxWidth: MediaQuery.of(context).size.width * 0.7,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: count == 1 ? 1 : 2,
          mainAxisSpacing: 2,
          crossAxisSpacing: 2,
          childAspectRatio: 1,
          children: images.map((path) {
            return GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => FullScreenMediaViewer(
                      mediaList: images,
                      initialIndex: images.indexOf(path),
                    ),
                  ),
                );
              },
              onLongPress: widget.onMore,
              child: _isNetworkUrl(path)
                  ? CachedNetworkImage(
                      imageUrl: path,
                      fit: BoxFit.cover,
                      placeholder: (context, url) =>
                          Container(color: Colors.grey.shade100),
                    )
                  : Image.file(File(path), fit: BoxFit.cover),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildReplyPreview(
    Map<String, dynamic> replyTo,
    bool isSender,
    bool isCodeBubble,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: isCodeBubble
            ? Colors.white.withOpacity(0.05)
            : (isSender ? Colors.white.withOpacity(0.2) : Colors.grey.shade100),
        borderRadius: BorderRadius.circular(10),
        border: Border(
          left: BorderSide(
            color: isCodeBubble
                ? Colors.blue.shade400
                : (isSender ? Colors.white.withOpacity(0.7) : bubbleColor),
            width: 3,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            replyTo["senderName"] ?? "",
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: isCodeBubble
                  ? Colors.blue.shade300
                  : (isSender ? Colors.white.withOpacity(0.9) : bubbleColor),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            replyTo["text"] ?? "",
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 11,
              color: isCodeBubble
                  ? Colors.grey.shade400
                  : (isSender
                        ? Colors.white.withOpacity(0.75)
                        : Colors.grey.shade600),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.of(context).size.width > 600;
    if (isSystem) {
      return Center(
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 8),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.grey.shade100,
            borderRadius: BorderRadius.circular(12),
          ),
          child: SelectableText(
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

    final Widget bubbleOnly = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: isSender
          ? CrossAxisAlignment.end
          : CrossAxisAlignment.start,
      children: [
        if (survey != null)
          _SurveyBubble(survey: survey!, isSender: isSender, onVote: onVote)
        else if (widget.images != null && widget.images!.isNotEmpty)
          _buildImageGrid(context)
        else if (imagePath != null &&
            imagePath!.isNotEmpty &&
            _isVisualUrl(imagePath!))
          _buildSingleImage(context, imagePath!)
        else if (fileName != null)
          InkWell(
            onTap: () async {
              if (fileUrl != null) {
                final fullUrl = ApiService.resolveFileUrl(
                  fileUrl!,
                  fileName: fileName,
                );
                final uri = Uri.parse(fullUrl);
                await launchUrl(uri, mode: LaunchMode.externalApplication);
              }
            },
            onLongPress: widget.onMore,
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: const EdgeInsets.all(10),
              constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width * 0.75,
              ),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade200),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.04),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      _getFileIcon(fileName!),
                      color: Colors.blue,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Flexible(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          fileName!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                        if (fileSize != null) ...[
                          const SizedBox(height: 2),
                          Text(
                            fileSize!,
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
          )
        else if (_isCode(message))
          GestureDetector(
            onLongPress: widget.onMore,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width * 0.72,
              ),
              decoration: BoxDecoration(
                color: const Color(0xFF1E1E1E), // Dark background for code
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (replyTo != null && !isRecalled)
                    _buildReplyPreview(replyTo!, isSender, true),
                  SelectionArea(
                    child: HighlightView(
                      message,
                      language: _detectLanguage(message),
                      theme: atomOneDarkTheme,
                      padding: EdgeInsets.zero,
                      textStyle: const TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 12,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          )
        else
          GestureDetector(
            onLongPress: widget.onMore,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
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
                      : (isSender ? Colors.transparent : Colors.grey.shade200),
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
                    _buildReplyPreview(replyTo!, isSender, false),
                  _LinkifiedSelectableText(
                    text: message,
                    isSender: isSender,
                    isRecalled: isRecalled,
                    bubbleColor: bubbleColor,
                  ),
                ],
              ),
            ),
          ),
      ],
    );

    final Widget timeWidget = Padding(
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
          if (widget.isEdited && imagePath == null && fileName == null) ...[
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
    );

    return MouseRegion(
      onEnter: isDesktop ? (_) => setState(() => _hovered = true) : null,
      onExit: isDesktop ? (_) => setState(() => _hovered = false) : null,
      child: Container(
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
            // Action bar and bubble centered together
            Flexible(
              child: Column(
                mainAxisSize: MainAxisSize.min,
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
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      if (isSender && isDesktop) _buildActionBar(),
                      Stack(
                        clipBehavior: Clip.none,
                        children: [
                          bubbleOnly,
                          if (widget.reactions != null &&
                              widget.reactions!.isNotEmpty)
                            Positioned(
                              bottom: -8,
                              left: isSender ? -12 : null,
                              right: !isSender ? -12 : null,
                              child: Wrap(
                                spacing: 4,
                                runSpacing: 4,
                                children: _getGroupedReactions().entries.map((
                                  entry,
                                ) {
                                  return Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 6,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: Colors.grey.shade200,
                                      ),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withOpacity(0.08),
                                          blurRadius: 4,
                                          offset: const Offset(0, 2),
                                        ),
                                      ],
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          entry.key,
                                          style: const TextStyle(fontSize: 12),
                                        ),
                                        if (entry.value > 1) ...[
                                          const SizedBox(width: 2),
                                          Text(
                                            entry.value.toString(),
                                            style: TextStyle(
                                              fontSize: 10,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.blue.shade700,
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                  );
                                }).toList(),
                              ),
                            ),
                        ],
                      ),
                      if (!isSender && isDesktop) _buildActionBar(),
                    ],
                  ),
                  timeWidget,
                  _buildReadBy(),
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
      ),
    );
  }

  IconData _getFileIcon(String fileName) {
    final extension = fileName.split('.').last.toLowerCase();
    switch (extension) {
      case 'pdf':
        return Icons.picture_as_pdf;
      case 'doc':
      case 'docx':
        return Icons.description;
      case 'xls':
      case 'xlsx':
        return Icons.table_chart;
      case 'ppt':
      case 'pptx':
        return Icons.slideshow;
      case 'txt':
        return Icons.text_snippet;
      case 'zip':
      case 'rar':
      case '7z':
        return Icons.folder_zip;
      default:
        return Icons.insert_drive_file;
    }
  }

  ImageProvider? _getAvatarImageProvider(String? avatarPath) {
    if (avatarPath != null && avatarPath.isNotEmpty) {
      if (avatarPath.startsWith('http')) {
        return CachedNetworkImageProvider(avatarPath);
      }
      final resolved = ApiService.resolveImageUrl(avatarPath);
      if (resolved.startsWith('http')) {
        return CachedNetworkImageProvider(resolved);
      }
    }
    return null;
  }
}

class _LinkifiedSelectableText extends StatelessWidget {
  final String text;
  final bool isSender;
  final bool isRecalled;
  final Color bubbleColor;

  const _LinkifiedSelectableText({
    required this.text,
    required this.isSender,
    required this.isRecalled,
    required this.bubbleColor,
  });

  @override
  Widget build(BuildContext context) {
    final style = TextStyle(
      color: isRecalled
          ? Colors.grey.shade500
          : (isSender ? Colors.white : Colors.black87),
      fontSize: 14,
      fontWeight: isRecalled ? FontWeight.w400 : FontWeight.w500,
      fontStyle: isRecalled ? FontStyle.italic : FontStyle.normal,
      fontFamily: 'sans-serif',
      height: 1.5,
    );

    if (isRecalled) {
      return SelectableText(text, style: style);
    }

    // URL regex
    final urlRegex = RegExp(
      r'((https?:\/\/|www\.)[^\s\/$.?#].[^\s]*)',
      caseSensitive: false,
    );

    final List<TextSpan> spans = [];
    int start = 0;

    for (final match in urlRegex.allMatches(text)) {
      if (match.start > start) {
        spans.add(TextSpan(text: text.substring(start, match.start)));
      }

      final url = match.group(0)!;
      spans.add(
        TextSpan(
          text: url,
          style: style.copyWith(
            color: isSender ? Colors.white : Colors.blue,
            decoration: TextDecoration.underline,
            decorationColor: isSender ? Colors.white70 : Colors.blue,
          ),
          recognizer: TapGestureRecognizer()
            ..onTap = () async {
              final uriStr = url.startsWith('http') ? url : 'https://$url';
              final uri = Uri.tryParse(uriStr);
              if (uri != null) {
                await launchUrl(uri, mode: LaunchMode.externalApplication);
              }
            },
        ),
      );
      start = match.end;
    }

    if (start < text.length) {
      spans.add(TextSpan(text: text.substring(start)));
    }

    return SelectableText.rich(TextSpan(children: spans), style: style);
  }
}

class _ActionBtn extends StatefulWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback? onTap;
  final Color? color;
  const _ActionBtn({
    required this.icon,
    required this.tooltip,
    this.onTap,
    this.color,
  });

  @override
  State<_ActionBtn> createState() => _ActionBtnState();
}

class _ActionBtnState extends State<_ActionBtn> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final isDisabled = widget.onTap == null;
    return Tooltip(
      message: widget.tooltip,
      child: MouseRegion(
        onEnter: (_) {
          setState(() => _hovered = true);
        },
        onExit: (_) {
          setState(() => _hovered = false);
        },
        cursor: isDisabled
            ? SystemMouseCursors.basic
            : SystemMouseCursors.click,
        child: GestureDetector(
          onTap: widget.onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 100),
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: _hovered && !isDisabled
                  ? Colors.grey.shade100
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(
              widget.icon,
              size: 20,
              color:
                  widget.color ??
                  (_hovered && !isDisabled
                      ? Colors.blue.shade600
                      : Colors.grey.shade600),
            ),
          ),
        ),
      ),
    );
  }
}

class _ReactionItem extends StatefulWidget {
  final String emoji;
  final VoidCallback onTap;
  const _ReactionItem({required this.emoji, required this.onTap});

  @override
  State<_ReactionItem> createState() => _ReactionItemState();
}

class _ReactionItemState extends State<_ReactionItem> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedScale(
          scale: _hovered ? 1.4 : 1.0,
          duration: const Duration(milliseconds: 150),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
            child: Text(widget.emoji, style: const TextStyle(fontSize: 20)),
          ),
        ),
      ),
    );
  }
}

class _SurveyBubble extends StatelessWidget {
  final Map<String, dynamic> survey;
  final bool isSender;
  final Function(int)? onVote;

  const _SurveyBubble({
    required this.survey,
    required this.isSender,
    this.onVote,
  });

  @override
  Widget build(BuildContext context) {
    final List options = survey["options"] ?? [];
    final String question = survey["question"] ?? "";
    final String myId =
        (AuthService().userProfile.value?['_id'] ??
                AuthService().userProfile.value?['id'])
            ?.toString() ??
        "";

    int totalVotes = 0;
    for (var opt in options) {
      final votes = opt["votes"] as List? ?? [];
      totalVotes += votes.length;
    }

    return Container(
      padding: const EdgeInsets.all(8), // Reduced padding
      constraints: const BoxConstraints(maxWidth: 320),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blue.withOpacity(0.1), width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(Icons.poll_outlined, size: 14, color: Colors.blue.shade600),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  question,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 13, // Smaller font
                    color: Color(0xFF1E293B),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ...List.generate(options.length, (index) {
            final opt = options[index];
            final text = opt["text"]?.toString() ?? "";
            final votes = opt["votes"] as List? ?? [];
            final count = votes.length;
            final percent = totalVotes > 0 ? (count / totalVotes) : 0.0;

            bool isVotedByMe = false;
            for (var v in votes) {
              final vId = (v is Map ? (v["_id"] ?? v["id"]) : v)?.toString();
              if (vId == myId) {
                isVotedByMe = true;
                break;
              }
            }

            return Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: _SurveyOption(
                text: text,
                count: count,
                percent: percent,
                isVotedByMe: isVotedByMe,
                onTap: () => onVote?.call(index),
              ),
            );
          }),
          const SizedBox(height: 2),
          Center(
            child: Text(
              "$totalVotes LƯỢT BÌNH CHỌN",
              style: TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 8,
                letterSpacing: 0.4,
                color: Colors.blueGrey.shade400,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SurveyOption extends StatefulWidget {
  final String text;
  final int count;
  final double percent;
  final bool isVotedByMe;
  final VoidCallback onTap;

  const _SurveyOption({
    required this.text,
    required this.count,
    required this.percent,
    required this.isVotedByMe,
    required this.onTap,
  });

  @override
  State<_SurveyOption> createState() => _SurveyOptionState();
}

class _SurveyOptionState extends State<_SurveyOption> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        child: Stack(
          children: [
            Container(
              height: 36, // Shorter bars
              decoration: BoxDecoration(
                color: _isHovered
                    ? const Color(0xFFF1F5F9)
                    : const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: widget.isVotedByMe
                      ? Colors.blue.shade300
                      : (_isHovered
                            ? Colors.grey.shade300
                            : const Color(0xFFF1F5F9)),
                ),
              ),
            ),
            FractionallySizedBox(
              widthFactor: widget.percent,
              child: Container(
                height: 36,
                decoration: BoxDecoration(
                  color: widget.isVotedByMe
                      ? const Color(0xFFDBEAFE)
                      : const Color(0xFFE2E8F0).withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
            Container(
              height: 36,
              padding: const EdgeInsets.symmetric(horizontal: 10),
              alignment: Alignment.centerLeft,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      widget.text,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 11, // Smaller text
                        color: widget.isVotedByMe
                            ? const Color(0xFF1E40AF)
                            : const Color(0xFF475569),
                      ),
                    ),
                  ),
                  Text(
                    "${widget.count} (${(widget.percent * 100).round()}%)",
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 9,
                      color: widget.isVotedByMe
                          ? const Color(0xFF2563EB)
                          : Colors.blueGrey.shade400,
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

class _ChatInputArea extends StatefulWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final VoidCallback onSend;
  final VoidCallback onEmoji;
  final bool isEmojiVisible;
  final VoidCallback onGallery;
  final VoidCallback onFile;
  final VoidCallback onSurvey;
  final Color themeColor;

  const _ChatInputArea({
    required this.controller,
    required this.focusNode,
    required this.onSend,
    required this.onEmoji,
    required this.isEmojiVisible,
    required this.onGallery,
    required this.onFile,
    required this.onSurvey,
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
        6,
        4,
        8,
        widget.isEmojiVisible ? 4 : MediaQuery.of(context).padding.bottom + 6,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Colors.grey.withOpacity(0.08))),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment
            .end, // Align with bottom for better professional look
        children: [
          Padding(
            padding: const EdgeInsets.only(
              bottom: 6,
            ), // lift slightly from bottom
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  constraints: const BoxConstraints(),
                  onPressed: widget.onGallery,
                  icon: Icon(
                    Icons.image_outlined,
                    color: Colors.blueGrey.shade600,
                    size: 20,
                  ),
                ),
                IconButton(
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  constraints: const BoxConstraints(),
                  onPressed: widget.onFile,
                  icon: Icon(
                    Icons.attach_file_outlined,
                    color: Colors.blueGrey.shade600,
                    size: 20,
                  ),
                ),
                IconButton(
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  constraints: const BoxConstraints(),
                  onPressed: widget.onSurvey,
                  icon: Icon(
                    Icons.poll_outlined,
                    color: Colors.blueGrey.shade600,
                    size: 20,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: Container(
              constraints: const BoxConstraints(maxHeight: 150),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 0),
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(22),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
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
                        style: const TextStyle(fontSize: 14, height: 1.5),
                        keyboardType: TextInputType.multiline,
                        textInputAction: isDesktop
                            ? TextInputAction.none
                            : TextInputAction.send,
                        onSubmitted: isDesktop ? null : (_) => widget.onSend(),
                        decoration: const InputDecoration(
                          hintText: "Aa",
                          border: InputBorder.none,
                          isDense: true,
                          hintStyle: TextStyle(color: Color(0xFF94A3B8)),
                          contentPadding: EdgeInsets.symmetric(vertical: 10),
                        ),
                      ),
                    ),
                  ),
                  GestureDetector(
                    onTap: widget.onEmoji,
                    child: Padding(
                      padding: const EdgeInsets.only(left: 4),
                      child: Icon(
                        widget.isEmojiVisible
                            ? Icons.keyboard_alt_outlined
                            : Icons.sentiment_satisfied_alt_outlined,
                        size: 22,
                        color: widget.isEmojiVisible
                            ? widget.themeColor
                            : const Color(0xFF64748B),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 4),
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: IconButton(
              onPressed: widget.onSend,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              icon: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: widget.themeColor,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.send_rounded,
                  color: Colors.white,
                  size: 18,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _InputIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _InputIconButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(8),
        child: Icon(icon, color: const Color(0xFF64748B), size: 22),
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
        avatarImage = CachedNetworkImageProvider(
          avatarPath!,
          errorListener: (e) => debugPrint('Error loading header avatar: $e'),
        );
      } else if (File(avatarPath!).existsSync()) {
        avatarImage = FileImage(File(avatarPath!));
      } else {
        final resolved = ApiService.resolveImageUrl(avatarPath!);
        if (resolved.startsWith('http://') || resolved.startsWith('https://')) {
          avatarImage = CachedNetworkImageProvider(
            resolved,
            errorListener: (e) => debugPrint('Error loading header avatar: $e'),
          );
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

bool _isVisualUrl(String url) {
  if (url.isEmpty) return false;
  final lower = url.toLowerCase().trim();
  // Support traditional extensions
  if (RegExp(r'\.(jpg|jpeg|png|gif|webp|mp4|mov|avi)(\?|$)').hasMatch(lower)) {
    return true;
  }
  // Support API image paths (e.g., /api/images/[id])
  if (lower.contains('/api/images/') || lower.contains('/images/')) {
    return true;
  }
  return false;
}

class _SurveyBottomSheet extends StatefulWidget {
  final Function(String question, List<String> options) onSend;

  const _SurveyBottomSheet({required this.onSend});

  @override
  State<_SurveyBottomSheet> createState() => _SurveyBottomSheetState();
}

class _SurveyBottomSheetState extends State<_SurveyBottomSheet> {
  final TextEditingController _questionController = TextEditingController();
  final List<TextEditingController> _optionControllers = [
    TextEditingController(),
    TextEditingController(),
  ];

  @override
  void dispose() {
    _questionController.dispose();
    for (var controller in _optionControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  void _addOption() {
    if (_optionControllers.length < 10) {
      setState(() {
        _optionControllers.add(TextEditingController());
      });
    }
  }

  void _removeOption(int index) {
    if (_optionControllers.length > 2) {
      setState(() {
        final controller = _optionControllers.removeAt(index);
        controller.dispose();
      });
    }
  }

  bool _isValid() {
    if (_questionController.text.trim().isEmpty) return false;
    if (_optionControllers.any((c) => c.text.trim().isEmpty)) return false;
    return true;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle
          Center(
            child: Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  "TẠO KHẢO SÁT",
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 13,
                    letterSpacing: 1.2,
                    color: Color(0xFF1E293B),
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close, size: 20),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
          ),
          const Divider(),
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "CÂU HỎI KHẢO SÁT",
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                      color: Colors.blueGrey,
                      letterSpacing: 1,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _questionController,
                    autofocus: true,
                    decoration: InputDecoration(
                      hintText: "Bạn muốn hỏi gì?",
                      filled: true,
                      fillColor: const Color(0xFFF1F5F9),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.all(16),
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    "CÁC LỰA CHỌN",
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                      color: Colors.blueGrey,
                      letterSpacing: 1,
                    ),
                  ),
                  const SizedBox(height: 12),
                  ...List.generate(_optionControllers.length, (index) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _optionControllers[index],
                              decoration: InputDecoration(
                                hintText: "Lựa chọn ${index + 1}",
                                filled: true,
                                fillColor: const Color(0xFFF1F5F9),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(16),
                                  borderSide: BorderSide.none,
                                ),
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 14,
                                ),
                              ),
                              onChanged: (_) => setState(() {}),
                            ),
                          ),
                          if (_optionControllers.length > 2)
                            IconButton(
                              onPressed: () => _removeOption(index),
                              icon: const Icon(
                                Icons.remove_circle_outline,
                                color: Colors.redAccent,
                                size: 20,
                              ),
                            ),
                        ],
                      ),
                    );
                  }),
                  if (_optionControllers.length < 10)
                    TextButton.icon(
                      onPressed: _addOption,
                      icon: const Icon(Icons.add, size: 18),
                      label: const Text(
                        "THÊM LỰA CHỌN",
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.5,
                        ),
                      ),
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.blue.shade600,
                      ),
                    ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: SizedBox(
              width: double.infinity,
              height: 54,
              child: ElevatedButton(
                onPressed: _isValid()
                    ? () => widget.onSend(
                        _questionController.text,
                        _optionControllers.map((c) => c.text).toList(),
                      )
                    : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _isValid()
                      ? const Color(0xFF94A3B8).withOpacity(0.8)
                      : Colors.grey.shade300,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: const Text(
                  "GỬI KHẢO SÁT",
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.5,
                    fontSize: 13,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
