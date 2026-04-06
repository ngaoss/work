import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:video_player/video_player.dart';
import '../../../../core/api_service.dart';
import '../../../../core/security.dart';
import '../../../../core/widgets/video_preview.dart';
import '../../../../core/widgets/mention_text_controller.dart';

class ReelsPage extends StatefulWidget {
  final bool isActive;
  final int initialIndex;
  final VoidCallback? onClose;

  const ReelsPage({
    super.key,
    this.isActive = true,
    this.initialIndex = 0,
    this.onClose,
  });

  @override
  State<ReelsPage> createState() => _ReelsPageState();
}

class _ReelsPageState extends State<ReelsPage> {
  List<dynamic> _reels = [];
  bool _isLoading = false;
  late int _currentPage;
  late final PageController _pageController;
  bool _isMuted = false;

  @override
  void initState() {
    super.initState();
    _currentPage = widget.initialIndex;
    _pageController = PageController(initialPage: widget.initialIndex);
    _fetchReels();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _toggleMute() {
    setState(() => _isMuted = !_isMuted);
  }

  Future<void> _fetchReels() async {
    setState(() => _isLoading = true);
    final List<dynamic> reelsRaw = await ApiService.getReels();
    final currentUserId =
        (AuthService().userProfile.value?['_id'] ??
                AuthService().userProfile.value?['id'])
            ?.toString();

    if (mounted) {
      setState(() {
        _reels = reelsRaw.map((r) {
          final Map<String, dynamic> reel = Map<String, dynamic>.from(r);
          final reactions = reel['reactions'] as List?;
          reel['isLiked'] =
              reactions?.any(
                (re) =>
                    (re['user']?.toString() == currentUserId ||
                    (re['user'] is Map &&
                        (re['user']['_id']?.toString() == currentUserId ||
                            re['user']['id']?.toString() == currentUserId))),
              ) ??
              false;
          reel['likes'] = reactions?.length ?? reel['likes'] ?? 0;
          return reel;
        }).toList();
        _isLoading = false;
      });
    }
  }

  void _showCreateReel() {
    showDialog(
      context: context,
      useRootNavigator: true,
      barrierDismissible: true,
      barrierColor: Colors.black.withOpacity(0.80),
      builder: (_) => CreateReelDialog(
        onPublish: (reel) async {
          final success = await ApiService.createReel(reel);
          if (success) {
            _fetchReels();
          }
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) widget.onClose?.call();
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        body: _isLoading
            ? const Center(
                child: CircularProgressIndicator(color: Colors.white),
              )
            : _reels.isEmpty
            ? _buildEmptyState()
            : _buildReelFeed(),
      ),
    );
  }

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

  Widget _buildReelFeed() {
    return Stack(
      children: [
        PageView.builder(
          controller: _pageController,
          onPageChanged: (index) {
            setState(() {
              _currentPage = index;
            });
          },
          scrollDirection: Axis.vertical,
          itemCount: _reels.length,
          itemBuilder: (_, i) => _ReelItem(
            reel: _reels[i],
            isActive: widget.isActive && _currentPage == i,
            isMuted: _isMuted,
            onLike: () async {
              final reelId = (_reels[i]["_id"] ?? _reels[i]["id"])?.toString();
              if (reelId != null) {
                setState(() {
                  final bool wasLiked = _reels[i]["isLiked"] == true;
                  _reels[i]["isLiked"] = !wasLiked;
                  int currentLikes =
                      int.tryParse(_reels[i]["likes"]?.toString() ?? "0") ?? 0;
                  _reels[i]["likes"] = wasLiked
                      ? (currentLikes > 0 ? currentLikes - 1 : 0)
                      : currentLikes + 1;
                });
                ApiService.likeReel(reelId);
              }
            },
            onComment: (comment) async {
              final reelId = _reels[i]["_id"] ?? _reels[i]["id"];
              if (reelId != null) {
                final userProfile = AuthService().userProfile.value;
                final String? authorId =
                    (userProfile?['_id'] ?? userProfile?['id'])?.toString();

                final bool success = await ApiService.addReelComment(
                  reelId.toString(),
                  comment["text"]?.toString() ?? "",
                  authorId: authorId,
                );
                return success;
              }
              return false;
            },
          ),
        ),
        // X button — top-left, back to news feed
        Positioned(
          top: 52,
          left: 16,
          child: Row(
            children: [
              GestureDetector(
                onTap: () => widget.onClose?.call(),
                child: Container(
                  width: 42,
                  height: 42,
                  decoration: const BoxDecoration(
                    color: Colors.black54,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.close, color: Colors.white, size: 22),
                ),
              ),
              const SizedBox(width: 12),
              GestureDetector(
                onTap: _toggleMute,
                child: Container(
                  width: 42,
                  height: 42,
                  decoration: const BoxDecoration(
                    color: Colors.black54,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    _isMuted ? Icons.volume_off : Icons.volume_up,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
              ),
            ],
          ),
        ),
        // + button — top-right, create reel
        Positioned(
          top: 52,
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
            Stack(
              alignment: Alignment.bottomRight,
              clipBehavior: Clip.none,
              children: [
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

class _ReelItem extends StatefulWidget {
  final dynamic reel;
  final bool isActive;
  final bool isMuted;
  final VoidCallback onLike;
  final Future<bool> Function(Map<String, dynamic>) onComment;

  const _ReelItem({
    required this.reel,
    required this.isActive,
    required this.isMuted,
    required this.onLike,
    required this.onComment,
  });

  @override
  State<_ReelItem> createState() => _ReelItemState();
}

class _ReelItemState extends State<_ReelItem> {
  bool _isPlaying = true;
  late final Future<Map<String, String>> _headersFuture;

  @override
  void initState() {
    super.initState();
    _headersFuture = ApiService.getAuthHeaders();
  }

  @override
  void didUpdateWidget(covariant _ReelItem oldWidget) {
    super.didUpdateWidget(oldWidget);
    // If this item becomes active again, resume playback automatically
    if (!oldWidget.isActive && widget.isActive) {
      _isPlaying = true;
    }
  }

  void _onTap() {
    setState(() {
      _isPlaying = !_isPlaying;
    });
  }

  @override
  Widget build(BuildContext context) {
    // author is a nested object: {_id, fullName, profilePicture}
    final authorObj = widget.reel['author'];
    final String authorName = (authorObj is Map)
        ? (authorObj['fullName'] ?? authorObj['name'] ?? 'Người dùng')
        : (authorObj?.toString() ?? 'Người dùng');
    final String? authorPic = (authorObj is Map)
        ? (authorObj['profilePicture']?.toString())
        : null;
    final String? authorAvatarUrl = authorPic != null
        ? ApiService.resolveImageUrl(authorPic)
        : null;

    return Stack(
      fit: StackFit.expand,
      children: [
        GestureDetector(
          onTap: _onTap,
          behavior: HitTestBehavior.opaque,
          child: Container(
            color: Colors.black,
            child: _buildMedia(widget.reel),
          ),
        ),
        if (!_isPlaying)
          IgnorePointer(
            child: Center(
              child: Container(
                width: 70,
                height: 70,
                decoration: BoxDecoration(
                  color: Colors.black38,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.play_arrow_rounded,
                  color: Colors.white,
                  size: 50,
                ),
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
              // Author row: avatar + name
              Row(
                children: [
                  CircleAvatar(
                    radius: 18,
                    backgroundColor: Colors.blueGrey.shade700,
                    backgroundImage:
                        authorAvatarUrl != null && authorAvatarUrl.isNotEmpty
                        ? NetworkImage(authorAvatarUrl)
                        : null,
                    child: (authorAvatarUrl == null || authorAvatarUrl.isEmpty)
                        ? Text(
                            authorName.isNotEmpty
                                ? authorName[0].toUpperCase()
                                : '?',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          )
                        : null,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '@$authorName',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      shadows: [Shadow(color: Colors.black54, blurRadius: 4)],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                (widget.reel['caption'] ?? '').toString().trim().isNotEmpty
                    ? widget.reel['caption']
                    : 'Khoảnh khắc mới',
                style: const TextStyle(color: Colors.white, fontSize: 13),
              ),
              const SizedBox(height: 12),
              // Music Info Marquee
              _MusicMarquee(
                title: (widget.reel['music'] is Map)
                    ? (widget.reel['music']['title'] ??
                          widget.reel['music']['name'] ??
                          'Âm thanh gốc')
                    : 'Âm thanh gốc',
                artist: (widget.reel['music'] is Map)
                    ? (widget.reel['music']['artist'] ??
                          widget.reel['music']['singer'] ??
                          authorName)
                    : authorName,
              ),
            ],
          ),
        ),
        Positioned(
          bottom: 40,
          right: 16,
          child: Column(
            children: [
              _ActionIcon(
                icon: (widget.reel['isLiked'] ?? false)
                    ? Icons.favorite
                    : Icons.favorite_border,
                label: (widget.reel['likes'] ?? 0).toString(),
                color: (widget.reel['isLiked'] ?? false)
                    ? Colors.red
                    : Colors.white,
                onTap: widget.onLike,
              ),
              _ActionIcon(
                icon: Icons.chat_bubble_outline,
                label:
                    (widget.reel['commentsCount'] ??
                            widget.reel['comments']?.length ??
                            0)
                        .toString(),
                onTap: () => _showComments(context),
              ),
              const _ActionIcon(icon: Icons.share_outlined, label: 'Chia sẻ'),
            ],
          ),
        ),
      ],
    );
  }

  String? _extractUrl(dynamic data) {
    if (data == null) return null;
    if (data is String) return data;
    if (data is Map) {
      return (data['url'] ??
              data['path'] ??
              data['videoUrl'] ??
              data['audioUrl'] ??
              data['link'])
          ?.toString();
    }
    return data.toString();
  }

  Widget _buildMedia(dynamic reel) {
    String? path = _extractUrl(
      reel['videoUrl'] ??
          reel['videoPath'] ??
          reel['video_path'] ??
          reel['imagePath'] ??
          reel['image_path'] ??
          reel['mediaPath'] ??
          reel['media_path'] ??
          reel['url'],
    );

    if (path == null) {
      return const Center(
        child: Icon(Icons.videocam_off, color: Colors.white24, size: 80),
      );
    }

    final bool isHttp = path.startsWith('http') || !File(path).existsSync();
    final String fullUrl = isHttp ? ApiService.resolveImageUrl(path) : path;
    final String lowerPath = fullUrl.toLowerCase();

    final bool isVideo =
        lowerPath.endsWith('.mp4') ||
        lowerPath.endsWith('.mov') ||
        lowerPath.endsWith('.m4v') ||
        lowerPath.contains('video');
    final bool isAudio =
        lowerPath.endsWith('.mp3') ||
        lowerPath.endsWith('.wav') ||
        lowerPath.endsWith('.m4a') ||
        lowerPath.endsWith('.aac');

    // Robust Background Music Detection
    String? musicUrl;
    final List<String> musicFields = [
      'musicUrl',
      'audioUrl',
      'music_url',
      'audio_url',
      'musicPath',
      'audioPath',
      'music_path',
      'audio_path',
      'sound',
      'music',
      'audio',
    ];
    for (var field in musicFields) {
      final val = _extractUrl(widget.reel[field]);
      if (val != null) {
        final low = val.toLowerCase();
        if (low.endsWith('.mp3') ||
            low.endsWith('.wav') ||
            low.endsWith('.m4a') ||
            low.endsWith('.aac') ||
            low.contains('audio') ||
            low.contains('music')) {
          final resolved = ApiService.resolveUrl(val);
          if (resolved != fullUrl) {
            musicUrl = resolved;
            break;
          }
        }
      }
    }
    // Fallback to legacy 'url' field if different from path and not already found
    if (musicUrl == null) {
      final String? potentialMusic = _extractUrl(widget.reel['url']);
      if (potentialMusic != null) {
        final low = potentialMusic.toLowerCase();
        if (low.endsWith('.mp3') || low.endsWith('.wav')) {
          final resolved = ApiService.resolveUrl(potentialMusic);
          if (resolved != fullUrl) {
            musicUrl = resolved;
          }
        }
      }
    }

    return FutureBuilder<Map<String, String>>(
      future: _headersFuture,
      builder: (context, snapshot) {
        final headers = snapshot.data;

        Widget mainContent;
        Widget? audioBg;

        if (isVideo || isAudio) {
          // Determine background for audio-only if no separate music
          if (isAudio && musicUrl == null) {
            final authorObj = widget.reel['author'];
            final String? authorPic = (authorObj is Map)
                ? (authorObj['profilePicture']?.toString() ??
                      authorObj['avatar']?.toString())
                : null;
            final String? avatarUrl = authorPic != null
                ? ApiService.resolveImageUrl(authorPic)
                : null;

            audioBg = Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 160,
                    height: 160,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withOpacity(0.05),
                      border: Border.all(color: Colors.white10, width: 2),
                    ),
                    padding: const EdgeInsets.all(20),
                    child: ClipOval(
                      child: avatarUrl != null
                          ? Image.network(
                              avatarUrl,
                              fit: BoxFit.cover,
                              headers: headers,
                            )
                          : const Icon(
                              Icons.music_note,
                              color: Colors.blue,
                              size: 80,
                            ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  const Icon(Icons.graphic_eq, color: Colors.blue, size: 40),
                ],
              ),
            );
          }

          if (!isHttp && File(path).existsSync()) {
            mainContent = VideoPreview(
              file: File(path),
              autoPlay: widget.isActive && _isPlaying,
              loop: true,
              mute: widget.isMuted || !widget.isActive,
            );
          } else {
            mainContent = VideoPreview(
              videoUrl: fullUrl,
              autoPlay: widget.isActive && _isPlaying,
              loop: true,
              mute: widget.isMuted || !widget.isActive,
              httpHeaders: headers,
            );
          }
        } else {
          // Handle Image
          if (!isHttp && File(path).existsSync()) {
            mainContent = Image.file(
              File(path),
              fit: BoxFit.contain,
              width: double.infinity,
              height: double.infinity,
            );
          } else {
            mainContent = Image.network(
              fullUrl,
              fit: BoxFit.contain,
              width: double.infinity,
              height: double.infinity,
              headers: headers,
              errorBuilder: (context, error, stackTrace) => const Center(
                child: Icon(
                  Icons.broken_image,
                  color: Colors.white24,
                  size: 80,
                ),
              ),
            );
          }
        }

        return Stack(
          children: [
            if (audioBg != null) audioBg,
            mainContent,
            // Secondary Audio Track (Background Music)
            if (musicUrl != null)
              Offstage(
                // Hide purely visual player for background music to avoid covering main media
                offstage: true,
                child: VideoPreview(
                  videoUrl: musicUrl,
                  autoPlay: widget.isActive && _isPlaying,
                  loop: true,
                  mute: widget.isMuted || !widget.isActive,
                  httpHeaders: headers,
                ),
              ),
          ],
        );
      },
    );
  }

  void _showComments(BuildContext context) {
    // Start with local comments if any, but properly fetch from API
    final reelId = widget.reel['_id'] ?? widget.reel['id'];
    List<dynamic> comments = List.from(widget.reel['comments'] ?? []);
    final TextEditingController ctrl = MentionTextEditingController();
    final FocusNode commentFocusNode = FocusNode();
    String? replyingToName;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) {
          // Inner function to load comments once opened
          Future<void> loadComments() async {
            if (reelId != null) {
              final fetched = await ApiService.getReelComments(
                reelId.toString(),
              );
              if (ctx.mounted) {
                setModalState(() {
                  comments = fetched;
                });
              }
            }
          }

          // Trigger load on first build
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (comments.isEmpty) loadComments();
          });

          return Container(
            height: MediaQuery.of(context).size.height * 0.75,
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  child: Column(
                    children: [
                      Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Colors.grey.shade300,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'BÌNH LUẬN (${comments.length})',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                Expanded(
                  child: comments.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.chat_bubble_outline,
                                size: 48,
                                color: Colors.grey.shade300,
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'Chưa có bình luận nào',
                                style: TextStyle(color: Colors.grey.shade400),
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: comments.length,
                          itemBuilder: (ctx, i) {
                            final comment = comments[i];
                            final author = comment['author'];
                            final String authorName = (author is Map)
                                ? (author['fullName'] ??
                                      author['name'] ??
                                      'Người dùng')
                                : (author ?? 'Người dùng').toString();

                            final String? avatarPic = (author is Map)
                                ? author['profilePicture']?.toString()
                                : null;

                            return Padding(
                              padding: const EdgeInsets.only(bottom: 16),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  FutureBuilder<Map<String, String>>(
                                    future: ApiService.getAuthHeaders(),
                                    builder: (context, headers) {
                                      return CircleAvatar(
                                        radius: 18,
                                        backgroundColor:
                                            Colors.blueGrey.shade100,
                                        backgroundImage: avatarPic != null
                                            ? NetworkImage(
                                                ApiService.resolveImageUrl(
                                                  avatarPic,
                                                ),
                                                headers: headers.data,
                                              )
                                            : null,
                                        child: avatarPic == null
                                            ? Text(
                                                authorName.isNotEmpty
                                                    ? authorName[0]
                                                          .toUpperCase()
                                                    : 'U',
                                                style: const TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              )
                                            : null,
                                      );
                                    },
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        // Comment bubble with reactions
                                        Stack(
                                          clipBehavior: Clip.none,
                                          children: [
                                            Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 12,
                                                    vertical: 8,
                                                  ),
                                              decoration: BoxDecoration(
                                                color: const Color(0xFFF1F5F9),
                                                borderRadius:
                                                    BorderRadius.circular(16),
                                              ),
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    authorName,
                                                    style: const TextStyle(
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      color: Colors.black,
                                                      fontSize: 12,
                                                    ),
                                                  ),
                                                  const SizedBox(height: 2),
                                                  Text(
                                                    comment['text']
                                                            ?.toString() ??
                                                        '',
                                                    style: const TextStyle(
                                                      fontSize: 13,
                                                      color: Colors.black87,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                            // Reaction count bubble
                                            if ((int.tryParse(
                                                      comment['likes']
                                                              ?.toString() ??
                                                          "0",
                                                    ) ??
                                                    0) >
                                                0)
                                              Positioned(
                                                bottom: -8,
                                                right: -8,
                                                child: Container(
                                                  padding:
                                                      const EdgeInsets.symmetric(
                                                        horizontal: 4,
                                                        vertical: 2,
                                                      ),
                                                  decoration: BoxDecoration(
                                                    color: Colors.white,
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          12,
                                                        ),
                                                    boxShadow: [
                                                      BoxShadow(
                                                        color: Colors.black
                                                            .withOpacity(0.1),
                                                        blurRadius: 4,
                                                        offset: const Offset(
                                                          0,
                                                          2,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                  child: Row(
                                                    mainAxisSize:
                                                        MainAxisSize.min,
                                                    children: [
                                                      const Icon(
                                                        Icons.favorite,
                                                        color: Colors.red,
                                                        size: 10,
                                                      ),
                                                      const SizedBox(width: 2),
                                                      Text(
                                                        comment['likes']
                                                            .toString(),
                                                        style: const TextStyle(
                                                          fontSize: 9,
                                                          fontWeight:
                                                              FontWeight.bold,
                                                          color: Colors.black54,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              ),
                                          ],
                                        ),
                                        const SizedBox(height: 8),
                                        // Action row
                                        Row(
                                          children: [
                                            const SizedBox(width: 8),
                                            Text(
                                              comment['time']?.toString() ??
                                                  'Vừa xong',
                                              style: const TextStyle(
                                                color: Colors.grey,
                                                fontSize: 10,
                                              ),
                                            ),
                                            const SizedBox(width: 14),
                                            GestureDetector(
                                              onTap: () async {
                                                final commentId =
                                                    (comment['_id'] ??
                                                            comment['id'])
                                                        ?.toString();
                                                if (commentId == null) return;

                                                final bool wasLiked =
                                                    comment['isLiked'] == true;
                                                setModalState(() {
                                                  comment['isLiked'] =
                                                      !wasLiked;
                                                  int currentLikes =
                                                      int.tryParse(
                                                        comment['likes']
                                                                ?.toString() ??
                                                            "0",
                                                      ) ??
                                                      0;
                                                  comment['likes'] = wasLiked
                                                      ? (currentLikes > 0
                                                            ? currentLikes - 1
                                                            : 0)
                                                      : currentLikes + 1;
                                                });

                                                ApiService.toggleCommentLike(
                                                  commentId,
                                                );
                                              },
                                              child: Text(
                                                comment['isLiked'] == true
                                                    ? "Đã thích"
                                                    : "Thích",
                                                style: TextStyle(
                                                  color:
                                                      comment['isLiked'] == true
                                                      ? Colors.red
                                                      : Colors.blueGrey,
                                                  fontSize: 10,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ),
                                            const SizedBox(width: 14),
                                            GestureDetector(
                                              onTap: () {
                                                setModalState(() {
                                                  replyingToName = authorName;
                                                });
                                                ctrl.text = "@$authorName ";
                                                ctrl.selection =
                                                    TextSelection.fromPosition(
                                                      TextPosition(
                                                        offset:
                                                            ctrl.text.length,
                                                      ),
                                                    );
                                                commentFocusNode.requestFocus();
                                              },
                                              child: const Text(
                                                "Phản hồi",
                                                style: TextStyle(
                                                  color: Colors.blueGrey,
                                                  fontSize: 10,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                ),
                // Reply banner
                if (replyingToName != null)
                  Container(
                    color: const Color(0xFFEFF6FF),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.reply, size: 14, color: Colors.blue),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            'Đang phản hồi $replyingToName',
                            style: const TextStyle(
                              color: Colors.blue,
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                        GestureDetector(
                          onTap: () {
                            setModalState(() => replyingToName = null);
                            ctrl.clear();
                            commentFocusNode.unfocus();
                          },
                          child: const Icon(
                            Icons.close,
                            size: 16,
                            color: Colors.blue,
                          ),
                        ),
                      ],
                    ),
                  ),
                Padding(
                  padding: EdgeInsets.fromLTRB(
                    16,
                    8,
                    16,
                    MediaQuery.of(ctx).viewInsets.bottom + 16,
                  ),
                  child: Row(
                    children: [
                      ValueListenableBuilder<Map<String, dynamic>?>(
                        valueListenable: AuthService().userProfile,
                        builder: (context, profile, _) {
                          final String? avatarId = profile?['profilePicture'];
                          return FutureBuilder<Map<String, String>>(
                            future: ApiService.getAuthHeaders(),
                            builder: (context, headers) {
                              return CircleAvatar(
                                radius: 18,
                                backgroundColor: Colors.blueGrey.shade100,
                                backgroundImage: avatarId != null
                                    ? NetworkImage(
                                        ApiService.resolveImageUrl(avatarId),
                                        headers: headers.data,
                                      )
                                    : null,
                                child: avatarId == null
                                    ? const Icon(
                                        Icons.person,
                                        size: 20,
                                        color: Colors.blueGrey,
                                      )
                                    : null,
                              );
                            },
                          );
                        },
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: ctrl,
                          focusNode: commentFocusNode,
                          decoration: InputDecoration(
                            hintText: replyingToName != null
                                ? 'Phản hồi $replyingToName...'
                                : 'Thêm bình luận...',
                            hintStyle: TextStyle(color: Colors.grey.shade400),
                            filled: true,
                            fillColor: Colors.grey.shade100,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(24),
                              borderSide: BorderSide.none,
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 10,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        icon: const Icon(Icons.send, color: Color(0xFF3B82F6)),
                        onPressed: () async {
                          if (ctrl.text.trim().isEmpty) return;
                          final String userText = ctrl.text.trim();
                          ctrl.clear();

                          // Optimistic UI update
                          final userProfile = AuthService().userProfile.value;
                          final tempComment = {
                            "author":
                                (userProfile?['fullName'] ??
                                userProfile?['name'] ??
                                'Bạn'),
                            "text": userText,
                            "time": "Vừa xong",
                            "id":
                                "temp_${DateTime.now().millisecondsSinceEpoch}",
                          };

                          setModalState(() {
                            comments = [tempComment, ...comments];
                          });

                          setModalState(() => replyingToName = null);

                          final success = await widget.onComment({
                            "text": userText,
                          });
                          if (success) {
                            loadComments(); // Refresh with real data
                          } else {
                            loadComments(); // Refresh anyway to revert or sync
                          }
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _MusicMarquee extends StatefulWidget {
  final String title;
  final String artist;
  const _MusicMarquee({required this.title, required this.artist});

  @override
  State<_MusicMarquee> createState() => _MusicMarqueeState();
}

class _MusicMarqueeState extends State<_MusicMarquee>
    with SingleTickerProviderStateMixin {
  late final AnimationController _rotationCtrl;
  late final ScrollController _scrollCtrl;

  @override
  void initState() {
    super.initState();
    _rotationCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat();
    _scrollCtrl = ScrollController();
    WidgetsBinding.instance.addPostFrameCallback((_) => _startMarquee());
  }

  void _startMarquee() async {
    while (mounted) {
      if (!_scrollCtrl.hasClients) {
        await Future.delayed(const Duration(milliseconds: 500));
        continue;
      }

      double maxScroll = _scrollCtrl.position.maxScrollExtent;
      // If we don't have enough content to scroll, wait and retry
      if (maxScroll <= 0) {
        await Future.delayed(const Duration(seconds: 1));
        continue;
      }

      // We want to scroll exactly the width of one cycle (item + gap)
      // Since we use builder, maxScrollExtent grows.
      // For a seamless jump, we scroll a decent distance then jump back.
      // But for simple "flow out left, in right", animate to max and jump.
      await _scrollCtrl.animateTo(
        maxScroll,
        duration: Duration(milliseconds: (maxScroll * 35).toInt()),
        curve: Curves.linear,
      );

      if (!mounted) break;
      _scrollCtrl.jumpTo(0);
      await Future.delayed(const Duration(milliseconds: 0));
    }
  }

  @override
  void dispose() {
    _rotationCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final textContent =
        '${widget.title.toUpperCase()} - ${widget.artist.toUpperCase()}';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.4),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          RotationTransition(
            turns: _rotationCtrl,
            child: const Icon(
              Icons.music_note_rounded,
              color: Colors.white,
              size: 14,
            ),
          ),
          const SizedBox(width: 10),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 160),
            child: SizedBox(
              height: 14,
              child: ListView.builder(
                controller: _scrollCtrl,
                scrollDirection: Axis.horizontal,
                physics: const NeverScrollableScrollPhysics(),
                // Use a large item count for infinite feel, or just enough
                itemCount: 100,
                itemBuilder: (context, index) {
                  return Padding(
                    padding: const EdgeInsets.only(
                      right: 40.0,
                    ), // Gap between repeats
                    child: Text(
                      textContent,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.0,
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionIcon extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback? onTap;

  const _ActionIcon({
    required this.icon,
    required this.label,
    this.color = Colors.white,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 20),
        child: Column(
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(height: 4),
            Text(
              label,
              style: const TextStyle(color: Colors.white, fontSize: 11),
            ),
          ],
        ),
      ),
    );
  }
}

class CreateReelDialog extends StatefulWidget {
  final Function(Map<String, dynamic>) onPublish;
  const CreateReelDialog({super.key, required this.onPublish});

  @override
  State<CreateReelDialog> createState() => _CreateReelDialogState();
}

class _CreateReelDialogState extends State<CreateReelDialog> {
  final ImagePicker _picker = ImagePicker();
  final TextEditingController _captionCtrl = TextEditingController();
  String? _mediaPath;
  XFile? _selectedXFile; // Add this
  Map<String, dynamic>? _selectedMusic;
  bool _publishing = false;

  @override
  void dispose() {
    _captionCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickMedia() async {
    final source = await showModalBottomSheet<String>(
      context: context,
      builder: (ctx) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.image_outlined),
            title: const Text('Ảnh từ thư viện'),
            onTap: () => Navigator.pop(ctx, 'image'),
          ),
          ListTile(
            leading: const Icon(Icons.videocam_outlined),
            title: const Text('Video từ thư viện'),
            onTap: () => Navigator.pop(ctx, 'video'),
          ),
          const SizedBox(height: 12),
        ],
      ),
    );

    if (source == null) return;

    try {
      XFile? _selectedFile;
      if (source == 'image') {
        _selectedFile = await _picker.pickImage(source: ImageSource.gallery);
      } else {
        _selectedFile = await _picker.pickVideo(source: ImageSource.gallery);
      }
      if (_selectedFile != null) {
        setState(() => _mediaPath = _selectedFile!.path);
        // We can also store the file itself if needed for bytes read later
        this._selectedXFile = _selectedFile;
      }
    } catch (e) {
      debugPrint('Pick media error: $e');
    }
  }

  void _publish() async {
    if (_publishing) return;
    setState(() => _publishing = true);

    String? finalMediaPath;

    // Upload media to server first
    if (_selectedXFile != null) {
      try {
        final bytes = await _selectedXFile!.readAsBytes();
        final uploadedPath = await ApiService.uploadImage(
          bytes,
          _selectedXFile!.name,
        );
        if (uploadedPath != null) {
          finalMediaPath = uploadedPath;
        }
      } catch (e) {
        debugPrint("Reel upload error: $e");
      }
    }

    widget.onPublish({
      'mediaPath': finalMediaPath != null
          ? ApiService.resolveImageUrl(finalMediaPath)
          : null,
      'caption': _captionCtrl.text.trim(),
      'musicId': _selectedMusic?['_id'] ?? _selectedMusic?['id'],
    });
    Navigator.of(context, rootNavigator: true).pop();
  }

  void _showMusicPicker() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _MusicPickerSheet(
        onSelect: (music) {
          setState(() => _selectedMusic = music);
        },
      ),
    );
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

  Widget _narrowLayout() {
    return Container(
      color: Colors.white,
      child: SingleChildScrollView(
        child: Column(
          children: [
            SizedBox(height: 300, child: _videoPanel()),
            _settingsPanel(),
          ],
        ),
      ),
    );
  }

  Widget _videoPanel() {
    return Container(
      color: Colors.black,
      child: _mediaPath != null ? _videoPicked() : _videoEmpty(),
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
            onTap: _pickMedia,
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
            'Phương tiện đã chọn',
            style: TextStyle(color: Colors.white70, fontSize: 13),
          ),
          const SizedBox(height: 16),
          GestureDetector(
            onTap: _pickMedia,
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

  Widget _settingsPanel() {
    return Container(
      color: Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [_settingsHeader(), _settingsBody()],
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
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 24),
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
          const SizedBox(height: 32),
          const _SectionLabel(icon: Icons.music_note, label: 'ÂM NHẠC'),
          const SizedBox(height: 12),
          GestureDetector(
            onTap: _showMusicPicker,
            child: Container(
              height: 100,
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: const Color(0xFF3B82F6).withOpacity(0.2),
                  width: 1.5,
                  style: BorderStyle
                      .solid, // Note: standard flutter doesn't do dashed easily without CustomPainter or package
                ),
              ),
              child: _selectedMusic == null
                  ? Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.music_note_outlined,
                          color: const Color(0xFF3B82F6).withOpacity(0.5),
                          size: 32,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'CHỌN BÀI HÁT',
                          style: TextStyle(
                            color: const Color(0xFF3B82F6).withOpacity(0.8),
                            fontWeight: FontWeight.w900,
                            fontSize: 10,
                            letterSpacing: 1.0,
                          ),
                        ),
                      ],
                    )
                  : ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 10,
                      ),
                      leading: Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: const Color(0xFF3B82F6).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.music_note, color: Colors.blue),
                      ),
                      title: Text(
                        _selectedMusic!['title'] ?? 'Tên bài hát',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Text(
                        _selectedMusic!['artist'] ?? 'Nghệ sĩ',
                        style: const TextStyle(fontSize: 12),
                      ),
                      trailing: const Icon(
                        Icons.check_circle,
                        color: Colors.blue,
                        size: 20,
                      ),
                    ),
            ),
          ),
          const SizedBox(height: 40),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _publish,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF3B82F6),
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: const Text(
                'ĐĂNG REEL',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
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
        Icon(icon, size: 16, color: Colors.blueGrey),
        const SizedBox(width: 8),
        Text(
          label,
          style: const TextStyle(
            color: Colors.blueGrey,
            fontWeight: FontWeight.bold,
            fontSize: 11,
            letterSpacing: 0.5,
          ),
        ),
      ],
    );
  }
}

class _MusicPickerSheet extends StatefulWidget {
  final Function(Map<String, dynamic>) onSelect;
  const _MusicPickerSheet({required this.onSelect});

  @override
  State<_MusicPickerSheet> createState() => _MusicPickerSheetState();
}

class _MusicPickerSheetState extends State<_MusicPickerSheet> {
  List<dynamic> _musicList = [];
  bool _loading = true;
  String? _playingId; // ID of the track currently being previewed
  VideoPlayerController? _previewController;
  bool _isPreviewLoading = false;

  @override
  void initState() {
    super.initState();
    _loadMusic();
  }

  @override
  void dispose() {
    _previewController?.dispose();
    super.dispose();
  }

  Future<void> _loadMusic() async {
    final list = await ApiService.getMusicList();
    if (mounted) {
      setState(() {
        _musicList = list;
        _loading = false;
      });
    }
  }

  Future<void> _togglePreview(Map<String, dynamic> music) async {
    final id = (music['_id'] ?? music['id'])?.toString();
    if (id == null) return;

    // If tapping the same track → stop
    if (_playingId == id) {
      await _previewController?.pause();
      _previewController?.dispose();
      setState(() {
        _playingId = null;
        _previewController = null;
        _isPreviewLoading = false;
      });
      return;
    }

    // Stop any current preview
    await _previewController?.pause();
    _previewController?.dispose();
    setState(() {
      _playingId = id;
      _previewController = null;
      _isPreviewLoading = true;
    });

    // Resolve URL
    final rawUrl =
        (music['url'] ??
                music['audioUrl'] ??
                music['musicUrl'] ??
                music['file'])
            ?.toString();
    if (rawUrl == null) {
      setState(() {
        _playingId = null;
        _isPreviewLoading = false;
      });
      return;
    }
    final resolvedUrl = ApiService.resolveUrl(rawUrl);

    try {
      final controller = VideoPlayerController.networkUrl(
        Uri.parse(resolvedUrl),
        httpHeaders: await ApiService.getAuthHeaders(),
      );
      await controller.initialize();
      controller.setLooping(false);
      controller.play();

      if (mounted) {
        setState(() {
          _previewController = controller;
          _isPreviewLoading = false;
        });

        // Auto-stop after track ends
        controller.addListener(() {
          if (controller.value.position >= controller.value.duration &&
              controller.value.duration.inMilliseconds > 0) {
            if (mounted) {
              setState(() {
                _playingId = null;
                _previewController = null;
              });
              controller.dispose();
            }
          }
        });
      }
    } catch (e) {
      debugPrint('Music preview error: $e');
      if (mounted) {
        setState(() {
          _playingId = null;
          _isPreviewLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.8,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(vertical: 20),
            child: Column(
              children: [
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'CHỌN ÂM NHẠC',
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 15,
                    letterSpacing: 1,
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _musicList.isEmpty
                ? const Center(child: Text('Không tìm thấy bài hát nào'))
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _musicList.length,
                    itemBuilder: (ctx, i) {
                      final m = _musicList[i];
                      final id = (m['_id'] ?? m['id'])?.toString();
                      final isPlaying = _playingId == id;
                      final isLoading = _playingId == id && _isPreviewLoading;

                      return Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        decoration: BoxDecoration(
                          color: isPlaying
                              ? const Color(0xFFEFF6FF)
                              : Colors.white,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: isPlaying
                                ? const Color(0xFF3B82F6)
                                : const Color(0xFFE2E8F0),
                            width: isPlaying ? 1.5 : 1,
                          ),
                        ),
                        child: Column(
                          children: [
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 10,
                              ),
                              child: Row(
                                children: [
                                  // Album art
                                  Container(
                                    width: 48,
                                    height: 48,
                                    decoration: BoxDecoration(
                                      gradient: const LinearGradient(
                                        colors: [
                                          Color(0xFF6366F1),
                                          Color(0xFF06B6D4),
                                        ],
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                      ),
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(
                                      Icons.music_note_rounded,
                                      color: Colors.white,
                                      size: 22,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  // Title + Artist
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          m['title'] ??
                                              m['name'] ??
                                              'Tên bài hát',
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 13,
                                            color: isPlaying
                                                ? const Color(0xFF1D4ED8)
                                                : Colors.black87,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          m['artist'] ??
                                              m['singer'] ??
                                              'Nghệ sĩ',
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            color: Colors.grey.shade500,
                                            fontSize: 11,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  // Play/Pause button
                                  GestureDetector(
                                    onTap: () => _togglePreview(
                                      Map<String, dynamic>.from(m),
                                    ),
                                    child: Container(
                                      width: 36,
                                      height: 36,
                                      decoration: BoxDecoration(
                                        color: isPlaying
                                            ? Colors.blue.withOpacity(0.12)
                                            : Colors.grey.shade100,
                                        shape: BoxShape.circle,
                                      ),
                                      child: isLoading
                                          ? const Padding(
                                              padding: EdgeInsets.all(9),
                                              child: CircularProgressIndicator(
                                                strokeWidth: 2,
                                                color: Colors.blue,
                                              ),
                                            )
                                          : Icon(
                                              isPlaying
                                                  ? Icons.pause_rounded
                                                  : Icons.play_arrow_rounded,
                                              color: isPlaying
                                                  ? Colors.blue
                                                  : Colors.blueGrey,
                                              size: 22,
                                            ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  // Select (check) button
                                  GestureDetector(
                                    onTap: () {
                                      _previewController?.pause();
                                      _previewController?.dispose();
                                      widget.onSelect(
                                        Map<String, dynamic>.from(m),
                                      );
                                      Navigator.pop(ctx);
                                    },
                                    child: Container(
                                      width: 36,
                                      height: 36,
                                      decoration: const BoxDecoration(
                                        color: Color(0xFF3B82F6),
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(
                                        Icons.check_rounded,
                                        color: Colors.white,
                                        size: 20,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            // Progress slider (shown when playing)
                            if (isPlaying && _previewController != null)
                              Padding(
                                padding: const EdgeInsets.fromLTRB(
                                  12,
                                  0,
                                  12,
                                  8,
                                ),
                                child: ValueListenableBuilder<VideoPlayerValue>(
                                  valueListenable: _previewController!,
                                  builder: (context, value, _) {
                                    final pos = value.position.inSeconds
                                        .toDouble();
                                    final dur = value.duration.inSeconds
                                        .toDouble();
                                    return SliderTheme(
                                      data: SliderTheme.of(context).copyWith(
                                        trackHeight: 2,
                                        thumbShape: const RoundSliderThumbShape(
                                          enabledThumbRadius: 5,
                                        ),
                                        overlayShape:
                                            const RoundSliderOverlayShape(
                                              overlayRadius: 10,
                                            ),
                                      ),
                                      child: Slider(
                                        value: dur > 0 ? pos.clamp(0, dur) : 0,
                                        min: 0,
                                        max: dur > 0 ? dur : 1,
                                        activeColor: Colors.blue,
                                        inactiveColor: Colors.blue.shade100,
                                        onChanged: dur > 0
                                            ? (v) => _previewController!.seekTo(
                                                Duration(seconds: v.toInt()),
                                              )
                                            : null,
                                      ),
                                    );
                                  },
                                ),
                              ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
