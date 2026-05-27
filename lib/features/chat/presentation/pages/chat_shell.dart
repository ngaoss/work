import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';

import '../../../home/presentation/pages/home_page.dart';
import '../../../personnel/presentation/pages/personnel_page.dart';
import '../../../community/presentation/pages/community_page.dart';
import '../../../profile/presentation/pages/profile_page.dart';
import '../../../reels/presentation/pages/reels_page.dart';
import '../../../documents/presentation/pages/documents_page.dart';
import 'messaging_page.dart';
import 'chat_detail_screen.dart';
import '../../../../core/security.dart';
import '../../../../core/api_service.dart';
import '../../../../core/utils/notification_helper.dart';
import '../../../../core/utils/update_helper.dart';

class ChatShell extends StatefulWidget {
  const ChatShell({super.key});

  @override
  State<ChatShell> createState() => _ChatShellState();
}

class _ChatShellState extends State<ChatShell> with WidgetsBindingObserver {
  int _currentIndex = 0;
  final Set<int> _visitedIndexes = {0};
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  List<Map<String, dynamic>> _allReels = [];
  int _initialReelIndex = 0;
  int _reelNavigationTime = 0;
  final GlobalKey<WorkHomePageState> _homeKey = GlobalKey<WorkHomePageState>();
  int _notificationCount = 0;
  List<dynamic> _notifications = [];
  bool _hasUpdate = false;
  String? _pendingChatId;
  List<Map<String, dynamic>> _miniChats = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _fetchGlobalReels();
    _fetchNotifications();
    ApiService.getMe();
    ApiService.notificationRefresh.addListener(_handleNotificationRefresh);
    Future.delayed(Duration(seconds: 3), _autoRefreshNotifications);
    ApiService.initializeSocket();
    _listenToMessagesForNotifications();
    _initNotifications();
    _checkForUpdates();
  }

  Future<void> _checkForUpdates() async {
    final result = await UpdateHelper.isUpdateAvailable();
    if (mounted) {
      setState(() {
        _hasUpdate = result;
      });
    }
  }

  Future<void> _initNotifications() async {
    await NotificationHelper.initialize();
    await NotificationHelper.requestPermissions();

    NotificationHelper.onNotificationTapped = (payload) async {
      if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
        try {
          await windowManager.show();
          await windowManager.restore();
          await windowManager.focus();
        } catch (e) {
          debugPrint('Error focusing window on notification tap: $e');
        }
      }

      if (payload != null && payload.isNotEmpty) {
        // If the payload is a chatId, navigate to it
        _navigateFromNotification({'link': '/chat/$payload'});
      }
    };
  }

  void _listenToMessagesForNotifications() {
    ApiService.newChatStream.listen((data) async {
      // debugPrint('DEBUG: Notification Data: $data');
      final messageData = data["message"] is Map ? data["message"] : data;

      // Robustly extract sender ID from both message object and top-level data
      final dynamic senderObj =
          messageData["sender"] ??
          messageData["senderId"] ??
          data["senderId"] ??
          data["sender"];

      final String senderId =
          (senderObj is Map ? (senderObj["_id"] ?? senderObj["id"]) : senderObj)
              ?.toString() ??
          "";

      var myId =
          (AuthService().userProfile.value?["_id"] ??
                  AuthService().userProfile.value?["id"])
              ?.toString();

      // If profile is missing, try to fetch it once (defensive)
      if (myId == null) {
        ApiService.getMe();
        return; // Skip this one, profile is being loaded
      }

      // 1. Don't notify for our own messages (Strict check)
      if (senderId.isNotEmpty && senderId == myId) {
        return;
      }

      // 2. Don't notify for typing indicators or internal metadata updates
      if (data['type'] == 'typing' ||
          data['isNewConversation'] == true ||
          data['isUpdateConversation'] == true) {
        return;
      }

      // 3. Only notify for actual new message events
      final socketEvent = data['_socketEvent'];
      if (socketEvent != null &&
          socketEvent != 'new_message' &&
          socketEvent != 'newMessage') {
        return;
      }

      // 4. Find the conversation ID before showing notification
      final dynamic rawChatId =
          data["chatId"] ??
          data["conversationId"] ??
          messageData["chatId"] ??
          messageData["conversationId"] ??
          (data["chat"] is Map ? data["chat"]["_id"] : data["chat"]) ??
          (messageData["chat"] is Map
              ? messageData["chat"]["_id"]
              : messageData["chat"]);

      final String? chatId = rawChatId?.toString();

      // 5. IMPORTANT: Don't notify if this is the chat user is currently looking at
      // debugPrint('Active chat check: $chatId vs ${ApiService.activeChatId}');
      if (chatId != null && chatId == ApiService.activeChatId) {
        return;
      }

      Map<String, dynamic>? chatDetails;
      if (chatId != null) {
        chatDetails = await ApiService.getChatDetails(chatId);
      }

      // Ensure it's a real message or has media attached
      final bool hasMedia =
          messageData["image"] != null ||
          messageData["video"] != null ||
          messageData["file"] != null ||
          (messageData["images"] != null && messageData["images"].isNotEmpty) ||
          messageData["audio"] != null ||
          data["image"] != null ||
          data["file"] != null;

      final bool hasText =
          messageData["text"] != null ||
          messageData["content"] != null ||
          data["text"] != null ||
          data["content"] != null;

      if (!hasText && !hasMedia) {
        return;
      }

      // Extract details for the notification with fallbacks
      final String senderName =
          (senderObj is Map
              ? (senderObj["fullName"] ?? senderObj["name"])
              : null) ??
          messageData["senderName"] ??
          data["senderName"] ??
          "Tin nhắn mới";

      final String messageText =
          messageData["text"]?.toString() ??
          messageData["content"]?.toString() ??
          data["text"]?.toString() ??
          data["content"]?.toString() ??
          "Đã gửi một tập tin";

      // Detect if it's a group message
      final chatObj =
          (data["chat"] is Map ? data["chat"] : messageData["chat"]) ??
          chatDetails;
      final String? groupName =
          data["groupName"]?.toString() ??
          messageData["groupName"]?.toString() ??
          (chatObj is Map ? chatObj["name"]?.toString() : null) ??
          (chatObj is Map ? chatObj["fullName"]?.toString() : null);

      final bool isGroup =
          (data["isGroup"] == true) ||
          (messageData["isGroup"] == true) ||
          (chatObj is Map &&
              (chatObj["isGroup"] == true || chatObj["type"] == "group")) ||
          (groupName != null && groupName.isNotEmpty);

      final String displayTitle = isGroup ? "Nhóm : $groupName" : senderName;
      final String displayBody = isGroup
          ? "$senderName : $messageText"
          : messageText;

      // Icons
      final String? senderAvatar = senderObj is Map
          ? (senderObj["profilePicture"] ?? senderObj["avatar"])?.toString()
          : (messageData["senderAvatar"] ?? data["senderAvatar"]);

      final String? groupAvatar =
          chatDetails?['avatar']?.toString() ??
          data["groupAvatar"]?.toString() ??
          messageData["groupAvatar"]?.toString() ??
          (data["chat"] is Map ? data["chat"]["avatar"]?.toString() : null);

      final String? rawIconPath = isGroup
          ? (groupAvatar ?? senderAvatar)
          : senderAvatar;
      final String? resolvedIconUrl = rawIconPath != null
          ? ApiService.resolveImageUrl(rawIconPath)
          : null;

      final int notificationId = chatId != null
          ? (chatId.hashCode.abs() % 1000000)
          : (DateTime.now().millisecondsSinceEpoch % 1000000);

      if (chatId != null) {
        NotificationHelper.showNotification(
          id: notificationId,
          title: displayTitle,
          body: displayBody,
          payload: chatId,
          imageUrl: resolvedIconUrl,
          checkMute: true,
        );
      }
    });
  }

  void _handleNotificationRefresh() {
    // debugPrint('DEBUG: notificationRefresh triggered');
    _fetchNotifications();
  }

  @override
  void dispose() {
    ApiService.notificationRefresh.removeListener(_handleNotificationRefresh);
    WidgetsBinding.instance.removeObserver(this);
    ApiService.disposeSocket();
    super.dispose();
  }

  Future<void> _autoRefreshNotifications() async {
    if (mounted) {
      // debugPrint('DEBUG: Auto-refreshing notifications');
      await _fetchNotifications();
      // Schedule next refresh
      Future.delayed(Duration(seconds: 3), _autoRefreshNotifications);
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _fetchNotifications();
    }
  }

  Future<void> _fetchGlobalReels() async {
    final reels = await ApiService.getReels();
    if (mounted) {
      setState(() {
        _allReels = List<Map<String, dynamic>>.from(reels);
      });
    }
  }

  Future<void> _fetchNotifications() async {
    // debugPrint('DEBUG: _fetchNotifications called');
    try {
      final notifications = await ApiService.getNotifications();
      // debugPrint('DEBUG: getNotifications returned');
      if (mounted) {
        // Sort by createdAt descending
        notifications.sort((a, b) {
          final aTime =
              DateTime.tryParse(a['createdAt']?.toString() ?? '') ??
              DateTime.now();
          final bTime =
              DateTime.tryParse(b['createdAt']?.toString() ?? '') ??
              DateTime.now();
          return bTime.compareTo(aTime);
        });

        // debugPrint('DEBUG: Fetched ${notifications.length} notifications');
        // for (var n in notifications) {
        //   debugPrint('DEBUG: Notification: ${n['type']} - ${n['content']}');
        // }

        final latestNotifications = notifications.take(10).toList();
        // debugPrint('DEBUG: Setting state with ${latestNotifications.length} latest notifications');
        setState(() {
          _notifications = latestNotifications;
          _notificationCount = latestNotifications
              .where((n) => n['isRead'] != true)
              .length;
          // debugPrint('DEBUG: After setState - _notificationCount=$_notificationCount, _notifications.length=${_notifications.length}');
          // debugPrint('DEBUG: Unread notifications:');
          // for (var n in _notifications.where((n) => n['isRead'] != true)) {
          //   debugPrint('  - ${n['content']} (isRead=${n['isRead']})');
          // }
        });
      } else {
        // debugPrint('DEBUG: Widget not mounted, skipping setState');
      }
    } catch (e) {
      // debugPrint('DEBUG: Error in _fetchNotifications: $e');
    }
  }

  void _showNotifications() {
    setState(() {
      _notificationCount = 0;
      for (var notification in _notifications) {
        notification['isRead'] = true;
      }
    });

    // Notify the server that notifications are read
    ApiService.markNotificationsAsRead();
    if (MediaQuery.of(context).size.width > 1100) {
      _showDesktopNotifications();
      return;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => Container(
          height: MediaQuery.of(context).size.height * 0.75,
          decoration: BoxDecoration(
            color: Theme.of(ctx).brightness == Brightness.dark ? const Color(0xFF252728) : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  vertical: 16,
                  horizontal: 16,
                ),
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Theme.of(ctx).brightness == Brightness.dark ? Colors.grey.shade800 : Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: Icon(
                        Icons.refresh,
                        size: 20,
                        color: Theme.of(ctx).brightness == Brightness.dark ? Colors.white70 : Colors.black87,
                      ),
                      onPressed: () async {
                        setModalState(() {});
                        await _fetchNotifications();
                        setModalState(() {});
                      },
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.only(bottom: 16),
                child: Text(
                  'THÔNG BÁO (${_notifications.length})',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    letterSpacing: 0.5,
                    color: Theme.of(ctx).brightness == Brightness.dark ? Colors.white : Colors.black87,
                  ),
                ),
              ),
              Divider(
                height: 1,
                color: Theme.of(ctx).brightness == Brightness.dark ? Colors.white12 : null,
              ),
              Expanded(
                child: _notifications.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.notifications_none_outlined,
                              size: 48,
                              color: Theme.of(ctx).brightness == Brightness.dark ? Colors.white30 : Colors.grey.shade300,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'Chưa có thông báo nào',
                              style: TextStyle(
                                color: Theme.of(ctx).brightness == Brightness.dark ? Colors.white38 : Colors.grey.shade400,
                              ),
                            ),
                          ],
                        ),
                      )
                    : Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: ListView.builder(
                          itemCount: _notifications.length,
                          itemBuilder: (ctx, i) {
                            final notification = _notifications[i];
                            final senders =
                                notification['senders'] as List<dynamic>? ?? [];
                            final sender = senders.isNotEmpty
                                ? senders[0]
                                : null;
                            final String senderName =
                                sender?['fullName']?.toString() ?? 'Người dùng';
                            final String? senderAvatar =
                                sender?['profilePicture']?.toString();
                            final String type =
                                notification['type']?.toString() ?? 'Thông báo';
                            final String content =
                                notification['content']?.toString() ?? '';
                            final String createdAt =
                                notification['createdAt']?.toString() ?? '';
                            final String link =
                                notification['link']?.toString() ?? '';
                            final bool isRead = notification['isRead'] == true;

                            // Format time
                            String timeDisplay = 'Vừa xong';
                            if (createdAt.isNotEmpty) {
                              try {
                                final date = DateTime.parse(createdAt);
                                final now = DateTime.now();
                                final diff = now.difference(date);
                                if (diff.inDays > 0) {
                                  timeDisplay = '${diff.inDays}d';
                                } else if (diff.inHours > 0) {
                                  timeDisplay = '${diff.inHours}h';
                                } else if (diff.inMinutes > 0) {
                                  timeDisplay = '${diff.inMinutes}m';
                                } else {
                                  timeDisplay = 'now';
                                }
                              } catch (e) {
                                timeDisplay = createdAt;
                              }
                            }

                            // Get type display name
                            String typeDisplay = '';
                            if (type.contains('reply')) {
                              typeDisplay = '📬';
                            } else if (type.contains('message')) {
                              typeDisplay = '💬';
                            } else {
                              typeDisplay = '📢';
                            }

                            return Column(
                              children: [
                                InkWell(
                                   highlightColor: Theme.of(ctx).brightness == Brightness.dark
                                       ? Colors.white.withOpacity(0.05)
                                       : Colors.black.withOpacity(0.05),
                                   splashColor: Theme.of(ctx).brightness == Brightness.dark
                                       ? Colors.white.withOpacity(0.05)
                                       : Colors.black.withOpacity(0.05),
                                   hoverColor: Theme.of(ctx).brightness == Brightness.dark
                                       ? Colors.white.withOpacity(0.025)
                                       : Colors.black.withOpacity(0.025),
                                   onTap: () {
                                     // Mark as read
                                     setState(() {
                                       notification['isRead'] = true;
                                       _notificationCount =
                                           _notifications
                                               .where(
                                                 (n) =>
                                                     n['isRead'] != true,
                                               )
                                               .length;
                                     });
                                     Navigator.pop(
                                       ctx,
                                     ); // Close bottom sheet
                                     _navigateFromNotification(
                                       notification,
                                     );
                                   },
                                   child: Padding(
                                     padding: const EdgeInsets.symmetric(
                                       vertical: 8,
                                       horizontal: 12,
                                     ),
                                     child: Row(
                                       crossAxisAlignment:
                                           CrossAxisAlignment.start,
                                        children: [
                                          // Avatar
                                          FutureBuilder<Map<String, String>>(
                                            future: ApiService.getAuthHeaders(),
                                            builder: (context, headers) {
                                              return CircleAvatar(
                                                radius: 20,
                                                backgroundColor: Theme.of(ctx).brightness == Brightness.dark
                                                    ? const Color(0xFF1E1F20)
                                                    : Colors.blueGrey.shade100,
                                                backgroundImage:
                                                    senderAvatar != null
                                                    ? NetworkImage(
                                                        ApiService.resolveImageUrl(
                                                          senderAvatar,
                                                        ),
                                                        headers: headers.data,
                                                      )
                                                    : null,
                                                child: senderAvatar == null
                                                    ? Text(
                                                        senderName.isNotEmpty
                                                            ? senderName[0]
                                                                  .toUpperCase()
                                                            : 'U',
                                                        style: TextStyle(
                                                          color: Theme.of(ctx).brightness == Brightness.dark ? Colors.white70 : Colors.white,
                                                          fontSize: 12,
                                                          fontWeight:
                                                              FontWeight.bold,
                                                        ),
                                                      )
                                                    : null,
                                              );
                                            },
                                          ),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                // Name and notification type badge
                                                Row(
                                                  children: [
                                                    Expanded(
                                                      child: Text(
                                                        senderName,
                                                        style: TextStyle(
                                                          fontWeight:
                                                              FontWeight.bold,
                                                          fontSize: 13,
                                                          color: Theme.of(ctx).brightness == Brightness.dark ? Colors.white.withOpacity(0.9) : Colors.black87,
                                                        ),
                                                      ),
                                                    ),
                                                    Container(
                        padding:
                                                          const EdgeInsets.symmetric(
                                                            horizontal: 6,
                                                            vertical: 2,
                                                          ),
                                                      decoration: BoxDecoration(
                                                        color: isRead
                                                            ? (Theme.of(ctx).brightness == Brightness.dark ? Colors.grey.shade800 : Colors.grey.shade200)
                                                            : const Color(
                                                                0xFFE3F2FD,
                                                              ),
                                                        borderRadius:
                                                            BorderRadius.circular(
                                                              12,
                                                            ),
                                                      ),
                                                      child: Text(
                                                        typeDisplay,
                                                        style: const TextStyle(
                                                          fontSize: 10,
                                                        ),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                                const SizedBox(height: 4),
                                                // Content
                                                Padding(
                                                  padding:
                                                      const EdgeInsets.only(
                                                        right: 12,
                                                      ),
                                                  child: Text(
                                                    content,
                                                    maxLines: 2,
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                    style: TextStyle(
                                                      fontSize: 13,
                                                      color: Theme.of(ctx).brightness == Brightness.dark ? Colors.white60 : Colors.black54,
                                                      fontWeight: isRead
                                                          ? FontWeight.normal
                                                          : FontWeight.w500,
                                                    ),
                                                  ),
                                                ),
                                                const SizedBox(height: 4),
                                                // Time
                                                Text(
                                                  timeDisplay,
                                                  style: TextStyle(
                                                    fontSize: 11,
                                                    color: Theme.of(ctx).brightness == Brightness.dark ? Colors.white30 : Colors.grey,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                Divider(
                                  height: 1,
                                  indent: 52,
                                  color: Theme.of(ctx).brightness == Brightness.dark ? Colors.white12 : null,
                                ),
                              ],
                            );
                          },
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showDesktopChats() {
    String currentFilter = 'all';
    final Future<List<dynamic>> chatsFuture = ApiService.getChats();

    showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.01),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setStatePopup) {
          return Stack(
            children: [
              Positioned(
                top: 75,
                right: 220,
                child: Material(
                  color: Colors.transparent,
                  child: Container(
                    width: 360,
                    height: 500,
                    decoration: BoxDecoration(
                      color: Theme.of(ctx).brightness == Brightness.dark ? const Color(0xFF252728) : Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.15),
                          blurRadius: 20,
                          offset: const Offset(0, 10),
                        ),
                      ],
                      border: Border.all(
                        color: Theme.of(ctx).brightness == Brightness.dark ? Colors.white12 : Colors.grey.shade200,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(
                            top: 16,
                            left: 16,
                            right: 8,
                            bottom: 8,
                          ),
                          child: Row(
                            children: [
                              Text(
                                "Đoạn chat",
                                style: TextStyle(
                                  color: Theme.of(ctx).brightness == Brightness.dark ? Colors.white : Colors.black,
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const Spacer(),
                              IconButton(
                                splashRadius: 20,
                                icon: Icon(
                                  Icons.open_in_full,
                                  size: 20,
                                  color: Theme.of(ctx).brightness == Brightness.dark ? Colors.white70 : Colors.black54,
                                ),
                                tooltip: "Mở toàn màn hình",
                                onPressed: () {
                                  Navigator.pop(ctx);
                                  _onItemTapped(6); // Navigate to full chat
                                },
                              ),
                              IconButton(
                                splashRadius: 20,
                                icon: Icon(
                                  Icons.edit_square,
                                  size: 20,
                                  color: Theme.of(ctx).brightness == Brightness.dark ? Colors.white70 : Colors.black54,
                                ),
                                tooltip: "Tin nhắn mới",
                                onPressed: () {
                                  // Optional: Handle new message action
                                },
                              ),
                            ],
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 4,
                          ),
                          child: Row(
                            children: [
                              GestureDetector(
                                onTap: () =>
                                    setStatePopup(() => currentFilter = 'all'),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    color: currentFilter == 'all'
                                        ? (Theme.of(ctx).brightness == Brightness.dark ? const Color(0xFF1E3A8A) : const Color(0xFFE8F3FF))
                                        : Colors.transparent,
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Text(
                                    "Tất cả",
                                    style: TextStyle(
                                      color: currentFilter == 'all'
                                          ? (Theme.of(ctx).brightness == Brightness.dark ? const Color(0xFF93C5FD) : const Color(0xFF0064D1))
                                          : (Theme.of(ctx).brightness == Brightness.dark ? Colors.white70 : Colors.black54),
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              GestureDetector(
                                onTap: () => setStatePopup(
                                  () => currentFilter = 'unread',
                                ),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    color: currentFilter == 'unread'
                                        ? (Theme.of(ctx).brightness == Brightness.dark ? const Color(0xFF1E3A8A) : const Color(0xFFE8F3FF))
                                        : Colors.transparent,
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Text(
                                    "Chưa đọc",
                                    style: TextStyle(
                                      color: currentFilter == 'unread'
                                          ? (Theme.of(ctx).brightness == Brightness.dark ? const Color(0xFF93C5FD) : const Color(0xFF0064D1))
                                          : (Theme.of(ctx).brightness == Brightness.dark ? Colors.white70 : Colors.black54),
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              GestureDetector(
                                onTap: () => setStatePopup(
                                  () => currentFilter = 'group',
                                ),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    color: currentFilter == 'group'
                                        ? (Theme.of(ctx).brightness == Brightness.dark ? const Color(0xFF1E3A8A) : const Color(0xFFE8F3FF))
                                        : Colors.transparent,
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Text(
                                    "Nhóm",
                                    style: TextStyle(
                                      color: currentFilter == 'group'
                                          ? (Theme.of(ctx).brightness == Brightness.dark ? const Color(0xFF93C5FD) : const Color(0xFF0064D1))
                                          : (Theme.of(ctx).brightness == Brightness.dark ? Colors.white70 : Colors.black54),
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 8),
                        Expanded(
                          child: FutureBuilder<List<dynamic>>(
                            future: chatsFuture,
                            builder: (context, snapshot) {
                              if (snapshot.connectionState ==
                                  ConnectionState.waiting) {
                                return Center(
                                  child: CircularProgressIndicator(
                                    color: Theme.of(ctx).brightness == Brightness.dark ? Colors.white30 : Colors.black26,
                                  ),
                                );
                              }
                              final allChats = snapshot.data ?? [];
                              final myId =
                                  (AuthService().userProfile.value?['_id'] ??
                                          AuthService()
                                              .userProfile
                                              .value?['id'])
                                      ?.toString();

                              final chats = allChats.where((chat) {
                                final isGroup =
                                    chat['isGroup'] == true ||
                                    chat['type'] == 'group';

                                final isUnread =
                                    (chat['unreadCount'] as num? ?? 0) > 0;

                                if (currentFilter == 'unread') return isUnread;
                                if (currentFilter == 'group') return isGroup;
                                return true;
                              }).toList();

                              if (chats.isEmpty) {
                                return Center(
                                  child: Text(
                                    "Không có cuộc trò chuyện nào",
                                    style: TextStyle(
                                      color: Theme.of(ctx).brightness == Brightness.dark ? Colors.white54 : Colors.black54,
                                    ),
                                  ),
                                );
                              }
                              return ListView.builder(
                                padding: EdgeInsets.zero,
                                itemCount: chats.length,
                                itemBuilder: (context, index) {
                                  final chat = chats[index];
                                  final isGroup =
                                      chat['isGroup'] == true ||
                                      chat['type'] == 'group';
                                  final groupName =
                                      chat['name']?.toString() ??
                                      chat['groupName']?.toString();

                                  String chatName = "Chat";
                                  String? chatAvatar;

                                  if (isGroup) {
                                    chatName = groupName ?? "Nhóm không tên";
                                    chatAvatar =
                                        chat['groupAvatar']?.toString() ??
                                        chat['avatar']?.toString();
                                  } else {
                                    final members =
                                        chat['participants']
                                            as List<dynamic>? ??
                                        chat['members'] as List<dynamic>? ??
                                        [];
                                    final otherMember = members.firstWhere((m) {
                                      if (m is! Map) return false;
                                      final mId = (m['_id'] ?? m['id'])
                                          ?.toString();
                                      final myId =
                                          (AuthService()
                                                      .userProfile
                                                      .value?['_id'] ??
                                                  AuthService()
                                                      .userProfile
                                                      .value?['id'])
                                              ?.toString();
                                      return mId != null &&
                                          myId != null &&
                                          mId != myId;
                                    }, orElse: () => null);
                                    chatName =
                                        chat['name']?.toString() ??
                                        otherMember?['fullName']?.toString() ??
                                        otherMember?['name']?.toString() ??
                                        "Người dùng";
                                    chatAvatar =
                                        otherMember?['profilePicture']
                                            ?.toString() ??
                                        otherMember?['avatar']?.toString();
                                  }

                                  final lastMessage = chat['lastMessage'];
                                  String messageText = "";
                                  String timeDisplay = "";
                                  bool isUnread = false;

                                  if (lastMessage != null &&
                                      lastMessage is Map) {
                                    final text =
                                        lastMessage['text']?.toString() ?? "";
                                    if (text.startsWith("IMAGE:")) {
                                      messageText = "Đã gửi một ảnh";
                                    } else if (text.startsWith("FILE:")) {
                                      messageText = "Đã gửi một tệp đính kèm";
                                    } else {
                                      messageText = text;
                                    }

                                    final createdAt =
                                        lastMessage['createdAt']?.toString() ??
                                        "";
                                    if (createdAt.isNotEmpty) {
                                      try {
                                        final date = DateTime.parse(createdAt);
                                        final now = DateTime.now();
                                        final diff = now.difference(date);
                                        if (diff.inDays > 0) {
                                          timeDisplay = '${diff.inDays} ngày';
                                        } else if (diff.inHours > 0) {
                                          timeDisplay = '${diff.inHours} giờ';
                                        } else if (diff.inMinutes > 0) {
                                          timeDisplay =
                                              '${diff.inMinutes} phút';
                                        } else {
                                          timeDisplay = 'Vừa xong';
                                        }
                                      } catch (_) {}
                                    }

                                    final lastReadBy =
                                        chat['lastReadBy'] as List<dynamic>? ??
                                        [];
                                    final myId =
                                        (AuthService()
                                                    .userProfile
                                                    .value?['_id'] ??
                                                AuthService()
                                                    .userProfile
                                                    .value?['id'])
                                            ?.toString();
                                    isUnread =
                                        (chat['unreadCount'] as num? ?? 0) > 0;
                                  }

                                  return InkWell(
                                    highlightColor: Theme.of(ctx).brightness == Brightness.dark
                                        ? Colors.white.withOpacity(0.05)
                                        : Colors.black.withOpacity(0.05),
                                    splashColor: Theme.of(ctx).brightness == Brightness.dark
                                        ? Colors.white.withOpacity(0.05)
                                        : Colors.black.withOpacity(0.05),
                                    hoverColor: Theme.of(ctx).brightness == Brightness.dark
                                        ? Colors.white.withOpacity(0.025)
                                        : Colors.black.withOpacity(0.025),
                                    onTap: () {
                                      Navigator.pop(ctx);
                                      final chatId =
                                          chat['_id']?.toString() ??
                                          chat['id']?.toString();
                                      if (chatId != null) {
                                        if (!_miniChats.any(
                                          (c) => c['id'] == chatId,
                                        )) {
                                          setState(() {
                                            if (_miniChats.length >= 2)
                                              _miniChats.removeAt(0);
                                            _miniChats.add({
                                              'id': chatId,
                                              'name': chatName,
                                              'avatarPath': chatAvatar,
                                              'isGroup': isGroup,
                                              'isOnline': false,
                                              'createdBy': chat['createdBy'],
                                            });
                                          });
                                        }
                                      }
                                    },
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 16,
                                        vertical: 8,
                                      ),
                                      child: Row(
                                        children: [
                                          CircleAvatar(
                                            radius: 28,
                                            backgroundColor: Theme.of(ctx).brightness == Brightness.dark
                                                ? const Color(0xFF1E1F20)
                                                : Colors.grey.shade200,
                                            backgroundImage:
                                                chatAvatar != null &&
                                                    chatAvatar
                                                        .toString()
                                                        .trim()
                                                        .isNotEmpty
                                                ? NetworkImage(
                                                    ApiService.resolveImageUrl(
                                                      chatAvatar,
                                                    ),
                                                  )
                                                : null,
                                            child:
                                                chatAvatar == null ||
                                                    chatAvatar
                                                        .toString()
                                                        .trim()
                                                        .isEmpty
                                                ? Icon(
                                                    Icons.person,
                                                    color: Theme.of(ctx).brightness == Brightness.dark ? Colors.white38 : Colors.black38,
                                                  )
                                                : null,
                                          ),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              mainAxisAlignment:
                                                  MainAxisAlignment.center,
                                              children: [
                                                Text(
                                                  chatName,
                                                  style: TextStyle(
                                                    color: Theme.of(context).brightness == Brightness.dark
                                                        ? Colors.white.withOpacity(0.95)
                                                        : Colors.black87,
                                                    fontSize: 15,
                                                    fontWeight: isUnread
                                                        ? FontWeight.w700
                                                        : FontWeight.w500,
                                                  ),
                                                  maxLines: 1,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                ),
                                                const SizedBox(height: 4),
                                                Row(
                                                  children: [
                                                    Expanded(
                                                      child: Text(
                                                        messageText.isEmpty
                                                            ? "Chưa có tin nhắn"
                                                            : messageText,
                                                        style: TextStyle(
                                                          color: isUnread
                                                              ? (Theme.of(context).brightness == Brightness.dark
                                                                  ? Colors.white
                                                                  : Colors.black87)
                                                              : (Theme.of(context).brightness == Brightness.dark
                                                                  ? Colors.white60
                                                                  : Colors.black45),
                                                          fontSize: 13,
                                                          fontWeight: isUnread
                                                              ? FontWeight.w700
                                                              : FontWeight.normal,
                                                        ),
                                                        maxLines: 1,
                                                        overflow: TextOverflow
                                                            .ellipsis,
                                                      ),
                                                    ),
                                                    if (timeDisplay
                                                        .isNotEmpty) ...[
                                                      Text(
                                                        " · $timeDisplay",
                                                        style: TextStyle(
                                                          color: isUnread
                                                              ? (Theme.of(context).brightness == Brightness.dark
                                                                  ? Colors.blue.shade300
                                                                  : Colors.blue.shade700)
                                                              : (Theme.of(context).brightness == Brightness.dark
                                                                  ? Colors.white30
                                                                  : Colors.grey),
                                                          fontSize: 13,
                                                          fontWeight: isUnread
                                                              ? FontWeight.w600
                                                              : FontWeight.normal,
                                                        ),
                                                      ),
                                                    ],
                                                  ],
                                                ),
                                              ],
                                            ),
                                          ),
                                          if (isUnread) ...[
                                            const SizedBox(width: 12),
                                            Container(
                                              width: 12,
                                              height: 12,
                                              decoration: const BoxDecoration(
                                                color: Color(0xFF0084FF),
                                                shape: BoxShape.circle,
                                              ),
                                            ),
                                          ],
                                        ],
                                      ),
                                    ),
                                  );
                                },
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showDesktopNotifications() {
    showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.01),
      builder: (ctx) => Stack(
        children: [
          Positioned(
            top: 75,
            right: 150,
            child: Material(
              color: Colors.transparent,
              child: Container(
                width: 360,
                height: 500,
                decoration: BoxDecoration(
                  color: Theme.of(ctx).brightness == Brightness.dark ? const Color(0xFF252728) : Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                    ),
                  ],
                  border: Border.all(
                    color: Theme.of(ctx).brightness == Brightness.dark ? Colors.white12 : Colors.grey.shade100,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(20),
                      child: Text(
                        "THÔNG BÁO MỚI",
                        style: TextStyle(
                          color: Theme.of(ctx).brightness == Brightness.dark ? Colors.grey.shade400 : Colors.grey.shade500,
                          fontSize: 12,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                    Divider(
                      height: 1,
                      color: Theme.of(ctx).brightness == Brightness.dark ? Colors.white12 : null,
                    ),
                    Expanded(
                      child: _notifications.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.notifications_none_outlined,
                                    size: 40,
                                    color: Theme.of(ctx).brightness == Brightness.dark ? Colors.white30 : Colors.grey.shade300,
                                  ),
                                  const SizedBox(height: 12),
                                  Text(
                                    "Không có thông báo mới",
                                    style: TextStyle(
                                      color: Theme.of(ctx).brightness == Brightness.dark ? Colors.white54 : Colors.grey,
                                      fontSize: 13,
                                    ),
                                  ),
                                ],
                              ),
                            )
                          : StatefulBuilder(
                              builder: (context, setState) {
                                final scrollController = ScrollController();
                                return Theme(
                                  data: Theme.of(context).copyWith(
                                    scrollbarTheme: ScrollbarThemeData(
                                      thumbColor: MaterialStateProperty.all(
                                        Theme.of(ctx).brightness == Brightness.dark ? Colors.white24 : Colors.grey.shade400,
                                      ),
                                      thickness: MaterialStateProperty.all(6),
                                      radius: const Radius.circular(3),
                                    ),
                                  ),
                                  child: Scrollbar(
                                    controller: scrollController,
                                    thumbVisibility: true,
                                    child: ListView.separated(
                                      controller: scrollController,
                                      padding: EdgeInsets.zero,
                                      itemCount: _notifications.length,
                                      separatorBuilder: (context, index) =>
                                          Divider(
                                            height: 1,
                                            color: Theme.of(ctx).brightness == Brightness.dark ? Colors.white12 : null,
                                          ),
                                      itemBuilder: (context, index) {
                                        final notification =
                                            _notifications[index];
                                        final content =
                                            notification['content']
                                                ?.toString() ??
                                            '';
                                        final senders =
                                            notification['senders']
                                                as List<dynamic>? ??
                                            [];
                                        final sender = senders.isNotEmpty
                                            ? senders[0]
                                            : null;

                                        final senderName =
                                            sender?['fullName'] ??
                                            sender?['name'] ??
                                            'Hệ thống';
                                        final senderAvatar =
                                            sender?['profilePicture'] ??
                                            sender?['avatar'];
                                        final createdAtRaw =
                                            notification['createdAt']
                                                ?.toString() ??
                                            '';

                                        // Format time
                                        String timeDisplay = createdAtRaw;
                                        if (createdAtRaw.isNotEmpty) {
                                          try {
                                            final date = DateTime.parse(
                                              createdAtRaw,
                                            );
                                            final now = DateTime.now();
                                            final diff = now.difference(date);
                                            if (diff.inDays > 0) {
                                              timeDisplay =
                                                  '${diff.inDays} ngày trước';
                                            } else if (diff.inHours > 0) {
                                              timeDisplay =
                                                  '${diff.inHours} giờ trước';
                                            } else if (diff.inMinutes > 0) {
                                              timeDisplay =
                                                  '${diff.inMinutes} phút trước';
                                            } else {
                                              timeDisplay = 'Vừa xong';
                                            }
                                          } catch (e) {
                                            timeDisplay = createdAtRaw;
                                          }
                                        }

                                        return InkWell(
                                           highlightColor: Theme.of(ctx).brightness == Brightness.dark
                                               ? Colors.white.withOpacity(0.05)
                                               : Colors.black.withOpacity(0.05),
                                           splashColor: Theme.of(ctx).brightness == Brightness.dark
                                               ? Colors.white.withOpacity(0.05)
                                               : Colors.black.withOpacity(0.05),
                                           hoverColor: Theme.of(ctx).brightness == Brightness.dark
                                               ? Colors.white.withOpacity(0.025)
                                               : Colors.black.withOpacity(0.025),
                                           onTap: () {
                                             Navigator.pop(ctx);
                                             _navigateFromNotification(
                                               notification,
                                             );
                                           },
                                           child: Padding(
                                             padding: const EdgeInsets.all(16),
                                             child: Row(
                                               crossAxisAlignment:
                                                   CrossAxisAlignment.start,
                                               children: [
                                                 CircleAvatar(
                                                   radius: 20,
                                                   backgroundColor: Theme.of(ctx).brightness == Brightness.dark
                                                       ? const Color(0xFF1E1F20)
                                                       : Colors.blueGrey.shade50,
                                                   backgroundImage:
                                                       senderAvatar != null
                                                       ? NetworkImage(
                                                           ApiService.resolveImageUrl(
                                                             senderAvatar,
                                                           ),
                                                         )
                                                       : null,
                                                   child: senderAvatar == null
                                                       ? Icon(
                                                           Icons.person,
                                                           size: 20,
                                                           color: Theme.of(ctx).brightness == Brightness.dark ? Colors.white38 : null,
                                                         )
                                                       : null,
                                                 ),
                                                 const SizedBox(width: 12),
                                                 Expanded(
                                                   child: Column(
                                                     crossAxisAlignment:
                                                         CrossAxisAlignment
                                                             .start,
                                                     children: [
                                                       RichText(
                                                         maxLines: 2,
                                                         overflow: TextOverflow
                                                             .ellipsis,
                                                         text: TextSpan(
                                                           children: [
                                                             TextSpan(
                                                               text:
                                                                   notification['groupName'] !=
                                                                       null
                                                                   ? "$senderName : "
                                                                   : "$senderName ",
                                                               style: TextStyle(
                                                                 fontWeight:
                                                                     FontWeight
                                                                         .w900,
                                                                 color: Theme.of(ctx).brightness == Brightness.dark
                                                                     ? Colors.white.withOpacity(0.9)
                                                                     : const Color(0xFF1E293B),
                                                                 fontSize: 13,
                                                               ),
                                                             ),
                                                             TextSpan(
                                                               text: content,
                                                               style: TextStyle(
                                                                 fontWeight:
                                                                     FontWeight
                                                                         .w500,
                                                                 color: Theme.of(ctx).brightness == Brightness.dark
                                                                     ? Colors.white60
                                                                     : const Color(0xFF64748B),
                                                                 fontSize: 13,
                                                               ),
                                                             ),
                                                           ],
                                                         ),
                                                       ),
                                                       const SizedBox(height: 6),
                                                       Text(
                                                         timeDisplay,
                                                         style: TextStyle(
                                                           color: Theme.of(ctx).brightness == Brightness.dark
                                                               ? Colors.white30
                                                               : Colors.grey.shade400,
                                                           fontSize: 10,
                                                           fontWeight:
                                                               FontWeight.bold,
                                                         ),
                                                       ),
                                                     ],
                                                   ),
                                                 ),
                                               ],
                                             ),
                                           ),
                                         );
                                      },
                                    ),
                                  ),
                                );
                              },
                            ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPage(int index) {
    if (!_visitedIndexes.contains(index)) {
      return const SizedBox.shrink();
    }
    switch (index) {
      case 0:
        return WorkHomePage(
          key: _homeKey,
          onNavigateToReels: (idx) {
            setState(() {
              _initialReelIndex = idx;
              _reelNavigationTime = DateTime.now().millisecondsSinceEpoch;
            });
            _onItemTapped(1);
          },
          onRefreshReels: _fetchGlobalReels,
          reels: _allReels,
        );
      case 1:
        return ReelsPage(
          key: ValueKey('reels_${_initialReelIndex}_$_reelNavigationTime'),
          isActive: _currentIndex == 1,
          initialIndex: _initialReelIndex,
          reels: _allReels,
          onClose: () => _onItemTapped(0),
          onRefresh: _fetchGlobalReels,
        );
      case 2:
        return const DocumentsPage();
      case 3:
        return const PersonnelPage();
      case 4:
        return const CommunityPage();
      case 5:
        return const ProfilePage();
      case 6:
        return MessagingPage(
          onBack: () => _onItemTapped(0),
          initialChatId: _pendingChatId,
        );
      default:
        return const SizedBox.shrink();
    }
  }

  void _navigateToReel(String reelId) async {
    final int targetIndex = _allReels.indexWhere(
      (r) => (r['_id'] ?? r['id'])?.toString() == reelId,
    );
    if (targetIndex < 0) {
      await _fetchGlobalReels();
    }
    final int newIndex = _allReels.indexWhere(
      (r) => (r['_id'] ?? r['id'])?.toString() == reelId,
    );
    setState(() {
      _initialReelIndex = newIndex >= 0 ? newIndex : 0;
      _reelNavigationTime = DateTime.now().millisecondsSinceEpoch;
    });
    _onItemTapped(1);
  }

  void _navigateFromNotification(Map<String, dynamic> notification) {
    final link = notification['link']?.toString() ?? '';
    final metadata = notification['metadata'] is Map<String, dynamic>
        ? notification['metadata'] as Map<String, dynamic>
        : <String, dynamic>{};
    String? postId = metadata['postId']?.toString();
    String? reelId = metadata['reelId']?.toString();

    if ((postId == null || postId.isEmpty) && link.isNotEmpty) {
      final uri = Uri.tryParse(link);
      final path = uri?.path ?? link;
      final segments = path.split('/')
        ..removeWhere((segment) => segment.isEmpty);
      for (var i = 0; i < segments.length; i++) {
        if (segments[i] == 'post' && i + 1 < segments.length) {
          postId = segments[i + 1];
          break;
        }
        if (segments[i] == 'reel' && i + 1 < segments.length) {
          reelId = segments[i + 1];
          break;
        }
      }
    }

    if (postId != null && postId.isNotEmpty) {
      _onItemTapped(0);
      _homeKey.currentState?.goToPost(postId);
      return;
    }
    if (reelId != null && reelId.isNotEmpty) {
      _navigateToReel(reelId);
      return;
    }

    if (link.contains('/chat/')) {
      final chatId = link.split('/chat/').last;
      setState(() {
        _pendingChatId = chatId;
      });
      _onItemTapped(6);

      // Clear pending ID after a short delay so it doesn't re-open every time we switch tabs
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) setState(() => _pendingChatId = null);
      });
      return;
    }
  }

  void _onItemTapped(int index) {
    setState(() {
      _currentIndex = index;
      _visitedIndexes.add(index);
    });
    if (_scaffoldKey.currentState?.isDrawerOpen ?? false) {
      Navigator.pop(context); // Close drawer
    }
  }

  int _getBottomIndex() {
    if (_currentIndex == 0) return 0; // BẢNG TIN
    if (_currentIndex == 3) return 1; // NHÂN SỰ
    if (_currentIndex == 4) return 2; // NHÓM (CỘNG ĐỒNG)
    if (_currentIndex == 5) return 3; // CÁ NHÂN
    return 0; // Default to Home for other pages
  }

  @override
  Widget build(BuildContext context) {
    final bool isDesktop = MediaQuery.of(context).size.width > 1100;

    if (isDesktop) {
      final bool isMessaging = _currentIndex == 6;
      final bool isReels = _currentIndex == 1;
      final bool isFullScreen = isMessaging || isReels;

      return Scaffold(
        backgroundColor: Theme.of(context).brightness == Brightness.dark
            ? const Color(0xFF252728)
            : const Color(0xFFF8FAFC),
        body: Stack(
          children: [
            Row(
              children: [
                if (!isFullScreen)
                  _DesktopSidebar(
                    currentIndex: _currentIndex,
                    onTap: _onItemTapped,
                  ),
                Expanded(
                  child: Column(
                    children: [
                      if (!isFullScreen)
                        _DesktopHeader(
                          onChatTap: _showDesktopChats,
                          currentChatActive: _currentIndex == 6,
                          notificationCount: _notificationCount,
                          onNotificationTap: _showNotifications,
                          onSearch: (val) {
                            if (_currentIndex == 0) {
                              _homeKey.currentState?.goToPost(val);
                            }
                          },
                        ),
                      Expanded(
                        child: IndexedStack(
                          index: _currentIndex,
                          children: List.generate(
                            7,
                            (index) => _buildPage(index),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                if (!isFullScreen) const _ContactsSidebar(),
              ],
            ),
            if (_miniChats.isNotEmpty)
              Positioned(
                bottom: 0,
                right: !isFullScreen
                    ? 260
                    : 20, // 250 (ContactsSidebar width) + 10 margin
                child: SizedBox(
                  width:
                      MediaQuery.of(context).size.width -
                      (!isFullScreen ? 260 : 20) -
                      20,
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    reverse: true,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: _miniChats.map((chatData) {
                        return Container(
                          key: ValueKey(chatData['id']),
                          width: 340,
                          height: 490,
                          margin: const EdgeInsets.only(left: 16),
                          decoration: BoxDecoration(
                            color: Theme.of(context).brightness == Brightness.dark
                                ? const Color(0xFF252728)
                                : Colors.white,
                            borderRadius: const BorderRadius.only(
                              topLeft: Radius.circular(12),
                              topRight: Radius.circular(12),
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.15),
                                blurRadius: 10,
                                offset: const Offset(0, -2),
                              ),
                            ],
                          ),
                          child: ClipRRect(
                            borderRadius: const BorderRadius.only(
                              topLeft: Radius.circular(12),
                              topRight: Radius.circular(12),
                            ),
                            child: Material(
                              child: ChatDetailScreen(
                                conversationId: chatData['id'],
                                name: chatData['name'],
                                avatarPath: chatData['avatarPath'],
                                isGroup: chatData['isGroup'] ?? false,
                                isOnline: chatData['isOnline'] ?? false,
                                createdBy: chatData['createdBy'],
                                isMini: true,
                                onClose: () {
                                  setState(() {
                                    _miniChats.removeWhere(
                                      (c) => c['id'] == chatData['id'],
                                    );
                                  });
                                },
                              ),
                            ),
                          ),
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

    return Scaffold(
      key: _scaffoldKey,
      appBar: AppBar(
        leading: IconButton(
          icon: Icon(
            Icons.menu,
            color: Theme.of(context).brightness == Brightness.dark
                ? Colors.white
                : Colors.blueGrey.shade700,
          ),
          onPressed: () => _scaffoldKey.currentState?.openDrawer(),
        ),
        title: _buildAppLogo(),
        actions: [
          if (_hasUpdate)
            _BlinkingUpdateButton(
              onTap: () => UpdateHelper.checkUpdate(context),
            ),
          _TopActionStatus(),
          ValueListenableBuilder<int>(
            valueListenable: ApiService.unreadChatCount,
            builder: (context, count, _) {
              return _TopAction(
                icon: Icons.chat_bubble_outline,
                badge: count > 0
                    ? (count > 99 ? "99+" : count.toString())
                    : null,
                onTap: () => _onItemTapped(6),
                isActive: _currentIndex == 6,
              );
            },
          ),
          _TopAction(
            icon: Icons.notifications_none_outlined,
            badge: _notificationCount > 0
                ? _notificationCount.toString()
                : null,
            onTap: () async {
              // Request permission if not already granted
              await NotificationHelper.requestPermissions();
              _showNotifications();
            },
          ),
          const SizedBox(width: 8),
        ],
        centerTitle: false,
        backgroundColor: Theme.of(context).brightness == Brightness.dark
            ? const Color(0xFF252728)
            : Colors.white,
        elevation: 0.5,
      ),
      drawer: _CustomDrawer(currentIndex: _currentIndex, onTap: _onItemTapped),
      body: IndexedStack(
        index: _currentIndex,
        children: List.generate(7, (index) => _buildPage(index)),
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).brightness == Brightness.dark
              ? const Color(0xFF252728)
              : Colors.white,
          border: Border(
            top: BorderSide(
              color: Theme.of(context).brightness == Brightness.dark
                  ? Colors.white12
                  : Colors.grey.withOpacity(0.1),
            ),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.01),
              blurRadius: 10,
              offset: const Offset(0, -5),
            ),
          ],
        ),
        child: BottomNavigationBar(
          backgroundColor: Theme.of(context).brightness == Brightness.dark
              ? const Color(0xFF252728)
              : Colors.white,
          currentIndex: _getBottomIndex(),
          type: BottomNavigationBarType.fixed,
          selectedItemColor: const Color(0xFF3B82F6),
          unselectedItemColor: Theme.of(context).brightness == Brightness.dark
              ? Colors.white38
              : Colors.blueGrey.shade300,
          showSelectedLabels: true,
          showUnselectedLabels: true,
          selectedLabelStyle: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 11,
          ),
          unselectedLabelStyle: const TextStyle(
            fontWeight: FontWeight.w500,
            fontSize: 11,
          ),
          onTap: (index) {
            switch (index) {
              case 0:
                _onItemTapped(0);
                break;
              case 1:
                _onItemTapped(3);
                break;
              case 2:
                _onItemTapped(4);
                break;
              case 3:
                _onItemTapped(5);
                break;
            }
          },
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.home_outlined),
              activeIcon: Icon(Icons.home),
              label: 'Bảng tin',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.person_add_alt_1_outlined),
              activeIcon: Icon(Icons.person_add_alt_1),
              label: 'Nhân sự',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.group_outlined),
              activeIcon: Icon(Icons.group),
              label: 'Cộng đồng',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.account_circle_outlined),
              activeIcon: Icon(Icons.account_circle),
              label: 'Cá nhân',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAppLogo() {
    return GestureDetector(
      onTap: () {
        if (_currentIndex != 0) {
          _onItemTapped(0);
        }
        // Always trigger refresh when logo is tapped
        _fetchGlobalReels();
        _homeKey.currentState?.refresh();
      },
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: const Color(0xFF3B82F6),
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Center(
          child: Text(
            "w",
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 20,
            ),
          ),
        ),
      ),
    );
  }
}

class _TopActionStatus extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(left: 8),
      width: 38,
      height: 38,
      decoration: BoxDecoration(
        color: Theme.of(context).brightness == Brightness.dark
            ? const Color(0xFF1E3A8A).withOpacity(0.3)
            : const Color(0xFFEFF6FF),
        shape: BoxShape.circle,
        border: Border.all(
          color: Theme.of(context).brightness == Brightness.dark
              ? const Color(0xFF3B82F6).withOpacity(0.4)
              : const Color(0xFF3B82F6).withOpacity(0.2),
        ),
      ),
      child: const Icon(
        Icons.notifications_active_outlined,
        size: 18,
        color: Color(0xFF3B82F6),
      ),
    );
  }
}

class _TopAction extends StatefulWidget {
  final IconData icon;
  final String? badge;
  final VoidCallback? onTap;
  final bool isActive;

  const _TopAction({
    required this.icon,
    this.badge,
    this.onTap,
    this.isActive = false,
  });

  @override
  State<_TopAction> createState() => _TopActionState();
}

class _TopActionState extends State<_TopAction>
    with SingleTickerProviderStateMixin {
  late AnimationController _bounceController;
  late Animation<double> _bounceAnim;

  @override
  void initState() {
    super.initState();
    _bounceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );

    _bounceAnim = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween(
          begin: 0.0,
          end: -5.0,
        ).chain(CurveTween(curve: Curves.easeOut)),
        weight: 35,
      ),
      TweenSequenceItem(
        tween: Tween(
          begin: -5.0,
          end: 0.0,
        ).chain(CurveTween(curve: Curves.bounceOut)),
        weight: 65,
      ),
    ]).animate(_bounceController);

    if (widget.badge != null) {
      _startBounce();
    }
  }

  void _startBounce() {
    _bounceController.repeat(period: const Duration(milliseconds: 2500));
  }

  @override
  void didUpdateWidget(_TopAction oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.badge != null && oldWidget.badge == null) {
      _startBounce();
    } else if (widget.badge == null && oldWidget.badge != null) {
      _bounceController.stop();
      _bounceController.reset();
    }
  }

  @override
  void dispose() {
    _bounceController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: widget.onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        margin: const EdgeInsets.only(left: 8),
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: widget.isActive
              ? const Color(0xFF3B82F6).withOpacity(0.1)
              : (Theme.of(context).brightness == Brightness.dark ? const Color(0xFF1E1F20) : const Color(0xFFF1F5F9)),
          shape: BoxShape.circle,
        ),
        child: Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.center,
          children: [
            Icon(
              widget.icon,
              size: 20,
              color: widget.isActive
                  ? const Color(0xFF3B82F6)
                  : (Theme.of(context).brightness == Brightness.dark ? Colors.white70 : const Color(0xFF475569)),
            ),
            if (widget.badge != null)
              Positioned(
                right: -2,
                top: -2,
                child: AnimatedBuilder(
                  animation: _bounceAnim,
                  builder: (context, child) {
                    return Transform.translate(
                      offset: Offset(0, _bounceAnim.value),
                      child: child,
                    );
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 4,
                      vertical: 1,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEF4444),
                      borderRadius: BorderRadius.circular(10),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.red.withOpacity(0.35),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    constraints: const BoxConstraints(
                      minWidth: 16,
                      minHeight: 16,
                    ),
                    child: Text(
                      widget.badge!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        height: 1.2,
                      ),
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

class _CustomDrawer extends StatelessWidget {
  final int currentIndex;
  final Function(int) onTap;

  const _CustomDrawer({required this.currentIndex, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Drawer(
      backgroundColor: Theme.of(context).brightness == Brightness.dark
          ? const Color(0xFF252728)
          : Colors.white,
      width: MediaQuery.of(context).size.width * 0.75,
      child: Column(
        children: [
          const SizedBox(height: 60),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  "WORK",
                  style: TextStyle(
                    color: Color(0xFF3B82F6),
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -1,
                  ),
                ),
                _CloseButton(),
              ],
            ),
          ),
          const SizedBox(height: 40),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 24),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                "MENU CHÍNH",
                style: TextStyle(
                  color: Colors.grey,
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.8,
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          _DrawerItem(
            label: "BẢNG TIN",
            icon: Icons.home_outlined,
            isActive: currentIndex == 0,
            onTap: () => onTap(0),
          ),
          _DrawerItem(
            label: "REELS",
            icon: Icons.play_circle_outline,
            isActive: currentIndex == 1,
            onTap: () => onTap(1),
          ),
          _DrawerItem(
            label: "TÀI LIỆU",
            icon: Icons.folder_open_outlined,
            isActive: currentIndex == 2,
            onTap: () => onTap(2),
          ),
          _DrawerItem(
            label: "NHÂN SỰ",
            icon: Icons.person_add_alt_1_outlined,
            isActive: currentIndex == 3,
            onTap: () => onTap(3),
          ),
          _DrawerItem(
            label: "NHÓM",
            icon: Icons.group_outlined,
            isActive: currentIndex == 4,
            onTap: () => onTap(4),
          ),
          _DrawerItem(
            label: "CÁ NHÂN",
            icon: Icons.person_outline,
            isActive: currentIndex == 5,
            onTap: () => onTap(5),
          ),
          const Spacer(),
          const _LogoutButton(),
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}

class _CloseButton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        color: Theme.of(context).brightness == Brightness.dark
            ? const Color(0xFF1E1F20)
            : const Color(0xFFF1F5F9),
        shape: BoxShape.circle,
      ),
      child: Center(
        child: IconButton(
          icon: Icon(
            Icons.close,
            size: 16,
            color: Theme.of(context).brightness == Brightness.dark
                ? Colors.white70
                : Colors.blueGrey,
          ),
          onPressed: () => Navigator.pop(context),
          padding: EdgeInsets.zero,
        ),
      ),
    );
  }
}

class _LogoutButton extends StatelessWidget {
  const _LogoutButton();
  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => AuthService().logout(),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Row(
          children: const [
            Icon(Icons.logout, color: Colors.red, size: 20),
            SizedBox(width: 12),
            Text(
              "ĐĂNG XUẤT",
              style: TextStyle(
                color: Colors.red,
                fontWeight: FontWeight.w800,
                fontSize: 13,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DrawerItem extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool isActive;
  final VoidCallback onTap;

  const _DrawerItem({
    required this.label,
    required this.icon,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: isActive ? const Color(0xFF3B82F6) : Colors.transparent,
            borderRadius: BorderRadius.circular(16),
            boxShadow: isActive
                ? [
                    BoxShadow(
                      color: const Color(0xFF3B82F6).withOpacity(0.3),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : [],
          ),
          child: Row(
            children: [
              Icon(
                icon,
                color: isActive
                    ? Colors.white
                    : (Theme.of(context).brightness == Brightness.dark
                        ? Colors.white70
                        : Colors.blueGrey.shade600),
                size: 22,
              ),
              const SizedBox(width: 16),
              Text(
                label,
                style: TextStyle(
                  color: isActive
                      ? Colors.white
                      : (Theme.of(context).brightness == Brightness.dark
                          ? Colors.white70
                          : Colors.blueGrey.shade700),
                  fontWeight: isActive ? FontWeight.bold : FontWeight.w600,
                  fontSize: 14,
                  letterSpacing: 0.2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DesktopSidebar extends StatelessWidget {
  final int currentIndex;
  final Function(int) onTap;

  const _DesktopSidebar({required this.currentIndex, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 240,
      decoration: BoxDecoration(
        color: Theme.of(context).brightness == Brightness.dark
            ? const Color(0xFF252728)
            : Colors.white,
        border: Border(
          right: BorderSide(
            color: Theme.of(context).brightness == Brightness.dark
                ? Colors.white12
                : Colors.grey.shade100,
          ),
        ),
      ),
      child: Column(
        children: [
          const SizedBox(height: 32),
          // Logo Section
          GestureDetector(
            onTap: () => onTap(0),
            behavior: HitTestBehavior.opaque,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: const Color(0xFF3B82F6),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Center(
                      child: Text(
                        "W",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    "WORK",
                    style: TextStyle(
                      color: Theme.of(context).brightness == Brightness.dark
                          ? Colors.white
                          : const Color(0xFF1E293B),
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.5,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 32),
          // Scrollable Menu Section
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 24),
                    child: Text(
                      "MENU CHÍNH",
                      style: TextStyle(
                        color: Colors.grey,
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.0,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  _DrawerItem(
                    label: "BẢNG TIN",
                    icon: Icons.home_outlined,
                    isActive: currentIndex == 0,
                    onTap: () => onTap(0),
                  ),
                  _DrawerItem(
                    label: "REELS",
                    icon: Icons.play_circle_outline,
                    isActive: currentIndex == 1,
                    onTap: () => onTap(1),
                  ),
                  _DrawerItem(
                    label: "TÀI LIỆU",
                    icon: Icons.folder_open_outlined,
                    isActive: currentIndex == 2,
                    onTap: () => onTap(2),
                  ),
                  _DrawerItem(
                    label: "NHÂN SỰ",
                    icon: Icons.person_add_alt_1_outlined,
                    isActive: currentIndex == 3,
                    onTap: () => onTap(3),
                  ),
                  _DrawerItem(
                    label: "NHÓM",
                    icon: Icons.group_outlined,
                    isActive: currentIndex == 4,
                    onTap: () => onTap(4),
                  ),
                  _DrawerItem(
                    label: "CÁ NHÂN",
                    icon: Icons.person_outline,
                    isActive: currentIndex == 5,
                    onTap: () => onTap(5),
                  ),
                ],
              ),
            ),
          ),
          // Footer Section
          const Divider(height: 1, indent: 20, endIndent: 20),
          const SizedBox(height: 16),
          const _LogoutButton(),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

class _DesktopHeader extends StatefulWidget {
  final VoidCallback onChatTap;
  final bool currentChatActive;
  final int notificationCount;
  final VoidCallback onNotificationTap;
  final Function(String) onSearch;

  const _DesktopHeader({
    required this.onChatTap,
    required this.currentChatActive,
    required this.notificationCount,
    required this.onNotificationTap,
    required this.onSearch,
  });

  @override
  State<_DesktopHeader> createState() => _DesktopHeaderState();
}

class _DesktopHeaderState extends State<_DesktopHeader>
    with SingleTickerProviderStateMixin {
  bool _hasUpdate = false;
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
    _checkForUpdate();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _checkForUpdate() async {
    final hasUpdate = await UpdateHelper.isUpdateAvailable();
    if (mounted) {
      setState(() => _hasUpdate = hasUpdate);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      height: 72,
      padding: const EdgeInsets.symmetric(horizontal: 32),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF252728) : Colors.white,
        border: Border(
          bottom: BorderSide(
            color: isDark ? Colors.white12 : Colors.grey.shade100,
          ),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Flexible(
                  child: Container(
                    constraints: const BoxConstraints(maxWidth: 500),
                    height: 40,
                    child: TextField(
                      onSubmitted: widget.onSearch,
                      style: TextStyle(
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                      decoration: InputDecoration(
                        hintText: "Tìm kiếm đồng nghiệp...",
                        hintStyle: TextStyle(
                          color: isDark ? Colors.white38 : Colors.grey.shade400,
                          fontSize: 13,
                        ),
                        prefixIcon: Icon(
                          Icons.search,
                          color: isDark ? Colors.white38 : Colors.grey.shade400,
                          size: 20,
                        ),
                        filled: true,
                        fillColor: isDark ? const Color(0xFF1E1F20) : const Color(0xFFF1F5F9),
                        contentPadding: EdgeInsets.zero,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(20),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                  ),
                ),
                if (_hasUpdate) ...[
                  const SizedBox(width: 16),
                  ScaleTransition(
                    scale: Tween<double>(begin: 0.9, end: 1.1).animate(
                      CurvedAnimation(
                        parent: _pulseController,
                        curve: Curves.easeInOut,
                      ),
                    ),
                    child: ElevatedButton.icon(
                      onPressed: () => UpdateHelper.openDownloadLink(context),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF3B82F6),
                        foregroundColor: Colors.white,
                        elevation: 4,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                      ),
                      icon: const Icon(Icons.rocket_launch, size: 16),
                      label: const Text(
                        "CẬP NHẬT NGAY",
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          Row(
            children: [
              ValueListenableBuilder<int>(
                valueListenable: ApiService.unreadChatCount,
                builder: (context, count, _) {
                  return _TopAction(
                    icon: Icons.chat_bubble_outline,
                    badge: count > 0
                        ? (count > 99 ? "99+" : count.toString())
                        : null,
                    onTap: widget.onChatTap,
                    isActive: widget.currentChatActive,
                  );
                },
              ),
              const SizedBox(width: 16),
              _TopAction(
                icon: Icons.notifications_none_outlined,
                badge: widget.notificationCount > 0
                    ? widget.notificationCount.toString()
                    : null,
                onTap: widget.onNotificationTap,
              ),
              const SizedBox(width: 16),
              ValueListenableBuilder<Map<String, dynamic>?>(
                valueListenable: AuthService().userProfile,
                builder: (context, profile, _) {
                  final String? avatar =
                      (profile?["profilePicture"] ?? profile?["avatar"])
                          ?.toString();
                  return CircleAvatar(
                    radius: 18,
                    backgroundColor: Colors.blueGrey.shade100,
                    backgroundImage: avatar != null
                        ? NetworkImage(ApiService.resolveImageUrl(avatar))
                        : null,
                    child: avatar == null
                        ? const Icon(Icons.person, size: 20)
                        : null,
                  );
                },
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ContactsSidebar extends StatefulWidget {
  const _ContactsSidebar();

  @override
  State<_ContactsSidebar> createState() => _ContactsSidebarState();
}

class _ContactsSidebarState extends State<_ContactsSidebar> {
  List<dynamic> _users = [];
  StreamSubscription? _statusSubscription;

  @override
  void initState() {
    super.initState();
    _fetchUsers();
    _statusSubscription = ApiService.userStatusStream.listen((data) {
      if (!mounted) return;
      final userId = (data["_id"] ?? data["id"] ?? data["userId"])?.toString();
      if (userId == null) return;

      setState(() {
        final index = _users.indexWhere((u) {
          final uId = (u["_id"] ?? u["id"])?.toString();
          return uId == userId;
        });

        if (index != -1) {
          // Clone user map and update status
          final updatedUser = Map<String, dynamic>.from(_users[index]);
          if (data.containsKey('isOnline')) {
            updatedUser['isOnline'] = data['isOnline'];
          }
          if (data.containsKey('status')) {
            updatedUser['status'] = data['status'];
          }
          _users[index] = updatedUser;
        }
      });
    });
  }

  @override
  void dispose() {
    _statusSubscription?.cancel();
    super.dispose();
  }

  Future<void> _fetchUsers() async {
    final users = await ApiService.getUsers();
    if (mounted) {
      setState(() {
        _users = users;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 250,
      decoration: BoxDecoration(
        color: Theme.of(context).brightness == Brightness.dark
            ? const Color(0xFF252728)
            : Colors.white,
        border: Border(
          left: BorderSide(
            color: Theme.of(context).brightness == Brightness.dark
                ? Colors.white12
                : Colors.grey.shade100,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 24),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  "GỢI Ý LIÊN HỆ",
                  style: TextStyle(
                    color: Colors.grey,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.5,
                  ),
                ),
                Icon(
                  Icons.more_horiz,
                  color: Colors.blue.withOpacity(0.5),
                  size: 16,
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              itemCount: _users.length,
              itemBuilder: (context, index) {
                final user = _users[index];
                final String name =
                    user["fullName"] ?? user["name"] ?? "Người dùng";
                final String? avatar =
                    (user["profilePicture"] ?? user["avatar"])?.toString();
                final bool isOnline =
                    user["isOnline"] == true ||
                    user["status"]?.toString().toLowerCase() == "online";

                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Row(
                    children: [
                      Stack(
                        children: [
                          CircleAvatar(
                            radius: 16,
                            backgroundColor: Colors.blueGrey.shade50,
                            backgroundImage: avatar != null
                                ? NetworkImage(
                                    ApiService.resolveImageUrl(avatar),
                                  )
                                : null,
                            child: avatar == null
                                ? Text(name.isNotEmpty ? name[0] : "")
                                : null,
                          ),
                          if (isOnline)
                            Positioned(
                              right: 0,
                              bottom: 0,
                              child: Container(
                                width: 8,
                                height: 8,
                                decoration: BoxDecoration(
                                  color: Colors.green,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: Theme.of(context).brightness == Brightness.dark
                                        ? const Color(0xFF252728)
                                        : Colors.white,
                                    width: 1.5,
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
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                                color: Theme.of(context).brightness == Brightness.dark
                                    ? Colors.white.withOpacity(0.9)
                                    : Colors.black87,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              isOnline ? "ĐANG ONLINE" : "NGOẠI TUYẾN",
                              style: TextStyle(
                                color: isOnline
                                    ? Colors.green
                                    : Colors.grey.shade400,
                                fontSize: 9,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _BlinkingUpdateButton extends StatefulWidget {
  final VoidCallback onTap;
  const _BlinkingUpdateButton({required this.onTap});

  @override
  State<_BlinkingUpdateButton> createState() => _BlinkingUpdateButtonState();
}

class _BlinkingUpdateButtonState extends State<_BlinkingUpdateButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    )..repeat(reverse: true);
    _animation = Tween<double>(
      begin: 0.95,
      end: 1.1,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: _animation,
      child: Center(
        child: Container(
          margin: const EdgeInsets.only(right: 8),
          child: TextButton(
            onPressed: widget.onTap,
            style: TextButton.styleFrom(
              backgroundColor: const Color(0xFF3B82F6), // Blue
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              elevation: 2,
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.system_update_rounded,
                  size: 14,
                  color: Colors.white,
                ),
                SizedBox(width: 4),
                Text(
                  "Cập nhật ngay",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
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
