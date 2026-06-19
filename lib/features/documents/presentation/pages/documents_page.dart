import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/api_service.dart';
import '../../../ocr/presentation/pages/ocr_page.dart';
import '../../../../core/widgets/global_error_wrapper.dart';

class DocumentsPage extends StatefulWidget {
  final bool isActive;
  const DocumentsPage({super.key, this.isActive = true});

  @override
  State<DocumentsPage> createState() => _DocumentsPageState();
}

class _DocumentsPageState extends State<DocumentsPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // Navigation state
  final List<Map<String, dynamic>> _breadcrumbs = [
    {'name': 'ROOT', 'id': null}
  ];
  String? _currentParentId;

  // Data
  List<dynamic> _folders = [];
  List<dynamic> _files = [];

  // UI state
  bool _isLoading = false;
  bool _isUploading = false;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (_tabController.indexIsChanging) {
        if (_tabController.index == 1) {
          // Could load shared documents here if there's a separate API
        }
      }
    });
    if (widget.isActive) {
      _loadDocuments();
    }
  }

  @override
  void didUpdateWidget(DocumentsPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isActive && !oldWidget.isActive) {
      _loadDocuments(parentId: _currentParentId);
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadDocuments({String? parentId}) async {
    setState(() => _isLoading = true);
    final data = await ApiService.getDocuments(parentId: parentId);
    setState(() {
      _folders = (data['folders'] as List?) ?? [];
      _files = (data['files'] as List?) ?? [];
      _isLoading = false;
    });
  }

  void _navigateToFolder(Map<String, dynamic> folder) {
    final id = (folder['_id'] ?? folder['id'])?.toString();
    final name = folder['name']?.toString() ?? 'Thư mục';
    setState(() {
      _breadcrumbs.add({'name': name, 'id': id});
      _currentParentId = id;
    });
    _loadDocuments(parentId: id);
  }

  void _navigateToBreadcrumb(int index) {
    if (index >= _breadcrumbs.length - 1) return;
    setState(() {
      _breadcrumbs.removeRange(index + 1, _breadcrumbs.length);
      _currentParentId = _breadcrumbs[index]['id'];
    });
    _loadDocuments(parentId: _currentParentId);
  }

  void _showCreateFolderDialog() {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Theme.of(context).brightness == Brightness.dark
            ? const Color(0xFF1E1F20)
            : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Tạo thư mục mới',
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: InputDecoration(
            hintText: 'Tên thư mục...',
            filled: true,
            fillColor: Theme.of(context).brightness == Brightness.dark
                ? const Color(0xFF252728)
                : const Color(0xFFF8FAFC),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide.none,
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Hủy'),
          ),
          ElevatedButton(
            onPressed: () async {
              final name = controller.text.trim();
              if (name.isEmpty) return;
              Navigator.pop(ctx);
              final result = await ApiService.createFolder(
                name,
                parentId: _currentParentId,
              );
              if (result != null) {
                _loadDocuments(parentId: _currentParentId);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Tạo thư mục thành công!'),
                      backgroundColor: Colors.green,
                    ),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF3B82F6),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Tạo'),
          ),
        ],
      ),
    );
  }

  Future<void> _uploadFiles() async {
    final result = await FilePicker.platform.pickFiles(allowMultiple: true);
    if (result == null || result.files.isEmpty) return;

    final paths = result.files
        .where((f) => f.path != null)
        .map((f) => f.path!)
        .toList();

    if (paths.isEmpty) return;

    setState(() => _isUploading = true);

    final res = await ApiService.uploadDocuments(
      paths,
      parentId: _currentParentId,
    );

    setState(() => _isUploading = false);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              res != null ? 'Tải lên thành công!' : 'Tải lên thất bại!'),
          backgroundColor: res != null ? Colors.green : Colors.red,
        ),
      );
      if (res != null) _loadDocuments(parentId: _currentParentId);
    }
  }

  void _showRenameDialog(Map<String, dynamic> item) {
    final id = (item['_id'] ?? item['id'])?.toString() ?? '';
    final controller =
        TextEditingController(text: item['name']?.toString() ?? '');
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Theme.of(context).brightness == Brightness.dark
            ? const Color(0xFF1E1F20)
            : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Đổi tên',
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: InputDecoration(
            filled: true,
            fillColor: Theme.of(context).brightness == Brightness.dark
                ? const Color(0xFF252728)
                : const Color(0xFFF8FAFC),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide.none,
            ),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Hủy')),
          ElevatedButton(
            onPressed: () async {
              final newName = controller.text.trim();
              if (newName.isEmpty) return;
              Navigator.pop(ctx);
              final ok = await ApiService.renameDocument(id, newName);
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content:
                        Text(ok ? 'Đã đổi tên!' : 'Đổi tên thất bại!'),
                    backgroundColor: ok ? Colors.green : Colors.red,
                  ),
                );
                if (ok) _loadDocuments(parentId: _currentParentId);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF3B82F6),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Lưu'),
          ),
        ],
      ),
    );
  }

  void _showDeleteDialog(Map<String, dynamic> item) {
    final id = (item['_id'] ?? item['id'])?.toString() ?? '';
    final name = item['name']?.toString() ?? 'tài liệu này';
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Theme.of(context).brightness == Brightness.dark
            ? const Color(0xFF1E1F20)
            : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Xác nhận xóa',
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
        content: Text('Bạn có chắc muốn xóa "$name"? Hành động này không thể hoàn tác.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Hủy')),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              final ok = await ApiService.deleteDocument(id);
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(ok ? 'Đã xóa!' : 'Xóa thất bại!'),
                    backgroundColor: ok ? Colors.green : Colors.red,
                  ),
                );
                if (ok) _loadDocuments(parentId: _currentParentId);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Xóa'),
          ),
        ],
      ),
    );
  }

  void _showShareDialog(Map<String, dynamic> item) {
    final id = (item['_id'] ?? item['id'])?.toString() ?? '';
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Theme.of(context).brightness == Brightness.dark
            ? const Color(0xFF1E1F20)
            : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Chia sẻ tài liệu',
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Nhập ID người dùng (cách nhau bởi dấu phẩy):',
                style: TextStyle(fontSize: 13, color: Colors.grey)),
            const SizedBox(height: 8),
            TextField(
              controller: controller,
              autofocus: true,
              maxLines: 2,
              decoration: InputDecoration(
                hintText: 'userId1, userId2...',
                filled: true,
                fillColor: Theme.of(context).brightness == Brightness.dark
                    ? const Color(0xFF252728)
                    : const Color(0xFFF8FAFC),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Hủy')),
          ElevatedButton(
            onPressed: () async {
              final raw = controller.text.trim();
              if (raw.isEmpty) return;
              final ids = raw.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
              Navigator.pop(ctx);
              final ok = await ApiService.shareDocument(id, ids);
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(ok ? 'Đã chia sẻ!' : 'Chia sẻ thất bại!'),
                    backgroundColor: ok ? Colors.green : Colors.red,
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF3B82F6),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Chia sẻ'),
          ),
        ],
      ),
    );
  }

  Future<void> _downloadFile(Map<String, dynamic> file) async {
    final id = (file['_id'] ?? file['id'])?.toString() ?? '';
    final downloadUrl = '${ApiService.baseUrl}/documents/download/$id';
    final uri = Uri.parse(downloadUrl);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Không thể mở link tải xuống')),
        );
      }
    }
  }

  List<dynamic> get _filteredFolders {
    if (_searchQuery.isEmpty) return _folders;
    return _folders.where((f) {
      final name = (f['name'] ?? '').toString().toLowerCase();
      return name.contains(_searchQuery.toLowerCase());
    }).toList();
  }

  List<dynamic> get _filteredFiles {
    if (_searchQuery.isEmpty) return _files;
    return _files.where((f) {
      final name = (f['name'] ?? '').toString().toLowerCase();
      return name.contains(_searchQuery.toLowerCase());
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isDesktop = MediaQuery.of(context).size.width > 900;

    return GlobalErrorWrapper(
      child: Scaffold(
        backgroundColor:
            isDark ? const Color(0xFF252728) : const Color(0xFFF8FAFC),
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1200),
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: isDesktop ? 32.0 : 0),
            child: NestedScrollView(
              headerSliverBuilder: (context, innerBoxIsScrolled) {
                return [
                  SliverToBoxAdapter(
                    child: _buildHeader(isDark, isDesktop),
                  ),
                ];
              },
              body: TabBarView(
                controller: _tabController,
                children: [
                  _buildMyDocsTab(isDark),
                  _buildSharedTab(isDark),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

  Widget _buildMobileHeader(bool isDark) {
    return Column(
      children: [
        // Top Card
        Container(
          margin: const EdgeInsets.all(16),
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF252728) : Colors.white,
            borderRadius: BorderRadius.circular(32),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(isDark ? 0.2 : 0.04),
                blurRadius: 24,
                offset: const Offset(0, 8),
              )
            ],
          ),
          child: Column(
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFF3B82F6).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Icon(Icons.folder_open, color: Color(0xFF3B82F6), size: 28),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Quản lý Tài liệu', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: isDark ? Colors.white : const Color(0xFF1E293B))),
                        const SizedBox(height: 4),
                        Text('Quản lý dữ liệu cá nhân, tải lên các định dạng và chia sẻ an toàn nội bộ.', style: TextStyle(fontSize: 12, height: 1.4, color: isDark ? Colors.white54 : Colors.blueGrey.shade400)),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: _ActionButton(
                      icon: Icons.create_new_folder_outlined,
                      label: 'TẠO\nTHƯ MỤC',
                      onTap: _showCreateFolderDialog,
                      color: isDark ? const Color(0xFF1E1F20) : const Color(0xFFF8FAFC),
                      textColor: const Color(0xFF1E293B),
                      borderColor: Colors.transparent,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _ActionButton(
                      icon: _isUploading ? null : Icons.upload_file,
                      label: _isUploading ? 'ĐANG TẢI...' : 'TẢI TÀI\nLIỆU',
                      onTap: _isUploading ? null : _uploadFiles,
                      color: const Color(0xFF3B82F6),
                      textColor: Colors.white,
                      isLoading: _isUploading,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        
        // Tabs Container
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF252728) : Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: isDark ? Colors.white10 : Colors.blueGrey.shade50),
          ),
          child: TabBar(
            controller: _tabController,
            indicator: BoxDecoration(
              color: const Color(0xFF3B82F6),
              borderRadius: BorderRadius.circular(16),
            ),
            labelColor: Colors.white,
            unselectedLabelColor: isDark ? Colors.white54 : Colors.blueGrey.shade400,
            indicatorSize: TabBarIndicatorSize.tab,
            dividerColor: Colors.transparent,
            labelStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12),
            tabs: const [
              Tab(child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.folder_shared_outlined, size: 14), SizedBox(width: 4), Text('TÀI LIỆU\nCỦA TÔI', textAlign: TextAlign.center)])),
              Tab(child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.people_outline, size: 14), SizedBox(width: 4), Text('ĐƯỢC CHIA\nSẺ VỚI TÔI', textAlign: TextAlign.center)])),
            ],
          ),
        ),
        
        // Grid/List + Search
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF252728) : Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: isDark ? Colors.white10 : Colors.blueGrey.shade50),
                ),
                padding: const EdgeInsets.all(4),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: Colors.transparent, borderRadius: BorderRadius.circular(12)), child: const Icon(Icons.grid_view, size: 20, color: Colors.blueGrey)),
                    Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: const Color(0xFFEFF6FF), borderRadius: BorderRadius.circular(12)), child: const Icon(Icons.list, size: 20, color: Color(0xFF3B82F6))),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                onChanged: (v) => setState(() => _searchQuery = v),
                decoration: InputDecoration(
                  hintText: 'Tìm tài liệu theo tên...',
                  hintStyle: TextStyle(fontSize: 14, color: isDark ? Colors.white30 : Colors.blueGrey.shade300),
                  prefixIcon: Icon(Icons.search, size: 20, color: isDark ? Colors.white38 : Colors.blueGrey.shade400),
                  filled: true,
                  fillColor: isDark ? const Color(0xFF252728) : Colors.white,
                  contentPadding: const EdgeInsets.symmetric(vertical: 16),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: isDark ? Colors.white10 : Colors.blueGrey.shade50)),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: isDark ? Colors.white10 : Colors.blueGrey.shade50)),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildHeader(bool isDark, bool isDesktop) {
    if (!isDesktop) return _buildMobileHeader(isDark);
    
    return Container(
      padding: EdgeInsets.fromLTRB(
          isDesktop ? 32 : 20, isDesktop ? 32 : 20, isDesktop ? 32 : 20, 0),
      color: isDark ? const Color(0xFF252728) : Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title row
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFF3B82F6).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.folder_open,
                    color: Color(0xFF3B82F6), size: 24),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Quản lý Tài liệu',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: isDark ? Colors.white : const Color(0xFF1E293B),
                      ),
                    ),
                    Text(
                      'Quản lý dữ liệu cá nhân, tải lên các định dạng và chia sẻ an toàn nội bộ',
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? Colors.white38 : Colors.blueGrey.shade400,
                      ),
                    ),
                  ],
                ),
              ),
              // Action buttons
              _ActionButton(
                icon: Icons.create_new_folder_outlined,
                label: 'TẠO THƯ MỤC',
                onTap: _showCreateFolderDialog,
                color: isDark ? const Color(0xFF3B82F6).withValues(alpha: 0.15) : const Color(0xFFEFF6FF),
                textColor: const Color(0xFF3B82F6),
                borderColor: const Color(0xFF3B82F6).withValues(alpha: 0.3),
              ),
              const SizedBox(width: 10),
              _ActionButton(
                icon: _isUploading ? null : Icons.upload_file,
                label: _isUploading ? 'ĐANG TẢI...' : 'TẢI TÀI LIỆU',
                onTap: _isUploading ? null : _uploadFiles,
                color: const Color(0xFF3B82F6),
                textColor: Colors.white,
                isLoading: _isUploading,
              ),
            ],
          ),
          const SizedBox(height: 20),
          // OCR quick access
          InkWell(
            onTap: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => const OCRPage())),
            borderRadius: BorderRadius.circular(10),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                    colors: [Color(0xFF3B82F6), Color(0xFF6366F1)]),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: const [
                  Icon(Icons.document_scanner, color: Colors.white, size: 16),
                  SizedBox(width: 8),
                  Text('ONLINE OCR',
                      style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 12)),
                  SizedBox(width: 6),
                  Icon(Icons.arrow_forward_ios, color: Colors.white70, size: 11),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          // Tabs + Search
          Row(
            children: [
              Expanded(
                child: TabBar(
                  controller: _tabController,
                  isScrollable: true,
                  tabAlignment: TabAlignment.start,
                  indicatorColor: const Color(0xFF3B82F6),
                  labelColor: const Color(0xFF3B82F6),
                  unselectedLabelColor:
                      isDark ? Colors.white38 : Colors.blueGrey.shade400,
                  labelStyle: const TextStyle(
                      fontWeight: FontWeight.w700, fontSize: 13),
                  tabs: const [
                    Tab(
                      child: Row(
                        children: [
                          Icon(Icons.folder_shared_outlined, size: 16),
                          SizedBox(width: 6),
                          Text('TÀI LIỆU CỦA TÔI'),
                        ],
                      ),
                    ),
                    Tab(
                      child: Row(
                        children: [
                          Icon(Icons.people_outline, size: 16),
                          SizedBox(width: 6),
                          Text('ĐƯỢC CHIA SẺ VỚI TÔI'),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              // Search
              SizedBox(
                width: 240,
                child: TextField(
                  onChanged: (v) => setState(() => _searchQuery = v),
                  decoration: InputDecoration(
                    hintText: 'Tìm tài liệu theo tên...',
                    hintStyle: TextStyle(
                        fontSize: 13,
                        color: isDark ? Colors.white30 : Colors.blueGrey.shade300),
                    prefixIcon: Icon(Icons.search,
                        size: 18,
                        color: isDark ? Colors.white38 : Colors.blueGrey.shade400),
                    filled: true,
                    fillColor:
                        isDark ? const Color(0xFF1E1F20) : const Color(0xFFF1F5F9),
                    contentPadding: const EdgeInsets.symmetric(vertical: 8),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ),
            ],
          ),
          Divider(
              height: 1,
              color: isDark ? Colors.white12 : Colors.grey.shade100),
        ],
      ),
    );
  }

  Widget _buildMyDocsTab(bool isDark) {
    final isDesktop = MediaQuery.of(context).size.width > 900;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Breadcrumb
        Container(
          color: isDesktop ? (isDark ? const Color(0xFF252728) : Colors.white) : Colors.transparent,
          padding: EdgeInsets.symmetric(horizontal: isDesktop ? 24 : 16, vertical: 10),
          child: Row(
            children: [
              for (int i = 0; i < _breadcrumbs.length; i++) ...[
                GestureDetector(
                  onTap: () => _navigateToBreadcrumb(i),
                  child: Text(
                    _breadcrumbs[i]['name'] ?? 'ROOT',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: i == _breadcrumbs.length - 1
                          ? (isDark ? Colors.white : const Color(0xFF1E293B))
                          : const Color(0xFF3B82F6),
                    ),
                  ),
                ),
                if (i < _breadcrumbs.length - 1)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    child: Icon(Icons.chevron_right,
                        size: 14,
                        color: isDark ? Colors.white38 : Colors.blueGrey.shade400),
                  ),
              ],
            ],
          ),
        ),
        if (isDesktop) Divider(height: 1, color: isDark ? Colors.white12 : Colors.grey.shade100),
        Expanded(
          child: Container(
            margin: isDesktop ? EdgeInsets.zero : const EdgeInsets.symmetric(horizontal: 16),
            decoration: isDesktop ? null : BoxDecoration(
              color: isDark ? const Color(0xFF252728) : Colors.white,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              children: [
                _buildTableHeader(isDark),
                Expanded(
                  child: _isLoading
                      ? const Center(child: CircularProgressIndicator())
                      : (_filteredFolders.isEmpty && _filteredFiles.isEmpty)
                          ? _buildEmpty(isDark)
                          : ListView(
                              padding: isDesktop ? EdgeInsets.zero : const EdgeInsets.only(bottom: 20),
                              children: [
                                ..._filteredFolders.map(
                                    (f) => _buildFolderRow(f, isDark)),
                                ..._filteredFiles.map(
                                    (f) => _buildFileRow(f, isDark)),
                              ],
                            ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSharedTab(bool isDark) {
    // "Được chia sẻ với tôi" - currently shows empty state since there's no dedicated API
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.people_outline,
              size: 56, color: isDark ? Colors.white24 : Colors.blueGrey.shade200),
          const SizedBox(height: 16),
          Text(
            'Chưa có tài liệu nào được chia sẻ với bạn',
            style: TextStyle(
              fontSize: 14,
              color: isDark ? Colors.white38 : Colors.blueGrey.shade400,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Tài liệu được chia sẻ từ đồng nghiệp sẽ hiển thị ở đây',
            style: TextStyle(
              fontSize: 12,
              color: isDark ? Colors.white24 : Colors.blueGrey.shade300,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTableHeader(bool isDark) {
    final isDesktop = MediaQuery.of(context).size.width > 900;
    return Container(
      color: isDesktop ? (isDark ? const Color(0xFF1E1F20) : const Color(0xFFF8FAFC)) : Colors.transparent,
      padding: EdgeInsets.symmetric(horizontal: isDesktop ? 24 : 16, vertical: 16),
      child: Row(
        children: [
          Expanded(
            flex: isDesktop ? 5 : 1,
            child: Text('TÊN TÀI LIỆU / THƯ MỤC',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.5,
                  color: isDark ? Colors.white38 : Colors.blueGrey.shade500,
                )),
          ),
          if (isDesktop) ...[
            SizedBox(
              width: 90,
              child: Text('KÍCH THƯỚC',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5,
                    color: isDark ? Colors.white38 : Colors.blueGrey.shade500,
                  )),
            ),
            SizedBox(
              width: 120,
              child: Text('NGÀY SỬA ĐỔI',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5,
                    color: isDark ? Colors.white38 : Colors.blueGrey.shade500,
                  )),
            ),
            SizedBox(
              width: 130,
              child: Text('THAO TÁC NHANH',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5,
                    color: isDark ? Colors.white38 : Colors.blueGrey.shade500,
                  )),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildFolderRow(Map<String, dynamic> folder, bool isDark) {
    final name = folder['name']?.toString() ?? 'Thư mục';
    final updatedAt = folder['updatedAt'] ?? folder['createdAt'];
    String dateStr = '';
    if (updatedAt != null) {
      try {
        final dt = DateTime.parse(updatedAt.toString()).toLocal();
        dateStr = DateFormat('dd/MM/yyyy\nHH:mm').format(dt);
      } catch (_) {}
    }

    return _TableRow(
      onTap: () => _navigateToFolder(folder),
      isDark: isDark,
      leading: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: const Color(0xFF3B82F6).withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Icon(Icons.folder, color: Color(0xFF3B82F6), size: 18),
      ),
      name: name,
      nameColor: const Color(0xFF3B82F6),
      size: '--',
      date: dateStr,
      onDownload: null,
      onShare: () => _showShareDialog(folder),
      onRename: () => _showRenameDialog(folder),
      onDelete: () => _showDeleteDialog(folder),
    );
  }

  Widget _buildFileRow(Map<String, dynamic> file, bool isDark) {
    final name = file['name']?.toString() ?? 'Tài liệu';
    final size = _formatSize(file['size']);
    final updatedAt = file['updatedAt'] ?? file['createdAt'];
    String dateStr = '';
    if (updatedAt != null) {
      try {
        final dt = DateTime.parse(updatedAt.toString()).toLocal();
        dateStr = DateFormat('dd/MM/yyyy\nHH:mm').format(dt);
      } catch (_) {}
    }
    final ext = name.contains('.') ? name.split('.').last.toLowerCase() : '';

    return _TableRow(
      onTap: null,
      isDark: isDark,
      leading: _FileIcon(ext: ext),
      name: name,
      nameColor: isDark ? Colors.white : const Color(0xFF1E293B),
      size: size,
      date: dateStr,
      onDownload: () => _downloadFile(file),
      onShare: () => _showShareDialog(file),
      onRename: () => _showRenameDialog(file),
      onDelete: () => _showDeleteDialog(file),
    );
  }

  Widget _buildEmpty(bool isDark) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.folder_open_outlined,
              size: 64, color: isDark ? Colors.white24 : Colors.blueGrey.shade200),
          const SizedBox(height: 16),
          Text(
            'Thư mục này đang trống',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white38 : Colors.blueGrey.shade500,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Nhấn "Tải tài liệu" để thêm file hoặc "Tạo thư mục" để tổ chức',
            style: TextStyle(
              fontSize: 12,
              color: isDark ? Colors.white24 : Colors.blueGrey.shade300,
            ),
          ),
        ],
      ),
    );
  }

  String _formatSize(dynamic size) {
    if (size == null) return '--';
    final bytes = (size is int) ? size : int.tryParse(size.toString()) ?? 0;
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }
}

// ==================== SUB WIDGETS ====================

class _ActionButton extends StatelessWidget {
  final IconData? icon;
  final String label;
  final VoidCallback? onTap;
  final Color color;
  final Color textColor;
  final Color? borderColor;
  final bool isLoading;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
    required this.color,
    required this.textColor,
    this.borderColor,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(10),
          border: borderColor != null
              ? Border.all(color: borderColor!)
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isLoading)
              const SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: Colors.white),
              )
            else if (icon != null)
              Icon(icon, size: 15, color: textColor),
            if (!isLoading && icon != null) const SizedBox(width: 7),
            Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                  color: textColor,
                  fontWeight: FontWeight.w800,
                  fontSize: 12,
                  height: 1.2),
            ),
          ],
        ),
      ),
    );
  }
}

class _TableRow extends StatefulWidget {
  final GestureTapCallback? onTap;
  final bool isDark;
  final Widget leading;
  final String name;
  final Color nameColor;
  final String size;
  final String date;
  final VoidCallback? onDownload;
  final VoidCallback? onShare;
  final VoidCallback? onRename;
  final VoidCallback? onDelete;

  const _TableRow({
    required this.onTap,
    required this.isDark,
    required this.leading,
    required this.name,
    required this.nameColor,
    required this.size,
    required this.date,
    required this.onDownload,
    required this.onShare,
    required this.onRename,
    required this.onDelete,
  });

  @override
  State<_TableRow> createState() => _TableRowState();
}

class _TableRowState extends State<_TableRow> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDark;
    final isDesktop = MediaQuery.of(context).size.width > 900;
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          color: _hovered
              ? (isDark
                  ? const Color(0xFF3B82F6).withValues(alpha: 0.06)
                  : const Color(0xFFEFF6FF))
              : Colors.transparent,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
          child: Row(
            children: [
              // Name column
              Expanded(
                flex: isDesktop ? 5 : 1,
                child: Row(
                  children: [
                    widget.leading,
                    const SizedBox(width: 16),
                    Expanded(
                      child: Text(
                        widget.name,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: isDesktop ? FontWeight.w500 : FontWeight.w800,
                          color: widget.nameColor,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              if (isDesktop) ...[
                // Size
                SizedBox(
                  width: 90,
                  child: Text(
                    widget.size,
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark ? Colors.white54 : Colors.blueGrey.shade500,
                    ),
                  ),
                ),
                // Date
                SizedBox(
                  width: 120,
                  child: Text(
                    widget.date,
                    style: TextStyle(
                      fontSize: 11,
                      height: 1.5,
                      color: isDark ? Colors.white54 : Colors.blueGrey.shade500,
                    ),
                  ),
                ),
                // Actions
                SizedBox(
                  width: 130,
                  child: Row(
                    children: [
                      if (widget.onDownload != null)
                        _QuickAction(
                          icon: Icons.download_outlined,
                          tooltip: 'Tải xuống',
                          onTap: widget.onDownload!,
                          color: const Color(0xFF3B82F6),
                        ),
                      _QuickAction(
                        icon: Icons.share_outlined,
                        tooltip: 'Chia sẻ',
                        onTap: widget.onShare ?? () {},
                        color: const Color(0xFF10B981),
                      ),
                      _QuickAction(
                        icon: Icons.edit_outlined,
                        tooltip: 'Đổi tên',
                        onTap: widget.onRename ?? () {},
                        color: Colors.orange,
                      ),
                      _QuickAction(
                        icon: Icons.delete_outline,
                        tooltip: 'Xóa',
                        onTap: widget.onDelete ?? () {},
                        color: Colors.red,
                      ),
                    ],
                  ),
                ),
              ] else ...[
                 PopupMenuButton(
                    icon: Icon(Icons.more_vert, color: isDark ? Colors.white54 : Colors.blueGrey),
                    padding: EdgeInsets.zero,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    itemBuilder: (ctx) => [
                       if (widget.onDownload != null) PopupMenuItem(onTap: widget.onDownload, child: const Text('Tải xuống', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600))),
                       if (widget.onShare != null) PopupMenuItem(onTap: widget.onShare, child: const Text('Chia sẻ', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600))),
                       if (widget.onRename != null) PopupMenuItem(onTap: widget.onRename, child: const Text('Đổi tên', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600))),
                       if (widget.onDelete != null) PopupMenuItem(onTap: widget.onDelete, child: const Text('Xóa', style: TextStyle(color: Colors.red, fontSize: 13, fontWeight: FontWeight.w600))),
                    ],
                 )
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _QuickAction extends StatefulWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  final Color color;

  const _QuickAction({
    required this.icon,
    required this.tooltip,
    required this.onTap,
    required this.color,
  });

  @override
  State<_QuickAction> createState() => _QuickActionState();
}

class _QuickActionState extends State<_QuickAction> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: widget.tooltip,
      child: MouseRegion(
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: GestureDetector(
          onTap: widget.onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 120),
            margin: const EdgeInsets.only(right: 4),
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: _hovered
                  ? widget.color.withValues(alpha: 0.12)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Icon(widget.icon,
                size: 16,
                color: _hovered
                    ? widget.color
                    : Theme.of(context).brightness == Brightness.dark
                        ? Colors.white38
                        : Colors.blueGrey.shade400),
          ),
        ),
      ),
    );
  }
}

class _FileIcon extends StatelessWidget {
  final String ext;
  const _FileIcon({required this.ext});

  @override
  Widget build(BuildContext context) {
    IconData icon;
    Color color;
    switch (ext) {
      case 'pdf':
        icon = Icons.picture_as_pdf_outlined;
        color = Colors.red.shade400;
        break;
      case 'doc':
      case 'docx':
        icon = Icons.description_outlined;
        color = Colors.blue.shade400;
        break;
      case 'xls':
      case 'xlsx':
        icon = Icons.table_chart_outlined;
        color = Colors.green.shade400;
        break;
      case 'ppt':
      case 'pptx':
        icon = Icons.slideshow_outlined;
        color = Colors.orange.shade400;
        break;
      case 'jpg':
      case 'jpeg':
      case 'png':
      case 'gif':
      case 'webp':
        icon = Icons.image_outlined;
        color = Colors.purple.shade400;
        break;
      case 'mp4':
      case 'mov':
      case 'avi':
        icon = Icons.videocam_outlined;
        color = Colors.pink.shade400;
        break;
      case 'zip':
      case 'rar':
      case '7z':
        icon = Icons.folder_zip_outlined;
        color = Colors.amber.shade600;
        break;
      default:
        icon = Icons.insert_drive_file_outlined;
        color = Colors.blueGrey.shade400;
    }
    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(icon, color: color, size: 17),
    );
  }
}
