import 'package:flutter/material.dart';

class WorkspaceSidebar extends StatelessWidget {
  const WorkspaceSidebar({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      width: 72,
      color: isDark ? const Color(0xFF020617) : const Color(0xFFE2E8F0),
      child: Column(
        children: [
          const SizedBox(height: 20),
          _WorkspaceIcon(
            icon: Icons.auto_fix_high,
            color: Colors.indigo,
            isActive: true,
          ),
          const SizedBox(height: 12),
          _WorkspaceIcon(
            icon: Icons.code,
            color: Colors.blueGrey,
            isActive: false,
          ),
          _WorkspaceIcon(
            icon: Icons.terminal,
            color: Colors.green,
            isActive: false,
          ),
          _WorkspaceIcon(
            icon: Icons.data_usage,
            color: Colors.amber,
            isActive: false,
          ),
          const Spacer(),
          _WorkspaceIcon(icon: Icons.add, color: Colors.grey, isActive: false),
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}

class _WorkspaceIcon extends StatelessWidget {
  final IconData icon;
  final Color color;
  final bool isActive;

  const _WorkspaceIcon({
    required this.icon,
    required this.color,
    required this.isActive,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Stack(
        alignment: Alignment.center,
        children: [
          if (isActive)
            Positioned(
              left: 0,
              child: Container(
                width: 4,
                height: 32,
                decoration: const BoxDecoration(
                  color: Colors.indigo,
                  borderRadius: BorderRadius.only(
                    topRight: Radius.circular(4),
                    bottomRight: Radius.circular(4),
                  ),
                ),
              ),
            ),
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: isActive ? color.withOpacity(0.2) : Colors.transparent,
              borderRadius: BorderRadius.circular(isActive ? 12 : 24),
              border: Border.all(
                color: isActive ? color : Colors.transparent,
                width: 2,
              ),
            ),
            child: Icon(icon, color: isActive ? color : Colors.grey, size: 28),
          ),
        ],
      ),
    );
  }
}
