import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../../../core/api_service.dart';

class ChatSettingsSheet extends StatefulWidget {
  final String name;
  final String? initials;
  final Color? color;
  final bool isGroup;
  final String? avatarPath;
  final List<Map<String, String>>? initialMembers;
  final Function(String, Color, String?) onUpdate;
  final Function(List<Map<String, String>>)? onUpdateMembers;

  const ChatSettingsSheet({
    super.key,
    this.name = "",
    this.initials,
    this.color = Colors.blue,
    this.isGroup = false,
    this.avatarPath,
    this.initialMembers,
    required this.onUpdate,
    this.onUpdateMembers,
  });

  @override
  State<ChatSettingsSheet> createState() => _ChatSettingsSheetState();
}

class _ChatSettingsSheetState extends State<ChatSettingsSheet> {
  late String _currentName;
  late Color _currentColor;
  String? _avatarPath;
  final bool _isOwner = true; // Hardcoded as owner for UI

  late List<Map<String, String>> _members;
  bool _isMembersExpanded = true;
  bool _isFilesExpanded = false;

  final List<Color> _themeColors = [
    Colors.blue,
    Colors.pink,
    Colors.purple,
    Colors.green,
    Colors.orange,
    Colors.blueGrey,
    Colors.red,
  ];

  @override
  void initState() {
    super.initState();
    _currentName = widget.name;
    _currentColor = widget.color ?? Colors.blue;
    _avatarPath = widget.avatarPath;
    _members = List.from(widget.initialMembers ?? []);
    if (widget.isGroup && _members.isEmpty) {
      // Dữ liệu thành viên sẽ được cập nhật từ API
    }
  }

  @override
  void dispose() {
    super.dispose();
  }

  void _editName() {
    if (!widget.isGroup) return; // Chỉ cho phép đổi đối với nhóm

    final c = TextEditingController(text: _currentName);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Đổi tên nhóm"),
        content: TextField(
          controller: c,
          decoration: const InputDecoration(hintText: "Nhập tên nhóm mới"),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Hủy"),
          ),
          ElevatedButton(
            onPressed: () {
              if (c.text.isNotEmpty) {
                setState(() => _currentName = c.text);
                widget.onUpdate(_currentName, _currentColor, _avatarPath);
              }
              Navigator.pop(ctx);
            },
            child: const Text("Lưu"),
          ),
        ],
      ),
    );
  }

  void _changeColor(Color color) {
    setState(() => _currentColor = color);
    widget.onUpdate(_currentName, _currentColor, _avatarPath);
  }

  Future<void> _pickAvatar() async {
    if (!widget.isGroup) return;
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      setState(() => _avatarPath = pickedFile.path);
      widget.onUpdate(_currentName, _currentColor, _avatarPath);
    }
  }

  void _removeMember(int index) {
    final memberName = _members[index]["name"] ?? _members[index]["fullName"] ?? "Thành viên này";
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Xác nhận xóa"),
        content: Text("Bạn có chắc chắn muốn mời $memberName ra khỏi nhóm?"),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Hủy", style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () {
              setState(() {
                _members.removeAt(index);
              });
              if (widget.onUpdateMembers != null) {
                widget.onUpdateMembers!(_members);
              }
              Navigator.pop(ctx);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text(
              "XÓA",
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _addMember() {
    final List<Map<String, String>> availableContacts = [
      {"name": "Trần Văn Quang", "role": "Nhân sự"},
      {"name": "Nguyễn Hùng Cường", "role": "Nhân sự"},
      {"name": "Lê Thị Lan", "role": "Kế toán"},
      {"name": "Phạm Văn Minh", "role": "Thiết kế"},
    ];

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                "Thêm thành viên",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              ...availableContacts.map((c) {
                final isAdded = _members.any((m) => m["name"] == c["name"]);
                return ListTile(
                  leading: CircleAvatar(
                    backgroundColor: Colors.blueGrey.shade50,
                    child: Text(
                      c["name"]!.substring(0, 1),
                      style: const TextStyle(
                        color: Colors.blueGrey,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  title: Text(
                    c["name"]!,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: isAdded ? Colors.grey : Colors.black87,
                    ),
                  ),
                  subtitle: Text(c["role"]!),
                  trailing: isAdded
                      ? const Icon(Icons.check_circle, color: Colors.green)
                      : const Icon(
                          Icons.add_circle_outline,
                          color: Colors.blue,
                        ),
                  onTap: () {
                    if (isAdded) return;
                    setState(() {
                      _members.add({
                        "name": c["name"]!,
                        "role": c["role"]!.toUpperCase(),
                        "isOwner": "false",
                        "fullName": c["name"]!,
                      });
                    });
                    if (widget.onUpdateMembers != null) {
                      widget.onUpdateMembers!(_members);
                    }
                    Navigator.pop(context);
                  },
                );
              }).toList(),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.9,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  "CÀI ĐẶT HỘI THOẠI",
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 14,
                    color: Color(0xFF0F172A),
                    letterSpacing: 0.5,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.black87),
                  splashRadius: 24,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
          const Divider(height: 1),

          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
              child: Column(
                children: [
                  // Avatar & Name
                  Center(
                    child: Stack(
                      children: [
                        GestureDetector(
                          onTap: _pickAvatar,
                          child: Container(
                            width: 80,
                            height: 80,
                            decoration: BoxDecoration(
                              color: Colors.grey.shade300,
                              borderRadius: BorderRadius.circular(24),
                              image: _avatarPath != null && _avatarPath!.isNotEmpty
                                  ? DecorationImage(
                                      image: _avatarPath!.startsWith('http')
                                          ? NetworkImage(ApiService.resolveImageUrl(_avatarPath!)) as ImageProvider
                                          : FileImage(File(_avatarPath!)),
                                      fit: BoxFit.cover,
                                    )
                                  : null,
                            ),
                            alignment: Alignment.center,
                            child: _avatarPath == null || _avatarPath!.isEmpty
                                ? Text(
                                    _currentName.length >= 2
                                        ? _currentName
                                              .substring(0, 2)
                                              .toUpperCase()
                                        : _currentName.toUpperCase(),
                                    style: const TextStyle(
                                      fontSize: 32,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.black87,
                                    ),
                                  )
                                : null,
                          ),
                        ),
                        if (widget.isGroup)
                          Positioned(
                            right: -4,
                            bottom: -4,
                            child: GestureDetector(
                              onTap: _pickAvatar,
                              child: Container(
                                padding: const EdgeInsets.all(4),
                                decoration: BoxDecoration(
                                  color: Colors.blue,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: Colors.white,
                                    width: 2,
                                  ),
                                ),
                                child: const Icon(
                                  Icons.camera_alt_outlined,
                                  color: Colors.white,
                                  size: 16,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Tên (có nút sửa nếu là nhóm)
                  GestureDetector(
                    onTap: _editName,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          _currentName,
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                        if (widget.isGroup) ...[
                          const SizedBox(width: 8),
                          const Icon(
                            Icons.edit_outlined,
                            color: Colors.grey,
                            size: 18,
                          ),
                        ],
                      ],
                    ),
                  ),

                  const SizedBox(height: 32),

                  // Chủ đề hội thoại (Màu tin nhắn)
                  const Text(
                    "CHỦ ĐỀ HỘI THOẠI",
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: Colors.blueGrey,
                      letterSpacing: 1,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(32),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.04),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Wrap(
                      alignment: WrapAlignment.center,
                      spacing: 0,
                      runSpacing: 8,
                      children: _themeColors.map((color) {
                        final isSelected = _currentColor.value == color.value;
                        return GestureDetector(
                          onTap: () => _changeColor(color),
                          child: Container(
                            margin: const EdgeInsets.symmetric(horizontal: 4),
                            padding: const EdgeInsets.all(2),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: isSelected
                                    ? Colors.grey.shade300
                                    : Colors.transparent,
                                width: 2,
                              ),
                            ),
                            child: CircleAvatar(
                              radius: 14,
                              backgroundColor: color,
                              child: isSelected
                                  ? const Icon(
                                      Icons.check,
                                      color: Colors.white,
                                      size: 14,
                                    )
                                  : null,
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),

                  const SizedBox(height: 32),

                  // Thành viên
                  GestureDetector(
                    onTap: () => setState(() => _isMembersExpanded = !_isMembersExpanded),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      color: Colors.transparent, // to increase touch area
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            "THÀNH VIÊN (${_members.length})",
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: Colors.blueGrey.shade400,
                              letterSpacing: 1,
                            ),
                          ),
                          Row(
                            children: [
                              if (widget.isGroup)
                                GestureDetector(
                                  onTap: _addMember,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 6,
                                    ),
                                    decoration: BoxDecoration(
                                      color: _currentColor.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Row(
                                      children: [
                                        Icon(
                                          Icons.person_add_alt_1_outlined,
                                          color: _currentColor,
                                          size: 14,
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          "THÊM NGƯỜI",
                                          style: TextStyle(
                                            color: _currentColor,
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              const SizedBox(width: 12),
                              Icon(
                                _isMembersExpanded
                                    ? Icons.keyboard_arrow_up
                                    : Icons.keyboard_arrow_down,
                                color: Colors.blueGrey.shade400,
                                size: 20,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (_isMembersExpanded) ...[
                    const SizedBox(height: 8),
                    // Danh sách thành viên
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: _members.isEmpty
                          ? const Padding(
                              padding: EdgeInsets.symmetric(vertical: 20),
                              child: Center(
                                child: Text(
                                  "Chưa có thành viên nào",
                                  style: TextStyle(
                                    color: Colors.grey,
                                    fontSize: 13,
                                    fontStyle: FontStyle.italic,
                                  ),
                                ),
                              ),
                            )
                          : Column(
                              children: _members.asMap().entries.map((entry) {
                                final i = entry.key;
                                final m = entry.value;
                                final memberName = m["name"] ?? m["fullName"] ?? "";
                                final memberRole = m["role"] ?? "Nhân sự";
                                final memberIsOwner = m["isOwner"] == "true";
                                final memberAvatarPath = m["profilePicture"] ?? m["avatar"];
                                return _MemberTile(
                                  name: memberName,
                                  role: memberRole,
                                  isOwner: memberIsOwner,
                                  avatarPath: memberAvatarPath,
                                  showRemoval: widget.isGroup &&
                                      _isOwner &&
                                      !memberIsOwner,
                                  onRemove: () => _removeMember(i),
                                );
                              }).toList(),
                            ),
                    ),
                  ],
                  const SizedBox(height: 24),
                  const Divider(height: 1),
                  const SizedBox(height: 24),

                  // Danh sách tệp
                  GestureDetector(
                    onTap: () => setState(() => _isFilesExpanded = !_isFilesExpanded),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      color: Colors.transparent,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            "DANH SÁCH TỆP (0)",
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: Colors.blueGrey.shade400,
                              letterSpacing: 1,
                            ),
                          ),
                          Icon(
                            _isFilesExpanded
                                ? Icons.keyboard_arrow_up
                                : Icons.keyboard_arrow_down,
                            color: Colors.blueGrey.shade400,
                            size: 20,
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (_isFilesExpanded) ...[
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: TextField(
                        decoration: InputDecoration(
                          hintText: "Tìm tên file...",
                          hintStyle: TextStyle(color: Colors.blueGrey.shade300, fontSize: 13),
                          border: InputBorder.none,
                          icon: Icon(Icons.search, color: Colors.blueGrey.shade300, size: 18),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    Center(
                      child: Text(
                        "Chưa có tài liệu nào",
                        style: TextStyle(
                          color: Colors.blueGrey.shade300,
                          fontSize: 11,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 32),

                  if (widget.isGroup) ...[
                    // Nút rời nhóm
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        onPressed: () {
                          // TODO: Thêm logic thực tế
                          Navigator.pop(context, 'leave');
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.orange.shade50,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.output_rounded,
                              color: Colors.deepOrange.shade600,
                              size: 18,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              "RỜI KHỎI NHÓM",
                              style: TextStyle(
                                color: Colors.deepOrange.shade600,
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Giải tán nhóm (Chủ nhóm mới có)
                    if (_isOwner)
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton(
                          onPressed: () {
                            // TODO: Thêm logic thực tế
                            Navigator.pop(context, 'disband');
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red.shade50,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.delete_outline,
                                color: Colors.red.shade700,
                                size: 18,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                "GIẢI TÁN NHÓM (XOÁ VĨNH VIỄN)",
                                style: TextStyle(
                                  color: Colors.red.shade700,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    const SizedBox(height: 24),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MemberTile extends StatelessWidget {
  final String name;
  final String role;
  final bool isOwner;
  final bool showRemoval;
  final String? avatarPath;
  final VoidCallback? onRemove;

  const _MemberTile({
    required this.name,
    required this.role,
    this.isOwner = false,
    this.showRemoval = false,
    this.avatarPath,
    this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: Colors.grey.shade300,
            backgroundImage: avatarPath != null && avatarPath!.isNotEmpty
                ? NetworkImage(ApiService.resolveImageUrl(avatarPath!)) as ImageProvider
                : null,
            child: avatarPath == null || avatarPath!.isEmpty
                ? Text(name.isNotEmpty ? name[0].toUpperCase() : '?', style: const TextStyle(color: Colors.black54))
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
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    color: Color(0xFF0F172A),
                  ),
                ),
                Text(
                  role,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 9,
                    color: Colors.blueGrey,
                  ),
                ),
              ],
            ),
          ),
          if (isOwner)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text(
                "CHỦ NHÓM",
                style: TextStyle(
                  color: Colors.blue,
                  fontWeight: FontWeight.bold,
                  fontSize: 9,
                ),
              ),
            )
          else if (showRemoval)
            IconButton(
              icon: const Icon(Icons.close, color: Colors.redAccent, size: 18),
              constraints: const BoxConstraints(),
              padding: EdgeInsets.zero,
              onPressed: onRemove,
            ),
        ],
      ),
    );
  }
}
