import 'package:flutter/material.dart';
import '../../../../core/security.dart';

class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SingleChildScrollView(
        child: Column(
          children: [
            // 1. Hero Banner and Overlapping Avatar
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
                      child: const Icon(
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

            // 2. Name and Role
            const Text(
              "Chưa đặt tên",
              style: TextStyle(
                fontWeight: FontWeight.w900,
                fontSize: 28,
                color: Color(0xFF1E293B),
              ),
            ),
            const SizedBox(height: 8),
            const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.business_center_outlined,
                  size: 14,
                  color: Color(0xFF3B82F6),
                ),
                SizedBox(width: 8),
                Text(
                  "CHƯA ĐẶT CHỨC VỤ",
                  style: TextStyle(
                    color: Color(0xFF3B82F6),
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 32),

            // 3. Action Buttons (Stacked and Aligned)
            Padding(
              padding: const EdgeInsets.only(right: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  _AlignedButton(
                    label: "ĐỔI MẬT KHẨU",
                    icon: Icons.lock_outline,
                    isSolid: false,
                  ),
                  const SizedBox(height: 12),
                  _AlignedButton(
                    label: "THIẾT LẬP HỒ SƠ",
                    icon: Icons.edit_note_outlined,
                    isSolid: true,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 48),

            // 4. Info Fields
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                children: [
                  _InfoField(
                    icon: Icons.email_outlined,
                    label: "EMAIL",
                    value: "Chưa đặt",
                  ),
                  _InfoField(
                    icon: Icons.phone_outlined,
                    label: "ĐIỆN THOẠI",
                    value: "Chưa đặt",
                  ),
                  _InfoField(
                    icon: Icons.calendar_today_outlined,
                    label: "NGÀY SINH",
                    value: "Chưa đặt",
                  ),
                  _InfoField(
                    icon: Icons.badge_outlined,
                    label: "ID NHÂN VIÊN",
                    value: "N/A",
                  ),
                  _InfoField(
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
  const _AlignedButton({
    required this.label,
    required this.icon,
    required this.isSolid,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 200, // Fixed width to ensure they don't "lệch"
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: BoxDecoration(
        color: isSolid ? const Color(0xFF0F172A) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: isSolid
            ? null
            : Border.all(color: Colors.grey.withOpacity(0.1)),
        boxShadow: isSolid
            ? [
                BoxShadow(
                  color: Colors.black.withOpacity(0.2),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ]
            : [],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 16, color: isSolid ? Colors.white : Colors.blueGrey),
          const SizedBox(width: 10),
          Text(
            label,
            style: TextStyle(
              color: isSolid ? Colors.white : Colors.black87,
              fontWeight: FontWeight.w900,
              fontSize: 11,
              letterSpacing: 0.5,
            ),
          ),
        ],
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
