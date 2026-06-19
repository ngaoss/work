import 'package:flutter/material.dart';
import '../../../../core/api_service.dart';
import '../../../../core/widgets/global_error_wrapper.dart';

class CommunityPage extends StatefulWidget {
  const CommunityPage({super.key});

  @override
  State<CommunityPage> createState() => _CommunityPageState();
}

class _CommunityPageState extends State<CommunityPage> {
  bool _isLoading = true;
  List<dynamic> _groups = [];
  String _searchQuery = "";

  @override
  void initState() {
    super.initState();
    _fetchGroups();
  }

  Future<void> _fetchGroups() async {
    setState(() => _isLoading = true);
    final groups = await ApiService.getGroups();
    if (mounted) {
      setState(() {
        _groups = groups;
        _isLoading = false;
      });
    }
  }

  List<dynamic> get _filteredGroups {
    if (_searchQuery.isEmpty) return _groups;
    return _groups.where((g) {
      final name = (g['name'] ?? '').toString().toLowerCase();
      return name.contains(_searchQuery.toLowerCase());
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isDesktop = MediaQuery.of(context).size.width > 900;

    return GlobalErrorWrapper(
      child: Scaffold(
        backgroundColor: isDark ? const Color(0xFF252728) : const Color(0xFFF8FAFC),
        body: SafeArea(
          child: Column(
          children: [
            // Header
            Padding(
              padding: EdgeInsets.fromLTRB(isDesktop ? 32 : 16, isDesktop ? 32 : 16, isDesktop ? 32 : 16, 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Cộng đồng",
                          style: TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: isDesktop ? 32 : 24,
                            letterSpacing: -1,
                            color: isDark ? Colors.white : const Color(0xFF1E293B),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          "Khám phá và kết nối với các nhóm nội bộ DeepCode.",
                          style: TextStyle(
                            fontSize: 13,
                            color: isDark ? Colors.white54 : Colors.blueGrey.shade500,
                            height: 1.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (isDesktop)
                    ElevatedButton.icon(
                      onPressed: () {},
                      icon: const Icon(Icons.add, size: 18),
                      label: const Text(
                        "TẠO NHÓM MỚI",
                        style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13, letterSpacing: 0.5),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF3B82F6),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                        elevation: 0,
                      ),
                    ),
                ],
              ),
            ),
            
            // Search Bar & Mobile Create Button
            Padding(
              padding: EdgeInsets.symmetric(horizontal: isDesktop ? 32 : 16),
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF1E1F20) : Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: isDark ? Colors.white10 : Colors.blueGrey.shade50),
                      ),
                      child: TextField(
                        onChanged: (v) => setState(() => _searchQuery = v),
                        decoration: InputDecoration(
                          hintText: 'Tìm kiếm nhóm...',
                          hintStyle: TextStyle(fontSize: 14, color: isDark ? Colors.white30 : Colors.blueGrey.shade300),
                          prefixIcon: Icon(Icons.search, size: 20, color: isDark ? Colors.white38 : Colors.blueGrey.shade400),
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                      ),
                    ),
                  ),
                  if (!isDesktop) ...[
                    const SizedBox(width: 12),
                    Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFF3B82F6),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: IconButton(
                        icon: const Icon(Icons.add, color: Colors.white),
                        onPressed: () {},
                      ),
                    )
                  ]
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Content Grid
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _filteredGroups.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.groups_outlined, color: isDark ? Colors.white24 : Colors.grey.shade300, size: 60),
                              const SizedBox(height: 16),
                              Text(
                                "Không tìm thấy nhóm nào",
                                style: TextStyle(color: isDark ? Colors.white54 : Colors.grey.shade500, fontSize: 13, fontWeight: FontWeight.w500),
                              ),
                            ],
                          ),
                        )
                      : GridView.builder(
                          padding: EdgeInsets.symmetric(horizontal: isDesktop ? 32 : 16, vertical: 8),
                          gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
                            maxCrossAxisExtent: 280,
                            mainAxisSpacing: 16,
                            crossAxisSpacing: 16,
                            childAspectRatio: 0.73, // Adjusted ratio to prevent overflow
                          ),
                          itemCount: _filteredGroups.length,
                          itemBuilder: (context, index) {
                            final group = _filteredGroups[index];
                            return _GroupCard(group: group, isDark: isDark);
                          },
                        ),
            ),
          ],
        ),
      ),
    ),
  );
}
}

class _GroupCard extends StatelessWidget {
  final Map<String, dynamic> group;
  final bool isDark;

  const _GroupCard({required this.group, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final String coverId = (group['cover'] ?? '').toString();
    final String name = (group['name'] ?? '').toString();
    final String privacy = (group['privacy'] ?? 'public').toString().toUpperCase();
    final int memberCount = group['memberCount'] ?? 0;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1F20) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.2 : 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          )
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Cover Image area
          Expanded(
            flex: 4,
            child: Stack(
              fit: StackFit.expand,
              children: [
                if (coverId.isNotEmpty)
                  FutureBuilder<Map<String, String>>(
                    future: ApiService.getAuthHeaders(),
                    builder: (context, snap) {
                      if (!snap.hasData) return Container(color: Colors.blueGrey.shade100);
                      return Image.network(
                        ApiService.resolveImageUrl(coverId),
                        headers: snap.data,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(color: Colors.blueGrey.shade100, child: const Icon(Icons.image, color: Colors.white54, size: 40)),
                      );
                    },
                  )
                else
                  Container(
                    color: const Color(0xFF3B82F6).withOpacity(0.2),
                    child: const Icon(Icons.groups, color: Color(0xFF3B82F6), size: 48),
                  ),
                // Privacy Pill
                Positioned(
                  top: 12,
                  left: 12,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(privacy == 'PUBLIC' ? Icons.language : Icons.lock, size: 10, color: const Color(0xFF10B981)),
                        const SizedBox(width: 4),
                        Text(
                          privacy,
                          style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: Colors.black87),
                        ),
                      ],
                    ),
                  ),
                )
              ],
            ),
          ),
          // Info area
          Expanded(
            flex: 5,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: isDark ? Colors.white : const Color(0xFF1E293B),
                      height: 1.2,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(Icons.people_outline, size: 14, color: isDark ? Colors.white54 : Colors.blueGrey.shade400),
                      const SizedBox(width: 6),
                      Text(
                        "$memberCount thành viên",
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark ? Colors.white54 : Colors.blueGrey.shade500,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                  const Spacer(),
                  SizedBox(
                    width: double.infinity,
                    height: 36,
                    child: ElevatedButton(
                      onPressed: () {},
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isDark ? const Color(0xFF3B82F6).withOpacity(0.2) : const Color(0xFFEFF6FF),
                        foregroundColor: const Color(0xFF3B82F6),
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text(
                        "THAM GIA NGAY",
                        style: TextStyle(fontWeight: FontWeight.w800, fontSize: 11, letterSpacing: 0.5),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
