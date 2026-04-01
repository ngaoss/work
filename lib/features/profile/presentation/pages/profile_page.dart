import 'package:flutter/material.dart';
import '../../../../core/api_service.dart';
import '../../../../core/security.dart';
import '../widgets/profile_settings_sheet.dart';

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

  @override
  void initState() {
    super.initState();
    if (widget.user != null) {
      _applyData(widget.user!);
    } else {
      _fetchProfile();
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
        data["dateOfBirth"] ?? data["birth"] ?? data["birthday"] ?? data["dob"];
    _birth = (rawBirth == null || rawBirth.toString().isEmpty)
        ? "Chưa đặt"
        : rawBirth.toString();
    // Employee ID: not available from API yet → N/A
    _employeeId = data["employeeId"] ?? data["employee_id"] ?? "N/A";
    _email = data["email"] ?? data["emailAddress"] ?? data["user_email"] ?? "";
    // profilePicture may be a MongoDB ObjectId → resolve to proper URL
    final picId = data["profilePicture"] ?? data["avatar"];
    _avatarUrl = picId != null ? ApiService.resolveAvatarUrl(picId) : null;
    _isLoading = false;
  }

  Future<void> _fetchProfile() async {
    // 1. Load from cached login data immediately (no loading spinner needed)
    final cached = AuthService().userProfile.value;
    if (cached != null && mounted) {
      setState(() => _applyData(cached));
    } else {
      setState(() => _isLoading = true);
    }

    // 2. Refresh from API in background
    final data = await ApiService.getMe();
    if (data != null && mounted) {
      setState(() => _applyData(data));
    } else if (mounted) {
      setState(() => _isLoading = false);
    }
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
          final success = await ApiService.updateProfile(newData);
          if (success && mounted) {
            _fetchProfile();
          }
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
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
                                        borderRadius: BorderRadius.circular(28),
                                        child: Image.network(
                                          ApiService.resolveAvatarUrl(
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
                      ],
                    ),
                  ),
                  const SizedBox(height: 48),
                  const _LogoutButton(),
                  const SizedBox(height: 100),
                ],
              ),
            ),
    );
  }
}

class _LogoutButton extends StatelessWidget {
  const _LogoutButton();
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: InkWell(
        onTap: () {
          AuthService().logout();
        },
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            color: Colors.red.withOpacity(0.05),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.red.withOpacity(0.1)),
          ),
          child: const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.logout, color: Colors.red, size: 20),
              SizedBox(width: 12),
              Text(
                "ĐĂNG XUẤT",
                style: TextStyle(
                  color: Colors.red,
                  fontWeight: FontWeight.w900,
                  fontSize: 13,
                  letterSpacing: 1.0,
                ),
              ),
            ],
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
