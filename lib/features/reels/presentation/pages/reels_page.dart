import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

class ReelsPage extends StatefulWidget {
  const ReelsPage({super.key});

  @override
  State<ReelsPage> createState() => _ReelsPageState();
}

class _ReelsPageState extends State<ReelsPage> {
  final List<Map<String, dynamic>> _reels = [];

  // Opens the create-reel dialog using the root navigator so it works
  // even when nested inside an IndexedStack / Scaffold drawer.
  void _showCreateReel() {
    showDialog(
      context: context,
      useRootNavigator: true,
      barrierDismissible: true,
      barrierColor: Colors.black.withOpacity(0.80),
      builder: (_) => CreateReelDialog(
        onPublish: (reel) {
          setState(() => _reels.insert(0, reel));
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: _reels.isEmpty ? _buildEmptyState() : _buildReelFeed(),
    );
  }

  // ── Empty state ──────────────────────────────────────────────────────────
  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _CreateReelCard(onTap: _showCreateReel),
          const SizedBox(height: 20),
          const Text(
            'Chưa có Reels nào',
            style: TextStyle(color: Colors.white38, fontSize: 13),
          ),
        ],
      ),
    );
  }

  // ── Reel feed ────────────────────────────────────────────────────────────
  Widget _buildReelFeed() {
    return Stack(
      children: [
        PageView.builder(
          scrollDirection: Axis.vertical,
          itemCount: _reels.length,
          itemBuilder: (_, i) => _ReelItem(reel: _reels[i]),
        ),
        Positioned(
          top: 60,
          right: 16,
          child: GestureDetector(
            onTap: _showCreateReel,
            child: Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: Colors.black45,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.add_circle_outline,
                color: Colors.white,
                size: 24,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ─── Create Reel Card (the visible button) ──────────────────────────────────

class _CreateReelCard extends StatelessWidget {
  final VoidCallback onTap;
  const _CreateReelCard({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        width: 150,
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 12),
        decoration: BoxDecoration(
          color: const Color(0xFF1A1D2B),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Colors.white.withOpacity(0.10), width: 1.5),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Avatar thumbnail + blue "+" badge
            Stack(
              alignment: Alignment.bottomRight,
              clipBehavior: Clip.none,
              children: [
                // Avatar / camera icon
                Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    color: Colors.blueGrey.shade800,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Icon(
                    Icons.videocam_rounded,
                    color: Colors.white,
                    size: 38,
                  ),
                ),
                // Blue "+" badge
                Positioned(
                  right: -4,
                  bottom: -4,
                  child: Container(
                    width: 26,
                    height: 26,
                    decoration: const BoxDecoration(
                      color: Color(0xFF3B82F6),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.add, color: Colors.white, size: 16),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            const Text(
              'TẠO REEL',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w900,
                fontSize: 13,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 5),
            const Text(
              'CHIA SẺ NGAY',
              style: TextStyle(
                color: Color(0xFF3B82F6),
                fontWeight: FontWeight.bold,
                fontSize: 10,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Reel item (for the feed) ───────────────────────────────────────────────

class _ReelItem extends StatelessWidget {
  final Map<String, dynamic> reel;
  const _ReelItem({required this.reel});

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.black, Colors.blueGrey.shade900],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
          child: const Center(
            child: Icon(
              Icons.videocam_outlined,
              color: Colors.white24,
              size: 80,
            ),
          ),
        ),
        Positioned(
          bottom: 40,
          left: 16,
          right: 80,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '@User',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
              if ((reel['caption'] ?? '').toString().isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  reel['caption'],
                  style: const TextStyle(color: Colors.white, fontSize: 13),
                ),
              ],
            ],
          ),
        ),
        Positioned(
          bottom: 40,
          right: 16,
          child: Column(
            children: const [
              _ActionIcon(icon: Icons.favorite_border, label: '0'),
              _ActionIcon(icon: Icons.chat_bubble_outline, label: '0'),
              _ActionIcon(icon: Icons.share_outlined, label: 'Chia sẻ'),
            ],
          ),
        ),
      ],
    );
  }
}

class _ActionIcon extends StatelessWidget {
  final IconData icon;
  final String label;
  const _ActionIcon({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        children: [
          Icon(icon, color: Colors.white, size: 28),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(color: Colors.white, fontSize: 11),
          ),
        ],
      ),
    );
  }
}

// ─── Create Reel Dialog ─────────────────────────────────────────────────────

class CreateReelDialog extends StatefulWidget {
  final Function(Map<String, dynamic>) onPublish;
  const CreateReelDialog({super.key, required this.onPublish});

  @override
  State<CreateReelDialog> createState() => _CreateReelDialogState();
}

class _CreateReelDialogState extends State<CreateReelDialog> {
  final ImagePicker _picker = ImagePicker();
  final TextEditingController _captionCtrl = TextEditingController();
  String? _videoPath;
  bool _publishing = false;

  @override
  void dispose() {
    _captionCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickVideo() async {
    try {
      final XFile? file = await _picker.pickVideo(source: ImageSource.gallery);
      if (file != null) setState(() => _videoPath = file.path);
    } catch (e) {
      debugPrint('Pick video error: $e');
    }
  }

  void _publish() {
    if (_publishing) return;
    setState(() => _publishing = true);
    Future.delayed(const Duration(milliseconds: 500), () {
      widget.onPublish({
        'id': DateTime.now().millisecondsSinceEpoch,
        'videoPath': _videoPath,
        'caption': _captionCtrl.text.trim(),
      });
      if (mounted) Navigator.of(context, rootNavigator: true).pop();
    });
  }

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.of(context).size.width;
    final isWide = w >= 680;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: EdgeInsets.symmetric(
        horizontal: isWide ? 40 : 16,
        vertical: 40,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: isWide
            ? SizedBox(
                height: 520,
                child: Row(
                  children: [
                    Expanded(flex: 5, child: _videoPanel()),
                    Expanded(flex: 4, child: _settingsPanel()),
                  ],
                ),
              )
            : _narrowLayout(),
      ),
    );
  }

  // ── Video panel (left / top) ──────────────────────────────────────────────
  Widget _videoPanel() {
    return Container(
      color: Colors.black,
      child: _videoPath != null ? _videoPicked() : _videoEmpty(),
    );
  }

  Widget _videoEmpty() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.08),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Icon(
              Icons.videocam_rounded,
              color: Colors.white60,
              size: 36,
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            'CHỌN VIDEO HOẶC ẢNH',
            style: TextStyle(
              color: Colors.white60,
              fontSize: 11,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 16),
          GestureDetector(
            onTap: _pickVideo,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFF3B82F6),
                borderRadius: BorderRadius.circular(24),
              ),
              child: const Text(
                'TẢI LÊN',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                  letterSpacing: 0.5,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _videoPicked() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.check_circle_outline, color: Colors.green, size: 56),
          const SizedBox(height: 12),
          const Text(
            'Video đã chọn',
            style: TextStyle(color: Colors.white70, fontSize: 13),
          ),
          const SizedBox(height: 16),
          GestureDetector(
            onTap: _pickVideo,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.white38),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Text(
                'CHỌN LẠI',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Settings panel (right / bottom) ─────────────────────────────────────
  Widget _settingsPanel() {
    return Container(
      color: Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _settingsHeader(),
          Expanded(child: SingleChildScrollView(child: _settingsBody())),
        ],
      ),
    );
  }

  Widget _settingsHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 20, 12, 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text(
            'THIẾT LẬP REEL',
            style: TextStyle(
              fontWeight: FontWeight.w900,
              fontSize: 16,
              letterSpacing: 0.5,
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, size: 20, color: Colors.blueGrey),
            onPressed: () => Navigator.of(context, rootNavigator: true).pop(),
          ),
        ],
      ),
    );
  }

  Widget _settingsBody() {
    final hasVideo = _videoPath != null;
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Author row
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: Colors.blueGrey.shade100,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.person, color: Colors.blueGrey),
              ),
              const SizedBox(width: 12),
              const Text(
                'Phùng Hoàng Long',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Caption
          const _SectionLabel(icon: Icons.title, label: 'MÔ TẢ'),
          const SizedBox(height: 10),
          TextField(
            controller: _captionCtrl,
            maxLines: 3,
            style: const TextStyle(fontSize: 13),
            decoration: InputDecoration(
              hintText: 'Viết chú thích...',
              hintStyle: const TextStyle(color: Colors.grey, fontSize: 13),
              filled: true,
              fillColor: const Color(0xFFF1F5F9),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.all(16),
            ),
          ),
          const SizedBox(height: 24),

          // Music
          const _SectionLabel(
            icon: Icons.music_note_outlined,
            label: 'ÂM NHẠC',
          ),
          const SizedBox(height: 10),
          Container(
            width: double.infinity,
            height: 72,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: const Color(0xFF3B82F6).withOpacity(0.30),
              ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: const [
                Icon(
                  Icons.music_note_outlined,
                  color: Color(0xFF3B82F6),
                  size: 22,
                ),
                SizedBox(height: 4),
                Text(
                  'CHỌN BÀI HÁT',
                  style: TextStyle(
                    color: Color(0xFF3B82F6),
                    fontWeight: FontWeight.bold,
                    fontSize: 11,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),

          // Publish button
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton.icon(
              onPressed: hasVideo ? _publish : null,
              icon: _publishing
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : const Icon(Icons.send_rounded, size: 16),
              label: const Text(
                'CHIA SẺ REEL',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                  letterSpacing: 0.5,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: hasVideo
                    ? const Color(0xFF3B82F6)
                    : Colors.blueGrey.shade100,
                foregroundColor: hasVideo
                    ? Colors.white
                    : Colors.blueGrey.shade400,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                elevation: hasVideo ? 4 : 0,
                shadowColor: const Color(0xFF3B82F6).withOpacity(0.4),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Narrow (mobile) layout ───────────────────────────────────────────────
  Widget _narrowLayout() {
    return Container(
      color: Colors.white,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _settingsHeader(),
          SizedBox(height: 220, child: _videoPanel()),
          Padding(padding: const EdgeInsets.all(20), child: _settingsBody()),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final IconData icon;
  final String label;
  const _SectionLabel({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 14, color: Colors.grey),
        const SizedBox(width: 6),
        Text(
          label,
          style: const TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.bold,
            color: Colors.grey,
            letterSpacing: 0.8,
          ),
        ),
      ],
    );
  }
}
