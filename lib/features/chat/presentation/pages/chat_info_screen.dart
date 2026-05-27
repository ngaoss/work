import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../../core/api_service.dart';
import '../../../../core/security.dart';
import 'media_files_links_screen.dart';

class ChatInfoScreen extends StatefulWidget {
  final String name;
  final String? avatarPath;
  final String? conversationId;
  final String? createdBy;
  final bool isGroup;
  final bool isMuted;
  final Color themeColor;
  final Function(bool) onMuteToggle;
  final Function(Color) onThemeChanged;
  final Function(String) onNameChanged;
  final List<Map<String, dynamic>>? initialMembers;

  const ChatInfoScreen({
    super.key,
    required this.name,
    this.avatarPath,
    this.conversationId,
    this.createdBy,
    this.isGroup = false,
    this.isMuted = false,
    this.themeColor = const Color(0xFF3B82F6),
    required this.onMuteToggle,
    required this.onThemeChanged,
    required this.onNameChanged,
    this.initialMembers,
  });

  @override
  State<ChatInfoScreen> createState() => _ChatInfoScreenState();
}

class _ChatInfoScreenState extends State<ChatInfoScreen> {
  late bool _isMuted;
  late Color _selectedColor;
  late String _name;
  late List<Map<String, dynamic>> _members;
  bool _isMembersExpanded = true;
  String? _createdBy;
  String? _avatarPath;
  bool _isUploadingAvatar = false;

  final List<Color> _themeColors = [
    const Color(0xFF3B82F6),
    const Color(0xFF10B981),
    const Color(0xFFF59E0B),
    const Color(0xFFEF4444),
    const Color(0xFF8B5CF6),
    const Color(0xFFEC4899),
  ];

  Color _getAvatarColor(String name) {
    if (name.isEmpty) return const Color(0xFF3B82F6);
    int hash = 0;
    for (var i = 0; i < name.length; i++) {
      hash = name.codeUnitAt(i) + ((hash << 5) - hash);
    }
    final index = hash.abs() % _themeColors.length;
    return _themeColors[index];
  }

  @override
  void initState() {
    super.initState();
    _isMuted = widget.isMuted;
    _selectedColor = widget.themeColor;
    _name = widget.name;
    _avatarPath = widget.avatarPath;
    _createdBy = widget.createdBy;
    _members = widget.initialMembers ?? [];
    _fetchLatestInfo();
  }

  Future<void> _fetchLatestInfo() async {
    if (widget.conversationId == null) return;
    try {
      final chat = await ApiService.getChatDetails(widget.conversationId!);
      if (mounted && chat != null) {
        setState(() {
          final participants = List<dynamic>.from(chat["participants"] ?? []);
          _members = participants
              .map((e) => Map<String, dynamic>.from(e))
              .toList();

          _createdBy = chat["createdBy"] is Map
              ? chat["createdBy"]["_id"]?.toString()
              : chat["createdBy"]?.toString();
        });
      }
    } catch (e) {
      debugPrint("Error fetching latest chat info: $e");
    }
  }

  Future<void> _changeAvatar() async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1024,
      maxHeight: 1024,
      imageQuality: 85,
    );

    if (image == null) return;

    if (mounted) {
      setState(() => _isUploadingAvatar = true);
    }

    try {
      final file = File(image.path);
      final uploadRes = await ApiService.uploadDocument(
        file,
        conversationId: widget.conversationId,
      );

      if (uploadRes != null && uploadRes['path'] != null) {
        final newAvatarPath = uploadRes['path'].toString();
        final success = await ApiService.updateGroupInfo(
          widget.conversationId!,
          {'avatar': newAvatarPath},
        );

        if (success && mounted) {
          setState(() {
            _avatarPath = newAvatarPath;
            _isUploadingAvatar = false;
          });
        }
      } else {
        throw "Không thể tải ảnh lên máy chủ";
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isUploadingAvatar = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Lỗi khi tải ảnh lên: $e")));
      }
    }
  }

  Future<void> _showRenameDialog() async {
    final TextEditingController controller = TextEditingController(text: _name);
    final newName = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Đổi tên nhóm"),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(hintText: "Nhập tên nhóm mới"),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Hủy"),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text("Lưu"),
          ),
        ],
      ),
    );

    if (newName != null && newName.isNotEmpty && newName != _name) {
      final success = await ApiService.updateGroupInfo(widget.conversationId!, {
        'name': newName,
      });
      if (success && mounted) {
        setState(() => _name = newName);
        widget.onNameChanged(newName);
      }
    }
  }

  void _showAddMemberDialog() async {
    final List<Map<String, dynamic>> users = (await ApiService.searchUsers(
      "",
    )).cast<Map<String, dynamic>>();
    if (!mounted) return;

    showDialog(
      context: context,
      builder: (context) => _AddMemberDialog(
        availableUsers: users,
        onAdd: (query, user) async {
          final success = await ApiService.addMembers(widget.conversationId!, [
            (user["_id"] ?? user["id"]).toString(),
          ]);
          if (success) {
            _fetchLatestInfo();
          }
        },
      ),
    );
  }

  Future<void> _removeMember(Map<String, dynamic> member) async {
    final mId = (member["_id"] ?? member["id"])?.toString();
    if (mId == null || widget.conversationId == null) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Xóa thành viên"),
        content: Text(
          "Bạn có muốn xóa ${member["fullName"] ?? "người này"} khỏi nhóm?",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text("Hủy"),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text("Xóa"),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final success = await ApiService.removeMember(
        widget.conversationId!,
        mId,
      );
      if (success) {
        _fetchLatestInfo();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.surface,
        elevation: 0,
        centerTitle: true,
        title: Text(
          "CÀI ĐẶT HỘI THOẠI",
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurface,
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
      body: ListView(
        padding: EdgeInsets.zero,
        children: [
          const SizedBox(height: 20),
          // Avatar
          Center(
            child: GestureDetector(
              onTap: () {
                if (_isUploadingAvatar) return;
                if (!widget.isGroup) return;

                final currentUserId =
                    AuthService().userProfile.value?["_id"]?.toString() ??
                    AuthService().userProfile.value?["id"]?.toString();
                if (currentUserId != _createdBy) return;

                _changeAvatar();
              },
              child: Stack(
                children: [
                  Container(
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      image: _avatarPath != null && _avatarPath!.isNotEmpty
                          ? DecorationImage(
                              image: CachedNetworkImageProvider(
                                ApiService.resolveImageUrl(_avatarPath!),
                              ),
                              fit: BoxFit.cover,
                            )
                          : null,
                      color: Colors.grey[200],
                      border: Border.all(color: Colors.grey.shade100, width: 4),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child:
                        (_avatarPath == null || _avatarPath!.isEmpty) &&
                            !_isUploadingAvatar
                        ? Center(
                            child: Text(
                              _name.isNotEmpty ? _name[0].toUpperCase() : "?",
                              style: const TextStyle(
                                fontSize: 48,
                                fontWeight: FontWeight.bold,
                                color: Colors.blueAccent,
                              ),
                            ),
                          )
                        : null,
                  ),
                  if (_isUploadingAvatar)
                    Positioned.fill(
                      child: Container(
                        decoration: const BoxDecoration(
                          color: Colors.black26,
                          shape: BoxShape.circle,
                        ),
                        child: const Center(
                          child: CircularProgressIndicator(
                            strokeWidth: 3,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ),
                  if (!_isUploadingAvatar &&
                      widget.isGroup &&
                      (AuthService().userProfile.value?["_id"]?.toString() ??
                              AuthService().userProfile.value?["id"]
                                  ?.toString()) ==
                          _createdBy)
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.blue,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2),
                        ),
                        child: const Icon(
                          Icons.camera_alt,
                          color: Colors.white,
                          size: 18,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          // Name
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                _name,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF0F172A),
                ),
              ),
              if (widget.isGroup &&
                  (AuthService().userProfile.value?["_id"]?.toString() ??
                          AuthService().userProfile.value?["id"]?.toString()) ==
                      _createdBy) ...[
                const SizedBox(width: 8),
                IconButton(
                  iconSize: 20,
                  icon: const Icon(Icons.edit_outlined, color: Colors.blue),
                  onPressed: () => _showRenameDialog(),
                ),
              ],
            ],
          ),
          const SizedBox(height: 32),

          // CHỦ ĐỀ HỘI THOẠI
          Center(
            child: Text(
              "CHỦ ĐỀ HỘI THOẠI",
              style: TextStyle(
                color: Colors.grey[500],
                fontSize: 12,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.8,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 20),
            padding: const EdgeInsets.symmetric(vertical: 16),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(24),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: _themeColors.map((color) {
                final isSelected = _selectedColor == color;
                return GestureDetector(
                  onTap: () async {
                    if (widget.conversationId != null) {
                      final Color newColor = isSelected ? Colors.white : color;
                      setState(() => _selectedColor = newColor);
                      widget.onThemeChanged(newColor);

                      // Persist to server
                      final hexColor =
                          '#${newColor.value.toRadixString(16).substring(2).toUpperCase()}';
                      await ApiService.updateGroupInfo(widget.conversationId!, {
                        'themeColor': hexColor,
                      });
                    }
                  },
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 8),
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                      border: isSelected
                          ? Border.all(color: Colors.white, width: 3)
                          : null,
                      boxShadow: isSelected
                          ? [
                              BoxShadow(
                                color: color.withOpacity(0.4),
                                blurRadius: 8,
                                offset: const Offset(0, 4),
                              ),
                            ]
                          : null,
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 32),

          // Thành viên
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  "THÀNH VIÊN",
                  style: TextStyle(
                    color: Colors.grey[500],
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.8,
                  ),
                ),
                GestureDetector(
                  onTap: () =>
                      setState(() => _isMembersExpanded = !_isMembersExpanded),
                  child: Icon(
                    _isMembersExpanded
                        ? Icons.keyboard_arrow_up
                        : Icons.keyboard_arrow_down,
                    color: Colors.black45,
                    size: 20,
                  ),
                ),
                if (widget.isGroup)
                  TextButton.icon(
                    onPressed: () => _showAddMemberDialog(),
                    icon: const Icon(Icons.person_add_outlined, size: 18),
                    label: const Text(
                      "THÊM NGƯỜI",
                      style: TextStyle(fontSize: 11),
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
                color: Theme.of(context).colorScheme.surface,
                borderRadius: BorderRadius.circular(24),
              ),
              child: Column(
                children: _members.isEmpty
                    ? [
                        _buildMemberItem(
                          name: widget.name,
                          avatar: widget.avatarPath,
                          role: "NHÂN SỰ",
                        ),
                      ]
                    : _members.map((m) {
                        final String? mId = (m["_id"] ?? m["id"])?.toString();
                        final String? myId =
                            (AuthService().userProfile.value?['_id'] ??
                                    AuthService().userProfile.value?['id'])
                                ?.toString();
                        final bool isMe =
                            mId != null && myId != null && mId == myId;
                        final String? creatorId = _createdBy;
                        final bool isOwner =
                            mId != null &&
                            creatorId != null &&
                            mId == creatorId;
                        final bool iAmOwner =
                            myId != null &&
                            creatorId != null &&
                            myId == creatorId;

                        return Padding(
                          padding: const EdgeInsets.only(bottom: 16),
                          child: _buildMemberItem(
                            name: isMe
                                ? (m["fullName"] ?? m["name"] ?? "Bạn")
                                : (m["fullName"] ?? m["name"] ?? "Vô danh"),
                            avatar: m["profilePicture"] ?? m["avatar"],
                            role: m["role"] ?? "NHÂN SỰ",
                            isMe: isMe,
                            isOwner: isOwner,
                            onRemove: (widget.isGroup && iAmOwner && !isOwner)
                                ? () => _removeMember(m)
                                : null,
                          ),
                        );
                      }).toList(),
              ),
            ),
          ],
          const SizedBox(height: 32),

          _buildSectionHeader("Thông tin về đoạn chat"),
          _buildMenuItem(
            icon: Icons.image_outlined,
            title: "Xem file phương tiện, file và liên kết",
            onTap: () {
              if (widget.conversationId != null) {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => MediaFilesLinksScreen(
                      conversationId: widget.conversationId!,
                      chatName: _name,
                    ),
                  ),
                );
              }
            },
          ),
          const SizedBox(height: 32),

          _buildSectionHeader("Hành động"),
          _buildMenuItem(
            icon: _isMuted
                ? Icons.notifications_active_rounded
                : Icons.notifications_off_rounded,
            title: _isMuted
                ? "Bật thông báo về ${widget.name}"
                : "Tắt thông báo về ${widget.name}",
            onTap: () {
              setState(() => _isMuted = !_isMuted);
              widget.onMuteToggle(_isMuted);
            },
          ),
          if (widget.isGroup) ...[
            const SizedBox(height: 16),
            _buildMenuItem(
              icon: Icons.delete_outline,
              color: Colors.red,
              title: "Xóa nhóm",
              onTap: () async {
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text("Xóa nhóm"),
                    content: const Text(
                      "Bạn có chắc chắn muốn xóa nhóm này không? Hành động này không thể hoàn tác.",
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(ctx, false),
                        child: const Text(
                          "Hủy",
                          style: TextStyle(color: Colors.grey),
                        ),
                      ),
                      TextButton(
                        onPressed: () => Navigator.pop(ctx, true),
                        child: const Text(
                          "Xóa",
                          style: TextStyle(
                            color: Colors.red,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
                if (confirm == true && widget.conversationId != null) {
                  final success = await ApiService.deleteGroup(
                    widget.conversationId!,
                  );
                  if (success && mounted) Navigator.pop(context, "deleted");
                }
              },
            ),
          ],
          const SizedBox(height: 48),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          color: Colors.grey[500],
          fontSize: 11,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.8,
        ),
      ),
    );
  }

  Widget _buildMenuItem({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    Color? color,
  }) {
    return ListTile(
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
      leading: Icon(icon, color: color ?? Colors.black87, size: 24),
      title: Text(
        title,
        style: TextStyle(
          color: color ?? Colors.black87,
          fontSize: 16,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  Widget _buildMemberItem({
    required String name,
    String? avatar,
    required String role,
    bool isMe = false,
    bool isOwner = false,
    VoidCallback? onRemove,
  }) {
    return Row(
      children: [
        CircleAvatar(
          radius: 20,
          backgroundColor: _getAvatarColor(name).withOpacity(0.1),
          backgroundImage: avatar != null && avatar.isNotEmpty
              ? CachedNetworkImageProvider(ApiService.resolveImageUrl(avatar))
              : null,
          child: (avatar == null || avatar.isEmpty)
              ? Text(
                  name.isNotEmpty ? name[0].toUpperCase() : "?",
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: _getAvatarColor(name),
                  ),
                )
              : null,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Flexible(
                    child: Text(
                      name,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (isOwner) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        "CHỦ NHÓM",
                        style: TextStyle(
                          fontSize: 8,
                          fontWeight: FontWeight.bold,
                          color: Colors.blue.shade700,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              Text(
                role,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey.shade500,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
        if (onRemove != null)
          IconButton(
            icon: const Icon(Icons.close, color: Colors.redAccent, size: 18),
            onPressed: onRemove,
          ),
      ],
    );
  }
}

class _AddMemberDialog extends StatefulWidget {
  final List<Map<String, dynamic>> availableUsers;
  final Function(String, Map<String, dynamic>) onAdd;
  const _AddMemberDialog({required this.availableUsers, required this.onAdd});
  @override
  State<_AddMemberDialog> createState() => _AddMemberDialogState();
}

class _AddMemberDialogState extends State<_AddMemberDialog> {
  late List<Map<String, dynamic>> _filteredUsers;
  final List<Color> _themeColors = [
    const Color(0xFF3B82F6),
    const Color(0xFF10B981),
    const Color(0xFFF59E0B),
    const Color(0xFFEF4444),
    const Color(0xFF8B5CF6),
    const Color(0xFFEC4899),
  ];

  Color _getAvatarColor(String name) {
    if (name.isEmpty) return const Color(0xFF3B82F6);
    int hash = 0;
    for (var i = 0; i < name.length; i++) {
      hash = name.codeUnitAt(i) + ((hash << 5) - hash);
    }
    final index = hash.abs() % _themeColors.length;
    return _themeColors[index];
  }

  @override
  void initState() {
    super.initState();
    _filteredUsers = List.from(widget.availableUsers);
  }

  void _filterUsers(String query) {
    setState(() {
      _filteredUsers = widget.availableUsers.where((u) {
        final name = (u["fullName"] ?? u["name"] ?? "")
            .toString()
            .toLowerCase();
        return name.contains(query.toLowerCase());
      }).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Container(
        width: 450,
        constraints: const BoxConstraints(maxHeight: 600),
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back_ios, size: 16),
                  onPressed: () => Navigator.pop(context),
                ),
                Expanded(
                  child: Center(
                    child: Text(
                      "THÊM THÀNH VIÊN",
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.2,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 40),
              ],
            ),
            const SizedBox(height: 20),
            TextField(
              onChanged: _filterUsers,
              decoration: InputDecoration(
                hintText: "Tìm đồng nghiệp...",
                hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 13),
                prefixIcon: Icon(
                  Icons.search,
                  color: Colors.grey.shade400,
                  size: 18,
                ),
                filled: true,
                fillColor: Theme.of(context).brightness == Brightness.dark ? const Color(0xFF333537) : const Color(0xFFF1F5F9),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(vertical: 0),
              ),
            ),
            const SizedBox(height: 24),
            Expanded(
              child: ListView.builder(
                itemCount: _filteredUsers.length,
                itemBuilder: (context, index) {
                  final user = _filteredUsers[index];
                  final name = user["fullName"] ?? user["name"] ?? "Vô danh";
                  final role = user["role"] ?? "NHÂN SỰ";
                  final avatar = user["profilePicture"] ?? user["avatar"];

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: InkWell(
                      onTap: () {
                        widget.onAdd("", user);
                        Navigator.pop(context);
                      },
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 18,
                            backgroundColor: _getAvatarColor(
                              name,
                            ).withOpacity(0.1),
                            backgroundImage: avatar != null && avatar.isNotEmpty
                                ? CachedNetworkImageProvider(
                                    ApiService.resolveImageUrl(avatar),
                                  )
                                : null,
                            child: (avatar == null || avatar.isEmpty)
                                ? Text(
                                    name.isNotEmpty
                                        ? name[0].toUpperCase()
                                        : "?",
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: _getAvatarColor(name),
                                    ),
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
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    color: Theme.of(context).colorScheme.onSurface,
                                  ),
                                ),
                                Text(
                                  role,
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.grey.shade500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const Icon(
                            Icons.add_circle_outline,
                            color: Colors.blue,
                            size: 20,
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
