import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../../core/api_service.dart';
import '../../../../core/security.dart';
import '../../../../core/widgets/full_screen_media_viewer.dart';
import '../../../../core/widgets/video_preview.dart';
import '../../../reels/presentation/pages/reels_page.dart';
import '../../../../core/widgets/mention_text_controller.dart';
import '../../../../core/utils/time_helper.dart';
import '../../../../core/utils/image_editor_helper.dart';
import '../../../../core/widgets/mention_suggestions_overlay.dart';
// import '../../../../core/utils/notification_helper.dart';
import 'package:path_provider/path_provider.dart';

class WorkHomePage extends StatefulWidget {
  final List<Map<String, dynamic>> reels;
  final Function(int)? onNavigateToReels;
  final VoidCallback? onRefreshReels;
  const WorkHomePage({
    super.key,
    this.onNavigateToReels,
    this.onRefreshReels,
    required this.reels,
  });

  @override
  State<WorkHomePage> createState() => WorkHomePageState();
}

class WorkHomePageState extends State<WorkHomePage> {
  void refresh() {
    _fetchPosts(refresh: true);
    widget.onRefreshReels?.call();
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeOut,
      );
    }
  }

  List<Map<String, dynamic>> _posts = [];
  bool _isPostsLoading = false;
  bool _isMoreLoading = false;
  int _currentPage = 1;
  int _totalPages = 1;
  late ScrollController _scrollController;
  final Map<String, GlobalKey<_PostCardState>> _postCardKeys = {};

  @override
  void initState() {
    super.initState();
    _scrollController = _SmoothScrollController();
    _fetchPosts(refresh: true);
    _scrollController.addListener(() {
      final pos = _scrollController.position.pixels;
      final max = _scrollController.position.maxScrollExtent;
      // debugPrint(
      //   'DEBUG: Scroll - pos: ${pos.toStringAsFixed(1)}, max: ${max.toStringAsFixed(1)}, moreLoading: $_isMoreLoading, postsLoading: $_isPostsLoading, page: $_currentPage/$_totalPages',
      // );
      if (pos >= max - 500 &&
          !_isMoreLoading &&
          !_isPostsLoading &&
          _currentPage < _totalPages) {
        // debugPrint('DEBUG: Triggering next page load...');
        _fetchPosts(refresh: false);
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _fetchPosts({bool refresh = true}) async {
    if (refresh) {
      setState(() {
        _isPostsLoading = true;
        _currentPage = 1;
      });
    } else {
      setState(() => _isMoreLoading = true);
    }

    final int targetPage = refresh ? 1 : _currentPage + 1;
    final result = await ApiService.getPosts(page: targetPage, limit: 10);

    final List<dynamic> newPosts = result['posts'] ?? [];
    int total = result['totalPages'] ?? 1;

    // Fallback: If we got a full page, allow at least one more page
    if (total <= targetPage && newPosts.length >= 10) {
      total = targetPage + 1;
      // debugPrint('DEBUG: Full page received, bumping totalPages to $total');
    }

    final currentUserId =
        (AuthService().userProfile.value?['_id'] ??
                AuthService().userProfile.value?['id'])
            ?.toString();

    if (mounted) {
      setState(() {
        final List<Map<String, dynamic>> processed = newPosts.map((p) {
          final Map<String, dynamic> post = Map<String, dynamic>.from(p);
          final reactions = post['reactions'] as List?;
          post['isLiked'] =
              reactions?.any(
                (r) =>
                    (r['user']?.toString() == currentUserId ||
                    (r['user'] is Map &&
                        (r['user']['_id']?.toString() == currentUserId ||
                            r['user']['id']?.toString() == currentUserId))),
              ) ??
              false;
          post['likes'] = reactions?.length ?? post['likes'] ?? 0;
          return post;
        }).toList();

        if (refresh) {
          _posts = processed;
          _currentPage = 1;
        } else {
          _posts.addAll(processed);
          _currentPage++;
        }
        _totalPages = total;
        _isPostsLoading = false;
        _isMoreLoading = false;
      });
    }
  }

  void _onPostAdded(
    String content,
    dynamic background,
    dynamic mediaFiles, // Can be List<XFile>, XFile, or String
  ) async {
    final List<Map<String, dynamic>> mediaList = [];
    final List<dynamic> filesToProcess = [];

    if (mediaFiles is List) {
      filesToProcess.addAll(mediaFiles);
    } else if (mediaFiles != null) {
      filesToProcess.add(mediaFiles);
    }

    for (final file in filesToProcess) {
      if (file is XFile) {
        final bytes = await file.readAsBytes();
        final uploadedPath = await ApiService.uploadImage(bytes, file.name);
        debugPrint('DEBUG: uploadedPath = $uploadedPath');
        if (uploadedPath != null) {
          mediaList.add({
            "url": uploadedPath,
            "type":
                file.name.toLowerCase().endsWith('.mp4') ||
                    file.name.toLowerCase().endsWith('.mov')
                ? "video"
                : "image",
          });
        }
      } else if (file is String) {
        mediaList.add({
          "url": file,
          "type":
              file.toLowerCase().endsWith('.mp4') ||
                  file.toLowerCase().endsWith('.mov')
              ? "video"
              : "image",
        });
      }
    }

    final Map<String, dynamic> payload = {
      "content": content,
      "media": mediaList,
      "status": "active",
      "background": mediaList.isNotEmpty
          ? null
          : (background is Color
                ? "#${background.value.toRadixString(16).padLeft(8, '0').substring(2)}"
                : background.toString()),
      "layout": "grid",
      "privacy": "public",
    };

    debugPrint('DEBUG: Post Payload = ${jsonEncode(payload)}');

    final success = await ApiService.createPost(payload);
    if (success && mounted) {
      _fetchPosts(refresh: true);
    }
  }

  void _toggleLike(int index) async {
    final String? postId = (_posts[index]["id"] ?? _posts[index]["_id"])
        ?.toString();
    if (postId == null) return;

    setState(() {
      final bool wasLiked = _posts[index]["isLiked"] == true;
      _posts[index]["isLiked"] = !wasLiked;
      int currentLikes =
          int.tryParse(_posts[index]["likes"]?.toString() ?? "0") ?? 0;
      if (!wasLiked) {
        _posts[index]["likes"] = currentLikes + 1;
      } else {
        _posts[index]["likes"] = (currentLikes > 0) ? currentLikes - 1 : 0;
      }
    });

    // Run in background
    ApiService.togglePostLike(postId);
  }

  Future<bool> _addComment(
    int postIndex,
    String text,
    String? mediaPath, {
    String? replyTo,
    dynamic parentCommentId,
  }) async {
    final String? postId = (_posts[postIndex]["id"] ?? _posts[postIndex]["_id"])
        ?.toString();
    if (postId == null) {
      debugPrint('ERROR: postId is null for index $postIndex');
      return false;
    }

    final userProfile = AuthService().userProfile.value;
    final String? authorId = (userProfile?['_id'] ?? userProfile?['id'])
        ?.toString();

    final success = await ApiService.addComment(postId, {
      "post": postId,
      "reel": null,
      "author": authorId,
      "text": text,
      "media": mediaPath != null ? [mediaPath] : [],
      "parentComment": parentCommentId,
      "status": "active",
    });

    if (success) {
      // Send notifications to mentioned users
      await _sendMentionNotifications(text, postId, authorId);
    }

    return success;
  }

  Future<void> _sendMentionNotifications(
    String text,
    String postId,
    String? authorId,
  ) async {
    if (authorId == null) return;

    debugPrint('DEBUG: _sendMentionNotifications called with text: "$text"');

    // Extract mentions using the same regex as MentionTextEditingController
    final mentionRegex = RegExp(r'@\S+(?:\s+(?![a-z])[^ \s@:;!?,]+)*');
    final mentions = mentionRegex
        .allMatches(text)
        .map((m) => m.group(0)?.substring(1) ?? '')
        .toList();

    debugPrint('DEBUG: Found mentions: $mentions');

    if (mentions.isEmpty) return;

    // Remove duplicates
    final uniqueMentions = mentions.toSet().toList();

    for (final mention in uniqueMentions) {
      debugPrint('DEBUG: Processing mention: "$mention"');
      try {
        // First try search API
        List<dynamic> users = await ApiService.searchUsers(mention);
        debugPrint(
          'DEBUG: searchUsers returned ${users.length} users for "$mention"',
        );

        // If search API returns no results, try getting all users and filter client-side
        if (users.isEmpty) {
          debugPrint(
            'DEBUG: Search API returned no results, trying getUsers...',
          );
          final allUsers = await ApiService.getUsers();
          users = allUsers.where((u) {
            final fullName = (u['fullName'] ?? u['name'] ?? '')
                .toString()
                .toLowerCase();
            final username = (u['username'] ?? '').toString().toLowerCase();
            final query = mention.toLowerCase();
            return fullName.contains(query) || username.contains(query);
          }).toList();
          debugPrint(
            'DEBUG: Filtered ${users.length} users from getUsers for "$mention"',
          );
        }

        final user = users.firstWhere(
          (u) =>
              (u['fullName'] ?? u['name'] ?? '').toString().toLowerCase() ==
                  mention.toLowerCase() ||
              (u['username'] ?? '').toString().toLowerCase() ==
                  mention.toLowerCase(),
          orElse: () => null,
        );

        debugPrint('DEBUG: Found user: $user');

        if (user != null) {
          final recipientId = (user['_id'] ?? user['id'])?.toString();
          debugPrint('DEBUG: recipientId: $recipientId, authorId: $authorId');
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
              'link': '/post/$postId',
              'metadata': {'postId': postId, 'mentionBy': authorId},
              'isRead': false,
              'createdAt': DateTime.now().toIso8601String(),
            });
            debugPrint('DEBUG: Local mention notification added');
          }
        } else {
          debugPrint('DEBUG: No user found for mention "$mention"');
        }
      } catch (e) {
        debugPrint('Error sending mention notification: $e');
      }
    }
  }

  void _toggleCommentLike(int postIndex, int commentIndex) async {
    final rawComments =
        _posts[postIndex]["commentList"] ?? _posts[postIndex]["comments"] ?? [];
    if (commentIndex < 0 || commentIndex >= rawComments.length) return;

    final comment = rawComments[commentIndex];
    final String? commentId = (comment["id"] ?? comment["_id"])?.toString();
    if (commentId == null) return;

    final currentUserId =
        (AuthService().userProfile.value?['_id'] ??
                AuthService().userProfile.value?['id'])
            ?.toString();

    setState(() {
      final bool wasLiked = comment["isLiked"] == true;
      comment["isLiked"] = !wasLiked;
      int currentLikes = int.tryParse(comment["likes"]?.toString() ?? "0") ?? 0;
      if (!wasLiked) {
        comment["likes"] = currentLikes + 1;
      } else {
        comment["likes"] = (currentLikes > 0) ? currentLikes - 1 : 0;
      }

      if (comment["reactions"] is List) {
        final reactions = List.from(comment["reactions"] as List);
        if (!wasLiked) {
          if (currentUserId != null) {
            reactions.add({
              'type': 'like',
              'reactionType': 'like',
              'user': currentUserId,
            });
          }
        } else {
          reactions.removeWhere((action) {
            if (action is Map) {
              final user = action['user'];
              final String? actionType =
                  action['type']?.toString() ??
                  action['reactionType']?.toString();
              return actionType == 'like' &&
                  (user == currentUserId ||
                      (user is Map &&
                          (user['_id']?.toString() == currentUserId ||
                              user['id']?.toString() == currentUserId)));
            }
            return false;
          });
        }
        comment["reactions"] = reactions;
      }
    });

    final String? postId = (_posts[postIndex]["id"] ?? _posts[postIndex]["_id"])
        ?.toString();
    ApiService.toggleCommentLike(commentId, postId: postId);
  }

  Future<void> goToPost(String postId) async {
    final key = _postCardKeys[postId];
    if (key?.currentContext != null) {
      await Scrollable.ensureVisible(
        key!.currentContext!,
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
        alignment: 0.1,
      );
      return;
    }

    // If the post is not currently mounted, refresh and try again.
    await _fetchPosts(refresh: true);
    await Future.delayed(const Duration(milliseconds: 500));
    final retryKey = _postCardKeys[postId];
    if (retryKey?.currentContext != null) {
      await Scrollable.ensureVisible(
        retryKey!.currentContext!,
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
        alignment: 0.1,
      );
    }
  }

  void _toggleReplyLike(int postIndex, int commentIndex, int replyIndex) {
    setState(() {
      final replies =
          _posts[postIndex]["commentList"]?[commentIndex]["replies"] ?? [];
      if (replyIndex < 0 || replyIndex >= replies.length) return;
      final reply = replies[replyIndex];
      final bool wasLiked = reply["isLiked"] == true;
      reply["isLiked"] = !wasLiked;
      int currentLikes = int.tryParse(reply["likes"]?.toString() ?? "0") ?? 0;
      if (!wasLiked) {
        reply["likes"] = currentLikes + 1;
      } else {
        reply["likes"] = (currentLikes > 0) ? currentLikes - 1 : 0;
      }

      if (reply["reactions"] is List) {
        final currentUserId =
            (AuthService().userProfile.value?['_id'] ??
                    AuthService().userProfile.value?['id'])
                ?.toString();
        final reactions = List.from(reply["reactions"] as List);
        if (!wasLiked) {
          if (currentUserId != null) {
            reactions.add({
              'type': 'like',
              'reactionType': 'like',
              'user': currentUserId,
            });
          }
        } else {
          reactions.removeWhere((action) {
            if (action is Map) {
              final user = action['user'];
              final String? actionType =
                  action['type']?.toString() ??
                  action['reactionType']?.toString();
              return actionType == 'like' &&
                  (user == currentUserId ||
                      (user is Map &&
                          (user['_id']?.toString() == currentUserId ||
                              user['id']?.toString() == currentUserId)));
            }
            return false;
          });
        }
        reply["reactions"] = reactions;
      }
    });
  }

  void _deletePost(int index) {
    showDialog(
      context: context,
      useRootNavigator: true,
      builder: (ctx) => AlertDialog(
        title: const Text("Xóa bài viết"),
        content: const Text(
          "Bạn có chắc chắn muốn xóa bài viết này? Hành động này không thể hoàn tác.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Hủy"),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              final String? postId =
                  (_posts[index]["id"] ?? _posts[index]["_id"])?.toString();
              if (postId != null) {
                // Show loading
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text("Đang xóa bài viết..."),
                      duration: Duration(seconds: 1),
                    ),
                  );
                }

                final result = await ApiService.deletePost(postId);

                if (mounted) {
                  if (result['success'] == true) {
                    setState(() {
                      _posts.removeAt(index);
                    });
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(result['message'] ?? "Đã xóa bài viết"),
                        backgroundColor: Colors.green,
                      ),
                    );
                  } else {
                    // Show error message
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          result['message'] ?? "Không thể xóa bài viết",
                        ),
                        backgroundColor: Colors.red,
                        duration: const Duration(seconds: 3),
                      ),
                    );
                    debugPrint('Delete post failed: ${result['message']}');
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

  void _editPost(int index) {
    final String initialContent =
        (_posts[index]["content"] ??
                _posts[index]["text"] ??
                _posts[index]["body"] ??
                "")
            .toString();
    final TextEditingController controller = TextEditingController(
      text: initialContent,
    );

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Chỉnh sửa bài viết"),
        content: TextField(
          controller: controller,
          maxLines: null,
          decoration: const InputDecoration(
            hintText: "Nội dung bài viết",
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Hủy"),
          ),
          ElevatedButton(
            onPressed: () async {
              final updatedContent = controller.text.trim();
              if (updatedContent.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text("Nội dung không được để trống"),
                    backgroundColor: Colors.red,
                  ),
                );
                return;
              }

              Navigator.pop(ctx);
              final String? postId =
                  (_posts[index]["id"] ?? _posts[index]["_id"])?.toString();
              if (postId == null) return;

              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text("Đang cập nhật bài viết..."),
                  duration: Duration(seconds: 1),
                ),
              );

              final result = await ApiService.updatePost(postId, {
                "content": updatedContent,
              });

              if (mounted) {
                if (result['success'] == true) {
                  setState(() {
                    _posts[index]["content"] = updatedContent;
                  });
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        result['message'] ?? "Đã cập nhật bài viết",
                      ),
                      backgroundColor: Colors.green,
                    ),
                  );
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        result['message'] ?? "Không thể cập nhật bài viết",
                      ),
                      backgroundColor: Colors.red,
                      duration: const Duration(seconds: 3),
                    ),
                  );
                  debugPrint('Edit post failed: ${result['message']}');
                }
              }
            },
            child: const Text("Lưu"),
          ),
        ],
      ),
    );
  }

  void _showCreateReelDialog() {
    showDialog(
      context: context,
      useRootNavigator: true,
      barrierDismissible: true,
      barrierColor: Colors.black.withOpacity(0.80),
      builder: (_) => CreateReelDialog(
        onPublish: (reel) async {
          final success = await ApiService.createReel(reel);
          if (success) {
            widget.onRefreshReels?.call();
          }
          if (success && mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Đang tải Reel lên...'),
                duration: Duration(seconds: 2),
              ),
            );
          }
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool isDesktop = MediaQuery.of(context).size.width > 1100;

    Widget scrollBody = CustomScrollView(
      controller: _scrollController,
      physics: const _SmoothScrollPhysics(
        parent: AlwaysScrollableScrollPhysics(),
      ),
      slivers: [
        SliverToBoxAdapter(
          child: Center(
            child: Container(
              constraints: BoxConstraints(
                maxWidth: isDesktop ? 680 : double.infinity,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _HeroBanner(),
                  _StatusInput(onPostAdded: _onPostAdded),
                  _MomentsSection(
                    onAddTap: _showCreateReelDialog,
                    onNavigateToReels: widget.onNavigateToReels,
                    reels: widget.reels,
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
        ),
        if (_isPostsLoading && _posts.isEmpty)
          const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: 40),
              child: Center(child: CircularProgressIndicator()),
            ),
          )
        else if (_posts.isEmpty)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 40),
              child: Center(
                child: Column(
                  children: [
                    Icon(
                      Icons.article_outlined,
                      color: Colors.grey.shade300,
                      size: 60,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      "Chưa có bài viết nào",
                      style: TextStyle(
                        color: Colors.grey.shade500,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          )
        else
          SliverList.builder(
            itemCount: _posts.length,
            itemBuilder: (context, index) {
              final postId =
                  (_posts[index]['id'] ?? _posts[index]['_id'])?.toString() ??
                  index.toString();
              final cardKey = _postCardKeys.putIfAbsent(
                postId,
                () => GlobalKey(),
              );
              return Center(
                child: Container(
                  constraints: BoxConstraints(
                    maxWidth: isDesktop ? 680 : double.infinity,
                  ),
                  child: _PostCard(
                    key: cardKey,
                    post: _posts[index],
                    postIndex: index,
                    onLike: () => _toggleLike(index),
                    onDelete: () => _deletePost(index),
                    onEdit: () => _editPost(index),
                    onComment: (text, media, {replyTo, parentCommentId}) =>
                        _addComment(
                          index,
                          text,
                          media,
                          replyTo: replyTo,
                          parentCommentId: parentCommentId,
                        ),
                    onToggleCommentLike: (commentIdx) =>
                        _toggleCommentLike(index, commentIdx),
                    onToggleReplyLike: (commentIdx, replyIdx) =>
                        _toggleReplyLike(index, commentIdx, replyIdx),
                  ),
                ),
              );
            },
          ),
        if (_isMoreLoading)
          SliverToBoxAdapter(
            child: Padding(
              key: const ValueKey("loading_more_spinner"),
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: Column(
                  children: [
                    const CircularProgressIndicator(strokeWidth: 2),
                    const SizedBox(height: 8),
                    Text(
                      "Đang tải bài viết mới...",
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        const SliverToBoxAdapter(child: SizedBox(height: 100)),
      ],
    );

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: RefreshIndicator(
        onRefresh: () async {
          await _fetchPosts(refresh: true);
          widget.onRefreshReels?.call();
        },
        child: scrollBody,
      ),
    );
  }
}

class _StatusInput extends StatelessWidget {
  final Function(String, dynamic, dynamic) onPostAdded;
  const _StatusInput({required this.onPostAdded});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
                    radius: 24,
                    backgroundColor: Colors.blueGrey.shade100,
                    backgroundImage: avatarId != null
                        ? NetworkImage(
                            ApiService.resolveImageUrl(avatarId),
                            headers: headers.data,
                          )
                        : null,
                    child: avatarId == null
                        ? const Icon(Icons.person, color: Colors.blueGrey)
                        : null,
                  );
                },
              );
            },
          ),
          const SizedBox(width: 12),
          Expanded(
            child: InkWell(
              onTap: () => _showCreatePost(context),
              borderRadius: BorderRadius.circular(12),
              child: Container(
                height: 48,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Text(
                      "${AuthService().userProfile.value?['name'] ?? 'Bạn'} ơi, bạn đang nghĩ gì?",
                      style: const TextStyle(color: Colors.grey, fontSize: 13),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Material(
            color: const Color(0xFFEFF6FF),
            borderRadius: BorderRadius.circular(12),
            child: InkWell(
              onTap: () => _showCreatePost(context),
              borderRadius: BorderRadius.circular(12),
              child: const SizedBox(
                width: 48,
                height: 48,
                child: Icon(Icons.add, color: Color(0xFF3B82F6)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showCreatePost(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _CreatePostSheet(onPost: onPostAdded),
    );
  }
}

class _CreatePostSheet extends StatefulWidget {
  final Function(String, dynamic, dynamic) onPost;
  const _CreatePostSheet({required this.onPost});
  @override
  State<_CreatePostSheet> createState() => _CreatePostSheetState();
}

class _CreatePostSheetState extends State<_CreatePostSheet> {
  dynamic _selectedBackground; // null means no background
  final TextEditingController _contentController =
      MentionTextEditingController();
  final ImagePicker _picker = ImagePicker();
  final FocusNode _focusNode = FocusNode();
  List<XFile> _selectedFiles = [];
  bool _showEmoji = false;

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(() {
      if (_focusNode.hasFocus) setState(() => _showEmoji = false);
    });
  }

  @override
  void dispose() {
    _contentController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _pickMedia(ImageSource source) async {
    if (source == ImageSource.gallery) {
      final List<XFile> files = await _picker.pickMultiImage();
      if (files.isNotEmpty) {
        setState(() => _selectedFiles.addAll(files));
      }
    } else {
      final XFile? file = await _picker.pickImage(source: source);
      if (file != null) setState(() => _selectedFiles.add(file));
    }
  }

  Future<void> _pickVideo() async {
    final XFile? file = await _picker.pickVideo(source: ImageSource.gallery);
    if (file != null) setState(() => _selectedFiles.add(file));
  }

  Future<void> _editImage(int index) async {
    final file = _selectedFiles[index];
    final isImage =
        !file.name.toLowerCase().endsWith('.mp4') &&
        !file.name.toLowerCase().endsWith('.mov');
    if (!isImage) return;

    try {
      final bytes = await file.readAsBytes();
      if (!mounted) return;
      final editedBytes = await ImageEditorHelper.editImage(context, bytes);

      if (editedBytes != null) {
        final tempDir = await getTemporaryDirectory();
        final tempFile = File(
          '${tempDir.path}/edited_${DateTime.now().millisecondsSinceEpoch}.jpg',
        );
        await tempFile.writeAsBytes(editedBytes);

        setState(() {
          _selectedFiles[index] = XFile(tempFile.path);
        });
      }
    } catch (e) {
      debugPrint('Edit image error: $e');
    }
  }

  void _insertEmoji(String emoji) {
    final text = _contentController.text;
    final selection = _contentController.selection;
    int start = selection.start;
    if (start < 0) start = text.length;
    final newText = text.replaceRange(
      start,
      selection.end < 0 ? start : selection.end,
      emoji,
    );
    setState(() {
      _contentController.text = newText;
      _contentController.selection = TextSelection.fromPosition(
        TextPosition(offset: start + emoji.length),
      );
    });
  }

  void _toggleEmoji() {
    if (_showEmoji) {
      _focusNode.requestFocus();
    } else {
      _focusNode.unfocus();
    }
    setState(() => _showEmoji = !_showEmoji);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  "Tạo bài viết mới",
                  style: TextStyle(fontWeight: FontWeight.w900, fontSize: 20),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                children: [
                  _AuthorHeader(),
                  const SizedBox(height: 16),
                  _PostBackgroundSelector(
                    selectedBackground: _selectedBackground,
                    onSelect: (bg) => setState(() => _selectedBackground = bg),
                  ),
                  const SizedBox(height: 16),
                  Stack(
                    children: [
                      Container(
                        height: 250,
                        decoration: _selectedBackground != null
                            ? PostBackgroundHelper.getDecoration(
                                _selectedBackground,
                              ).copyWith(
                                borderRadius: BorderRadius.circular(16),
                              )
                            : BoxDecoration(
                                color: const Color(0xFFF8FAFC),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: Colors.grey.shade200),
                              ),
                        padding: const EdgeInsets.all(24),
                        alignment: Alignment.center,
                        child: TextField(
                          controller: _contentController,
                          focusNode: _focusNode,
                          maxLines: null,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: _selectedBackground != null
                                ? Colors.white
                                : Colors.black87,
                            fontSize: 24,
                            fontWeight: FontWeight.w900,
                          ),
                          decoration: InputDecoration(
                            hintText: "Bạn đang nghĩ gì?",
                            border: InputBorder.none,
                            hintStyle: TextStyle(
                              color: _selectedBackground != null
                                  ? Colors.white70
                                  : Colors.grey,
                            ),
                          ),
                        ),
                      ),
                      if (_selectedFiles.isNotEmpty)
                        Positioned(
                          bottom: 12,
                          left: 12,
                          right: 12,
                          child: SizedBox(
                            height: 100,
                            child: ListView.builder(
                              scrollDirection: Axis.horizontal,
                              itemCount: _selectedFiles.length,
                              itemBuilder: (context, idx) {
                                final file = _selectedFiles[idx];
                                return Padding(
                                  padding: const EdgeInsets.only(right: 12),
                                  child: Stack(
                                    children: [
                                      Container(
                                        width: 100,
                                        height: 100,
                                        decoration: BoxDecoration(
                                          color: Colors.black26,
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                          border: Border.all(
                                            color: Colors.white,
                                            width: 2,
                                          ),
                                        ),
                                        child: ClipRRect(
                                          borderRadius: BorderRadius.circular(
                                            10,
                                          ),
                                          child:
                                              file.name.toLowerCase().endsWith(
                                                    '.mp4',
                                                  ) ||
                                                  file.name
                                                      .toLowerCase()
                                                      .endsWith('.mov')
                                              ? (kIsWeb
                                                    ? const Center(
                                                        child: Icon(
                                                          Icons.videocam,
                                                          color: Colors.white,
                                                        ),
                                                      )
                                                    : VideoPreview(
                                                        file: File(file.path),
                                                      ))
                                              : (kIsWeb
                                                    ? Image.network(
                                                        file.path,
                                                        fit: BoxFit.cover,
                                                      )
                                                    : Image.file(
                                                        File(file.path),
                                                        fit: BoxFit.cover,
                                                      )),
                                        ),
                                      ),
                                      if (!file.name.toLowerCase().endsWith(
                                            '.mp4',
                                          ) &&
                                          !file.name.toLowerCase().endsWith(
                                            '.mov',
                                          ))
                                        Positioned(
                                          top: 4,
                                          left: 4,
                                          child: GestureDetector(
                                            onTap: () => _editImage(idx),
                                            child: Container(
                                              padding: const EdgeInsets.all(2),
                                              decoration: BoxDecoration(
                                                color: Colors.blue.withOpacity(
                                                  0.6,
                                                ),
                                                shape: BoxShape.circle,
                                              ),
                                              child: const Icon(
                                                Icons.edit,
                                                size: 14,
                                                color: Colors.white,
                                              ),
                                            ),
                                          ),
                                        ),
                                      Positioned(
                                        top: 4,
                                        right: 4,
                                        child: GestureDetector(
                                          onTap: () => setState(() {
                                            _selectedFiles.removeAt(idx);
                                          }),
                                          child: Container(
                                            padding: const EdgeInsets.all(2),
                                            decoration: const BoxDecoration(
                                              color: Colors.black54,
                                              shape: BoxShape.circle,
                                            ),
                                            child: const Icon(
                                              Icons.close,
                                              size: 14,
                                              color: Colors.white,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _BuildMediaAttachmentsTool(
                    onImage: () => _pickMedia(ImageSource.gallery),
                    onCamera: _pickVideo,
                    onEmoji: _toggleEmoji,
                  ),
                  if (_showEmoji)
                    _EmojiGrid(onSelected: _insertEmoji, height: 200),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(24),
            child: SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: () {
                  if (_contentController.text.isNotEmpty ||
                      _selectedFiles.isNotEmpty) {
                    widget.onPost(
                      _contentController.text,
                      _selectedBackground,
                      _selectedFiles,
                    );
                    Navigator.pop(context);
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF3B82F6),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  "ĐĂNG BÀI",
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmojiGrid extends StatelessWidget {
  final Function(String) onSelected;
  final double height;
  const _EmojiGrid({required this.onSelected, this.height = 250});

  final List<String> emojis = const [
    "😀",
    "😃",
    "😄",
    "😁",
    "😆",
    "😅",
    "😂",
    "🤣",
    "😊",
    "😇",
    "🙂",
    "🙃",
    "😉",
    "😌",
    "😍",
    "🥰",
    "😘",
    "😗",
    "😙",
    "😚",
    "😋",
    "😛",
    "😝",
    "😜",
    "🤪",
    "🤨",
    "🧐",
    "🤓",
    "😎",
    "🤩",
    "🥳",
    "😏",
    "👍",
    "👎",
    "👌",
    "🤟",
    "✌️",
    "🤞",
    "🤝",
    "🙏",
    "💪",
    "🔥",
    "✨",
    "❤️",
    "💙",
    "✅",
    "❌",
    "💯",
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      color: const Color(0xFFF1F5F9),
      padding: const EdgeInsets.all(12),
      child: GridView.builder(
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 7,
          mainAxisSpacing: 8,
          crossAxisSpacing: 8,
        ),
        itemCount: emojis.length,
        itemBuilder: (context, index) => GestureDetector(
          onTap: () => onSelected(emojis[index]),
          child: Center(
            child: Text(emojis[index], style: const TextStyle(fontSize: 24)),
          ),
        ),
      ),
    );
  }
}

class _PostCard extends StatefulWidget {
  final Map<String, dynamic> post;
  final int postIndex;
  final VoidCallback onLike;
  final VoidCallback onDelete;
  final VoidCallback onEdit;
  final Function(int) onToggleCommentLike;
  final Function(int, int) onToggleReplyLike;
  final Future<bool> Function(
    String,
    String?, {
    String? replyTo,
    dynamic parentCommentId,
  })
  onComment;
  const _PostCard({
    super.key,
    required this.post,
    required this.postIndex,
    required this.onLike,
    required this.onDelete,
    required this.onEdit,
    required this.onComment,
    required this.onToggleCommentLike,
    required this.onToggleReplyLike,
  });

  @override
  State<_PostCard> createState() => _PostCardState();
}

class _PostCardState extends State<_PostCard> {
  String? _isReplyingTo;
  dynamic _replyingToCommentId;
  bool _isExpanded = false;
  bool _isMenuVisible = false;
  List<dynamic> _localComments = [];
  final FocusNode _commentFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    final raw = widget.post["commentList"] ?? widget.post["comments"] ?? [];
    final list = List<dynamic>.from(raw);
    _processComments(list);
    _localComments = list;
    _fetchComments();
  }

  @override
  void dispose() {
    _commentFocusNode.dispose();
    super.dispose();
  }

  void _processComments(List<dynamic> comments) {
    final currentUserId =
        (AuthService().userProfile.value?['_id'] ??
                AuthService().userProfile.value?['id'])
            ?.toString();

    for (var c in comments) {
      if (c is! Map<String, dynamic>) continue;

      final reactions = c['reactions'] as List?;
      c['isLiked'] =
          reactions?.any((r) {
            final rUser = r['user'];
            return rUser?.toString() == currentUserId ||
                (rUser is Map &&
                    (rUser['_id']?.toString() == currentUserId ||
                        rUser['id']?.toString() == currentUserId));
          }) ??
          false;
      c['likes'] = reactions?.length ?? c['likes'] ?? 0;

      final replies = c['replies'] as List?;
      if (replies != null) {
        for (var r in replies) {
          if (r is! Map<String, dynamic>) continue;
          final rReactions = r['reactions'] as List?;
          r['isLiked'] =
              rReactions?.any((rr) {
                final rrUser = rr['user'];
                return rrUser?.toString() == currentUserId ||
                    (rrUser is Map &&
                        (rrUser['_id']?.toString() == currentUserId ||
                            rrUser['id']?.toString() == currentUserId));
              }) ??
              false;
          r['likes'] = rReactions?.length ?? r['likes'] ?? 0;
        }
      }
    }
  }

  Future<void> _fetchComments() async {
    final String? postId = (widget.post["id"] ?? widget.post["_id"])
        ?.toString();
    if (postId == null || postId.isEmpty) return;

    final fetched = await ApiService.getComments(postId);
    if (mounted) {
      _processComments(fetched);
      setState(() {
        _localComments = fetched;
      });
    }
  }

  void _toggleLocalCommentLike(int commentIndex) {
    if (commentIndex < 0 || commentIndex >= _localComments.length) return;
    final comment = _localComments[commentIndex] as Map<String, dynamic>;
    final String? currentUserId =
        (AuthService().userProfile.value?['_id'] ??
                AuthService().userProfile.value?['id'])
            ?.toString();
    final String? commentId = (comment["id"] ?? comment["_id"])?.toString();

    setState(() {
      final bool wasLiked = comment["isLiked"] == true;
      comment["isLiked"] = !wasLiked;
      int currentLikes = int.tryParse(comment["likes"]?.toString() ?? "0") ?? 0;
      comment["likes"] = wasLiked
          ? (currentLikes > 0 ? currentLikes - 1 : 0)
          : currentLikes + 1;

      final reactions = comment["reactions"] is List
          ? List.from(comment["reactions"] as List)
          : <dynamic>[];
      if (!wasLiked) {
        if (currentUserId != null) {
          reactions.add({
            'type': 'like',
            'reactionType': 'like',
            'user': currentUserId,
          });
        }
      } else {
        reactions.removeWhere((action) {
          if (action is Map) {
            final user = action['user'];
            final String? actionType =
                action['type']?.toString() ??
                action['reactionType']?.toString();
            return actionType == 'like' &&
                (user == currentUserId ||
                    (user is Map &&
                        (user['_id']?.toString() == currentUserId ||
                            user['id']?.toString() == currentUserId)));
          }
          return false;
        });
      }
      comment["reactions"] = reactions;
    });

    final String? postId = (widget.post["id"] ?? widget.post["_id"])
        ?.toString();
    if (commentId != null && commentId.isNotEmpty) {
      ApiService.toggleCommentReaction(
        commentId,
        reactionType: 'like',
        postId: postId,
      );
    }
  }

  void _toggleLocalReplyLike(int commentIndex, int replyIndex) {
    if (commentIndex < 0 || commentIndex >= _localComments.length) return;
    final comment = _localComments[commentIndex] as Map<String, dynamic>;
    final replies = comment["replies"] as List<dynamic>?;
    if (replies == null || replyIndex < 0 || replyIndex >= replies.length)
      return;
    final reply = replies[replyIndex] as Map<String, dynamic>;
    final String? currentUserId =
        (AuthService().userProfile.value?['_id'] ??
                AuthService().userProfile.value?['id'])
            ?.toString();
    final String? replyId = (reply["id"] ?? reply["_id"])?.toString();

    setState(() {
      final bool wasLiked = reply["isLiked"] == true;
      reply["isLiked"] = !wasLiked;
      int currentLikes = int.tryParse(reply["likes"]?.toString() ?? "0") ?? 0;
      reply["likes"] = wasLiked
          ? (currentLikes > 0 ? currentLikes - 1 : 0)
          : currentLikes + 1;

      final reactions = reply["reactions"] is List
          ? List.from(reply["reactions"] as List)
          : <dynamic>[];
      if (!wasLiked) {
        if (currentUserId != null) {
          reactions.add({
            'type': 'like',
            'reactionType': 'like',
            'user': currentUserId,
          });
        }
      } else {
        reactions.removeWhere((action) {
          if (action is Map) {
            final user = action['user'];
            final String? actionType =
                action['type']?.toString() ??
                action['reactionType']?.toString();
            return actionType == 'like' &&
                (user == currentUserId ||
                    (user is Map &&
                        (user['_id']?.toString() == currentUserId ||
                            user['id']?.toString() == currentUserId)));
          }
          return false;
        });
      }
      reply["reactions"] = reactions;
    });

    final String? postId = (widget.post["id"] ?? widget.post["_id"])
        ?.toString();
    if (replyId != null && replyId.isNotEmpty) {
      ApiService.toggleCommentReaction(
        replyId,
        reactionType: 'like',
        postId: postId,
      );
    }
  }

  void _showFullImage(String path) {
    final bool isNet = path.startsWith('http') || !File(path).existsSync();
    final String resolved = isNet ? ApiService.resolveImageUrl(path) : path;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            FullScreenMediaViewer(mediaList: [resolved], initialIndex: 0),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final List<Map<String, dynamic>> comments = List<Map<String, dynamic>>.from(
      _localComments,
    );
    final int commentsCount =
        int.tryParse(widget.post["commentsCount"]?.toString() ?? "0") ??
        comments.length;
    final int likesCount =
        int.tryParse(widget.post["likes"]?.toString() ?? "0") ??
        (widget.post["reactions"] is List
            ? (widget.post["reactions"] as List).length
            : 0);
    final List<dynamic> mediaItems = widget.post["media"] is List
        ? widget.post["media"]
        : (widget.post["mediaPath"] != null
              ? [
                  {"url": widget.post["mediaPath"], "type": "image"},
                ]
              : []);
    final String authorName = widget.post["author"] is Map
        ? (widget.post["author"]["fullName"]?.toString() ??
              widget.post["author"]["name"]?.toString() ??
              "Người dùng")
        : (widget.post["author"]?.toString() ??
              widget.post["user"]?.toString() ??
              "Người dùng");

    // Extract authorId from multiple possible locations
    String? _extractAuthorId() {
      // Try from author object
      if (widget.post["author"] is Map) {
        return (widget.post["author"]["_id"] ?? widget.post["author"]["id"])
            ?.toString();
      }
      // Try from userId field
      if (widget.post["userId"] != null) {
        return widget.post["userId"].toString();
      }
      // Try from author_id field
      if (widget.post["author_id"] != null) {
        return widget.post["author_id"].toString();
      }
      // Try from user object
      if (widget.post["user"] is Map) {
        return (widget.post["user"]["_id"] ?? widget.post["user"]["id"])
            ?.toString();
      }
      return null;
    }

    final String? extractedAuthorId = _extractAuthorId();
    final String content =
        (widget.post["content"] ??
                widget.post["text"] ??
                widget.post["body"] ??
                "")
            .toString();
    final bool hasMedia = mediaItems.isNotEmpty;
    final bool isLongText = content.length > 220;
    final String displayContent =
        ((isLongText && !_isExpanded)
                ? "${content.substring(0, 200)}..."
                : content)
            .replaceAll(RegExp(r' +'), ' ');
    final bool hasBg =
        widget.post["bgColor"] != null ||
        (widget.post["background"] != null &&
            widget.post["background"] != "null");

    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          margin: const EdgeInsets.only(bottom: 12),
          color: Colors.white,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _PostHeader(
                author: authorName,
                authorId: extractedAuthorId,
                avatar:
                    (widget.post["author"] is Map
                        ? widget.post["author"]["profilePicture"]
                        : null) ??
                    (widget.post["user"] is Map
                        ? widget.post["user"]["profilePicture"]
                        : null) ??
                    widget.post["authorAvatar"]?.toString(),
                role: (() {
                  if (widget.post["author"] is Map) {
                    return (widget.post["author"]["department"] ??
                            widget.post["author"]["role"] ??
                            "IT System")
                        .toString();
                  }
                  return (widget.post["department"] ??
                          widget.post["role"] ??
                          widget.post["position"] ??
                          "IT System")
                      .toString();
                })(),
                time: formatTime(
                  widget.post["time"] ??
                      widget.post["created_at"] ??
                      widget.post["createdAt"],
                ),
                onDelete: widget.onDelete,
                onEdit: widget.onEdit,
                onToggleMenu: () =>
                    setState(() => _isMenuVisible = !_isMenuVisible),
              ),
              if (content.isNotEmpty && (hasMedia || !hasBg))
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      MentionText(
                        text: displayContent,
                        textAlign: TextAlign.left,
                        style: const TextStyle(
                          fontSize: 15,
                          height: 1.4,
                          color: Colors.black87,
                        ),
                      ),
                      if (isLongText && !_isExpanded)
                        GestureDetector(
                          onTap: () => setState(() => _isExpanded = true),
                          child: const Padding(
                            padding: EdgeInsets.only(top: 4),
                            child: Text(
                              "Xem thêm",
                              style: TextStyle(
                                color: Colors.blue,
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              if (hasMedia) _buildMediaGrid(mediaItems),
              if (!hasMedia && hasBg)
                Container(
                  width: double.infinity,
                  height: 250,
                  decoration: PostBackgroundHelper.getDecoration(
                    widget.post["bgColor"] ?? widget.post["background"],
                  ),
                  alignment: Alignment.center,
                  padding: const EdgeInsets.all(32),
                  child: MentionText(
                    text: content,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      fontFamilyFallback: [
                        "Apple Color Emoji",
                        "Segoe UI Emoji",
                        "Segoe UI Symbol",
                        "Noto Color Emoji",
                      ],
                    ),
                  ),
                ),

              _PostEngagement(likes: likesCount, comments: commentsCount),
              const Divider(height: 1),
              _PostActions(
                isLiked: widget.post["isLiked"] == true,
                onLike: widget.onLike,
                onCommentTap: () => _commentFocusNode.requestFocus(),
              ),
              const Divider(height: 1),

              if (comments.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: Center(
                    child: Text(
                      "HÃY LÀ NGƯỜI ĐẦU TIÊN BÌNH LUẬN",
                      style: TextStyle(
                        color: Colors.grey,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              if (comments.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                  child: Column(
                    children: comments.asMap().entries.map((e) {
                      final commentIdx = e.key;
                      final comment = e.value;
                      final replies = List<Map<String, dynamic>>.from(
                        comment["replies"] ?? [],
                      );
                      return _CommentTile(
                        comment: comment,
                        onLike: () => _toggleLocalCommentLike(commentIdx),
                        onReply: () => setState(() {
                          _isReplyingTo =
                              (comment["author"] is Map
                                      ? (comment["author"]["fullName"] ??
                                            comment["author"]["name"])
                                      : comment["author"])
                                  ?.toString();
                          _replyingToCommentId =
                              (comment["id"] ?? comment["_id"])?.toString();
                        }),
                        replies: replies,
                        onReplyLike: (replyIdx) =>
                            _toggleLocalReplyLike(commentIdx, replyIdx),
                        onReplyReply: (authorName) => setState(() {
                          _isReplyingTo = authorName;
                          _replyingToCommentId =
                              (comment["id"] ?? comment["_id"])?.toString();
                        }),
                      );
                    }).toList(),
                  ),
                ),

              _QuickCommentInput(
                focusNode: _commentFocusNode,
                onSubmit: (text, media, {replyTo, parentCommentId}) async {
                  // Optimistic UI Update
                  final tempComment = {
                    "author": AuthService().userProfile.value,
                    "text": text,
                    "time": "Vừa xong",
                    "likes": 0,
                    "mediaPath": media,
                    "id": "temp_${DateTime.now().millisecondsSinceEpoch}",
                  };

                  setState(() {
                    _localComments = [tempComment, ..._localComments];
                  });

                  final success = await widget.onComment(
                    text,
                    media,
                    replyTo: replyTo,
                    parentCommentId: parentCommentId,
                  );

                  if (success) {
                    _fetchComments();
                  } else {
                    // Rollback if failed
                    _fetchComments();
                  }
                },
                replyTo: _isReplyingTo,
                replyingToCommentId: _replyingToCommentId,
                onCancelReply: () => setState(() {
                  _isReplyingTo = null;
                  _replyingToCommentId = null;
                }),
              ),
            ],
          ),
        ),
        if (_isMenuVisible)
          Positioned(
            top: 60,
            right: 16,
            child: Material(
              color: Colors.transparent,
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.15),
                      blurRadius: 16,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    GestureDetector(
                      onTap: () {
                        setState(() => _isMenuVisible = false);
                        widget.onEdit();
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.edit_outlined,
                              color: Colors.black54,
                              size: 20,
                            ),
                            const SizedBox(width: 12),
                            Text(
                              'Chỉnh sửa',
                              style: TextStyle(
                                color: Colors.grey.shade900,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    Container(height: 1, color: Colors.grey.shade100),
                    GestureDetector(
                      onTap: () {
                        setState(() => _isMenuVisible = false);
                        widget.onDelete();
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.delete_outline,
                              color: Colors.red,
                              size: 20,
                            ),
                            const SizedBox(width: 12),
                            const Text(
                              'Xóa bài viết',
                              style: TextStyle(
                                color: Colors.red,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildMediaGrid(List<dynamic> items) {
    if (items.isEmpty) return const SizedBox.shrink();
    if (items.length == 1) {
      return _buildMediaItem(items[0], single: true);
    }
    return SizedBox(
      height: 250,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(child: _buildMediaItem(items[0], height: 250)),
          const SizedBox(width: 2),
          Expanded(
            child: Column(
              children: [
                Expanded(child: _buildMediaItem(items[1], height: 124)),
                if (items.length > 2) ...[
                  const SizedBox(height: 2),
                  Expanded(
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        _buildMediaItem(items[2], height: 124),
                        if (items.length > 3)
                          Container(
                            color: Colors.black45,
                            child: Center(
                              child: Text(
                                "+${items.length - 2}",
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMediaItem(dynamic item, {bool single = false, double? height}) {
    final String url =
        (item["url"] ?? item["videoUrl"] ?? item["mediaPath"] ?? "").toString();
    if (url.isEmpty) return const SizedBox.shrink();

    final String type = (item["type"] ?? "image").toString();
    final bool isVideo =
        type == "video" ||
        url.toLowerCase().endsWith(".mp4") ||
        url.toLowerCase().endsWith(".mov");

    final bool isNet = url.startsWith('http') || !File(url).existsSync();

    return GestureDetector(
      onTap: () => _showFullImage(url),
      child: Container(
        width: double.infinity,
        height: height ?? (single ? null : 250),
        constraints: single
            ? const BoxConstraints(minHeight: 200, maxHeight: 800)
            : null,
        child: Hero(
          tag: "post_${widget.postIndex}_$url",
          child: isVideo
              ? (isNet
                    ? VideoPreview(videoUrl: ApiService.resolveImageUrl(url))
                    : VideoPreview(file: File(url)))
              : (isNet
                    ? CachedNetworkImage(
                        imageUrl: ApiService.resolveImageUrl(url),
                        fit: single ? BoxFit.fitWidth : BoxFit.cover,
                        alignment: Alignment.topCenter,
                        placeholder: (context, url) =>
                            Container(color: Colors.grey.shade200),
                        errorWidget: (context, url, error) => const Center(
                          child: Icon(Icons.broken_image, color: Colors.grey),
                        ),
                      )
                    : Image.file(
                        File(url),
                        fit: single ? BoxFit.fitWidth : BoxFit.cover,
                        alignment: Alignment.topCenter,
                      )),
        ),
      ),
    );
  }
}

class _CommentTile extends StatelessWidget {
  final Map<String, dynamic> comment;
  final VoidCallback onLike;
  final VoidCallback onReply;
  final List<Map<String, dynamic>> replies;
  final Function(int) onReplyLike;
  final Function(String) onReplyReply;

  const _CommentTile({
    required this.comment,
    required this.onLike,
    required this.onReply,
    required this.replies,
    required this.onReplyLike,
    required this.onReplyReply,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          FutureBuilder<Map<String, String>>(
            future: ApiService.getAuthHeaders(),
            builder: (context, headers) {
              final String? avatarId =
                  (comment["authorAvatar"] ??
                          comment["profilePicture"] ??
                          (comment["author"] is Map
                              ? comment["author"]["profilePicture"]
                              : null) ??
                          comment["author"])
                      ?.toString();
              return CircleAvatar(
                radius: 14,
                backgroundColor: Colors.blueGrey.shade100,
                backgroundImage: avatarId != null
                    ? NetworkImage(
                        ApiService.resolveImageUrl(avatarId),
                        headers: headers.data,
                      )
                    : null,
                child: avatarId == null
                    ? const Icon(Icons.person, size: 18)
                    : null,
              );
            },
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Comment bubble
                _CommentBubble(comment: comment),
                if (comment["mediaPath"] != null)
                  Builder(
                    builder: (context) {
                      final String path = comment["mediaPath"].toString();
                      return Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: GestureDetector(
                          onTap: () {
                            final String resolved =
                                (path.startsWith('http') ||
                                    path.startsWith('/'))
                                ? ApiService.resolveUrl(path)
                                : path;
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => FullScreenMediaViewer(
                                  mediaList: [resolved],
                                  initialIndex: 0,
                                ),
                              ),
                            );
                          },
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Hero(
                              tag: path,
                              child: (() {
                                final bool isVideo =
                                    path.toLowerCase().endsWith('.mp4') ||
                                    path.toLowerCase().endsWith('.mov');
                                final bool isNet =
                                    path.startsWith('http') ||
                                    !File(path).existsSync();

                                if (isVideo) {
                                  return SizedBox(
                                    width: 120,
                                    height: 120,
                                    child: isNet
                                        ? VideoPreview(
                                            videoUrl: ApiService.resolveUrl(
                                              path,
                                            ),
                                          )
                                        : VideoPreview(file: File(path)),
                                  );
                                } else {
                                  return isNet
                                      ? CachedNetworkImage(
                                          imageUrl: ApiService.resolveUrl(path),
                                          height: 120,
                                          width: 120,
                                          fit: BoxFit.cover,
                                          placeholder: (context, url) =>
                                              Container(
                                                color: Colors.grey.shade200,
                                              ),
                                          errorWidget: (context, url, error) =>
                                              const Center(
                                                child: Icon(
                                                  Icons.broken_image,
                                                  color: Colors.grey,
                                                ),
                                              ),
                                        )
                                      : Image.file(
                                          File(path),
                                          height: 120,
                                          width: 120,
                                          fit: BoxFit.cover,
                                        );
                                }
                              })(),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                const SizedBox(height: 4),
                // Action row
                _CommentActions(
                  time: formatTime(
                    comment["time"] ??
                        comment["createdAt"] ??
                        comment["created_at"],
                  ),
                  likes: int.tryParse(comment["likes"]?.toString() ?? "0") ?? 0,
                  isLiked: comment["isLiked"] == true,
                  onLike: onLike,
                  onReply: onReply,
                  reactions: comment["reactions"] as List<dynamic>?,
                ),
                // Replies (threaded)
                if (replies.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Vertical connector line
                        Container(
                          width: 30,
                          alignment: Alignment.topCenter,
                          padding: const EdgeInsets.only(top: 0),
                          child: Container(
                            width: 2,
                            height: 40,
                            decoration: BoxDecoration(
                              color: Colors.blueGrey.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                        ),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: replies.asMap().entries.map((re) {
                              final ri = re.key;
                              final reply = re.value;
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 10),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    FutureBuilder<Map<String, String>>(
                                      future: ApiService.getAuthHeaders(),
                                      builder: (context, headers) {
                                        final String? rAvatar =
                                            (reply["authorAvatar"] ??
                                                    reply["profilePicture"] ??
                                                    (reply["author"] is Map
                                                        ? reply["author"]["profilePicture"]
                                                        : null) ??
                                                    reply["author"])
                                                ?.toString();
                                        return CircleAvatar(
                                          radius: 12,
                                          backgroundColor:
                                              Colors.blueGrey.shade100,
                                          backgroundImage: rAvatar != null
                                              ? NetworkImage(
                                                  ApiService.resolveImageUrl(
                                                    rAvatar,
                                                  ),
                                                  headers: headers.data,
                                                )
                                              : null,
                                          child: rAvatar == null
                                              ? const Icon(
                                                  Icons.person,
                                                  size: 15,
                                                )
                                              : null,
                                        );
                                      },
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          _CommentBubble(
                                            comment: reply,
                                            small: true,
                                          ),
                                          const SizedBox(height: 3),
                                          _CommentActions(
                                            time: formatTime(
                                              reply["time"] ??
                                                  reply["createdAt"] ??
                                                  reply["created_at"],
                                            ),
                                            likes: reply["likes"] is int
                                                ? reply["likes"]
                                                : 0,
                                            isLiked: reply["isLiked"] == true,
                                            onLike: () => onReplyLike(ri),
                                            onReply: () {
                                              final dynamic author =
                                                  reply["author"];
                                              final String name =
                                                  (author is Map
                                                          ? (author["fullName"] ??
                                                                author["name"])
                                                          : author)
                                                      ?.toString() ??
                                                  "Người dùng";
                                              onReplyReply(name);
                                            },
                                            reactions:
                                                reply["reactions"]
                                                    as List<dynamic>?,
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
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CommentBubble extends StatelessWidget {
  final Map<String, dynamic> comment;
  final bool small;
  const _CommentBubble({required this.comment, this.small = false});

  @override
  Widget build(BuildContext context) {
    final reactions = comment['reactions'] as List<dynamic>?;
    final int likeCount = reactions != null
        ? reactions.where((r) {
            final String? actionType =
                r['type']?.toString() ?? r['reactionType']?.toString();
            return actionType == 'like';
          }).length
        : int.tryParse(comment['likes']?.toString() ?? '0') ?? 0;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          decoration: BoxDecoration(
            color: const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                (comment["author"] is Map
                            ? (comment["author"]["fullName"] ??
                                  comment["author"]["name"])
                            : comment["author"])
                        ?.toString() ??
                    "Người dùng",
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                  fontSize: small ? 11 : 12,
                ),
              ),
              if (comment["text"]?.toString().isNotEmpty == true)
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: MentionText(
                    text: (comment["text"]?.toString() ?? "").replaceAll(
                      RegExp(r' +'),
                      ' ',
                    ),
                    textAlign: TextAlign.left,
                    style: TextStyle(
                      fontSize: small ? 12 : 13,
                      color: Colors.black87,
                    ),
                  ),
                ),
            ],
          ),
        ),
        if (likeCount > 0)
          Positioned(
            bottom: -8,
            right: -8,
            child: IgnorePointer(
              ignoring: true,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.thumb_up, color: Colors.blue, size: 10),
                    const SizedBox(width: 2),
                    Text(
                      likeCount.toString(),
                      style: const TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                        color: Colors.black54,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _CommentActions extends StatelessWidget {
  final String time;
  final int likes;
  final bool isLiked;
  final VoidCallback onLike;
  final VoidCallback onReply;
  final List<dynamic>? reactions;

  const _CommentActions({
    required this.time,
    required this.likes,
    required this.isLiked,
    required this.onLike,
    required this.onReply,
    this.reactions,
  });

  @override
  Widget build(BuildContext context) {
    // Count reactions by type
    final int totalReactions = reactions?.length ?? likes;
    final int likeCount = reactions != null
        ? reactions!.where((r) {
            final String? actionType =
                r['type']?.toString() ?? r['reactionType']?.toString();
            return actionType == 'like';
          }).length
        : likes;
    final currentUserId =
        (AuthService().userProfile.value?['_id'] ??
                AuthService().userProfile.value?['id'])
            ?.toString();
    final bool likedByReaction =
        reactions?.any((r) {
          final String? actionType =
              r['type']?.toString() ?? r['reactionType']?.toString();
          if (actionType != 'like') return false;
          final user = r['user'];
          if (user == null) return false;
          if (user is String) return user == currentUserId;
          if (user is Map) {
            return (user['_id']?.toString() == currentUserId ||
                user['id']?.toString() == currentUserId);
          }
          return false;
        }) ??
        false;
    final bool effectiveLiked = isLiked || likedByReaction;

    return Row(
      children: [
        const SizedBox(width: 8),
        Text(time, style: const TextStyle(color: Colors.grey, fontSize: 10)),
        const SizedBox(width: 14),
        Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: onLike,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              child: Text(
                "Thích",
                style: TextStyle(
                  color: effectiveLiked ? Colors.blue : Colors.blueGrey,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 14),
        GestureDetector(
          onTap: onReply,
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
    );
  }
}

class _QuickCommentInput extends StatefulWidget {
  final Function(String, String?, {String? replyTo, dynamic parentCommentId})
  onSubmit;
  final String? replyTo;
  final dynamic replyingToCommentId;
  final VoidCallback onCancelReply;
  final FocusNode? focusNode;
  const _QuickCommentInput({
    required this.onSubmit,
    this.replyTo,
    this.replyingToCommentId,
    required this.onCancelReply,
    this.focusNode,
  });
  @override
  State<_QuickCommentInput> createState() => _QuickCommentInputState();
}

class _QuickCommentInputState extends State<_QuickCommentInput> {
  final TextEditingController _controller = MentionTextEditingController();
  final ImagePicker _picker = ImagePicker();
  late final FocusNode _focusNode;
  String? _tempImagePath;
  bool _showEmoji = false;

  List<dynamic> _allUsers = [];
  List<dynamic> _filteredUsers = [];
  bool _showMentions = false;
  int _mentionSelectedIndex = 0;
  int _mentionQueryIndex = -1;

  @override
  void didUpdateWidget(covariant _QuickCommentInput oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.replyTo != oldWidget.replyTo && widget.replyTo != null) {
      final mentionText = '@${widget.replyTo} ';
      if (_controller.text.trim().isEmpty ||
          !_controller.text.startsWith(mentionText)) {
        _controller.text = mentionText;
        _controller.selection = TextSelection.collapsed(
          offset: _controller.text.length,
        );
      }
      _focusNode.requestFocus();
    }
  }

  @override
  void initState() {
    super.initState();
    _focusNode = widget.focusNode ?? FocusNode();
    _focusNode.addListener(() {
      if (_focusNode.hasFocus) setState(() => _showEmoji = false);
    });
    _controller.addListener(_onTextChanged);
    _loadUsers();
    if (widget.replyTo != null) {
      final mentionText = '@${widget.replyTo} ';
      _controller.text = mentionText;
      _controller.selection = TextSelection.collapsed(
        offset: _controller.text.length,
      );
    }
  }

  @override
  void dispose() {
    _controller.removeListener(_onTextChanged);
    _controller.dispose();
    if (widget.focusNode == null) {
      _focusNode.dispose();
    }
    super.dispose();
  }

  Future<void> _loadUsers() async {
    final users = await ApiService.getUsers();
    if (mounted) {
      setState(() => _allUsers = users);
    }
  }

  void _onTextChanged() {
    final text = _controller.text;
    final selection = _controller.selection;

    if (selection.start != selection.end || selection.start < 0) {
      if (_showMentions) setState(() => _showMentions = false);
      return;
    }

    final cursorPosition = selection.start;
    final textBeforeCursor = text.substring(0, cursorPosition);

    final lastAt = textBeforeCursor.lastIndexOf('@');
    if (lastAt != -1) {
      final query = textBeforeCursor.substring(lastAt + 1);
      // Only show if there's no space between @ and cursor
      if (!query.contains(' ') && !query.contains('\n')) {
        final filtered = _allUsers.where((u) {
          final name = (u['fullName'] ?? u['name'] ?? '')
              .toString()
              .toLowerCase();
          return name.contains(query.toLowerCase());
        }).toList();

        setState(() {
          _filteredUsers = filtered;
          _showMentions = filtered.isNotEmpty;
          _mentionSelectedIndex = 0;
          _mentionQueryIndex = lastAt;
        });
        return;
      }
    }

    if (_showMentions) {
      setState(() {
        _showMentions = false;
      });
    }
  }

  void _insertMention(Map<String, dynamic> user) {
    final name = (user['fullName'] ?? user['name'] ?? '').toString();
    final text = _controller.text;
    final before = text.substring(0, _mentionQueryIndex);
    final after = text.substring(_controller.selection.end);

    final newText = "$before@$name\u200B $after";
    _controller.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(
        offset: before.length + name.length + 2,
      ),
    );
    setState(() {
      _showMentions = false;
    });
    _focusNode.requestFocus();
  }

  Future<void> _pickImage(ImageSource source) async {
    final XFile? file = await _picker.pickImage(source: source);
    if (file != null) setState(() => _tempImagePath = file.path);
  }

  void _insertEmoji(String emoji) {
    final text = _controller.text;
    final selection = _controller.selection;
    int start = selection.start;
    if (start < 0) start = text.length;
    final newText = text.replaceRange(
      start,
      selection.end < 0 ? start : selection.end,
      emoji,
    );
    setState(() {
      _controller.text = newText;
      _controller.selection = TextSelection.fromPosition(
        TextPosition(offset: start + emoji.length),
      );
    });
  }

  void _toggleEmoji() {
    if (_showEmoji) {
      _focusNode.requestFocus();
    } else {
      _focusNode.unfocus();
    }
    setState(() => _showEmoji = !_showEmoji);
  }

  void _submit() {
    if (_controller.text.trim().isNotEmpty || _tempImagePath != null) {
      widget.onSubmit(
        _controller.text,
        _tempImagePath,
        replyTo: widget.replyTo,
        parentCommentId: widget.replyingToCommentId,
      );
      _controller.clear();
      setState(() {
        _tempImagePath = null;
        _showEmoji = false;
      });
      widget.onCancelReply();
      FocusScope.of(context).unfocus();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        if (_showMentions && _filteredUsers.isNotEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: MentionSuggestionsOverlay(
              suggestions: _filteredUsers,
              selectedIndex: _mentionSelectedIndex,
              onSelect: _insertMention,
              themeColor: const Color(0xFF3B82F6),
            ),
          ),
        if (widget.replyTo != null)
          _ReplyBanner(name: widget.replyTo!, onCancel: widget.onCancelReply),
        if (_tempImagePath != null)
          Padding(
            padding: const EdgeInsets.all(16),
            child: Stack(
              children: [
                Container(
                  height: 100,
                  width: 100,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.file(File(_tempImagePath!), fit: BoxFit.cover),
                  ),
                ),
                Positioned(
                  top: 4,
                  right: 4,
                  child: GestureDetector(
                    onTap: () => setState(() => _tempImagePath = null),
                    child: const CircleAvatar(
                      radius: 10,
                      backgroundColor: Colors.red,
                      child: Icon(Icons.close, size: 12, color: Colors.white),
                    ),
                  ),
                ),
              ],
            ),
          ),
        Padding(
          key: const ValueKey("comment_input_row"),
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
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
                        radius: 16,
                        backgroundColor: Colors.blueGrey.shade100,
                        backgroundImage: avatarId != null
                            ? NetworkImage(
                                ApiService.resolveImageUrl(avatarId),
                                headers: headers.data,
                              )
                            : null,
                        child: avatarId == null
                            ? const Icon(Icons.person, size: 20)
                            : null,
                      );
                    },
                  );
                },
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Focus(
                          onKeyEvent: (FocusNode node, KeyEvent event) {
                            if (event is KeyDownEvent ||
                                event is KeyRepeatEvent) {
                              if (_showMentions) {
                                if (event.logicalKey ==
                                    LogicalKeyboardKey.arrowDown) {
                                  setState(() {
                                    _mentionSelectedIndex =
                                        (_mentionSelectedIndex + 1) %
                                        _filteredUsers.length;
                                  });
                                  return KeyEventResult.handled;
                                } else if (event.logicalKey ==
                                    LogicalKeyboardKey.arrowUp) {
                                  setState(() {
                                    _mentionSelectedIndex =
                                        (_mentionSelectedIndex -
                                            1 +
                                            _filteredUsers.length) %
                                        _filteredUsers.length;
                                  });
                                  return KeyEventResult.handled;
                                } else if (event.logicalKey ==
                                        LogicalKeyboardKey.enter ||
                                    event.logicalKey ==
                                        LogicalKeyboardKey.numpadEnter) {
                                  _insertMention(
                                    _filteredUsers[_mentionSelectedIndex],
                                  );
                                  return KeyEventResult.handled;
                                } else if (event.logicalKey ==
                                    LogicalKeyboardKey.escape) {
                                  setState(() => _showMentions = false);
                                  return KeyEventResult.handled;
                                }
                              }
                            }
                            return KeyEventResult.ignored;
                          },
                          child: TextField(
                            controller: _controller,
                            focusNode: _focusNode,
                            cursorColor: Colors.black87,
                            style: const TextStyle(
                              color: Colors.black87,
                              fontSize: 13,
                            ),
                            onSubmitted: (_) => _submit(),
                            decoration: const InputDecoration(
                              hintText: "Viết bình luận...",
                              border: InputBorder.none,
                              hintStyle: TextStyle(
                                color: Colors.grey,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ),
                      ),
                      GestureDetector(
                        onTap: _toggleEmoji,
                        child: Icon(
                          _showEmoji
                              ? Icons.keyboard
                              : Icons.emoji_emotions_outlined,
                          size: 20,
                          color: _showEmoji ? Colors.blue : Colors.blueGrey,
                        ),
                      ),
                      const SizedBox(width: 8),
                      GestureDetector(
                        onTap: () => _pickImage(ImageSource.gallery),
                        child: Icon(
                          Icons.camera_alt_outlined,
                          size: 20,
                          color: _tempImagePath != null
                              ? Colors.blue
                              : Colors.blueGrey,
                        ),
                      ),
                      const SizedBox(width: 8),
                      GestureDetector(
                        onTap: _submit,
                        child: const Icon(
                          Icons.send,
                          size: 20,
                          color: Color(0xFF3B82F6),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        if (_showEmoji) _EmojiGrid(onSelected: _insertEmoji, height: 200),
      ],
    );
  }
}

class _ReplyBanner extends StatelessWidget {
  final String name;
  final VoidCallback onCancel;
  const _ReplyBanner({required this.name, required this.onCancel});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: Colors.blue.withOpacity(0.05),
      child: Row(
        children: [
          const Icon(Icons.reply, size: 14, color: Colors.blue),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              "Đang phản hồi bài viết của $name...",
              style: const TextStyle(
                color: Colors.blue,
                fontSize: 11,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          GestureDetector(
            onTap: onCancel,
            child: const Icon(Icons.close, size: 14, color: Colors.blueGrey),
          ),
        ],
      ),
    );
  }
}

class _PostHeader extends StatelessWidget {
  final String author;
  final String? authorId;
  final String? avatar;
  final String role;
  final String time;
  final VoidCallback onDelete;
  final VoidCallback onEdit;
  final VoidCallback onToggleMenu;

  const _PostHeader({
    Key? key,
    required this.author,
    this.authorId,
    this.avatar,
    required this.role,
    required this.time,
    required this.onDelete,
    required this.onEdit,
    required this.onToggleMenu,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final currentUserId =
        AuthService().userProfile.value?['_id']?.toString() ??
        AuthService().userProfile.value?['id']?.toString();
    final isOwner =
        authorId != null && currentUserId != null && authorId == currentUserId;

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          FutureBuilder<Map<String, String>>(
            future: ApiService.getAuthHeaders(),
            builder: (context, headers) {
              return CircleAvatar(
                radius: 20,
                backgroundColor: Colors.blueGrey.shade100,
                backgroundImage: avatar != null
                    ? NetworkImage(
                        ApiService.resolveImageUrl(avatar),
                        headers: headers.data,
                      )
                    : null,
                child: avatar == null ? const Icon(Icons.person) : null,
              );
            },
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  author,
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  "$role . $time",
                  style: const TextStyle(
                    color: Colors.grey,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          if (isOwner)
            IconButton(
              icon: const Icon(Icons.more_horiz, color: Colors.grey),
              onPressed: onToggleMenu,
            ),
        ],
      ),
    );
  }
}

class _PostEngagement extends StatelessWidget {
  final int likes;
  final int comments;
  const _PostEngagement({required this.likes, required this.comments});
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(4),
                decoration: const BoxDecoration(
                  color: Colors.red,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.favorite,
                  color: Colors.white,
                  size: 10,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                likes > 0 ? "$likes" : "0",
                style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
              ),
              const SizedBox(width: 4),
              Text(
                "cảm xúc",
                style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
              ),
            ],
          ),
          Text(
            "$comments BÌNH LUẬN",
            style: TextStyle(
              color: Colors.grey.shade600,
              fontSize: 11,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}

class _PostActions extends StatelessWidget {
  final bool isLiked;
  final VoidCallback onLike;
  final VoidCallback onCommentTap;
  const _PostActions({
    required this.isLiked,
    required this.onLike,
    required this.onCommentTap,
  });
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          _ActionButton(
            icon: isLiked ? Icons.thumb_up : Icons.thumb_up_alt_outlined,
            label: "THÍCH",
            color: isLiked ? Colors.blue : Colors.blueGrey,
            onTap: onLike,
          ),
          _ActionButton(
            icon: Icons.chat_bubble_outline,
            label: "BÌNH LUẬN",
            color: Colors.blueGrey,
            onTap: onCommentTap,
          ),
          _ActionButton(
            icon: Icons.share_outlined,
            label: "CHIA SẺ",
            color: Colors.blueGrey,
            onTap: () {},
          ),
        ],
      ),
    );
  }
}

class _HeroBanner extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF5D5FEF), Color(0xFF3B82F6)],
        ),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ValueListenableBuilder<Map<String, dynamic>?>(
            valueListenable: AuthService().userProfile,
            builder: (context, profile, _) {
              final String fullName =
                  profile?['fullName'] ?? profile?['name'] ?? 'Bạn hiện tại';
              final String firstName = fullName.split(' ').last;

              return Row(
                children: [
                  Text(
                    "Chào mừng trở lại, ",
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    firstName,
                    style: const TextStyle(
                      color: Colors.amber,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Text("👋", style: TextStyle(fontSize: 18)),
                ],
              );
            },
          ),
          const SizedBox(height: 12),
          const Text(
            "Kết nối và cộng tác cùng đồng nghiệp.",
            style: TextStyle(color: Colors.white70, fontSize: 13),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text(
                  "USER",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _ActionButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });
  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 18, color: color),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: color,
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AuthorHeader extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<Map<String, dynamic>?>(
      valueListenable: AuthService().userProfile,
      builder: (context, profile, _) {
        final String? avatarId = profile?['profilePicture'];
        final String name =
            profile?['fullName'] ?? profile?['name'] ?? 'Người dùng';

        return Row(
          children: [
            FutureBuilder<Map<String, String>>(
              future: ApiService.getAuthHeaders(),
              builder: (context, headers) {
                return CircleAvatar(
                  backgroundColor: Colors.blueGrey.shade100,
                  backgroundImage: avatarId != null
                      ? NetworkImage(
                          ApiService.resolveImageUrl(avatarId),
                          headers: headers.data,
                        )
                      : null,
                  child: avatarId == null ? const Icon(Icons.person) : null,
                );
              },
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                Container(
                  margin: const EdgeInsets.only(top: 4),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Text(
                    "Công khai",
                    style: TextStyle(
                      color: Colors.blue,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );
  }
}

class _PostBackgroundSelector extends StatelessWidget {
  final dynamic selectedBackground;
  final Function(dynamic) onSelect;

  final List<dynamic> backgrounds = [
    null, // No background
    ...PostBackgroundHelper.backgrounds,
  ];

  _PostBackgroundSelector({
    required this.selectedBackground,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "Màu nền bài đăng",
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 13,
            color: Colors.blueGrey,
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 32,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: backgrounds.length,
            separatorBuilder: (_, __) => const SizedBox(width: 10),
            itemBuilder: (context, index) {
              final bg = backgrounds[index];
              return GestureDetector(
                onTap: () => onSelect(bg),
                child: Container(
                  width: 32,
                  height: 32,
                  decoration: bg == null
                      ? BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: selectedBackground == null
                                ? Colors.blue
                                : Colors.grey.shade300,
                            width: 2,
                          ),
                        )
                      : PostBackgroundHelper.getDecoration(bg).copyWith(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: selectedBackground == bg
                                ? Colors.blue
                                : Colors.grey.shade300,
                            width: 2,
                          ),
                        ),
                  child: bg == null
                      ? const Center(
                          child: Icon(
                            Icons.close,
                            size: 16,
                            color: Colors.grey,
                          ),
                        )
                      : null,
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _BuildMediaAttachmentsTool extends StatelessWidget {
  final VoidCallback onImage;
  final VoidCallback onCamera;
  final VoidCallback onEmoji;
  const _BuildMediaAttachmentsTool({
    required this.onImage,
    required this.onCamera,
    required this.onEmoji,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          const Text(
            "Thêm vào bài viết",
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
          ),
          const Spacer(),
          GestureDetector(
            onTap: onImage,
            child: const Icon(Icons.image, color: Colors.green),
          ),
          const SizedBox(width: 16),
          GestureDetector(
            onTap: onCamera,
            child: const Icon(Icons.video_collection, color: Colors.red),
          ),
          const SizedBox(width: 16),
          GestureDetector(
            onTap: onEmoji,
            child: const Icon(
              Icons.emoji_emotions_outlined,
              color: Colors.amber,
            ),
          ),
        ],
      ),
    );
  }
}

class _MomentsSection extends StatelessWidget {
  final VoidCallback onAddTap;
  final Function(int)? onNavigateToReels;
  final List<dynamic> reels;
  const _MomentsSection({
    required this.onAddTap,
    this.onNavigateToReels,
    required this.reels,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 24, 16, 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  Icon(
                    Icons.video_call_outlined,
                    color: Colors.indigo,
                    size: 24,
                  ),
                  SizedBox(width: 8),
                  Text(
                    "KHOẢNH KHẮC",
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                ],
              ),
              Text(
                "XEM TẤT CẢ >",
                style: TextStyle(
                  color: Colors.blue.shade700,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
        SizedBox(
          height: 180,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            children: [
              _MomentCard(isAdd: true, onAddTap: onAddTap),
              if (reels.isEmpty)
                Container(
                  width: MediaQuery.of(context).size.width - 160,
                  alignment: Alignment.center,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.video_library_outlined,
                        color: Colors.grey.shade300,
                        size: 40,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        "Chưa có khoảnh khắc nào",
                        style: TextStyle(
                          color: Colors.grey.shade500,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                )
              else
                ...reels.asMap().entries.map((entry) {
                  final int idx = entry.key;
                  final reel = entry.value;
                  final author = reel['author'] is Map ? reel['author'] : null;
                  String? displayName = author?['fullName'];
                  if (displayName != null && displayName.trim().contains(' ')) {
                    displayName = displayName.trim().split(' ').last;
                  }
                  return _MomentCard(
                    isAdd: false,
                    thumbnail:
                        reel["videoUrl"] ??
                        reel["videoPath"] ??
                        reel["video_path"] ??
                        reel["url"],
                    caption: reel["caption"],
                    authorName: displayName,
                    authorAvatar: author?['profilePicture'],
                    onTap: () => onNavigateToReels?.call(idx),
                  );
                }),
            ],
          ),
        ),
      ],
    );
  }
}

class _MomentCard extends StatelessWidget {
  final bool isAdd;
  final VoidCallback? onAddTap;
  final VoidCallback? onTap;
  final String? thumbnail;
  final String? caption;
  final String? authorName;
  final String? authorAvatar;

  const _MomentCard({
    this.isAdd = false,
    this.onAddTap,
    this.onTap,
    this.thumbnail,
    this.caption,
    this.authorName,
    this.authorAvatar,
  });

  @override
  Widget build(BuildContext context) {
    if (isAdd) {
      return Container(
        width: 110,
        margin: const EdgeInsets.only(right: 12),
        child: CustomPaint(
          painter: _DashedBorderPainter(
            color: Colors.blueGrey.withOpacity(0.4),
            radius: 16,
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: onAddTap,
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Stack(
                      clipBehavior: Clip.none,
                      children: [
                        ValueListenableBuilder<Map<String, dynamic>?>(
                          valueListenable: AuthService().userProfile,
                          builder: (context, profile, _) {
                            final String? avatarId = profile?['profilePicture'];
                            return FutureBuilder<Map<String, String>>(
                              future: ApiService.getAuthHeaders(),
                              builder: (context, headers) {
                                return CircleAvatar(
                                  radius: 22,
                                  backgroundColor: Colors.grey.shade700,
                                  backgroundImage: avatarId != null
                                      ? NetworkImage(
                                          ApiService.resolveImageUrl(avatarId),
                                          headers: headers.data,
                                        )
                                      : null,
                                  child: avatarId == null
                                      ? const Icon(
                                          Icons.person,
                                          color: Colors.white,
                                          size: 26,
                                        )
                                      : null,
                                );
                              },
                            );
                          },
                        ),
                        Positioned(
                          right: -4,
                          bottom: -4,
                          child: Container(
                            width: 22,
                            height: 22,
                            decoration: BoxDecoration(
                              color: const Color(0xFF3B82F6),
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 2),
                            ),
                            child: const Icon(
                              Icons.add,
                              color: Colors.white,
                              size: 14,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      "TẠO REEL",
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 11,
                        color: Color(0xFF0F172A),
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 2),
                    const Text(
                      "CHIA SẺ NGAY",
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 9,
                        color: Colors.blueGrey,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    }
    return GestureDetector(
      onTap: isAdd ? onAddTap : onTap,
      child: Container(
        width: 110,
        margin: const EdgeInsets.only(right: 12),
        decoration: BoxDecoration(
          color: const Color(0xFF1A1D2B),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white.withOpacity(0.05)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (thumbnail != null)
              FutureBuilder<Map<String, String>>(
                future: ApiService.getAuthHeaders(),
                builder: (context, headers) {
                  return CachedNetworkImage(
                    imageUrl: ApiService.resolveUrl(thumbnail!),
                    fit: BoxFit.cover,
                    httpHeaders: headers.data,
                    placeholder: (context, url) =>
                        Container(color: Colors.blueGrey.shade900),
                    errorWidget: (context, url, error) => Container(
                      color: Colors.blueGrey.shade900,
                      child: const Icon(Icons.videocam, color: Colors.white24),
                    ),
                  );
                },
              )
            else
              Container(color: Colors.blueGrey.shade900),
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.transparent, Colors.black.withOpacity(0.6)],
                ),
              ),
            ),
            Positioned(
              bottom: 8,
              left: 8,
              right: 8,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (authorName != null)
                    Row(
                      children: [
                        if (authorAvatar != null)
                          FutureBuilder<Map<String, String>>(
                            future: ApiService.getAuthHeaders(),
                            builder: (context, headers) => Container(
                              width: 14,
                              height: 14,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: Colors.white,
                                  width: 0.5,
                                ),
                              ),
                              child: ClipOval(
                                child: CachedNetworkImage(
                                  imageUrl: ApiService.resolveImageUrl(
                                    authorAvatar!,
                                  ),
                                  httpHeaders: headers.data,
                                  fit: BoxFit.cover,
                                  placeholder: (context, url) => Container(
                                    color: Colors.blueGrey.shade200,
                                  ),
                                  errorWidget: (context, url, error) =>
                                      const Icon(
                                        Icons.person,
                                        size: 8,
                                        color: Colors.white,
                                      ),
                                ),
                              ),
                            ),
                          ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            authorName!,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                              shadows: [
                                Shadow(color: Colors.black54, blurRadius: 2),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  const SizedBox(height: 2),
                  Text(
                    (caption ?? '').trim().isNotEmpty
                        ? caption!
                        : 'Khoảnh khắc mới',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 8.5,
                      fontWeight: FontWeight.w900,
                      shadows: [Shadow(color: Colors.black54, blurRadius: 2)],
                    ),
                  ),
                ],
              ),
            ),
            const Positioned(
              top: 8,
              right: 8,
              child: Icon(
                Icons.play_circle_fill,
                color: Colors.white70,
                size: 18,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DashedBorderPainter extends CustomPainter {
  final Color color;
  final double radius;

  _DashedBorderPainter({required this.color, required this.radius});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    final RRect rrect = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Radius.circular(radius),
    );

    Path path = Path()..addRRect(rrect);

    Path dashPath = Path();
    for (var pathMetric in path.computeMetrics()) {
      double distance = 0.0;
      while (distance < pathMetric.length) {
        dashPath.addPath(
          pathMetric.extractPath(distance, distance + 6),
          Offset.zero,
        );
        distance += 12;
      }
    }

    canvas.drawPath(dashPath, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class PostBackgroundHelper {
  static final List<String> backgrounds = [
    'linear-gradient(45deg, rgb(240, 147, 251) 0%, rgb(245, 87, 108) 100%)',
    'linear-gradient(to right, rgb(79, 172, 254) 0%, rgb(0, 242, 254) 100%)',
    'linear-gradient(120deg, rgb(132, 250, 176) 0%, rgb(143, 211, 244) 100%)',
    'linear-gradient(to top, rgb(207, 217, 223) 0%, rgb(226, 235, 240) 100%)',
    'rgb(26, 26, 26)',
    'rgb(37, 99, 235)',
    'linear-gradient(to right, rgb(250, 112, 154) 0%, rgb(254, 225, 64) 100%)',
  ];

  static BoxDecoration getDecoration(dynamic bg) {
    if (bg == null || bg == 'null' || bg == '') {
      return const BoxDecoration(color: Color(0xFF3B82F6));
    }

    if (bg is Color) return BoxDecoration(color: bg);
    if (bg is Gradient) return BoxDecoration(gradient: bg);

    final String b = bg.toString();

    // Mapping known strings to Flutter objects
    if (b.contains('240, 147, 251') && b.contains('245, 87, 108')) {
      return const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.bottomLeft,
          end: Alignment.topRight,
          colors: [Color(0xFFF093FB), Color(0xFFF5576C)],
        ),
      );
    }
    if (b.contains('79, 172, 254') && b.contains('0, 242, 254')) {
      return const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [Color(0xFF4FACFE), Color(0xFF00F2FE)],
        ),
      );
    }
    if (b.contains('132, 250, 176') && b.contains('143, 211, 244')) {
      return const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment(-0.5, -0.86),
          end: Alignment(0.5, 0.86),
          colors: [Color(0xFF84FAB0), Color(0xFF8FD3F4)],
        ),
      );
    }
    if (b.contains('207, 217, 223') && b.contains('226, 235, 240')) {
      return const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
          colors: [Color(0xFFCFD9DF), Color(0xFFE2EBF0)],
        ),
      );
    }
    if (b.contains('26, 26, 26')) {
      return const BoxDecoration(color: Color(0xFF1A1A1A));
    }
    if (b.contains('37, 99, 235')) {
      return const BoxDecoration(color: Color(0xFF2563EB));
    }
    if (b.contains('250, 112, 154') && b.contains('254, 225, 64')) {
      return const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [Color(0xFFFA709A), Color(0xFFFEE140)],
        ),
      );
    }

    // Default or Hex fallback
    if (b.startsWith('#')) {
      try {
        final String hex = b.replaceFirst('#', '');
        if (hex.length == 6) {
          return BoxDecoration(color: Color(int.parse('FF$hex', radix: 16)));
        } else if (hex.length == 8) {
          return BoxDecoration(color: Color(int.parse(hex, radix: 16)));
        }
      } catch (_) {}
    }

    return const BoxDecoration(color: Color(0xFF3B82F6));
  }
}

class _SmoothScrollController extends ScrollController {
  @override
  ScrollPosition createScrollPosition(
    ScrollPhysics physics,
    ScrollContext context,
    ScrollPosition? oldPosition,
  ) {
    return _SmoothScrollPosition(
      physics: physics,
      context: context,
      oldPosition: oldPosition,
    );
  }
}

class _SmoothScrollPosition extends ScrollPositionWithSingleContext {
  _SmoothScrollPosition({
    required super.physics,
    required super.context,
    super.oldPosition,
  });

  @override
  void pointerScroll(double delta) {
    // Smoother scrolling for news feed (0.6 multiplier)
    super.pointerScroll(delta * 0.6);
  }
}

class _SmoothScrollPhysics extends ClampingScrollPhysics {
  const _SmoothScrollPhysics({super.parent});

  @override
  _SmoothScrollPhysics applyTo(ScrollPhysics? ancestor) {
    return _SmoothScrollPhysics(parent: buildParent(ancestor));
  }
}
