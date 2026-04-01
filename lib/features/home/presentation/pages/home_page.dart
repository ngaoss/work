import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../../../core/api_service.dart';
import '../../../../core/security.dart';
import '../../../../core/widgets/full_screen_media_viewer.dart';
import '../../../../core/widgets/video_preview.dart';
import '../../../reels/presentation/pages/reels_page.dart';

class WorkHomePage extends StatefulWidget {
  final List<Map<String, dynamic>> reels;
  final Function(int)? onNavigateToReels;
  const WorkHomePage({super.key, this.onNavigateToReels, required this.reels});

  @override
  State<WorkHomePage> createState() => _WorkHomePageState();
}

class _WorkHomePageState extends State<WorkHomePage> {
  List<Map<String, dynamic>> _posts = [];
  bool _isPostsLoading = false;

  @override
  void initState() {
    super.initState();
    _fetchPosts();
  }

  Future<void> _fetchPosts() async {
    setState(() => _isPostsLoading = true);
    final posts = await ApiService.getPosts();
    debugPrint('HomePage: Fetched ${posts.length} posts');
    if (mounted) {
      setState(() {
        _posts = List<Map<String, dynamic>>.from(posts);
        _isPostsLoading = false;
      });
    }
  }

  void _addNewPost(String content, Color bgColor, String? mediaPath) async {
    final success = await ApiService.createPost({
      "content": content,
      "bgColor": bgColor.value.toString(),
      "mediaPath": mediaPath,
    });
    if (success && mounted) {
      _fetchPosts();
    }
  }

  void _toggleLike(int index) {
    setState(() {
      _posts[index]["isLiked"] = !(_posts[index]["isLiked"] as bool);
      if (_posts[index]["isLiked"]) {
        _posts[index]["likes"]++;
      } else {
        _posts[index]["likes"]--;
      }
    });
  }

  void _addComment(
    int postIndex,
    String text,
    String? mediaPath, {
    String? replyTo,
    int? parentCommentId,
  }) async {
    final success = await ApiService.addComment({
      "postId": _posts[postIndex]["id"],
      "text": text,
      "replyTo": replyTo,
      "parentId": parentCommentId,
    });
    if (success && mounted) {
      _fetchPosts();
    }
  }

  void _toggleCommentLike(int postIndex, int commentIndex) {
    setState(() {
      final comment = _posts[postIndex]["commentList"][commentIndex];
      comment["isLiked"] = !(comment["isLiked"] as bool);
      if (comment["isLiked"]) {
        comment["likes"]++;
      } else {
        comment["likes"]--;
      }
    });
  }

  void _toggleReplyLike(int postIndex, int commentIndex, int replyIndex) {
    setState(() {
      final reply =
          (_posts[postIndex]["commentList"][commentIndex]["replies"]
              as List<Map<String, dynamic>>)[replyIndex];
      reply["isLiked"] = !(reply["isLiked"] as bool);
      if (reply["isLiked"]) {
        reply["likes"]++;
      } else {
        reply["likes"]--;
      }
    });
  }

  void _deletePost(int index) {
    setState(() {
      _posts.removeAt(index);
    });
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text("Đã xóa bài viết")));
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
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _HeroBanner(),
            _StatusInput(onPostAdded: _addNewPost),
            _MomentsSection(
              onAddTap: _showCreateReelDialog,
              onNavigateToReels: widget.onNavigateToReels,
              reels: widget.reels,
            ),
            const SizedBox(height: 16),
            if (_isPostsLoading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 40),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_posts.isEmpty)
              Padding(
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
              )
            else
              ...List.generate(
                _posts.length,
                (index) => _PostCard(
                  post: _posts[index],
                  onLike: () => _toggleLike(index),
                  onDelete: () => _deletePost(index),
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
            const SizedBox(height: 100),
          ],
        ),
      ),
    );
  }
}

class _StatusInput extends StatelessWidget {
  final Function(String, Color, String?) onPostAdded;
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
                            ApiService.resolveAvatarUrl(avatarId),
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
  final Function(String, Color, String?) onPost;
  const _CreatePostSheet({required this.onPost});
  @override
  State<_CreatePostSheet> createState() => _CreatePostSheetState();
}

class _CreatePostSheetState extends State<_CreatePostSheet> {
  Color _selectedBgColor = const Color(0xFF3B82F6);
  final TextEditingController _contentController = TextEditingController();
  final ImagePicker _picker = ImagePicker();
  final FocusNode _focusNode = FocusNode();
  String? _mediaPath;
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
    final XFile? file = await _picker.pickImage(source: source);
    if (file != null) setState(() => _mediaPath = file.path);
  }

  Future<void> _pickVideo() async {
    final XFile? file = await _picker.pickVideo(source: ImageSource.gallery);
    if (file != null) setState(() => _mediaPath = file.path);
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
                    selectedColor: _selectedBgColor,
                    onSelect: (color) =>
                        setState(() => _selectedBgColor = color),
                  ),
                  const SizedBox(height: 16),
                  Stack(
                    children: [
                      Container(
                        height: 250,
                        decoration: BoxDecoration(
                          color: _selectedBgColor,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        padding: const EdgeInsets.all(24),
                        alignment: Alignment.center,
                        child: TextField(
                          controller: _contentController,
                          focusNode: _focusNode,
                          maxLines: null,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 24,
                            fontWeight: FontWeight.w900,
                          ),
                          decoration: const InputDecoration(
                            hintText: "Bạn đang nghĩ gì?",
                            border: InputBorder.none,
                            hintStyle: TextStyle(color: Colors.white70),
                          ),
                        ),
                      ),
                      if (_mediaPath != null)
                        Positioned(
                          bottom: 12,
                          right: 12,
                          child: Container(
                            width: 80,
                            height: 80,
                            decoration: BoxDecoration(
                              color: Colors.black26,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.white, width: 2),
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(10),
                              child:
                                  _mediaPath!.toLowerCase().endsWith('.mp4') ||
                                      _mediaPath!.toLowerCase().endsWith('.mov')
                                  ? VideoPreview(file: File(_mediaPath!))
                                  : Image.file(
                                      File(_mediaPath!),
                                      fit: BoxFit.cover,
                                    ),
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
                      _mediaPath != null) {
                    widget.onPost(
                      _contentController.text,
                      _selectedBgColor,
                      _mediaPath,
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
  final VoidCallback onLike;
  final VoidCallback onDelete;
  final Function(String, String?, {String? replyTo, int? parentCommentId})
  onComment;
  final Function(int) onToggleCommentLike;
  final Function(int, int) onToggleReplyLike;
  const _PostCard({
    required this.post,
    required this.onLike,
    required this.onDelete,
    required this.onComment,
    required this.onToggleCommentLike,
    required this.onToggleReplyLike,
  });

  @override
  State<_PostCard> createState() => _PostCardState();
}

class _PostCardState extends State<_PostCard> {
  String? _isReplyingTo;
  int? _replyingToCommentId;

  @override
  Widget build(BuildContext context) {
    final List<dynamic> commentsRaw =
        widget.post["commentList"] ?? widget.post["comments"] ?? [];
    final List<Map<String, dynamic>> comments = List<Map<String, dynamic>>.from(
      commentsRaw,
    );
    final String authorName = widget.post["author"] is Map
        ? widget.post["author"]["name"]
        : (widget.post["author"] ?? widget.post["user"] ?? "Người dùng");
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      color: Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _PostHeader(
            author: authorName,
            avatar:
                widget.post["author"]?["profilePicture"] ??
                (widget.post["user"]?["profilePicture"]),
            role: widget.post["role"] ?? widget.post["position"] ?? "",
            time: widget.post["time"] ?? widget.post["created_at"] ?? "",
            onDelete: widget.onDelete,
          ),
          if (widget.post["mediaPath"] != null)
            GestureDetector(
              onTap: () {
                final String mLink = ApiService.resolveUrl(
                  widget.post["mediaPath"],
                );
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => FullScreenMediaViewer(
                      mediaPath:
                          widget.post["mediaPath"].toString().startsWith('http')
                          ? widget.post["mediaPath"]
                          : mLink,
                    ),
                  ),
                );
              },
              child: SizedBox(
                width: double.infinity,
                height: 400, // Increased height for video/media
                child: Hero(
                  tag: widget.post["mediaPath"],
                  child: Builder(
                    builder: (context) {
                      final String rp = widget.post["mediaPath"].toString();
                      final bool isNet = rp.startsWith('http');
                      final String fP = isNet ? ApiService.resolveUrl(rp) : rp;
                      final String lP = fP.toLowerCase();
                      final bool isV =
                          lP.endsWith('.mp4') || lP.endsWith('.mov');

                      if (isV) {
                        return isNet
                            ? VideoPreview(videoUrl: fP)
                            : VideoPreview(file: File(rp));
                      } else {
                        return isNet
                            ? Image.network(
                                fP,
                                fit: BoxFit.cover,
                                errorBuilder: (c, e, s) => const Center(
                                  child: Icon(Icons.broken_image),
                                ),
                              )
                            : Image.file(File(rp), fit: BoxFit.cover);
                      }
                    },
                  ),
                ),
              ),
            )
          else
            Container(
              width: double.infinity,
              height: 250,
              color: widget.post["bgColor"],
              alignment: Alignment.center,
              padding: const EdgeInsets.all(32),
              child: Text(
                widget.post["content"] ??
                    widget.post["text"] ??
                    widget.post["body"] ??
                    "",
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),

          _PostEngagement(
            likes: widget.post["likes"] ?? 0,
            comments: comments.length,
          ),
          const Divider(height: 1),
          _PostActions(isLiked: widget.post["isLiked"], onLike: widget.onLike),
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
                  final replies =
                      (comment["replies"] as List<Map<String, dynamic>>?) ?? [];
                  return _CommentTile(
                    comment: comment,
                    onLike: () => widget.onToggleCommentLike(commentIdx),
                    onReply: () => setState(() {
                      _isReplyingTo = comment["author"];
                      _replyingToCommentId = comment["id"];
                    }),
                    replies: replies,
                    onReplyLike: (replyIdx) =>
                        widget.onToggleReplyLike(commentIdx, replyIdx),
                    onReplyReply: (replyAuthor) => setState(() {
                      _isReplyingTo = replyAuthor;
                      _replyingToCommentId = comment["id"];
                    }),
                  );
                }).toList(),
              ),
            ),

          _QuickCommentInput(
            onSubmit: (text, media, {replyTo, parentCommentId}) =>
                widget.onComment(
                  text,
                  media,
                  replyTo: replyTo,
                  parentCommentId: parentCommentId,
                ),
            replyTo: _isReplyingTo,
            replyingToCommentId: _replyingToCommentId,
            onCancelReply: () => setState(() {
              _isReplyingTo = null;
              _replyingToCommentId = null;
            }),
          ),
        ],
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
                  comment["authorAvatar"] ??
                  comment["profilePicture"] ??
                  (comment["author"] is Map
                      ? comment["author"]["profilePicture"]
                      : null);
              return CircleAvatar(
                radius: 14,
                backgroundColor: Colors.blueGrey.shade100,
                backgroundImage: avatarId != null
                    ? NetworkImage(
                        ApiService.resolveAvatarUrl(avatarId),
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
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: GestureDetector(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => FullScreenMediaViewer(
                              mediaPath: comment["mediaPath"],
                            ),
                          ),
                        );
                      },
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Hero(
                          tag: comment["mediaPath"],
                          child:
                              (comment["mediaPath"] as String)
                                      .toLowerCase()
                                      .endsWith('.mp4') ||
                                  (comment["mediaPath"] as String)
                                      .toLowerCase()
                                      .endsWith('.mov')
                              ? SizedBox(
                                  width: 120,
                                  height: 120,
                                  child: VideoPreview(
                                    file: File(comment["mediaPath"]),
                                  ),
                                )
                              : Image.file(
                                  File(comment["mediaPath"]),
                                  height: 120,
                                  width: 120,
                                  fit: BoxFit.cover,
                                ),
                        ),
                      ),
                    ),
                  ),
                const SizedBox(height: 4),
                // Action row
                _CommentActions(
                  time: comment["time"],
                  likes: comment["likes"],
                  isLiked: comment["isLiked"],
                  onLike: onLike,
                  onReply: onReply,
                ),
                // Replies (threaded)
                if (replies.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: IntrinsicHeight(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Vertical connector line
                          SizedBox(
                            width: 30,
                            child: Center(
                              child: Container(
                                width: 2,
                                decoration: BoxDecoration(
                                  color: Colors.blueGrey.withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(2),
                                ),
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
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      CircleAvatar(
                                        radius: 12,
                                        backgroundColor:
                                            Colors.blueGrey.shade100,
                                        child: const Icon(
                                          Icons.person,
                                          size: 15,
                                        ),
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
                                              time: reply["time"],
                                              likes: reply["likes"],
                                              isLiked: reply["isLiked"],
                                              onLike: () => onReplyLike(ri),
                                              onReply: () =>
                                                  onReplyReply(reply["author"]),
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
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            comment["author"],
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: small ? 11 : 12,
            ),
          ),
          if (comment["text"].toString().isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                comment["text"],
                style: TextStyle(fontSize: small ? 12 : 13),
              ),
            ),
        ],
      ),
    );
  }
}

class _CommentActions extends StatelessWidget {
  final String time;
  final int likes;
  final bool isLiked;
  final VoidCallback onLike;
  final VoidCallback onReply;
  const _CommentActions({
    required this.time,
    required this.likes,
    required this.isLiked,
    required this.onLike,
    required this.onReply,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const SizedBox(width: 8),
        Text(time, style: const TextStyle(color: Colors.grey, fontSize: 10)),
        const SizedBox(width: 14),
        GestureDetector(
          onTap: onLike,
          child: Text(
            "Thích${likes > 0 ? " ($likes)" : ""}",
            style: TextStyle(
              color: isLiked ? Colors.blue : Colors.blueGrey,
              fontSize: 10,
              fontWeight: FontWeight.bold,
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
  final Function(String, String?, {String? replyTo, int? parentCommentId})
  onSubmit;
  final String? replyTo;
  final int? replyingToCommentId;
  final VoidCallback onCancelReply;
  const _QuickCommentInput({
    required this.onSubmit,
    this.replyTo,
    this.replyingToCommentId,
    required this.onCancelReply,
  });
  @override
  State<_QuickCommentInput> createState() => _QuickCommentInputState();
}

class _QuickCommentInputState extends State<_QuickCommentInput> {
  final TextEditingController _controller = TextEditingController();
  final ImagePicker _picker = ImagePicker();
  final FocusNode _focusNode = FocusNode();
  String? _tempImagePath;
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
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
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
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Row(
            children: [
              CircleAvatar(
                radius: 14,
                backgroundColor: Colors.blueGrey.shade100,
                child: const Icon(Icons.person, size: 18),
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
                        child: TextField(
                          controller: _controller,
                          focusNode: _focusNode,
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
  final String? avatar;
  final String role;
  final String time;
  final VoidCallback onDelete;
  const _PostHeader({
    required this.author,
    this.avatar,
    required this.role,
    required this.time,
    required this.onDelete,
  });
  @override
  Widget build(BuildContext context) {
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
                        ApiService.resolveAvatarUrl(avatar),
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
                  "$role • $time",
                  style: const TextStyle(
                    color: Colors.grey,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.more_horiz, color: Colors.grey),
            onPressed: () => showModalBottomSheet(
              context: context,
              builder: (c) => Wrap(
                children: [
                  ListTile(
                    leading: const Icon(
                      Icons.delete_outline,
                      color: Colors.red,
                    ),
                    title: const Text(
                      "Xóa bài viết",
                      style: TextStyle(color: Colors.red),
                    ),
                    onTap: () {
                      onDelete();
                      Navigator.pop(c);
                    },
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
          Text(
            "$likes cảm xúc",
            style: const TextStyle(
              color: Colors.blueGrey,
              fontSize: 11,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            "$comments BÌNH LUẬN",
            style: const TextStyle(
              color: Colors.blueGrey,
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
  const _PostActions({required this.isLiked, required this.onLike});
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
            onTap: () {},
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
          Row(
            children: [
              const Text(
                "Chào mừng trở lại, ",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Text(
                "Long",
                style: TextStyle(
                  color: Colors.amber,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(width: 8),
              const Text("👋"),
            ],
          ),
          const SizedBox(height: 12),
          const Text(
            "Kết nối và cộng tác cùng đồng nghiệp.",
            style: TextStyle(color: Colors.white70, fontSize: 13),
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
                          ApiService.resolveAvatarUrl(avatarId),
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
  final Color selectedColor;
  final Function(Color) onSelect;
  final List<Color> colors = [
    const Color(0xFF3B82F6),
    const Color(0xFFEF4444),
    const Color(0xFF10B981),
    const Color(0xFF8B5CF6),
    const Color(0xFFF59E0B),
    const Color(0xFF0F172A),
  ];
  _PostBackgroundSelector({
    required this.selectedColor,
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
            itemCount: colors.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (context, index) => GestureDetector(
              onTap: () => onSelect(colors[index]),
              child: Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: colors[index],
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: selectedColor == colors[index]
                        ? Colors.blue
                        : Colors.grey.shade300,
                    width: 2,
                  ),
                ),
              ),
            ),
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
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.grey.shade800,
                          ),
                          child: const Icon(
                            Icons.person,
                            color: Colors.white,
                            size: 28,
                          ),
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
                  return Image.network(
                    ApiService.resolveUrl(thumbnail!),
                    fit: BoxFit.cover,
                    headers: headers.data,
                    errorBuilder: (ctx, err, stack) => Container(
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
                                child: Image.network(
                                  ApiService.resolveAvatarUrl(authorAvatar!),
                                  headers: headers.data,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) => const Icon(
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
