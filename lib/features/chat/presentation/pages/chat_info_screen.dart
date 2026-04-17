import 'package:flutter/material.dart';
import '../../../../core/api_service.dart';

class ChatInfoScreen extends StatefulWidget {
  final String name;
  final String? avatarPath;
  final String? conversationId;
  final bool isGroup;
  final bool isMuted;
  final Function(bool) onMuteToggle;

  const ChatInfoScreen({
    super.key,
    required this.name,
    this.avatarPath,
    this.conversationId,
    this.isGroup = false,
    this.isMuted = false,
    required this.onMuteToggle,
  });

  @override
  State<ChatInfoScreen> createState() => _ChatInfoScreenState();
}

class _ChatInfoScreenState extends State<ChatInfoScreen> {
  late bool _isMuted;
  Color _selectedColor = const Color(0xFF3B82F6);
  bool _isMembersExpanded = true;

  final List<Color> _themeColors = [
    const Color(0xFF3B82F6), // Blue
    const Color(0xFFD12D6C), // Pink
    const Color(0xFF8B5CF6), // Purple
    const Color(0xFF10B981), // Teal
    const Color(0xFFF97316), // Orange
    const Color(0xFF334155), // Navy
    const Color(0xFFEF4444), // Red
  ];

  @override
  void initState() {
    super.initState();
    _isMuted = widget.isMuted;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        title: const Text(
          "CÀI ĐẶT HỘI THOẠI",
          style: TextStyle(
            color: Color(0xFF1E293B),
            fontSize: 16,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.5,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.transparent),
          onPressed: null,
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: CircleAvatar(
              backgroundColor: Colors.grey.shade100,
              radius: 18,
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.black87, size: 20),
                onPressed: () => Navigator.pop(context),
              ),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            const SizedBox(height: 20),
            // Avatar
            Center(
              child: Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  image: widget.avatarPath != null && widget.avatarPath!.isNotEmpty
                      ? DecorationImage(
                          image: NetworkImage(ApiService.resolveImageUrl(widget.avatarPath!)),
                          fit: BoxFit.cover,
                        )
                      : null,
                  color: Colors.grey[200],
                ),
                child: widget.avatarPath == null || widget.avatarPath!.isEmpty
                    ? Center(
                        child: Text(
                          widget.name.isNotEmpty ? widget.name[0].toUpperCase() : "?",
                          style: const TextStyle(
                            fontSize: 48,
                            fontWeight: FontWeight.bold,
                            color: Colors.blueAccent,
                          ),
                        ),
                      )
                    : null,
              ),
            ),
            const SizedBox(height: 12),
            // Name
            Text(
              widget.name,
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: Color(0xFF0F172A),
              ),
            ),
            const SizedBox(height: 32),

            // CHỦ ĐỀ HỘI THOẠI
            _buildSectionHeader("CHỦ ĐỀ HỘI THOẠI"),
            const SizedBox(height: 12),
            SizedBox(
              height: 50,
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                scrollDirection: Axis.horizontal,
                itemCount: _themeColors.length,
                itemBuilder: (context, index) {
                  final color = _themeColors[index];
                  final isSelected = _selectedColor == color;
                  return GestureDetector(
                    onTap: () => setState(() => _selectedColor = color),
                    child: Container(
                      width: 42,
                      height: 42,
                      margin: const EdgeInsets.symmetric(horizontal: 8),
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: color.withOpacity(0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: isSelected
                          ? const Icon(Icons.check, color: Colors.white, size: 20)
                          : null,
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 40),

            // THÀNH VIÊN
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    "THÀNH VIÊN (2)",
                    style: TextStyle(
                      color: Colors.grey[500],
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                    ),
                  ),
                  GestureDetector(
                    onTap: () => setState(() => _isMembersExpanded = !_isMembersExpanded),
                    child: Icon(
                      _isMembersExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                      color: Colors.black54,
                    ),
                  ),
                ],
              ),
            ),
            if (_isMembersExpanded) ...[
              const SizedBox(height: 16),
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 20),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Column(
                  children: [
                    _buildMemberItem(
                      name: widget.name,
                      avatar: widget.avatarPath,
                      role: "NHÂN SỰ",
                    ),
                    const SizedBox(height: 16),
                    _buildMemberItem(
                      name: "Bạn",
                      avatar: null,
                      role: "NHÂN SỰ",
                      isMe: true,
                    ),
                  ],
                ),
              ),
            ],
            
            const SizedBox(height: 32),
            
            // Thông tin về đoạn chat
            _buildSectionHeader("Thông tin về đoạn chat"),
            _buildMenuItem(
              icon: Icons.image_outlined,
              title: "Xem file phương tiện, file và liên kết",
              onTap: () {},
            ),
            
            const SizedBox(height: 32),
            
            // Hành động
            _buildSectionHeader("Hành động"),
            _buildMenuItem(
              icon: _isMuted ? Icons.notifications_active_rounded : Icons.notifications_off_rounded,
              title: _isMuted ? "Bật thông báo về ${widget.name}" : "Tắt thông báo về ${widget.name}",
              onTap: () {
                setState(() {
                  _isMuted = !_isMuted;
                });
                widget.onMuteToggle(_isMuted);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(_isMuted ? "Đã tắt thông báo" : "Đã bật thông báo")),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMemberItem({
    required String name,
    String? avatar,
    required String role,
    bool isMe = false,
  }) {
    return Row(
      children: [
        CircleAvatar(
          radius: 20,
          backgroundColor: Colors.grey.shade200,
          backgroundImage: avatar != null && avatar.isNotEmpty
              ? NetworkImage(ApiService.resolveImageUrl(avatar))
              : null,
          child: (avatar == null || avatar.isEmpty)
              ? Text(
                  name.isNotEmpty ? name[0] : "?",
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                )
              : null,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                name,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1E293B),
                ),
              ),
              Text(
                role,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey.shade500,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSectionHeader(String title) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      child: Text(
        title,
        style: TextStyle(
          color: Colors.grey[600],
          fontSize: 13,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildMenuItem({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
  }) {
    return ListTile(
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
      leading: Icon(icon, color: Colors.black87, size: 24),
      title: Text(
        title,
        style: const TextStyle(
          color: Colors.black87,
          fontSize: 16,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}
