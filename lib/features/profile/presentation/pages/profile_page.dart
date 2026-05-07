import 'package:flutter/material.dart';
import '../../../../core/api_service.dart';
import '../../../../core/security.dart';
import '../widgets/profile_settings_sheet.dart';
import '../../../../core/utils/notification_helper.dart';
import 'package:file_picker/file_picker.dart';
import '../../../../core/utils/update_helper.dart';

class ProfilePage extends StatefulWidget {
  final Map<String, dynamic>? user;
  const ProfilePage({super.key, this.user});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  String _name = "...";
  String _job = "...";
  String _department = "...";
  String _phone = "...";
  String _birth = "...";
  String _gender = "...";
  String _employeeId = "...";
  String _email = "...";
  String? _avatarUrl;
  bool _isLoading = false;
  String _activeSoundName = "Mặc định";

  @override
  void initState() {
    super.initState();
    if (widget.user != null) {
      _applyData(widget.user!);
      // Vẫn fetch thêm để cập nhật dữ liệu mới nhất nếu có thay đổi từ web
      _fetchProfile();
    } else {
      _fetchProfile();
    }
    _loadActiveSound();
  }

  Future<void> _loadActiveSound() async {
    final sound = await NotificationHelper.getActiveSound();
    if (mounted) {
      setState(() => _activeSoundName = sound['name'] ?? "Mặc định");
    }
  }

  void _applyData(Map<String, dynamic> data) {
    _name = data["fullName"] ?? data["name"] ?? data["display_name"] ?? "Mới";
    _job = data["position"] ?? data["jobTitle"] ?? data["job"] ?? "Vị trí";
    _department = data["department"] ?? "";
    _phone = data["phoneNumber"] ?? data["phone"] ?? data["phone_number"] ?? "";
    _gender = data["gender"] ?? "Nam";
    // Birth: show "Chưa đặt" if null or empty
    final rawBirth =
        data["dateOfBirth"] ??
        data["dateofbirth"] ??
        data["birthDate"] ??
        data["birth_date"] ??
        data["birth"] ??
        data["birthday"] ??
        data["dob"];
    if (rawBirth != null && rawBirth.toString().isNotEmpty) {
      try {
        final dt = DateTime.parse(rawBirth.toString()).toLocal();
        _birth =
            "${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}";
      } catch (e) {
        _birth = rawBirth.toString();
      }
    } else {
      _birth = "Chưa đặt";
    }
    // Employee ID: not available from API yet → N/A
    _employeeId = data["employeeId"] ?? data["employee_id"] ?? "N/A";
    _email = data["email"] ?? data["emailAddress"] ?? data["user_email"] ?? "";
    // profilePicture may be a MongoDB ObjectId → resolve to proper URL
    final picId = data["profilePicture"] ?? data["avatar"];
    _avatarUrl = picId != null ? ApiService.resolveImageUrl(picId) : null;
    _isLoading = false;
  }

  Future<void> _fetchProfile() async {
    // 1. Load from cached data if available
    final cached = (widget.user != null)
        ? widget.user
        : AuthService().userProfile.value;
    if (cached != null && mounted) {
      setState(() => _applyData(cached));
    } else {
      setState(() => _isLoading = true);
    }

    // 2. Refresh from API
    // If we have widget.user, we might want to fetch a specific user profile
    // But for now, we'll refresh 'getMe' to ensure global state is fresh
    final data = await ApiService.getMe();
    if (data != null && mounted) {
      setState(() => _applyData(data));
    } else if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _pickNotificationSound() async {
    final List<Map<String, String>> sounds =
        await NotificationHelper.getAvailableSounds();

    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Container(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          "ÂM THANH THÔNG BÁO",
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            color: Colors.blueGrey,
                            letterSpacing: 1.0,
                          ),
                        ),
                        IconButton(
                          onPressed: () async {
                            FilePickerResult? result = await FilePicker.platform
                                .pickFiles(
                                  type: FileType.custom,
                                  allowedExtensions: ['mp3', 'wav', 'ogg'],
                                );
                            if (result != null &&
                                result.files.single.path != null) {
                              String path = result.files.single.path!;
                              String name = result.files.single.name;
                              await NotificationHelper.addSound(name, path);
                              final updatedSounds =
                                  await NotificationHelper.getAvailableSounds();
                              setModalState(() {
                                sounds.clear();
                                sounds.addAll(updatedSounds);
                              });
                            }
                          },
                          icon: const Icon(
                            Icons.add_circle,
                            color: Colors.blue,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Flexible(
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: sounds.length,
                      itemBuilder: (context, index) {
                        final sound = sounds[index];
                        final bool isActive = _activeSoundName == sound['name'];
                        return ListTile(
                          leading: Icon(
                            isActive
                                ? Icons.check_circle
                                : Icons.music_note_outlined,
                            color: isActive ? Colors.blue : Colors.blueGrey,
                          ),
                          title: Text(
                            sound['name']!,
                            style: TextStyle(
                              fontWeight: isActive
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                              color: isActive ? Colors.blue : Colors.black87,
                            ),
                          ),
                          onTap: () async {
                            await NotificationHelper.setActiveSound(
                              sound['name']!,
                              sound['path']!,
                            );
                            await _loadActiveSound();
                            if (context.mounted) Navigator.pop(context);
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _showSettings() {
    if (widget.user != null) return;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => ProfileSettingsSheet(
        initialData: {
          "phone": _phone,
          "birth": _birth,
          "gender": _gender,
          "job": _job,
          "name": _name,
        },
        onUpdate: (newData) async {
          final payload = {
            "email": _email,
            "fullName": _name,
            "phoneNumber": newData["phone"],
            "dateOfBirth": newData["birth"],
            "gender": newData["gender"],
            "position": newData["job"],
          };
          final success = await ApiService.updateProfile(payload);
          if (success && mounted) {
            _fetchProfile();
          }
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool isDesktop = MediaQuery.of(context).size.width > 900;

    if (!isDesktop) {
      return Scaffold(
        backgroundColor: Colors.white,
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
                child: Column(
                  children: [
                    Stack(
                      clipBehavior: Clip.none,
                      alignment: Alignment.bottomCenter,
                      children: [
                        Container(
                          height: 220,
                          decoration: const BoxDecoration(
                            gradient: LinearGradient(
                              colors: [Color(0xFF3B82F6), Color(0xFF6366F1)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.vertical(
                              bottom: Radius.circular(40),
                            ),
                          ),
                        ),
                        if (widget.user != null)
                          Positioned(
                            top: MediaQuery.of(context).padding.top + 8,
                            left: 8,
                            child: IconButton(
                              icon: const Icon(
                                Icons.arrow_back_ios_new,
                                color: Colors.white,
                              ),
                              onPressed: () => Navigator.pop(context),
                            ),
                          ),
                        Positioned(
                          bottom: -60,
                          child: Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(32),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.1),
                                  blurRadius: 20,
                                  offset: const Offset(0, 10),
                                ),
                              ],
                            ),
                            child: Container(
                              width: 120,
                              height: 120,
                              decoration: BoxDecoration(
                                color: Colors.blueGrey.shade50,
                                borderRadius: BorderRadius.circular(28),
                              ),
                              child: _avatarUrl != null
                                  ? FutureBuilder<Map<String, String>>(
                                      future: ApiService.getAuthHeaders(),
                                      builder: (context, headers) {
                                        return ClipRRect(
                                          borderRadius: BorderRadius.circular(
                                            28,
                                          ),
                                          child: Image.network(
                                            ApiService.resolveImageUrl(
                                              _avatarUrl,
                                            ),
                                            fit: BoxFit.cover,
                                            headers: headers.data,
                                            errorBuilder: (ctx, err, stack) =>
                                                const Icon(
                                                  Icons.person,
                                                  size: 70,
                                                  color: Colors.blueGrey,
                                                ),
                                          ),
                                        );
                                      },
                                    )
                                  : const Icon(
                                      Icons.person,
                                      size: 70,
                                      color: Colors.blueGrey,
                                    ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 80),
                    Text(
                      _name,
                      style: const TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 24,
                        color: Color(0xFF1E293B),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.verified_user_sharp,
                          size: 14,
                          color: const Color(0xFF3B82F6).withOpacity(0.8),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          (_job +
                                  (_department.isNotEmpty
                                      ? ' • $_department'
                                      : ''))
                              .toUpperCase(),
                          style: const TextStyle(
                            color: Color(0xFF64748B),
                            fontWeight: FontWeight.bold,
                            fontSize: 10,
                            letterSpacing: 1.2,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 32),
                    if (widget.user == null)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        child: Row(
                          children: [
                            Expanded(
                              child: _AlignedButton(
                                label: "THIẾT LẬP HỒ SƠ",
                                icon: Icons.edit_note_outlined,
                                isSolid: true,
                                onTap: _showSettings,
                              ),
                            ),
                          ],
                        ),
                      ),
                    const SizedBox(height: 48),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Column(
                        children: [
                          _InfoField(
                            icon: Icons.email_outlined,
                            label: "EMAIL",
                            value: _email,
                          ),
                          _InfoField(
                            icon: Icons.phone_outlined,
                            label: "ĐIỆN THOẠI",
                            value: _phone,
                          ),
                          _InfoField(
                            icon: Icons.calendar_today_outlined,
                            label: "NGÀY SINH",
                            value: _birth,
                          ),
                          _InfoField(
                            icon: Icons.badge_outlined,
                            label: "ID NHÂN VIÊN",
                            value: _employeeId,
                          ),
                          const _InfoField(
                            icon: Icons.language_outlined,
                            label: "NGÔN NGỮ",
                            value: "Tiếng Việt",
                          ),
                          const SizedBox(height: 12),
                          _SettingsItem(
                            icon: Icons.music_note_outlined,
                            label: "ÂM THANH THÔNG BÁO",
                            value: _activeSoundName,
                            onTap: _pickNotificationSound,
                          ),
                          _SettingsItem(
                            icon: Icons.system_update_outlined,
                            label: "CẬP NHẬT ỨNG DỤNG",
                            value: "Kiểm tra phiên bản mới",
                            onTap: () => UpdateHelper.checkUpdate(context),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 100),
                  ],
                ),
              ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              child: Center(
                child: Container(
                  constraints: const BoxConstraints(maxWidth: 900),
                  padding: const EdgeInsets.symmetric(
                    vertical: 40,
                    horizontal: 24,
                  ),
                  child: Column(
                    children: [
                      // Profile Header Card
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(32),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.04),
                              blurRadius: 20,
                              offset: const Offset(0, 10),
                            ),
                          ],
                        ),
                        child: Column(
                          children: [
                            Stack(
                              clipBehavior: Clip.none,
                              alignment: Alignment.bottomCenter,
                              children: [
                                Container(
                                  height: 180,
                                  decoration: const BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: [
                                        Color(0xFF3B82F6),
                                        Color(0xFF6366F1),
                                      ],
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                    ),
                                    borderRadius: BorderRadius.only(
                                      topLeft: Radius.circular(32),
                                      topRight: Radius.circular(32),
                                      bottomLeft: Radius.circular(40),
                                      bottomRight: Radius.circular(40),
                                    ),
                                  ),
                                ),
                                if (widget.user != null)
                                  Positioned(
                                    top: 16,
                                    left: 16,
                                    child: IconButton(
                                      icon: const Icon(
                                        Icons.arrow_back_ios_new,
                                        color: Colors.white,
                                      ),
                                      onPressed: () => Navigator.pop(context),
                                    ),
                                  ),
                                Positioned(
                                  bottom: -50,
                                  child: Container(
                                    padding: const EdgeInsets.all(6),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(32),
                                    ),
                                    child: Container(
                                      width: 100,
                                      height: 100,
                                      decoration: BoxDecoration(
                                        color: Colors.blueGrey.shade50,
                                        borderRadius: BorderRadius.circular(28),
                                      ),
                                      child: _avatarUrl != null
                                          ? FutureBuilder<Map<String, String>>(
                                              future:
                                                  ApiService.getAuthHeaders(),
                                              builder: (context, headers) {
                                                return ClipRRect(
                                                  borderRadius:
                                                      BorderRadius.circular(28),
                                                  child: Image.network(
                                                    ApiService.resolveImageUrl(
                                                      _avatarUrl,
                                                    ),
                                                    fit: BoxFit.cover,
                                                    headers: headers.data,
                                                    errorBuilder:
                                                        (ctx, err, stack) =>
                                                            const Icon(
                                                              Icons.person,
                                                              size: 60,
                                                              color: Colors
                                                                  .blueGrey,
                                                            ),
                                                  ),
                                                );
                                              },
                                            )
                                          : const Icon(
                                              Icons.person,
                                              size: 60,
                                              color: Colors.blueGrey,
                                            ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 60),
                            Text(
                              _name,
                              style: const TextStyle(
                                fontWeight: FontWeight.w900,
                                fontSize: 24,
                                color: Color(0xFF1E293B),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.verified_user_sharp,
                                  size: 14,
                                  color: const Color(
                                    0xFF3B82F6,
                                  ).withOpacity(0.8),
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  (_job +
                                          (_department.isNotEmpty
                                              ? ' • $_department'
                                              : ''))
                                      .toUpperCase(),
                                  style: const TextStyle(
                                    color: Color(0xFF64748B),
                                    fontWeight: FontWeight.bold,
                                    fontSize: 10,
                                    letterSpacing: 1.2,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 24),
                            if (widget.user == null)
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 24,
                                ),
                                child: SizedBox(
                                  width: 300,
                                  child: _AlignedButton(
                                    label: "THIẾT LẬP HỒ SƠ",
                                    icon: Icons.edit_note_outlined,
                                    isSolid: true,
                                    onTap: _showSettings,
                                  ),
                                ),
                              ),
                            const SizedBox(height: 32),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                      // Info Fields Card
                      Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(32),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.04),
                              blurRadius: 20,
                              offset: const Offset(0, 10),
                            ),
                          ],
                        ),
                        child: GridView.count(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          crossAxisCount: 2,
                          crossAxisSpacing: 16,
                          mainAxisSpacing: 4,
                          childAspectRatio: 3.5,
                          children: [
                            _InfoField(
                              icon: Icons.email_outlined,
                              label: "EMAIL",
                              value: _email,
                            ),
                            _InfoField(
                              icon: Icons.phone_outlined,
                              label: "ĐIỆN THOẠI",
                              value: _phone,
                            ),
                            _InfoField(
                              icon: Icons.calendar_today_outlined,
                              label: "NGÀY SINH",
                              value: _birth,
                            ),
                            _InfoField(
                              icon: Icons.badge_outlined,
                              label: "ID NHÂN VIÊN",
                              value: _employeeId,
                            ),
                            const _InfoField(
                              icon: Icons.language_outlined,
                              label: "NGÔN NGỮ",
                              value: "Tiếng Việt",
                            ),
                            _SettingsItem(
                              icon: Icons.music_note_outlined,
                              label: "ÂM THANH THÔNG BÁO",
                              value: _activeSoundName,
                              onTap: _pickNotificationSound,
                            ),
                            _SettingsItem(
                              icon: Icons.system_update_outlined,
                              label: "CẬP NHẬT ỨNG DỤNG",
                              value: "Kiểm tra phiên bản mới",
                              onTap: () => UpdateHelper.checkUpdate(context),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 100),
                    ],
                  ),
                ),
              ),
            ),
    );
  }
}

class _AlignedButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool isSolid;
  final VoidCallback onTap;
  const _AlignedButton({
    required this.label,
    required this.icon,
    required this.isSolid,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 18),
        decoration: BoxDecoration(
          color: isSolid ? const Color(0xFF3B82F6) : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: isSolid
              ? null
              : Border.all(color: Colors.blue.withOpacity(0.1)),
          boxShadow: isSolid
              ? [
                  BoxShadow(
                    color: const Color(0xFF3B82F6).withOpacity(0.3),
                    blurRadius: 15,
                    offset: const Offset(0, 8),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 20,
              color: isSolid ? Colors.white : Colors.blueGrey,
            ),
            const SizedBox(width: 12),
            Text(
              label,
              style: TextStyle(
                color: isSolid ? Colors.white : Colors.blueGrey,
                fontWeight: FontWeight.w900,
                fontSize: 12,
                letterSpacing: 1.0,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoField extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const _InfoField({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 14, color: Colors.blueAccent.withOpacity(0.6)),
              const SizedBox(width: 8),
              Text(
                label,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 9,
                  color: Colors.blueGrey,
                  letterSpacing: 1.0,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.only(left: 22),
            child: Text(
              value,
              style: const TextStyle(
                fontWeight: FontWeight.w900,
                fontSize: 14,
                color: Color(0xFF1E293B),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SettingsItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? value;
  final VoidCallback onTap;

  const _SettingsItem({
    required this.icon,
    required this.label,
    this.value,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(24),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: const Color(0xFF3B82F6).withOpacity(0.05),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: const Color(0xFF3B82F6).withOpacity(0.1)),
        ),
        child: Row(
          children: [
            Icon(icon, size: 20, color: const Color(0xFF3B82F6)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 11,
                      color: Colors.blueGrey,
                      letterSpacing: 0.5,
                    ),
                  ),
                  if (value != null)
                    Text(
                      value!,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: Color(0xFF1E293B),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, size: 18, color: Colors.blueGrey),
          ],
        ),
      ),
    );
  }
}
