import 'package:flutter/material.dart';
import '../../../home/presentation/pages/home_page.dart';
import '../../../personnel/presentation/pages/personnel_page.dart';
import '../../../community/presentation/pages/community_page.dart';
import '../../../profile/presentation/pages/profile_page.dart';
import '../../../reels/presentation/pages/reels_page.dart';
import '../../../documents/presentation/pages/documents_page.dart';
import 'messaging_page.dart';
import '../../../../core/security.dart';
import '../../../../core/api_service.dart';

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

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _fetchGlobalReels();
    _fetchNotifications();
    ApiService.getMe(); // Lấy thông tin cá nhân mới nhất ngầm

    ApiService.notificationRefresh.addListener(_handleNotificationRefresh);

    // Auto-refresh notifications every 3 seconds
    Future.delayed(Duration(seconds: 3), _autoRefreshNotifications);
    
    // Initialize Socket Connection for real-time messaging
    ApiService.initializeSocket();
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
          final aTime = DateTime.tryParse(a['createdAt']?.toString() ?? '') ?? DateTime.now();
          final bTime = DateTime.tryParse(b['createdAt']?.toString() ?? '') ?? DateTime.now();
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
          _notificationCount = latestNotifications.where((n) => n['isRead'] != true).length;
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
    // debugPrint('DEBUG: _showNotifications called, _notificationCount=$_notificationCount, _notifications.length=${_notifications.length}');
    setState(() {
      _notificationCount = 0;
      for (var notification in _notifications) {
        notification['isRead'] = true;
      }
    });
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => Container(
          height: MediaQuery.of(context).size.height * 0.75,
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.refresh, size: 20),
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
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: _notifications.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.notifications_none_outlined,
                              size: 48,
                              color: Colors.grey.shade300,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'Chưa có thông báo nào',
                              style: TextStyle(color: Colors.grey.shade400),
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
                          final senders = notification['senders'] as List<dynamic>? ?? [];
                          final sender = senders.isNotEmpty ? senders[0] : null;
                          final String senderName = sender?['fullName']?.toString() ?? 'Người dùng';
                          final String? senderAvatar = sender?['profilePicture']?.toString();
                          final String type = notification['type']?.toString() ?? 'Thông báo';
                          final String content = notification['content']?.toString() ?? '';
                          final String createdAt = notification['createdAt']?.toString() ?? '';
                          final String link = notification['link']?.toString() ?? '';
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
                              Padding(
                                padding: const EdgeInsets.symmetric(vertical: 8),
                                child: GestureDetector(
                                  onTap: link.isNotEmpty ? () {
                                    // Mark as read
                                    setState(() {
                                      notification['isRead'] = true;
                                      _notificationCount = _notifications.where((n) => n['isRead'] != true).length;
                                    });
                                    Navigator.pop(ctx); // Close bottom sheet
                                    _navigateFromNotification(notification);
                                  } : null,
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 12),
                                    child: Row(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        // Avatar
                                        FutureBuilder<Map<String, String>>(
                                          future: ApiService.getAuthHeaders(),
                                          builder: (context, headers) {
                                            return CircleAvatar(
                                              radius: 20,
                                              backgroundColor: Colors.blueGrey.shade100,
                                              backgroundImage: senderAvatar != null
                                                  ? NetworkImage(
                                                      ApiService.resolveImageUrl(senderAvatar),
                                                      headers: headers.data,
                                                    )
                                                  : null,
                                              child: senderAvatar == null
                                                  ? Text(
                                                      senderName.isNotEmpty ? senderName[0].toUpperCase() : 'U',
                                                      style: const TextStyle(
                                                        color: Colors.white,
                                                        fontSize: 12,
                                                        fontWeight: FontWeight.bold,
                                                      ),
                                                    )
                                                  : null,
                                            );
                                          },
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              // Name and notification type badge
                                              Row(
                                                children: [
                                                  Expanded(
                                                    child: Text(
                                                      senderName,
                                                      style: const TextStyle(
                                                        fontWeight: FontWeight.bold,
                                                        fontSize: 13,
                                                        color: Colors.black87,
                                                      ),
                                                    ),
                                                  ),
                                                  Container(
                                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                    decoration: BoxDecoration(
                                                      color: isRead ? Colors.grey.shade200 : const Color(0xFFE3F2FD),
                                                      borderRadius: BorderRadius.circular(12),
                                                    ),
                                                    child: Text(
                                                      typeDisplay,
                                                      style: const TextStyle(fontSize: 10),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                              const SizedBox(height: 4),
                                              // Content
                                              Padding(
                                                padding: const EdgeInsets.only(right: 12),
                                                child: Text(
                                                  content,
                                                  maxLines: 2,
                                                  overflow: TextOverflow.ellipsis,
                                                  style: TextStyle(
                                                    fontSize: 13,
                                                    color: Colors.black54,
                                                    fontWeight: isRead ? FontWeight.normal : FontWeight.w500,
                                                  ),
                                                ),
                                              ),
                                              const SizedBox(height: 4),
                                              // Time
                                              Text(
                                                timeDisplay,
                                                style: const TextStyle(
                                                  fontSize: 11,
                                                  color: Colors.grey,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                              const Divider(height: 1, indent: 52),
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
        return const MessagingPage();
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
      final segments = path.split('/')..removeWhere((segment) => segment.isEmpty);
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
      _onItemTapped(6);
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
    return Scaffold(
      key: _scaffoldKey,
      appBar: AppBar(
        leading: IconButton(
          icon: Icon(Icons.menu, color: Colors.blueGrey.shade700),
          onPressed: () => _scaffoldKey.currentState?.openDrawer(),
        ),
        title: _buildAppLogo(),
        actions: [
          _TopActionStatus(),
          _TopAction(
            icon: Icons.chat_bubble_outline,
            onTap: () => _onItemTapped(6),
            isActive: _currentIndex == 6,
          ),
          _TopAction(
            icon: Icons.notifications_none_outlined,
            badge: _notificationCount > 0 ? _notificationCount.toString() : null,
            onTap: () {
              // debugPrint('DEBUG: Bell icon tapped, _notificationCount=$_notificationCount');
              _showNotifications();
            },
          ),
          const SizedBox(width: 8),
        ],
        centerTitle: false,
        backgroundColor: Colors.white,
        elevation: 0.5,
      ),
      drawer: _CustomDrawer(currentIndex: _currentIndex, onTap: _onItemTapped),
      body: IndexedStack(
        index: _currentIndex,
        children: List.generate(7, (index) => _buildPage(index)),
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: Colors.grey.withOpacity(0.1))),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.01),
              blurRadius: 10,
              offset: const Offset(0, -5),
            ),
          ],
        ),
        child: BottomNavigationBar(
          currentIndex: _getBottomIndex(),
          type: BottomNavigationBarType.fixed,
          selectedItemColor: const Color(0xFF3B82F6),
          unselectedItemColor: Colors.blueGrey.shade300,
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
        color: const Color(0xFFEFF6FF),
        shape: BoxShape.circle,
        border: Border.all(color: const Color(0xFF3B82F6).withOpacity(0.2)),
      ),
      child: const Icon(
        Icons.notifications_active_outlined,
        size: 18,
        color: Color(0xFF3B82F6),
      ),
    );
  }
}

class _TopAction extends StatelessWidget {
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
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        margin: const EdgeInsets.only(left: 8),
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: isActive
              ? const Color(0xFF3B82F6).withOpacity(0.1)
              : const Color(0xFFF1F5F9),
          shape: BoxShape.circle,
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Icon(
              icon,
              size: 20,
              color: isActive
                  ? const Color(0xFF3B82F6)
                  : const Color(0xFF475569),
            ),
            if (badge != null)
              Positioned(
                right: 0,
                top: 0,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.red,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.2),
                        blurRadius: 4,
                        offset: const Offset(0, 1),
                      ),
                    ],
                  ),
                  constraints: const BoxConstraints(
                    minWidth: 20,
                    minHeight: 20,
                  ),
                  child: Text(
                    badge!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
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
      backgroundColor: Colors.white,
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
        color: const Color(0xFFF1F5F9),
        shape: BoxShape.circle,
      ),
      child: Center(
        child: IconButton(
          icon: const Icon(Icons.close, size: 16, color: Colors.blueGrey),
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
                color: isActive ? Colors.white : Colors.blueGrey.shade600,
                size: 22,
              ),
              const SizedBox(width: 16),
              Text(
                label,
                style: TextStyle(
                  color: isActive ? Colors.white : Colors.blueGrey.shade700,
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
