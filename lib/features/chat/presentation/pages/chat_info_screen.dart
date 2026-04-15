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
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black87),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black87),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.more_vert, color: Colors.black87),
            onPressed: () {},
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
            const SizedBox(height: 24),
            // Name
            Text(
              widget.name,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 48),
            
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
