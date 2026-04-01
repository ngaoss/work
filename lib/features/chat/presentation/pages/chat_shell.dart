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

class _ChatShellState extends State<ChatShell> {
  int _currentIndex = 0;
  final Set<int> _visitedIndexes = {0};
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  List<Map<String, dynamic>> _allReels = [];
  int _initialReelIndex = 0;

  @override
  void initState() {
    super.initState();
    _fetchGlobalReels();
  }

  Future<void> _fetchGlobalReels() async {
    final reels = await ApiService.getReels();
    if (mounted) {
      setState(() {
        _allReels = List<Map<String, dynamic>>.from(reels);
      });
    }
  }

  List<Widget> get _pages => [
    WorkHomePage(
      onNavigateToReels: (idx) {
        setState(() => _initialReelIndex = idx);
        _onItemTapped(1);
      },
      reels: _allReels,
    ), // 0: BẢNG TIN
    ReelsPage(
      key: ValueKey('reels_$_initialReelIndex'),
      isActive: _currentIndex == 1,
      initialIndex: _initialReelIndex,
      onClose: () => _onItemTapped(0), // back to news feed
    ), // 1: REELS
    const DocumentsPage(), // 2: TÀI LIỆU
    const PersonnelPage(), // 3: NHÂN SỰ
    const CommunityPage(), // 4: NHÓM
    const ProfilePage(), // 5: CÁ NHÂN
    const MessagingPage(), // 6: TIN NHẮN
  ];

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
          _TopAction(icon: Icons.notifications_none_outlined, badge: "5"),
          const SizedBox(width: 8),
        ],
        centerTitle: false,
        backgroundColor: Colors.white,
        elevation: 0.5,
      ),
      drawer: _CustomDrawer(currentIndex: _currentIndex, onTap: _onItemTapped),
      body: IndexedStack(
        index: _currentIndex,
        children: _pages.asMap().entries.map((entry) {
          final int index = entry.key;
          if (_visitedIndexes.contains(index)) {
            return entry.value;
          }
          return const SizedBox.shrink();
        }).toList(),
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
      onTap: () => _onItemTapped(0),
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
                right: 4,
                top: 4,
                child: Container(
                  padding: const EdgeInsets.all(2),
                  decoration: const BoxDecoration(
                    color: Colors.red,
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    badge!,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 9,
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
