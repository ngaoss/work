import 'dart:io';
import 'dart:ui';
import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
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
import '../../../../core/widgets/mention_text_controller.dart';
import '../../../../core/widgets/mention_suggestions_overlay.dart';
import '../../../../core/utils/reaction_utils.dart';

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
  final bool isMini;
  final VoidCallback? onClose;

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
    this.isMini = false,
    this.onClose,
  });

  @override
  State<ChatDetailScreen> createState() => _ChatDetailScreenState();
}

class _ChatDetailScreenState extends State<ChatDetailScreen> {
  final TextEditingController _controller = MentionTextEditingController();
  final ImagePicker _picker = ImagePicker();
  final FocusNode _focusNode = FocusNode();

  bool _showEmoji = false;
  final List<XFile> _selectedFiles = [];
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
  Color _themeColor = Colors.white;
  List<Map<String, String>> _filteredMembers = [];
  bool _showMentions = false;
  int _mentionStartIndex = -1;
  int _mentionSelectedIndex = 0;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    _scrollController.addListener(_scrollListener);

    _currentName = widget.name;
    _currentInitials = widget.initials;
    _themeColor = widget.color ?? Colors.white;
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
    _controller.addListener(_onTextChanged);
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

          // Propagate "recalled" status to any messages replying to this one
          if (newMessage["isRecalled"] == true) {
            final msgId = newMessage["id"]?.toString();
            for (int i = 0; i < _messages.length; i++) {
              if (_messages[i]["replyTo"] != null &&
                  _messages[i]["replyTo"]["id"]?.toString() == msgId) {
                _messages[i] = {
                  ..._messages[i],
                  "replyTo": {
                    ..._messages[i]["replyTo"],
                    "text": "Tin nhắn đã được thu hồi",
                    "imagePath": null,
                  },
                };
              }
            }
          }
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

    // Fallback: Extract from text if it's a file message from Web (e.g. "Đã gửi tài liệu: file.ext")
    if (finalFileName == null && msgText.contains("Đã gửi tài liệu:")) {
      finalFileName = msgText.split("Đã gửi tài liệu:").last.trim();
    }

    final replyDataRaw = msgData["replyTo"] ?? msgData["parentMessage"];
    Map<String, dynamic>? replyData;
    if (replyDataRaw != null && replyDataRaw is Map) {
      final bool isReplyRecalled =
          replyDataRaw["isRecalled"] == true ||
          replyDataRaw["status"] == "recalled" ||
          (replyDataRaw["text"] ?? "").toString().contains(
            "Tin nhắn đã được thu hồi",
          );

      replyData = {
        "id": (replyDataRaw["_id"] ?? replyDataRaw["id"])?.toString(),
        "text": isReplyRecalled
            ? "Tin nhắn đã được thu hồi"
            : (replyDataRaw["text"] ?? replyDataRaw["content"] ?? "")
                  .toString(),
        "senderName":
            replyDataRaw["sender"]?["fullName"] ??
            replyDataRaw["sender"]?["name"] ??
            (replyDataRaw["senderName"] ?? "Người dùng"),
        "imagePath": isReplyRecalled
            ? null
            : _extractMediaUrl(
                replyDataRaw["media"] ?? replyDataRaw["attachments"],
                filterVisual: true,
              ),
      };
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
      "replyTo": replyData,
      "images": _extractAllMediaUrls(
        msgData["media"] ?? msgData["attachments"],
      ),
      "imagePath": _getFilteredImagePath(
        imagePreview ??
            _extractMediaUrl(msgData["media"], filterVisual: true) ??
            _extractMediaUrl(msgData["attachments"], filterVisual: true) ??
            (msgData["imageUrl"] != null &&
                    _isVisualUrl(msgData["imageUrl"].toString())
                ? ApiService.resolveImageUrl(msgData["imageUrl"])
                : null) ??
            (msgData["image"] is String &&
                    _isVisualUrl(msgData["image"].toString())
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
      "isSystemRecall": msgText.contains("hệ thống thu hồi tự động"),
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

      // Last resort: extract from URL — but ONLY for non-image files
      final url = (item["url"] ?? item["fileUrl"] ?? item["path"] ?? "")
          .toString();
      if (url.isNotEmpty && url.contains('/') && !_isVisualUrl(url)) {
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
    _controller.removeListener(_onTextChanged);
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onTextChanged() {
    final text = _controller.text;
    final selection = _controller.selection;

    if (selection.start != selection.end || selection.start < 0) {
      if (_showMentions) setState(() => _showMentions = false);
      return;
    }

    final cursorPosition = selection.start;
    final textBeforeCursor = text.substring(0, cursorPosition);

    // Find the last '@' before cursor
    final lastAt = textBeforeCursor.lastIndexOf('@');

    if (lastAt != -1) {
      // Check if there's a space between '@' and cursor
      final textAfterAt = textBeforeCursor.substring(lastAt + 1);
      if (!textAfterAt.contains(' ')) {
        _mentionStartIndex = lastAt;
        _filterMembers(textAfterAt);
        if (!_showMentions && _filteredMembers.isNotEmpty) {
          setState(() {
            _showMentions = true;
            _mentionSelectedIndex = 0;
          });
        } else if (_showMentions && _filteredMembers.isEmpty) {
          setState(() => _showMentions = false);
        }
        return;
      }
    }

    if (_showMentions) {
      setState(() => _showMentions = false);
    }
  }

  void _filterMembers(String query) {
    setState(() {
      if (query.isEmpty) {
        _filteredMembers = List.from(_members);
      } else {
        final q = query.toLowerCase();
        _filteredMembers = _members.where((m) {
          final name = (m['fullName'] ?? m['name'] ?? '').toLowerCase();
          return name.contains(q);
        }).toList();
      }
      _mentionSelectedIndex = 0;
    });
  }

  void _insertMention(Map<String, dynamic> member) {
    final name = (member['fullName'] ?? member['name'] ?? '').toString();
    final text = _controller.text;
    final before = text.substring(0, _mentionStartIndex);
    final after = text.substring(_controller.selection.end);

    // Append Zero-Width Space (\u200B) after the name to "lock" it.
    // This prevents the regex from greedily capturing subsequent words.
    final newText = "$before@$name\u200B $after";
    _controller.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(
        offset: before.length + name.length + 3, // +1 @, +1 \u200B, +1 space
      ),
    );

    setState(() {
      _showMentions = false;
    });
    _focusNode.requestFocus();
  }

  Future<void> _pickMedia(ImageSource source) async {
    debugPrint("DEBUG: _pickMedia triggered");
    try {
      if (kIsWeb ||
          Platform.isWindows ||
          Platform.isMacOS ||
          Platform.isLinux) {
        final result = await FilePicker.platform.pickFiles(
          type: FileType.image,
          allowMultiple: true,
        );
        if (result != null && result.files.isNotEmpty) {
          setState(() {
            for (var file in result.files) {
              if (file.path != null) {
                _selectedFiles.add(XFile(file.path!));
              }
            }
          });
        }
      } else {
        final List<XFile> picked = await _picker.pickMultiImage(
          imageQuality: 85,
        );
        if (picked.isNotEmpty) {
          setState(() {
            _selectedFiles.addAll(picked);
          });
        }
      }
      debugPrint("DEBUG: _selectedFiles count: ${_selectedFiles.length}");
    } catch (e) {
      debugPrint("Error picking media: $e");
    }
  }

  Future<void> _pickFile() async {
    // debugPrint("DEBUG: _pickFile triggered");
    try {
      final result = await FilePicker.platform.pickFiles(
        allowMultiple: true,
        type: FileType.custom,
        allowedExtensions: [
          'pdf',
          'doc',
          'docx',
          'xls',
          'xlsx',
          'ppt',
          'pptx',
          'txt',
          'zip',
          'rar',
        ],
      );
      if (result == null || result.files.isEmpty) return;

      setState(() {
        for (var file in result.files) {
          if (file.path != null) {
            _selectedFiles.add(XFile(file.path!));
          }
        }
      });
      debugPrint("DEBUG: _selectedFiles count: ${_selectedFiles.length}");
    } catch (e) {
      debugPrint("File pick error: $e");
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

  bool _isSending = false;
  void _sendMessage() async {
    if (_isSending) return;

    final text = _controller.text.trim();
    if (text.isEmpty && _selectedFiles.isEmpty) return;

    _isSending = true;

    if (_editingMessageId != null) {
      setState(() {
        final index = _messages.indexWhere((m) => m["id"] == _editingMessageId);
        if (index != -1) {
          _messages[index]["text"] = text;
          _messages[index]["isEdited"] = true;
        }
        _editingMessageId = null;
        _controller.clear();
      });
      return;
    }

    if (_activeConversationId == null) return;

    final List<XFile> filesToSend = List.from(_selectedFiles);
    final List<String> optimisticImages = filesToSend
        .where(
          (f) => [
            'jpg',
            'jpeg',
            'png',
            'gif',
            'webp',
            'bmp',
          ].contains(f.path.toLowerCase().split('.').last),
        )
        .map((f) => f.path)
        .toList();
    final String? optimisticFirstImage = optimisticImages.isNotEmpty
        ? optimisticImages.first
        : null;

    final replyMsg = _replyingTo;
    final replyToId = replyMsg?["id"]?.toString();

    // Optimistic Update
    final tempId = "temp_${DateTime.now().millisecondsSinceEpoch}";
    setState(() {
      _messages.insert(0, {
        "id": tempId,
        "text": text,
        "isSender": true,
        "isUploading": filesToSend.isNotEmpty,
        "time":
            "${DateTime.now().hour}:${DateTime.now().minute.toString().padLeft(2, '0')}",
        "senderName": "Bạn",
        "imagePath": optimisticFirstImage,
        "images": optimisticImages,
        "replyTo": replyMsg != null
            ? {
                "id": replyMsg["id"],
                "text": replyMsg["text"],
                "senderName": replyMsg["senderName"],
                "imagePath": replyMsg["imagePath"],
              }
            : null,
      });
      _controller.clear();
      _selectedFiles.clear();
      _replyingTo = null;
      _showEmoji = false;
    });

    try {
      final List<Map<String, dynamic>> uploadedMedia = [];
      for (var file in filesToSend) {
        final path = file.path;
        final ext = path.toLowerCase().split('.').last;
        final isImg = [
          'jpg',
          'jpeg',
          'png',
          'gif',
          'webp',
          'bmp',
        ].contains(ext);

        if (isImg) {
          final bytes = await file.readAsBytes();
          final fileName = file.name.isNotEmpty ? file.name : "upload.jpg";
          final imageId = await ApiService.uploadImage(bytes, fileName);
          if (imageId != null) {
            String finalPath = imageId;
            // If it's a full URL, extract only the ID
            if (finalPath.startsWith('http')) {
              final uri = Uri.parse(finalPath);
              if (uri.pathSegments.isNotEmpty) {
                finalPath = uri.pathSegments.last;
              }
            }
            // Use relative API path for Web compatibility
            final relativeUrl = "/api/images/$finalPath";
            uploadedMedia.add({
              "url": relativeUrl,
              "type": "image",
              "_id": finalPath,
            });
          }
        } else {
          final docRes = await ApiService.uploadDocument(
            File(path),
            conversationId: _activeConversationId,
          );
          if (docRes != null) {
            final fileUrl =
                docRes['fileUrl'] ?? docRes['url'] ?? docRes['path'];
            final fileId = docRes['_id'] ?? docRes['id'] ?? fileUrl;
            if (fileUrl != null) {
              uploadedMedia.add({
                "url": fileUrl,
                "type": "file",
                "fileName": file.name,
                "_id": fileId,
              });
            }
          }
        }
      }

      final success = await ApiService.sendMessage(
        _activeConversationId!,
        text,
        replyTo: replyToId,
        media: uploadedMedia.isNotEmpty ? uploadedMedia : null,
      );

      if (!success) {
        setState(() => _messages.removeWhere((m) => m["id"] == tempId));
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Gửi tin nhắn thất bại")),
          );
        }
      }
      debugPrint("DEBUG: _sendMessage completed. Success: $success");
    } catch (e) {
      setState(() => _messages.removeWhere((m) => m["id"] == tempId));
      debugPrint("Error sending message: $e");
    } finally {
      _isSending = false;
    }
  }

  void _recallMessage(Map<String, dynamic> msg) async {
    final msgId = msg["id"]?.toString();
    if (msgId == null || _activeConversationId == null) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Xác nhận thu hồi"),
        content: const Text("Bạn có muốn thu hồi tin nhắn này không?"),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Hủy", style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text("Thu hồi"),
          ),
        ],
      ),
    );

    if (confirm != true) return;

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
      appBar: AppBar(
        elevation: 1,
        automaticallyImplyLeading: !widget.isMini,
        leading: widget.isMini
            ? null
            : IconButton(
                icon: const Icon(
                  Icons.arrow_back_ios,
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
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _currentName,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurface,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    widget.isOnline ? "Đang hoạt động" : "Ngoại tuyến",
                    style: TextStyle(
                      color: widget.isOnline ? Colors.green : Colors.grey,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          if (!widget.isMini)
            IconButton(
              icon: Icon(
                Icons.more_horiz,
                color:
                    _themeColor == Colors.white ||
                            _themeColor == const Color(0xFFFFFFFF)
                        ? Colors.blue
                        : _themeColor,
              ),
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
          if (widget.isMini)
            IconButton(
              icon: Icon(
                Icons.close,
                color: Theme.of(context).brightness == Brightness.dark
                    ? Colors.white70
                    : Colors.black54,
              ),
              iconSize: 20,
              onPressed: () {
                widget.onClose?.call();
              },
            ),
          const SizedBox(width: 4),
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
                      physics: const AlwaysScrollableScrollPhysics(),
                      cacheExtent: 3000,
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
                                ? (msg["isSystemRecall"] == true
                                      ? msg["text"]
                                      : "Tin nhắn đã được thu hồi")
                                : (msg["text"] ?? ""),
                            isSender: msg["isSender"],
                            isSystem: msg["isSystem"] ?? false,
                            isEdited: msg["isEdited"] ?? false,
                            isRecalled: msg["isRecalled"] == true,
                            isSystemRecall: msg["isSystemRecall"] == true,
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

                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_showMentions && _filteredMembers.isNotEmpty)
                      MentionSuggestionsOverlay(
                        suggestions: _filteredMembers,
                        onSelect: _insertMention,
                        themeColor: _themeColor,
                        selectedIndex: _mentionSelectedIndex,
                      ),
                    _ChatInputArea(
                      controller: _controller,
                      focusNode: _focusNode,
                      isEmojiVisible: _showEmoji,
                      selectedFiles: _selectedFiles,
                      onEmoji: _toggleEmoji,
                      onGallery: () => _pickMedia(ImageSource.gallery),
                      onFile: _pickFile,
                      onSurvey: _showSurveyCreator,
                      onSend: _sendMessage,
                      onRemoveFile: (index) =>
                          setState(() => _selectedFiles.removeAt(index)),
                      themeColor: _themeColor,
                      isMentionShowing: _showMentions,
                      onMentionUp: () => setState(() {
                        _mentionSelectedIndex =
                            (_mentionSelectedIndex -
                                1 +
                                _filteredMembers.length) %
                            _filteredMembers.length;
                      }),
                      onMentionDown: () => setState(() {
                        _mentionSelectedIndex =
                            (_mentionSelectedIndex + 1) %
                            _filteredMembers.length;
                      }),
                      onMentionSelect: () {
                        if (_filteredMembers.isNotEmpty) {
                          _insertMention(
                            _filteredMembers[_mentionSelectedIndex],
                          );
                        }
                      },
                      onMentionCancel: () =>
                          setState(() => _showMentions = false),
                    ),
                  ],
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
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border(top: BorderSide(color: Theme.of(context).dividerColor)),
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
  final bool isSystemRecall;
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
    this.isSystemRecall = false,
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
                  color: Theme.of(context).colorScheme.surface,
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
  bool get isSystemRecall => widget.isSystemRecall;
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

  bool _isNetworkUrl(String path) {
    return path.startsWith('http://') || path.startsWith('https://');
  }

  Widget _buildSingleImage(BuildContext context, String path) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => FullScreenMediaViewer(
              mediaList: [ApiService.resolveImageUrl(path)],
              initialIndex: 0,
            ),
          ),
        );
      },
      onLongPress: widget.onMore,
      child: Container(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.7,
          maxHeight: 500, // Reasonable maximum height
        ),
        child: Hero(
          tag: ApiService.resolveImageUrl(path),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: _isNetworkUrl(path)
                ? (path.toLowerCase().endsWith('.mp4') ||
                          path.toLowerCase().endsWith('.mov')
                      ? VideoPreview(videoUrl: path)
                      : CachedNetworkImage(
                          imageUrl: ApiService.resolveImageUrl(path),
                          fit: BoxFit.contain, // Respect aspect ratio
                          placeholder: (context, url) => Container(
                            height: 200,
                            width: 200,
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
                      : Image.file(
                          File(path),
                          fit: BoxFit.contain,
                          errorBuilder: (context, error, stackTrace) {
                            return const Center(
                              child: Icon(
                                Icons.broken_image,
                                color: Colors.red,
                              ),
                            );
                          },
                        )),
          ),
        ),
      ),
    );
  }

  Widget _buildImageGrid(BuildContext context) {
    final images = widget.images!;
    final int count = images.length;

    if (count == 1) {
      return _buildSingleImage(context, images[0]);
    }

    return Container(
      constraints: const BoxConstraints(maxWidth: 300),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: count == 2 ? 2 : 2, // Standard grid
          mainAxisSpacing: 2,
          crossAxisSpacing: 2,
          childAspectRatio: 1, // Keep squares for multi-image grid
          children: images.map((path) {
            return GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => FullScreenMediaViewer(
                      mediaList: images
                          .map((p) => ApiService.resolveImageUrl(p))
                          .toList(),
                      initialIndex: images.indexOf(path),
                    ),
                  ),
                );
              },
              onLongPress: widget.onMore,
              child: _isNetworkUrl(path)
                  ? CachedNetworkImage(
                      imageUrl: ApiService.resolveImageUrl(path),
                      fit: BoxFit.cover,
                      placeholder: (context, url) =>
                          Container(color: Colors.grey.shade100),
                    )
                  : Image.file(
                      File(path),
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return const Icon(
                          Icons.broken_image,
                          color: Colors.red,
                        );
                      },
                    ),
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
            : (Theme.of(context).brightness == Brightness.dark
                  ? Colors.white.withOpacity(0.08)
                  : Colors.black.withOpacity(0.05)),
        borderRadius: BorderRadius.circular(10),
        border: Border(
          left: BorderSide(
            color: isCodeBubble
                ? Colors.blue.shade400
                : bubbleColor,
            width: 3,
          ),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Flexible(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  replyTo["senderName"] ?? "",
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: isCodeBubble
                        ? Colors.blue.shade300
                        : (Theme.of(context).brightness == Brightness.dark
                              ? Colors.white.withOpacity(0.9)
                              : Colors.black87),
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
                        : (Theme.of(context).brightness == Brightness.dark
                              ? Colors.white.withOpacity(0.6)
                              : Colors.grey.shade600),
                  ),
                ),
              ],
            ),
          ),
          if (replyTo["imagePath"] != null) ...[
            const SizedBox(width: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: SizedBox(
                width: 40,
                height: 40,
                child: replyTo["imagePath"].toString().startsWith('http')
                    ? CachedNetworkImage(
                        imageUrl: replyTo["imagePath"],
                        fit: BoxFit.cover,
                        errorWidget: (context, url, error) =>
                            const Icon(Icons.error, size: 20),
                      )
                    : Image.file(
                        File(replyTo["imagePath"]),
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) =>
                            const Icon(Icons.image, size: 20),
                      ),
              ),
            ),
          ],
        ],
      ),
    );
  }

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

    return LayoutBuilder(
      builder: (context, constraints) {
        final availableWidth = constraints.maxWidth > 0 ? constraints.maxWidth : MediaQuery.of(context).size.width;
        final isDesktop = Theme.of(context).platform == TargetPlatform.windows || 
                          Theme.of(context).platform == TargetPlatform.macOS || 
                          Theme.of(context).platform == TargetPlatform.linux;

        final Widget bubbleOnly = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: isSender
          ? CrossAxisAlignment.end
          : CrossAxisAlignment.start,
      children: [
        if (survey != null)
          _SurveyBubble(survey: survey!, isSender: isSender, onVote: onVote),

        if (widget.images != null && widget.images!.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: _buildImageGrid(context),
          )
        else if (imagePath != null &&
            imagePath!.isNotEmpty &&
            _isVisualUrl(imagePath!))
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: _buildSingleImage(context, imagePath!),
          ),

        if (fileName != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: InkWell(
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
                  maxWidth: availableWidth * 0.75,
                ),
                decoration: BoxDecoration(
                  color: Theme.of(context).brightness == Brightness.dark
                      ? const Color(0xFF333537)
                      : Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Theme.of(context).brightness == Brightness.dark
                        ? Colors.white10
                        : Colors.grey.shade200,
                  ),
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
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: Theme.of(context).brightness == Brightness.dark
                                  ? Colors.white.withOpacity(0.9)
                                  : Colors.black87,
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
            ),
          ),

        if (message.isNotEmpty && survey == null)
          if (_isCode(message))
            GestureDetector(
              onLongPress: widget.onMore,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                constraints: BoxConstraints(
                  maxWidth: availableWidth * 0.85,
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
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                constraints: BoxConstraints(
                  maxWidth: availableWidth * 0.85,
                ),
                decoration: BoxDecoration(
                  color: isRecalled
                      ? (isSystemRecall
                            ? (Theme.of(context).brightness == Brightness.dark
                                ? const Color(0xFF3E2D1D)
                                : const Color(0xFFFFF7ED))
                            : (Theme.of(context).brightness == Brightness.dark
                                ? const Color(0xFF2E3032)
                                : Colors.grey.shade100))
                      : (Theme.of(context).brightness == Brightness.dark
                            ? const Color(0xFF333537)
                            : Colors.white),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isRecalled
                        ? (isSystemRecall
                              ? (Theme.of(context).brightness == Brightness.dark
                                  ? Colors.orange.shade800
                                  : Colors.orange.shade200)
                              : (Theme.of(context).brightness == Brightness.dark
                                  ? Colors.white10
                                  : Colors.grey.shade300))
                        : (Theme.of(context).brightness == Brightness.dark
                              ? Colors.white10
                              : Colors.grey.shade200),
                  ),
                  boxShadow: isRecalled
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
                    if (isSystemRecall)
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.only(top: 2, right: 6),
                            child: Icon(
                              Icons.info_outline_rounded,
                              size: 14,
                              color: Colors.orange.shade800,
                            ),
                          ),
                          Flexible(
                            child: _LinkifiedSelectableText(
                              text: message,
                              isSender: isSender,
                              isRecalled: isRecalled,
                              isSystemRecall: isSystemRecall,
                              bubbleColor: bubbleColor,
                            ),
                          ),
                        ],
                      )
                    else
                      _LinkifiedSelectableText(
                        text: message,
                        isSender: isSender,
                        isRecalled: isRecalled,
                        isSystemRecall: isSystemRecall,
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
                          color: Theme.of(context).brightness == Brightness.dark
                              ? Colors.grey.shade300
                              : Colors.blueGrey.shade600,
                        ),
                      ),
                    ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      if (isSender && isDesktop) _buildActionBar(),
                      Flexible(
                        child: Stack(
                          clipBehavior: Clip.none,
                        children: [
                          bubbleOnly,
                          if (!isRecalled &&
                              widget.reactions != null &&
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
                                    decoration: BoxDecoration(
                                      color: Theme.of(context).brightness == Brightness.dark
                                          ? const Color(0xFF333537)
                                          : Colors.white,
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: Theme.of(context).brightness == Brightness.dark
                                            ? Colors.white12
                                            : Colors.grey.shade200,
                                      ),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withOpacity(0.08),
                                          blurRadius: 4,
                                          offset: const Offset(0, 2),
                                        ),
                                      ],
                                    ),
                                    child: Material(
                                      color: Colors.transparent,
                                      child: InkWell(
                                        borderRadius: BorderRadius.circular(12),
                                        hoverColor: Colors.black.withOpacity(0.05),
                                        onTap: () {
                                          if (widget.reactions != null) {
                                            ReactionUtils.showReactionList(context, widget.reactions!);
                                          }
                                        },
                                        child: Padding(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 6,
                                            vertical: 2,
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
                                                    color: Theme.of(context).brightness == Brightness.dark
                                                        ? Colors.blue.shade300
                                                        : Colors.blue.shade700,
                                                  ),
                                                ),
                                              ],
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                  );
                                }).toList(),
                              ),
                          ),
                        ],
                      ),
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
    });
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
  final bool isSystemRecall;
  final Color bubbleColor;

  const _LinkifiedSelectableText({
    required this.text,
    required this.isSender,
    required this.isRecalled,
    this.isSystemRecall = false,
    required this.bubbleColor,
  });

  @override
  Widget build(BuildContext context) {
    final style = TextStyle(
      color: isRecalled
          ? (isSystemRecall ? Colors.orange.shade900 : Colors.grey.shade500)
          : (Theme.of(context).brightness == Brightness.dark
                ? Colors.white.withOpacity(0.95)
                : Colors.black87),
      fontSize: 14,
      fontWeight: isRecalled ? FontWeight.w400 : FontWeight.w500,
      fontStyle: isRecalled ? FontStyle.italic : FontStyle.normal,
      height: 1.5,
    );

    if (isRecalled) {
      return SelectableText(text, style: style);
    }

    // Regex for URLs and Mentions
    // 1. Locked mention with \u200B (modern app format)
    // 2. Fallback to capitalized words for legacy/web messages
    final combinedRegex = RegExp(
      r'(([hH][tT][tT][pP][sS]?:\/\/|[wW][wW][wW]\.)[^\s\/$.?#].[^\s]*)|' // URL
      r'(@\S+(?:\s+[^ \s@:;!?,]+)*\u200B|@\S+(?:\s+[A-ZÀ-Ỹ][^ \s@:;!?,]*)*)', // Mentions
    );

    final List<InlineSpan> spans = [];
    int start = 0;

    for (final match in combinedRegex.allMatches(text)) {
      if (match.start > start) {
        spans.add(TextSpan(text: text.substring(start, match.start)));
      }

      final matchText = match.group(0)!;
      if (matchText.startsWith('@')) {
        // Mention Style - Blue text only, no background
        spans.add(
          TextSpan(
            text: matchText.replaceAll('\u200b', ''),
            style: style.copyWith(
              color: isSender
                  ? const Color(0xFF60A5FA)
                  : const Color(0xFF0EA5E9), // Light blue for mentions
              fontWeight: FontWeight.w700,
            ),
          ),
        );
      } else {
        // URL Style
        final url = matchText;
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
      }
      start = match.end;
    }

    if (start < text.length) {
      spans.add(TextSpan(text: text.substring(start)));
    }

    return SelectableText.rich(
      TextSpan(children: spans),
      style: style,
      textAlign: isSender ? TextAlign.left : TextAlign.left,
    );
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
        color: Theme.of(context).colorScheme.surface,
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
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 13, // Smaller font
                    color: Theme.of(context).colorScheme.onSurface,
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
                    ? (Theme.of(context).brightness == Brightness.dark ? const Color(0xFF333537) : const Color(0xFFF1F5F9))
                    : (Theme.of(context).brightness == Brightness.dark ? const Color(0xFF333537) : const Color(0xFFF8FAFC)),
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
  final List<XFile> selectedFiles;
  final Function(int) onRemoveFile;
  final VoidCallback onGallery;
  final VoidCallback onFile;
  final VoidCallback onSurvey;
  final Color themeColor;
  final bool isMentionShowing;
  final VoidCallback onMentionUp;
  final VoidCallback onMentionDown;
  final VoidCallback onMentionSelect;
  final VoidCallback onMentionCancel;

  const _ChatInputArea({
    required this.controller,
    required this.focusNode,
    required this.onSend,
    required this.onEmoji,
    required this.isEmojiVisible,
    required this.selectedFiles,
    required this.onRemoveFile,
    required this.onGallery,
    required this.onFile,
    required this.onSurvey,
    this.themeColor = const Color(0xFF3B82F6),
    required this.isMentionShowing,
    required this.onMentionUp,
    required this.onMentionDown,
    required this.onMentionSelect,
    required this.onMentionCancel,
  });

  @override
  State<_ChatInputArea> createState() => _ChatInputAreaState();
}

class _ChatInputAreaState extends State<_ChatInputArea> {
  bool _isImage(String path) {
    final ext = path.toLowerCase().split('.').last;
    final isImg = ['jpg', 'jpeg', 'png', 'gif', 'webp', 'bmp'].contains(ext);
    // debugPrint("DEBUG: _isImage for path '$path' calculated ext '$ext' -> $isImg");
    return isImg;
  }

  IconData _getFileIcon(String fileName) {
    final String ext = fileName.toLowerCase().split('.').last;
    switch (ext) {
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
      case 'zip':
      case 'rar':
      case '7z':
        return Icons.archive;
      case 'mp3':
      case 'wav':
        return Icons.audio_file;
      case 'mp4':
      case 'mov':
      case 'avi':
        return Icons.video_file;
      default:
        return Icons.insert_drive_file;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.of(context).size.width > 600;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (widget.selectedFiles.isNotEmpty)
          Container(
            height: 100,
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              border: Border(
                top: BorderSide(color: Colors.grey.withOpacity(0.08)),
              ),
            ),
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: widget.selectedFiles.length + 1,
              itemBuilder: (context, index) {
                if (index == 0) {
                  // Add Button
                  return Padding(
                    padding: const EdgeInsets.only(right: 12),
                    child: Tooltip(
                      message: "Tải file khác lên",
                      preferBelow: false,
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: widget.onGallery,
                          borderRadius: BorderRadius.circular(16),
                          hoverColor: widget.themeColor.withOpacity(0.08),
                          splashColor: widget.themeColor.withOpacity(0.15),
                          highlightColor: widget.themeColor.withOpacity(0.05),
                          child: Container(
                            width: 70,
                            height: 70,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: const Color(0xFFE2E8F0),
                                width: 1.5,
                              ),
                            ),
                            child: Icon(
                              Icons.add_photo_alternate_outlined,
                              color: Colors.blueGrey.shade400,
                              size: 28,
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                }

                final fileIndex = index - 1;
                return Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.05),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: _isImage(widget.selectedFiles[fileIndex].path)
                              ? Image.file(
                                  File(widget.selectedFiles[fileIndex].path),
                                  width: 70,
                                  height: 70,
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) {
                                    return Container(
                                      width: 70,
                                      height: 70,
                                      color: const Color(0xFFF1F5F9),
                                      child: const Icon(
                                        Icons.broken_image,
                                        color: Colors.red,
                                      ),
                                    );
                                  },
                                )
                              : Container(
                                  width: 70,
                                  height: 70,
                                  color: const Color(0xFFF1F5F9),
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        _getFileIcon(
                                          widget.selectedFiles[fileIndex].name,
                                        ),
                                        color: Colors.blueGrey.shade400,
                                        size: 24,
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        widget.selectedFiles[fileIndex].name
                                            .split('.')
                                            .last
                                            .toUpperCase(),
                                        style: TextStyle(
                                          fontSize: 9,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.blueGrey.shade600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                        ),
                      ),
                      Positioned(
                        top: -6,
                        right: -6,
                        child: GestureDetector(
                          onTap: () => widget.onRemoveFile(fileIndex),
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: Colors.red.shade500,
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 2),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.15),
                                  blurRadius: 4,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: const Icon(
                              Icons.close_rounded,
                              size: 14,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        Container(
          padding: EdgeInsets.fromLTRB(
            6,
            4,
            8,
            widget.isEmojiVisible
                ? 4
                : MediaQuery.of(context).padding.bottom + 6,
          ),
          decoration: BoxDecoration(
            color: Theme.of(context).brightness == Brightness.dark
                ? const Color(0xFF252728)
                : Colors.white,
            border: Border(
              top: BorderSide(
                color: Theme.of(context).brightness == Brightness.dark
                    ? Colors.white12
                    : Colors.grey.withOpacity(0.08),
              ),
            ),
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
                      tooltip: "Gửi ảnh",
                      icon: Icon(
                        Icons.image_outlined,
                        color: Theme.of(context).brightness == Brightness.dark
                            ? Colors.white70
                            : Colors.blueGrey.shade600,
                        size: 20,
                      ),
                    ),
                    IconButton(
                      visualDensity: VisualDensity.compact,
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      constraints: const BoxConstraints(),
                      onPressed: widget.onFile,
                      tooltip: "Gửi tài liệu",
                      icon: Icon(
                        Icons.attach_file_outlined,
                        color: Theme.of(context).brightness == Brightness.dark
                            ? Colors.white70
                            : Colors.blueGrey.shade600,
                        size: 20,
                      ),
                    ),
                    IconButton(
                      visualDensity: VisualDensity.compact,
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      constraints: const BoxConstraints(),
                      onPressed: widget.onSurvey,
                      tooltip: "Tạo khảo sát",
                      icon: Icon(
                        Icons.poll_outlined,
                        color: Theme.of(context).brightness == Brightness.dark
                            ? Colors.white70
                            : Colors.blueGrey.shade600,
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
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 0,
                  ),
                  decoration: BoxDecoration(
                    color: Theme.of(context).brightness == Brightness.dark
                        ? const Color(0xFF1E1F20)
                        : const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(22),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(
                        child: Focus(
                          onKeyEvent: (FocusNode node, KeyEvent event) {
                            if (event is KeyDownEvent ||
                                event is KeyRepeatEvent) {
                              if (widget.isMentionShowing) {
                                if (event.logicalKey ==
                                    LogicalKeyboardKey.arrowDown) {
                                  widget.onMentionDown();
                                  return KeyEventResult.handled;
                                } else if (event.logicalKey ==
                                    LogicalKeyboardKey.arrowUp) {
                                  widget.onMentionUp();
                                  return KeyEventResult.handled;
                                } else if (event.logicalKey ==
                                        LogicalKeyboardKey.enter ||
                                    event.logicalKey ==
                                        LogicalKeyboardKey.numpadEnter) {
                                  widget.onMentionSelect();
                                  return KeyEventResult.handled;
                                } else if (event.logicalKey ==
                                    LogicalKeyboardKey.escape) {
                                  widget.onMentionCancel();
                                  return KeyEventResult.handled;
                                }
                              }

                              final isEnter =
                                  event.logicalKey == LogicalKeyboardKey.enter;
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
                          },
                          child: TextField(
                            controller: widget.controller,
                            focusNode: widget.focusNode,
                            maxLines: null,
                            style: TextStyle(
                              fontSize: 14,
                              height: 1.5,
                              color: Theme.of(context).brightness == Brightness.dark
                                  ? Colors.white
                                  : Colors.black87,
                            ),
                            keyboardType: TextInputType.multiline,
                            textInputAction: isDesktop
                                ? TextInputAction.none
                                : TextInputAction.send,
                            onSubmitted: isDesktop
                                ? null
                                : (_) => widget.onSend(),
                            decoration: const InputDecoration(
                              hintText: "Aa",
                              border: InputBorder.none,
                              isDense: true,
                              hintStyle: TextStyle(color: Color(0xFF94A3B8)),
                              contentPadding: EdgeInsets.symmetric(
                                vertical: 10,
                              ),
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
                                : (Theme.of(context).brightness == Brightness.dark
                                    ? Colors.white60
                                    : const Color(0xFF64748B)),
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
                      color:
                          widget.themeColor == Colors.white ||
                              widget.themeColor == const Color(0xFFFFFFFF)
                          ? const Color(0xFF3B82F6)
                          : widget.themeColor,
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
        ),
      ],
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
                          color:
                              (color == Colors.white ||
                                  color == const Color(0xFFFFFFFF))
                              ? Colors.blueGrey
                              : (color ?? Colors.blueGrey),
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

  // 1. Explicitly EXCLUDE common non-visual extensions
  if (RegExp(
    r'\.(xlsx|xls|docx|doc|pdf|zip|rar|7z|txt|csv|ppt|pptx)(\?|$)',
  ).hasMatch(lower)) {
    return false;
  }

  // 2. SUPPORT traditional visual extensions
  if (RegExp(r'\.(jpg|jpeg|png|gif|webp|mp4|mov|avi)(\?|$)').hasMatch(lower)) {
    return true;
  }

  // 3. SUPPORT API image paths (only if no conflicting extension above)
  if (lower.contains('/api/images/') ||
      lower.contains('/images/') ||
      lower.contains('/storage/images/')) {
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
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
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
                Text(
                  "TẠO KHẢO SÁT",
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 13,
                    letterSpacing: 1.2,
                    color: Theme.of(context).colorScheme.onSurface,
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
                      fillColor: Theme.of(context).brightness == Brightness.dark ? const Color(0xFF333537) : const Color(0xFFF1F5F9),
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
                                fillColor: Theme.of(context).brightness == Brightness.dark ? const Color(0xFF333537) : const Color(0xFFF1F5F9),
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
