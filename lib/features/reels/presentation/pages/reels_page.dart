import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/gestures.dart';
import 'package:image_picker/image_picker.dart';
import 'package:video_player/video_player.dart';
import '../../../../core/api_service.dart';
import '../../../../core/security.dart';
import '../../../../core/widgets/video_preview.dart';
import '../../../../core/widgets/mention_text_controller.dart';
import '../../../../core/widgets/mention_suggestions_overlay.dart';
import '../../../../core/utils/time_helper.dart';
import '../../../../core/utils/image_editor_helper.dart';
import '../../../../core/utils/reaction_utils.dart';
import 'package:path_provider/path_provider.dart';

class ReelsPage extends StatefulWidget {
  final bool isActive;
  final int initialIndex;
  final VoidCallback? onClose;

  final VoidCallback? onRefresh;
  final List<dynamic>? reels;
  const ReelsPage({
    super.key,
    this.isActive = true,
    this.initialIndex = 0,
    this.onClose,
    this.onRefresh,
    this.reels,
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
  bool _showCommentsSidebar = true;

  @override
  void initState() {
    super.initState();
    _currentPage = widget.initialIndex;

    // Initialize with passed reels if available
    if (widget.reels != null && widget.reels!.isNotEmpty) {
      _reels = List<dynamic>.from(widget.reels!);
    }

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
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Đang xử lý Khoảnh khắc...'),
                  duration: Duration(seconds: 2),
                ),
              );
            }
            for (int i = 0; i < 3; i++) {
              await Future.delayed(const Duration(milliseconds: 2000));
              _fetchReels();
              widget.onRefresh?.call();
            }
          }
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool isDesktop = MediaQuery.of(context).size.width > 1100;

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
            : (isDesktop ? _buildDesktopReelFeed() : _buildReelFeed()),
      ),
    );
  }

  Widget _buildDesktopReelFeed() {
    return Row(
      children: [
        Expanded(
          child: Stack(
            children: [
              Listener(
                onPointerSignal: (pointerSignal) {
                  if (pointerSignal is PointerScrollEvent) {
                    final scrollEvent = pointerSignal;
                    if (scrollEvent.scrollDelta.dy > 50) {
                      _pageController.nextPage(
                        duration: const Duration(milliseconds: 400),
                        curve: Curves.easeInOut,
                      );
                    } else if (scrollEvent.scrollDelta.dy < -50) {
                      _pageController.previousPage(
                        duration: const Duration(milliseconds: 400),
                        curve: Curves.easeInOut,
                      );
                    }
                  }
                },
                child: PageView.builder(
                  controller: _pageController,
                  scrollDirection: Axis.vertical,
                  itemCount: _reels.length,
                  onPageChanged: (index) =>
                      setState(() => _currentPage = index),
                  physics:
                      const NeverScrollableScrollPhysics(), // Managed by mouse wheel
                  itemBuilder: (_, i) => Center(
                    child: Container(
                      constraints: const BoxConstraints(maxWidth: 500),
                      child: _ReelItem(
                        reel: _reels[i],
                        isActive: widget.isActive && _currentPage == i,
                        isMuted: _isMuted,
                        onLike: () => _handleLike(i),
                        onComment: (c) => _handleComment(i, c),
                        showSideActions: false,
                      ),
                    ),
                  ),
                ),
              ),
              // Controls overlay (X, Mute, +)
              Positioned(
                top: 24,
                left: 24,
                child: Row(
                  children: [
                    _IconBtn(
                      icon: Icons.close,
                      onTap: () => widget.onClose?.call(),
                    ),
                    const SizedBox(width: 12),
                    _IconBtn(
                      icon: _isMuted ? Icons.volume_off : Icons.volume_up,
                      onTap: _toggleMute,
                    ),
                  ],
                ),
              ),
              if (_reels.isNotEmpty)
                Positioned(
                  bottom: 40,
                  right: 16,
                  child: _buildDesktopSideActions(),
                ),
            ],
          ),
        ),
        // Sidebar
        if (_reels.isNotEmpty && _showCommentsSidebar)
          Container(
            width: 400,
            color: Theme.of(context).brightness == Brightness.dark
                ? const Color(0xFF252728)
                : Colors.white,
            child: ReelCommentSidebar(
              reelId:
                  (_reels[_currentPage]['_id'] ?? _reels[_currentPage]['id'])
                      ?.toString() ??
                  '',
              onClose: () => setState(() => _showCommentsSidebar = false),
            ),
          ),
      ],
    );
  }

  void _deleteReelFromFeed(BuildContext context, int index) {
    final reel = _reels[index];
    showDialog(
      context: context,
      useRootNavigator: true,
      builder: (ctx) => AlertDialog(
        title: const Text("Xóa Reel"),
        content: const Text(
          "Bạn có chắc chắn muốn xóa reel này? Hành động này không thể hoàn tác.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Hủy"),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              final String? reelId = (reel["id"] ?? reel["_id"])?.toString();
              if (reelId != null) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text("Đang xóa reel..."),
                      duration: Duration(seconds: 1),
                    ),
                  );
                }

                final result = await ApiService.deleteReel(reelId);

                if (mounted) {
                  if (result['success'] == true) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(result['message'] ?? "Đã xóa reel"),
                        backgroundColor: Colors.green,
                      ),
                    );
                    setState(() {
                      _reels.removeAt(index);
                      if (_currentPage >= _reels.length && _currentPage > 0) {
                        _currentPage--;
                        _pageController.jumpToPage(_currentPage);
                      }
                    });
                    ApiService.notificationRefresh.notifyListeners();
                    widget.onRefresh?.call();
                    widget.onClose?.call();
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(result['message'] ?? "Không thể xóa reel"),
                        backgroundColor: Colors.red,
                        duration: const Duration(seconds: 3),
                      ),
                    );
                  }
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text("Xóa"),
          ),
        ],
      ),
    );
  }

  Widget _buildDesktopSideActions() {
    if (_currentPage >= _reels.length) return const SizedBox.shrink();
    final reel = _reels[_currentPage];
    final currentUserId = (AuthService().userProfile.value?['_id'] ?? AuthService().userProfile.value?['id'])?.toString();
    final authorId = (reel['author']?['_id'] ?? reel['author']?['id'])?.toString();

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _ActionIcon(
          icon: (reel['isLiked'] ?? false) ? Icons.favorite : Icons.favorite_border,
          label: (reel['likes'] ?? 0).toString(),
          color: (reel['isLiked'] ?? false) ? Colors.red : Colors.white,
          onTap: () => _handleLike(_currentPage),
        ),
        _ActionIcon(
          icon: Icons.chat_bubble_outline,
          label: (reel['commentsCount'] ?? reel['comments']?.length ?? 0).toString(),
          onTap: () {
            setState(() {
              _showCommentsSidebar = !_showCommentsSidebar;
            });
          },
        ),
        _ActionIcon(
          icon: Icons.visibility_outlined,
          label: (reel['views'] ?? 1).toString(),
        ),
        if (currentUserId != null && currentUserId == authorId)
          _ActionIcon(
            icon: Icons.delete_outline,
            label: 'Xóa',
            color: Colors.redAccent,
            onTap: () => _deleteReelFromFeed(context, _currentPage),
          ),
      ],
    );
  }

  void _handleLike(int i) {
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
  }

  Future<bool> _handleComment(int i, Map<String, dynamic> comment) async {
    final reelId = _reels[i]["_id"] ?? _reels[i]["id"];
    if (reelId == null) return false;

    final userProfile = AuthService().userProfile.value;
    final String? authorId = (userProfile?['_id'] ?? userProfile?['id'])
        ?.toString();

    final String commentText = comment["text"]?.toString() ?? "";
    final bool success = await ApiService.addReelComment(
      reelId.toString(),
      commentText,
      authorId: authorId,
    );

    if (success) {
      await _sendMentionNotifications(commentText, reelId.toString(), authorId);
    }
    return success;
  }

  Future<void> _sendMentionNotifications(
    String text,
    String reelId,
    String? authorId,
  ) async {
    if (authorId == null) return;

    // Extract mentions using the same regex as MentionTextEditingController
    final mentionRegex = RegExp(r'@\S+(?:\s+(?![a-z])[^ \s@:;!?,]+)*');
    final mentions = mentionRegex
        .allMatches(text)
        .map((m) => m.group(0)?.substring(1) ?? '')
        .toList();

    if (mentions.isEmpty) return;

    // Remove duplicates
    final uniqueMentions = mentions.toSet().toList();

    for (final mention in uniqueMentions) {
      try {
        // First try search API
        List<dynamic> users = await ApiService.searchUsers(mention);

        // If search API returns no results, try getting all users and filter client-side
        if (users.isEmpty) {
          final allUsers = await ApiService.getUsers();
          users = allUsers.where((u) {
            final fullName = (u['fullName'] ?? u['name'] ?? '')
                .toString()
                .toLowerCase();
            final username = (u['username'] ?? '').toString().toLowerCase();
            final query = mention.toLowerCase();
            return fullName.contains(query) || username.contains(query);
          }).toList();
        }

        final user = users.firstWhere(
          (u) =>
              (u['fullName'] ?? u['name'] ?? '').toString().toLowerCase() ==
                  mention.toLowerCase() ||
              (u['username'] ?? '').toString().toLowerCase() ==
                  mention.toLowerCase(),
          orElse: () => null,
        );

        if (user != null) {
          final recipientId = (user['_id'] ?? user['id'])?.toString();
          if (recipientId != null) {
            final authorName =
                AuthService().userProfile.value?['fullName']?.toString() ??
                'Bạn';
            debugPrint(
              'DEBUG: Creating local mention notification for $recipientId',
            );
            ApiService.addLocalNotification({
              'recipient': recipientId,
              'senders': [
                {
                  'fullName': authorName,
                  'profilePicture': AuthService()
                      .userProfile
                      .value?['profilePicture']
                      ?.toString(),
                },
              ],
              'type': 'mention',
              'content': 'Bạn được đề cập trong một bình luận',
              'link': '/reel/$reelId',
              'metadata': {'reelId': reelId, 'mentionBy': authorId},
              'isRead': false,
              'createdAt': DateTime.now().toIso8601String(),
            });
            debugPrint('DEBUG: Local mention notification added');
          }
        }
      } catch (e) {
        debugPrint('Error sending mention notification: $e');
      }
    }
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

                final String commentText = comment["text"]?.toString() ?? "";
                final bool success = await ApiService.addReelComment(
                  reelId.toString(),
                  commentText,
                  authorId: authorId,
                );

                if (success) {
                  await _sendMentionNotifications(
                    commentText,
                    reelId.toString(),
                    authorId,
                  );
                }

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
    this.showSideActions = true,
  });

  final bool showSideActions;

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

  void _deleteReel(BuildContext context) {
    showDialog(
      context: context,
      useRootNavigator: true,
      builder: (ctx) => AlertDialog(
        title: const Text("Xóa Reel"),
        content: const Text(
          "Bạn có chắc chắn muốn xóa reel này? Hành động này không thể hoàn tác.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Hủy"),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              final String? reelId =
                  (widget.reel["id"] ?? widget.reel["_id"])?.toString();
              if (reelId != null) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text("Đang xóa reel..."),
                      duration: Duration(seconds: 1),
                    ),
                  );
                }

                final result = await ApiService.deleteReel(reelId);

                if (mounted) {
                  if (result['success'] == true) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(result['message'] ?? "Đã xóa reel"),
                        backgroundColor: Colors.green,
                      ),
                    );
                    // Trigger a refresh somehow. If the page provides a way to refresh or pop if it's the last one.
                    // For now, if we are in a Feed, we should probably remove it from the list.
                    // If `ReelsPage` had `onDelete` we could call it. Since not, we can trigger global refresh.
                    ApiService.notificationRefresh.notifyListeners();
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          result['message'] ?? "Không thể xóa reel",
                        ),
                        backgroundColor: Colors.red,
                        duration: const Duration(seconds: 3),
                      ),
                    );
                  }
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text("Xóa"),
          ),
        ],
      ),
    );
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
              if (widget.reel['music'] != null)
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
        if (widget.showSideActions)
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
                _ActionIcon(
                  icon: Icons.visibility_outlined,
                  label: (widget.reel['views'] ?? 1).toString(),
                ),
                if ((AuthService().userProfile.value?['_id'] ?? AuthService().userProfile.value?['id'])?.toString() == 
                    (widget.reel['author']?['_id'] ?? widget.reel['author']?['id'])?.toString())
                  _ActionIcon(
                    icon: Icons.delete_outline,
                    label: 'Xóa',
                    color: Colors.redAccent,
                    onTap: () => _deleteReel(context),
                  ),
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
    String? replyingToId;
    List<dynamic> allUsers = [];
    List<dynamic> filteredUsers = [];
    bool showMentions = false;
    int mentionSelectedIndex = 0;
    int mentionQueryIndex = -1;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) {
          void onTextChanged() {
            final text = ctrl.text;
            final selection = ctrl.selection;

            if (selection.start != selection.end || selection.start < 0) {
              if (showMentions) setModalState(() => showMentions = false);
              return;
            }

            final cursorPosition = selection.start;
            final textBeforeCursor = text.substring(0, cursorPosition);

            int lastAt = -1;
            for (int i = textBeforeCursor.length - 1; i >= 0; i--) {
              if (textBeforeCursor[i] == '@') {
                if (i == 0 || textBeforeCursor[i - 1].trim().isEmpty) {
                  lastAt = i;
                  break;
                }
              }
            }
            if (lastAt != -1) {
              final query = textBeforeCursor.substring(lastAt + 1);
              if (!query.contains(' ') && !query.contains('\n')) {
                final filtered = allUsers.where((u) {
                  final name = (u['fullName'] ?? u['name'] ?? '')
                      .toString()
                      .toLowerCase();
                  return name.contains(query.toLowerCase());
                }).toList();

                setModalState(() {
                  filteredUsers = filtered;
                  showMentions = filtered.isNotEmpty;
                  mentionSelectedIndex = 0;
                  mentionQueryIndex = lastAt;
                });
                return;
              }
            }

            if (showMentions) {
              setModalState(() {
                showMentions = false;
              });
            }
          }

          void insertMention(Map<String, dynamic> user) {
            final name = (user['fullName'] ?? user['name'] ?? '').toString();
            final text = ctrl.text;
            final before = text.substring(0, mentionQueryIndex);
            final after = text.substring(ctrl.selection.end);

            final newText = "$before@$name\u200B $after";
            ctrl.value = TextEditingValue(
              text: newText,
              selection: TextSelection.collapsed(
                offset: before.length + name.length + 2,
              ),
            );
            setModalState(() {
              showMentions = false;
            });
            commentFocusNode.requestFocus();
          }

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

          Future<void> loadUsers() async {
            final users = await ApiService.getUsers();
            if (ctx.mounted) {
              setModalState(() {
                allUsers = users;
              });
            }
          }

          // Trigger load on first build
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (allUsers.isEmpty) {
              loadUsers();
              ctrl.addListener(onTextChanged);
            }
            if (comments.isEmpty) loadComments();
          });

          return Container(
            height: MediaQuery.of(context).size.height * 0.75,
            decoration: BoxDecoration(
              color: Theme.of(context).brightness == Brightness.dark
                  ? const Color(0xFF252728)
                  : Colors.white,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
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
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
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
                                                      fontWeight:
                                                          FontWeight.bold,
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
                                                    color: Theme.of(context).brightness == Brightness.dark
                                                         ? const Color(0xFF333537)
                                                         : const Color(
                                                      0xFFF1F5F9,
                                                    ),
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          16,
                                                        ),
                                                  ),
                                                  child: Column(
                                                    crossAxisAlignment:
                                                        CrossAxisAlignment
                                                            .start,
                                                    children: [
                                                      Text(
                                                        authorName,
                                                        style: TextStyle(
                                                          fontWeight:
                                                              FontWeight.bold,
                                                          color: Theme.of(context).brightness == Brightness.dark
                                                              ? Colors.white
                                                              : Colors.black,
                                                          fontSize: 12,
                                                        ),
                                                      ),
                                                      const SizedBox(height: 2),
                                                      MentionText(
                                                        text:
                                                            comment['text']
                                                                ?.toString() ??
                                                            '',
                                                        style: TextStyle(
                                                          fontSize: 13,
                                                          color: Theme.of(context).brightness == Brightness.dark
                                                              ? Colors.white.withOpacity(0.9)
                                                              : Colors.black87,
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
                                                    child: GestureDetector(
                                                      onTap: () {
                                                        final List<dynamic>?
                                                            commentReactions =
                                                            comment['reactions']
                                                                as List<
                                                                    dynamic>?;
                                                        if (commentReactions !=
                                                                null &&
                                                            commentReactions
                                                                .isNotEmpty) {
                                                          ReactionUtils
                                                              .showReactionList(
                                                            context,
                                                            commentReactions,
                                                            allUsers,
                                                          );
                                                        }
                                                      },
                                                      child: Container(
                                                        padding:
                                                            const EdgeInsets
                                                                .symmetric(
                                                              horizontal: 4,
                                                              vertical: 2,
                                                            ),
                                                        decoration: BoxDecoration(
                                                          color: Theme.of(context)
                                                                      .brightness ==
                                                                  Brightness.dark
                                                              ? const Color(
                                                                  0xFF333537,
                                                                )
                                                              : Colors.white,
                                                          borderRadius:
                                                              BorderRadius
                                                                  .circular(
                                                            12,
                                                          ),
                                                          boxShadow: [
                                                            BoxShadow(
                                                              color: Colors.black
                                                                  .withOpacity(
                                                                    0.1,
                                                                  ),
                                                              blurRadius: 4,
                                                              offset:
                                                                  const Offset(
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
                                                            const SizedBox(
                                                              width: 2,
                                                            ),
                                                            Text(
                                                              comment['likes']
                                                                  .toString(),
                                                              style: TextStyle(
                                                                fontSize: 9,
                                                                fontWeight:
                                                                    FontWeight
                                                                        .bold,
                                                                color: Theme.of(
                                                                            context)
                                                                        .brightness ==
                                                                        Brightness
                                                                            .dark
                                                                    ? Colors
                                                                        .white70
                                                                    : Colors
                                                                        .black54,
                                                              ),
                                                            ),
                                                          ],
                                                        ),
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
                                                  formatTime(
                                                    comment['time'] ??
                                                        comment['createdAt'] ??
                                                        comment['created_at'],
                                                  ),
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
                                                    if (commentId == null)
                                                      return;

                                                    final bool wasLiked =
                                                        comment['isLiked'] ==
                                                        true;
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
                                                      comment['likes'] =
                                                          wasLiked
                                                          ? (currentLikes > 0
                                                                ? currentLikes -
                                                                      1
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
                                                          comment['isLiked'] ==
                                                              true
                                                          ? Colors.red
                                                          : Colors.blueGrey,
                                                      fontSize: 10,
                                                      fontWeight:
                                                          FontWeight.bold,
                                                    ),
                                                  ),
                                                ),
                                                const SizedBox(width: 14),
                                                GestureDetector(
                                                  onTap: () {
                                                    setModalState(() {
                                                      replyingToName =
                                                          authorName;
                                                      replyingToId =
                                                          (comment['_id'] ??
                                                                  comment['id'])
                                                              ?.toString();
                                                    });
                                                    ctrl.text =
                                                        "@$authorName  ";
                                                    ctrl.selection =
                                                        TextSelection.fromPosition(
                                                          TextPosition(
                                                            offset: ctrl
                                                                .text
                                                                .length,
                                                          ),
                                                        );
                                                    commentFocusNode
                                                        .requestFocus();
                                                  },
                                                  child: const Text(
                                                    "Phản hồi",
                                                    style: TextStyle(
                                                      color: Colors.blueGrey,
                                                      fontSize: 10,
                                                      fontWeight:
                                                          FontWeight.bold,
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
                                  if (comment['replies'] != null &&
                                      (comment['replies'] as List).isNotEmpty)
                                    Padding(
                                      padding: const EdgeInsets.only(
                                        left: 42,
                                        top: 0,
                                        bottom: 8,
                                      ),
                                      child: Column(
                                        children: (comment['replies'] as List).map((
                                          reply,
                                        ) {
                                          final rAuthor = reply['author'];
                                          final String rAuthorName =
                                              (rAuthor is Map)
                                              ? (rAuthor['fullName'] ??
                                                    rAuthor['name'] ??
                                                    'Người dùng')
                                              : (rAuthor ?? 'Người dùng')
                                                    .toString();
                                          final String? rAvatarId =
                                              (rAuthor is Map)
                                              ? rAuthor['profilePicture']
                                                    ?.toString()
                                              : null;

                                          return Padding(
                                            padding: const EdgeInsets.only(
                                              bottom: 10,
                                            ),
                                            child: Row(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                FutureBuilder<
                                                  Map<String, String>
                                                >(
                                                  future:
                                                      ApiService.getAuthHeaders(),
                                                  builder: (context, headers) {
                                                    return CircleAvatar(
                                                      radius: 12,
                                                      backgroundColor: Colors
                                                          .blueGrey
                                                          .shade100,
                                                      backgroundImage:
                                                          rAvatarId != null
                                                          ? NetworkImage(
                                                              ApiService.resolveImageUrl(
                                                                rAvatarId,
                                                              ),
                                                              headers:
                                                                  headers.data,
                                                            )
                                                          : null,
                                                      child: rAvatarId == null
                                                          ? Text(
                                                              rAuthorName
                                                                      .isNotEmpty
                                                                  ? rAuthorName[0]
                                                                        .toUpperCase()
                                                                  : 'U',
                                                              style:
                                                                  const TextStyle(
                                                                    color: Colors
                                                                        .white,
                                                                    fontSize:
                                                                        10,
                                                                  ),
                                                            )
                                                          : null,
                                                    );
                                                  },
                                                ),
                                                const SizedBox(width: 10),
                                                Expanded(
                                                  child: Column(
                                                    crossAxisAlignment:
                                                        CrossAxisAlignment
                                                            .start,
                                                    children: [
                                                      Container(
                                                        padding:
                                                            const EdgeInsets.symmetric(
                                                              horizontal: 10,
                                                              vertical: 6,
                                                            ),
                                                        decoration: BoxDecoration(
                                                          color: Theme.of(context).brightness == Brightness.dark
                                                              ? const Color(0xFF333537)
                                                              : const Color(0xFFF1F5F9),
                                                          borderRadius:
                                                              BorderRadius.circular(
                                                                16,
                                                              ),
                                                        ),
                                                        child: Column(
                                                          crossAxisAlignment:
                                                              CrossAxisAlignment
                                                                  .start,
                                                          children: [
                                                            Text(
                                                              rAuthorName,
                                                              style: const TextStyle(
                                                                fontWeight:
                                                                    FontWeight
                                                                        .bold,
                                                                fontSize: 11,
                                                              ),
                                                            ),
                                                            const SizedBox(
                                                              height: 2,
                                                            ),
                                                            MentionText(
                                                              text:
                                                                  reply['text']
                                                                      ?.toString() ??
                                                                  '',
                                                              style:
                                                                  const TextStyle(
                                                                    fontSize:
                                                                        12,
                                                                    color: Colors
                                                                        .black87,
                                                                  ),
                                                            ),
                                                          ],
                                                        ),
                                                      ),
                                                      const SizedBox(height: 4),
                                                      Text(
                                                        formatTime(
                                                          reply['time'] ??
                                                              reply['createdAt'] ??
                                                              reply['created_at'],
                                                        ),
                                                        style: const TextStyle(
                                                          color: Colors.grey,
                                                          fontSize: 9,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              ],
                                            ),
                                          );
                                        }).toList(),
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
                            setModalState(() {
                              replyingToName = null;
                              replyingToId = null;
                            });
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
                if (showMentions && filteredUsers.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: MentionSuggestionsOverlay(
                      suggestions: filteredUsers,
                      selectedIndex: mentionSelectedIndex,
                      onSelect: insertMention,
                      themeColor: const Color(0xFF3B82F6),
                    ),
                  ),
                Padding(
                  key: const ValueKey("reels_comment_input"),
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
                        child: Focus(
                          onKeyEvent: (FocusNode node, KeyEvent event) {
                            if (event is KeyDownEvent ||
                                event is KeyRepeatEvent) {
                              if (showMentions) {
                                if (event.logicalKey ==
                                    LogicalKeyboardKey.arrowDown) {
                                  setModalState(() {
                                    mentionSelectedIndex =
                                        (mentionSelectedIndex + 1) %
                                        filteredUsers.length;
                                  });
                                  return KeyEventResult.handled;
                                } else if (event.logicalKey ==
                                    LogicalKeyboardKey.arrowUp) {
                                  setModalState(() {
                                    mentionSelectedIndex =
                                        (mentionSelectedIndex -
                                            1 +
                                            filteredUsers.length) %
                                        filteredUsers.length;
                                  });
                                  return KeyEventResult.handled;
                                } else if (event.logicalKey ==
                                        LogicalKeyboardKey.enter ||
                                    event.logicalKey ==
                                        LogicalKeyboardKey.numpadEnter) {
                                  insertMention(
                                    filteredUsers[mentionSelectedIndex],
                                  );
                                  return KeyEventResult.handled;
                                } else if (event.logicalKey ==
                                    LogicalKeyboardKey.escape) {
                                  setModalState(() => showMentions = false);
                                  return KeyEventResult.handled;
                                }
                              }
                            }
                            return KeyEventResult.ignored;
                          },
                          child: TextField(
                            controller: ctrl,
                            focusNode: commentFocusNode,
                            style: const TextStyle(
                              color: Colors.black,
                              fontSize: 13,
                            ),
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

                          final String? parentId = replyingToId;
                          setModalState(() {
                            replyingToName = null;
                            replyingToId = null;
                          });

                          final success = await widget.onComment({
                            "text": userText,
                            "parentCommentId": parentId,
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

class _ActionIcon extends StatefulWidget {
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
  State<_ActionIcon> createState() => _ActionIconState();
}

class _ActionIconState extends State<_ActionIcon> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: Padding(
          padding: const EdgeInsets.only(bottom: 20),
          child: Column(
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _isHovered ? Colors.white.withOpacity(0.2) : Colors.transparent,
                ),
                child: Icon(
                  widget.icon, 
                  color: widget.color, 
                  size: _isHovered ? 32 : 28,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                widget.label,
                style: TextStyle(
                  color: Colors.white, 
                  fontSize: 11,
                  fontWeight: _isHovered ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            ],
          ),
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
  String? _mediaType; // 'image' or 'video'
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
        setState(() {
          _mediaPath = _selectedFile!.path;
          _mediaType = source;
        });
        // We can also store the file itself if needed for bytes read later
        this._selectedXFile = _selectedFile;
      }
    } catch (e) {
      debugPrint('Pick media error: $e');
    }
  }

  Future<void> _editImage() async {
    if (_mediaPath == null || _mediaType != 'image') return;

    try {
      final bytes = await _selectedXFile!.readAsBytes();
      if (!mounted) return;
      final editedBytes = await ImageEditorHelper.editImage(context, bytes);

      if (editedBytes != null) {
        final tempDir = await getTemporaryDirectory();
        final tempFile = File(
          '${tempDir.path}/edited_${DateTime.now().millisecondsSinceEpoch}.jpg',
        );
        await tempFile.writeAsBytes(editedBytes);

        setState(() {
          _mediaPath = tempFile.path;
          _selectedXFile = XFile(tempFile.path);
        });
      }
    } catch (e) {
      debugPrint('Edit image error: $e');
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
          String pathId = uploadedPath;
          if (pathId.startsWith('http')) {
            final uri = Uri.parse(pathId);
            if (uri.pathSegments.isNotEmpty) {
              pathId = uri.pathSegments.last;
            }
          }
          finalMediaPath = "/api/images/$pathId";
        }
      } catch (e) {
        debugPrint("Reel upload error: $e");
      }
    }
    // Ensure finalMediaPath defaults to something or handles local properly (as per ApiService behavior)
    final String? finalUrl = finalMediaPath ?? _mediaPath;

    widget.onPublish({
      'caption': _captionCtrl.text.trim(),
      'mediaType': _mediaType ?? 'video',
      'music': _selectedMusic?['_id'] ?? _selectedMusic?['id'],
      'videoUrl': finalUrl,
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
    return Stack(
      fit: StackFit.expand,
      children: [
        if (_mediaPath != null)
          _mediaType == 'image'
              ? (kIsWeb
                  ? Image.network(_mediaPath!, fit: BoxFit.cover)
                  : Image.file(File(_mediaPath!), fit: BoxFit.cover))
              : (kIsWeb
                  ? const Center(
                      child: Icon(
                        Icons.videocam,
                        color: Colors.white,
                        size: 64,
                      ),
                    )
                  : VideoPreview(
                      file: File(_mediaPath!),
                    )),
        Container(color: Colors.black.withOpacity(0.4)),
        Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.check_circle_outline, color: Colors.green, size: 56),
              const SizedBox(height: 12),
              const Text(
                'Phương tiện đã chọn',
                style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              GestureDetector(
                onTap: _pickMedia,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.black54,
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
              if (_mediaType == 'image') ...[
                const SizedBox(height: 12),
                GestureDetector(
                  onTap: _editImage,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade700,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Text(
                      'CHỈNH SỬA ẢNH',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
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

class _IconBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _IconBtn({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 42,
        height: 42,
        decoration: const BoxDecoration(
          color: Colors.black54,
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: Colors.white, size: 22),
      ),
    );
  }
}

class ReelCommentSidebar extends StatefulWidget {
  final String reelId;
  final VoidCallback onClose;
  const ReelCommentSidebar({
    super.key,
    required this.reelId,
    required this.onClose,
  });

  @override
  State<ReelCommentSidebar> createState() => _ReelCommentSidebarState();
}

class _ReelCommentSidebarState extends State<ReelCommentSidebar> {
  final TextEditingController _ctrl = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  List<dynamic> _comments = [];
  bool _isLoading = false;
  String? _replyingToId;
  String? _replyingToName;

  @override
  void initState() {
    super.initState();
    _fetchComments();
  }

  @override
  void didUpdateWidget(ReelCommentSidebar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.reelId != widget.reelId) {
      _fetchComments();
    }
  }

  Future<void> _fetchComments() async {
    setState(() => _isLoading = true);
    try {
      final comments = await ApiService.getReelComments(widget.reelId);
      final currentUserId =
          (AuthService().userProfile.value?['_id'] ??
                  AuthService().userProfile.value?['id'])
              ?.toString();

      if (mounted) {
        setState(() {
          _comments = comments.map((c) {
            final Map<String, dynamic> comment = Map<String, dynamic>.from(c);
            final reactions = comment['reactions'] as List?;
            comment['isLiked'] =
                reactions?.any(
                  (re) =>
                      (re['user']?.toString() == currentUserId ||
                      (re['user'] is Map &&
                          (re['user']['_id']?.toString() == currentUserId ||
                              re['user']['id']?.toString() == currentUserId))),
                ) ??
                false;
            comment['likes'] = reactions?.length ?? comment['likes'] ?? 0;
            return comment;
          }).toList();
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _postComment() async {
    final text = _ctrl.text.trim();
    if (text.isEmpty) return;

    final userProfile = AuthService().userProfile.value;
    final authorId = (userProfile?['_id'] ?? userProfile?['id'])?.toString();

    final success = await ApiService.addReelComment(
      widget.reelId,
      text,
      authorId: authorId,
    );

    if (success) {
      _ctrl.clear();
      _focusNode.unfocus();
      setState(() {
        _replyingToId = null;
        _replyingToName = null;
      });
      _fetchComments();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Column(
      children: [
        // Header
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: isDark ? Colors.white.withOpacity(0.05) : Colors.grey.shade200,
              ),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.chat_bubble_outline,
                    size: 20,
                    color: Color(0xFF3B82F6),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '${_comments.length} BÌNH LUẬN',
                    style: const TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
              IconButton(
                icon: const Icon(Icons.close, size: 20),
                onPressed: widget.onClose,
              ),
            ],
          ),
        ),
        // Comments List
        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _comments.isEmpty
              ? _buildEmptyState()
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _comments.length,
                  itemBuilder: (context, index) =>
                      _commentItem(_comments[index]),
                ),
        ),
        // Input
        if (_replyingToName != null)
          Container(
            color: isDark ? Colors.blue.withOpacity(0.1) : const Color(0xFFEFF6FF),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                const Icon(Icons.reply, size: 14, color: Colors.blue),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Đang phản hồi $_replyingToName',
                    style: const TextStyle(color: Colors.blue, fontSize: 12),
                  ),
                ),
                GestureDetector(
                  onTap: () => setState(() {
                    _replyingToName = null;
                    _replyingToId = null;
                  }),
                  child: const Icon(Icons.close, size: 16, color: Colors.blue),
                ),
              ],
            ),
          ),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            border: Border(
              top: BorderSide(
                color: isDark ? Colors.white.withOpacity(0.05) : Colors.grey.shade200,
              ),
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _ctrl,
                  focusNode: _focusNode,
                  decoration: InputDecoration(
                    hintText: 'Viết cảm nghĩ...',
                    border: InputBorder.none,
                    hintStyle: TextStyle(
                      fontSize: 13,
                      color: isDark ? Colors.grey : Colors.grey.shade400,
                    ),
                  ),
                  style: const TextStyle(fontSize: 13),
                  onSubmitted: (_) => _postComment(),
                ),
              ),
              IconButton(
                icon: const Icon(
                  Icons.send,
                  color: Color(0xFF3B82F6),
                  size: 20,
                ),
                onPressed: _postComment,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.chat_bubble_outline,
            size: 48,
            color: Colors.grey.shade300,
          ),
          const SizedBox(height: 16),
          const Text(
            'Chưa có thảo luận nào',
            style: TextStyle(color: Colors.grey, fontSize: 13),
          ),
        ],
      ),
    );
  }

  Widget _commentItem(Map<String, dynamic> comment) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final author = comment['author'];
    final authorName = (author is Map)
        ? (author['fullName'] ?? 'Người dùng')
        : author.toString();
    final avatarId = (author is Map)
        ? author['profilePicture']?.toString()
        : null;

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 16,
            backgroundImage: avatarId != null
                ? NetworkImage(ApiService.resolveImageUrl(avatarId))
                : null,
            child: avatarId == null
                ? Text(authorName.isNotEmpty ? authorName[0] : '?')
                : null,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: isDark
                        ? const Color(0xFF333537)
                        : const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        authorName,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        comment['text'] ?? '',
                        style: TextStyle(
                          fontSize: 13,
                          color: isDark ? Colors.white.withOpacity(0.9) : Colors.black87,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    const SizedBox(width: 4),
                    Text(
                      formatTime(comment['createdAt']),
                      style: const TextStyle(fontSize: 10, color: Colors.grey),
                    ),
                    const SizedBox(width: 16),
                    GestureDetector(
                      onTap: () {
                        setState(() {
                          _replyingToName = authorName;
                          _replyingToId = comment['_id'];
                          _ctrl.text = "@$authorName ";
                        });
                        _focusNode.requestFocus();
                      },
                      child: const Text(
                        'Phản hồi',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: Colors.blueGrey,
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
  }
}
