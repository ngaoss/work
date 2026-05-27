import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/api_service.dart';
import 'package:cached_network_image/cached_network_image.dart';

class MediaFilesLinksScreen extends StatefulWidget {
  final String conversationId;
  final String chatName;

  const MediaFilesLinksScreen({
    super.key,
    required this.conversationId,
    required this.chatName,
  });

  @override
  State<MediaFilesLinksScreen> createState() => _MediaFilesLinksScreenState();
}

class _MediaFilesLinksScreenState extends State<MediaFilesLinksScreen> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _allMessages = [];

  List<Map<String, dynamic>> _mediaMessages = [];
  List<Map<String, dynamic>> _fileMessages = [];
  List<Map<String, dynamic>> _linkMessages = [];

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<void> _fetchData() async {
    setState(() => _isLoading = true);
    try {
      final result = await ApiService.getMessages(
        widget.conversationId,
        limit: 100,
      );

      _allMessages = ApiService.extractList(
        result,
      ).cast<Map<String, dynamic>>();
      _filterMessages();
    } catch (e) {
      debugPrint("Error fetching media/files: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _filterMessages() {
    _mediaMessages = [];
    _fileMessages = [];
    _linkMessages = [];

    final urlRegex = RegExp(
      r'https?:\/\/(www\.)?[-a-zA-Z0-9@:%._\+~#=]{1,256}\.[a-zA-Z0-9()]{1,6}\b([-a-zA-Z0-9()@:%_\+.~#?&//=]*)',
      caseSensitive: false,
    );

    for (var msg in _allMessages) {
      if (msg["isRecalled"] == true || msg["status"] == "recalled") continue;

      final media = msg["media"] ?? msg["attachments"] ?? [];
      final imageUrl = msg["imageUrl"] ?? msg["image"];
      final text = msg["text"]?.toString() ?? "";

      String? imagePath;
      if (media is List && media.isNotEmpty) {
        imagePath = _extractMediaUrl(media, filterVisual: true);
      } else if (imageUrl != null) {
        final resolved = ApiService.resolveImageUrl(imageUrl);
        if (_isVisualUrl(resolved)) imagePath = resolved;
      }

      if (imagePath != null) {
        _mediaMessages.add({...msg, "displayPath": imagePath});
      }

      String? filePath;
      String? fileName;
      if (media is List && media.isNotEmpty) {
        fileName = _extractFileName(media);
        filePath = _extractMediaUrl(
          media,
          filterVisual: false,
          fileName: fileName,
        );
      }

      if (filePath != null && fileName != null && imagePath == null) {
        _fileMessages.add({
          ...msg,
          "displayPath": filePath,
          "displayName": fileName,
          "displaySize": _extractMediaSize(media),
        });
      }

      if (urlRegex.hasMatch(text)) {
        _linkMessages.add(msg);
      }
    }

    // Sort all by newest first (Top-to-bottom)
    int _comparator(Map<String, dynamic> a, Map<String, dynamic> b) {
      final tA =
          DateTime.tryParse(a["createdAt"]?.toString() ?? "") ?? DateTime(1970);
      final tB =
          DateTime.tryParse(b["createdAt"]?.toString() ?? "") ?? DateTime(1970);
      return tB.compareTo(tA);
    }

    _mediaMessages.sort(_comparator);
    _fileMessages.sort(_comparator);
    _linkMessages.sort(_comparator);
  }

  bool _isVisualUrl(String url) {
    if (url.isEmpty) return false;
    final lower = url.toLowerCase().trim();
    if (RegExp(
      r'\.(jpg|jpeg|png|gif|webp|mp4|mov|avi)(\?|$)',
    ).hasMatch(lower)) {
      return true;
    }
    if (lower.contains('/api/images/') || lower.contains('/images/')) {
      return true;
    }
    return false;
  }

  String? _extractMediaUrl(
    dynamic mediaList, {
    bool filterVisual = false,
    String? fileName,
  }) {
    if (mediaList is! List || mediaList.isEmpty) return null;
    final item = mediaList[0];
    String url = "";
    if (item is Map) {
      url = (item["url"] ?? item["fileUrl"] ?? item["path"] ?? "").toString();
      if (filterVisual) {
        final type = (item["type"] ?? "").toString().toLowerCase();
        if (type == "file") return null;
        if (type != "image" && type != "video") {
          if (!_isVisualUrl(url)) return null;
        }
      }
    } else if (item is String) {
      url = item;
      if (filterVisual && !_isVisualUrl(url)) return null;
    }

    if (url.isEmpty) return null;

    if (filterVisual) {
      return ApiService.resolveImageUrl(url);
    } else {
      return ApiService.resolveFileUrl(url, fileName: fileName);
    }
  }

  String? _extractFileName(dynamic mediaList) {
    if (mediaList is! List || mediaList.isEmpty) return null;
    final item = mediaList[0];
    if (item is Map) {
      final name = item["name"] ?? item["fileName"] ?? item["filename"];
      if (name != null && name.toString().isNotEmpty) return name.toString();
      final path = item["path"] ?? item["url"] ?? item["fileUrl"];
      if (path != null && path.toString().isNotEmpty) {
        final s = path.toString();
        if (s.contains('/')) return s.split('/').last;
        if (s.contains('\\')) return s.split('\\').last;
      }
      return "Tệp tin";
    }
    return "Tài liệu";
  }

  String? _extractMediaSize(dynamic mediaList) {
    if (mediaList is! List || mediaList.isEmpty) return null;
    final item = mediaList[0];
    if (item is Map && item["size"] != null) {
      final size = item["size"];
      if (size is int) return "${(size / 1024).round()} KB";
      if (size is String) return size;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        appBar: AppBar(
          backgroundColor: Theme.of(context).colorScheme.surface,
          elevation: 0,
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.chatName,
                style: const TextStyle(
                  color: Color(0xFF0F172A),
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Text(
                "Ảnh, File và Liên kết",
                style: TextStyle(
                  color: Colors.grey,
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          leading: IconButton(
            icon: Icon(
              Icons.arrow_back_ios_new,
              color: Theme.of(context).colorScheme.onSurface,
              size: 20,
            ),
            onPressed: () => Navigator.pop(context),
          ),
          bottom: const TabBar(
            labelColor: Color(0xFF3B82F6),
            unselectedLabelColor: Colors.grey,
            indicatorColor: Color(0xFF3B82F6),
            indicatorWeight: 3,
            labelStyle: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            tabs: [
              Tab(text: "PHƯƠNG TIỆN"),
              Tab(text: "FILE"),
              Tab(text: "LIÊN KẾT"),
            ],
          ),
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : TabBarView(
                children: [
                  _buildMediaGrid(),
                  _buildFileList(),
                  _buildLinkList(),
                ],
              ),
      ),
    );
  }

  Widget _buildMediaGrid() {
    if (_mediaMessages.isEmpty) {
      return _buildEmptyState(
        Icons.image_outlined,
        "Chưa có ảnh hoặc video nào",
      );
    }

    return GridView.builder(
      padding: const EdgeInsets.all(4),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 5, // Increased from 3 to shrink images
        crossAxisSpacing: 4,
        mainAxisSpacing: 4,
      ),
      itemCount: _mediaMessages.length,
      itemBuilder: (context, index) {
        final msg = _mediaMessages[index];
        final url = msg["displayPath"] ?? "";

        return GestureDetector(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => _PhotoViewerScreen(
                  imageUrls: _mediaMessages
                      .map((m) => m["displayPath"].toString())
                      .toList(),
                  initialIndex: index,
                ),
              ),
            );
          },
          child: Hero(
            tag: "media_$index",
            child: CachedNetworkImage(
              imageUrl: url,
              fit: BoxFit.cover,
              placeholder: (context, url) => Container(color: Colors.grey[200]),
              errorWidget: (context, url, error) => Container(
                color: Colors.grey[200],
                child: const Icon(Icons.error),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildFileList() {
    if (_fileMessages.isEmpty) {
      return _buildEmptyState(
        Icons.insert_drive_file_outlined,
        "Chưa có file nào",
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _fileMessages.length,
      itemBuilder: (context, index) {
        final msg = _fileMessages[index];
        final fileName = msg["displayName"] ?? "Tệp tin";
        final fileSize = msg["displaySize"] ?? "";
        final fileUrl = msg["displayPath"];

        return Card(
          elevation: 0,
          margin: const EdgeInsets.only(bottom: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: Colors.grey.shade200),
          ),
          child: ListTile(
            onTap: () async {
              if (fileUrl != null) {
                final fullUrl = ApiService.resolveFileUrl(
                  fileUrl,
                  fileName: fileName,
                );
                await launchUrl(
                  Uri.parse(fullUrl),
                  mode: LaunchMode.externalApplication,
                );
              }
            },
            leading: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                _getFileIcon(fileName),
                color: const Color(0xFF3B82F6),
              ),
            ),
            title: Text(
              fileName,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            subtitle: Text(
              fileSize,
              style: const TextStyle(fontSize: 11, color: Colors.grey),
            ),
            trailing: const Icon(
              Icons.download_rounded,
              size: 20,
              color: Colors.grey,
            ),
          ),
        );
      },
    );
  }

  Widget _buildLinkList() {
    if (_linkMessages.isEmpty) {
      return _buildEmptyState(Icons.link_outlined, "Chưa có liên kết nào");
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _linkMessages.length,
      itemBuilder: (context, index) {
        final msg = _linkMessages[index];
        final text = msg["text"]?.toString() ?? "";
        final urlRegex = RegExp(
          r'https?:\/\/(www\.)?[-a-zA-Z0-9@:%._\+~#=]{1,256}\.[a-zA-Z0-9()]{1,6}\b([-a-zA-Z0-9()@:%_\+.~#?&//=]*)',
        );
        final match = urlRegex.firstMatch(text);
        final url = match?.group(0) ?? "";

        return Card(
          elevation: 0,
          margin: const EdgeInsets.only(bottom: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: Colors.grey.shade200),
          ),
          child: ListTile(
            onTap: () async {
              if (url.isNotEmpty) await launchUrl(Uri.parse(url));
            },
            leading: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.link, color: Colors.orange),
            ),
            title: Text(
              url,
              style: const TextStyle(
                color: Color(0xFF3B82F6),
                fontSize: 13,
                decoration: TextDecoration.underline,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            subtitle: Text(
              text,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 12),
            ),
          ),
        );
      },
    );
  }

  Widget _buildEmptyState(IconData icon, String message) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 64, color: Colors.grey[300]),
          const SizedBox(height: 16),
          Text(
            message,
            style: const TextStyle(
              color: Colors.grey,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  IconData _getFileIcon(String fileName) {
    final ext = fileName.split('.').last.toLowerCase();
    switch (ext) {
      case 'pdf':
        return Icons.picture_as_pdf;
      case 'doc':
      case 'docx':
        return Icons.description;
      case 'xls':
      case 'xlsx':
        return Icons.table_chart;
      case 'txt':
        return Icons.text_snippet;
      case 'zip':
      case 'rar':
        return Icons.folder_zip;
      default:
        return Icons.insert_drive_file;
    }
  }
}

class _PhotoViewerScreen extends StatefulWidget {
  final List<String> imageUrls;
  final int initialIndex;

  const _PhotoViewerScreen({
    required this.imageUrls,
    required this.initialIndex,
  });

  @override
  State<_PhotoViewerScreen> createState() => _PhotoViewerScreenState();
}

class _PhotoViewerScreenState extends State<_PhotoViewerScreen> {
  late PageController _pageController;
  late int _currentIndex;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: widget.initialIndex);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text(
          "${_currentIndex + 1} / ${widget.imageUrls.length}",
          style: const TextStyle(color: Colors.white, fontSize: 16),
        ),
      ),
      body: Stack(
        children: [
          PageView.builder(
            controller: _pageController,
            itemCount: widget.imageUrls.length,
            onPageChanged: (index) => setState(() => _currentIndex = index),
            itemBuilder: (context, index) {
              return InteractiveViewer(
                minScale: 0.5,
                maxScale: 4.0,
                child: Center(
                  child: CachedNetworkImage(
                    imageUrl: widget.imageUrls[index],
                    placeholder: (context, url) =>
                        const Center(child: CircularProgressIndicator()),
                    errorWidget: (context, url, error) =>
                        const Icon(Icons.error, color: Colors.white),
                  ),
                ),
              );
            },
          ),
          // Nút bên trái
          if (_currentIndex > 0)
            Positioned(
              left: 10,
              top: 0,
              bottom: 0,
              child: Center(
                child: IconButton(
                  icon: const Icon(
                    Icons.arrow_back_ios,
                    color: Colors.white,
                    size: 30,
                  ),
                  onPressed: () {
                    _pageController.previousPage(
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeInOut,
                    );
                  },
                ),
              ),
            ),
          // Nút bên phải
          if (_currentIndex < widget.imageUrls.length - 1)
            Positioned(
              right: 10,
              top: 0,
              bottom: 0,
              child: Center(
                child: IconButton(
                  icon: const Icon(
                    Icons.arrow_forward_ios,
                    color: Colors.white,
                    size: 30,
                  ),
                  onPressed: () {
                    _pageController.nextPage(
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeInOut,
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
