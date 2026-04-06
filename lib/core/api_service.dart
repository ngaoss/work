import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'security.dart';

class ApiService {
  static const String siteUrl = 'https://work.deepcode.vn';
  static const String baseUrl = '$siteUrl/api';

  static String resolveUrl(dynamic path) {
    if (path == null) return '';
    final String s = path.toString().trim();
    if (s.isEmpty) return '';
    if (s.startsWith('http')) return Uri.encodeFull(s);
    final String cleanPath = s.startsWith('/') ? s.substring(1) : s;
    return Uri.encodeFull('$siteUrl/$cleanPath');
  }

  /// Resolve any image/avatar value (may be a MongoDB ObjectId or URL)
  /// to a full URL using the /api/images/:id endpoint or static path
  static String resolveImageUrl(dynamic path) {
    if (path == null) return '';
    final String s = path.toString().trim();
    if (s.isEmpty) return '';
    if (s.startsWith('http')) return Uri.encodeFull(s);

    // If it looks like a MongoDB ObjectId (24 hex chars), build API URL
    if (RegExp(r'^[a-f0-9]{24}$').hasMatch(s)) {
      return '$baseUrl/images/$s';
    }

    // Otherwise treat as relative path
    final String cleanPath = s.startsWith('/') ? s.substring(1) : s;
    return Uri.encodeFull('$siteUrl/$cleanPath');
  }

  static Future<Map<String, String>> getAssetHeaders() async {
    final token = AuthService().authToken.value;
    return {if (token != null) 'Authorization': 'Bearer $token'};
  }

  static Future<Map<String, String>> _getHeaders() async {
    final token = AuthService().authToken.value;
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  /// Return the current auth headers for Image.network / VideoPlayer
  static Future<Map<String, String>> getAuthHeaders() => getAssetHeaders();

  static List<dynamic> _extractList(dynamic data) {
    if (data is List) return data;
    if (data is Map) {
      if (data.containsKey('data') && data['data'] is List) return data['data'];
      for (final key in [
        'users',
        'posts',
        'reels',
        'items',
        'results',
        'feed',
      ]) {
        if (data.containsKey(key) && data[key] is List) return data[key];
      }
    }
    debugPrint('ApiService: No list found in: $data');
    return [];
  }

  static dynamic _processResponse(http.Response response, String method) {
    debugPrint('ApiService $method response: ${response.statusCode}');
    if (response.statusCode >= 200 && response.statusCode < 300) {
      try {
        final data = jsonDecode(response.body);
        debugPrint('ApiService $method data: $data');
        return data;
      } catch (e) {
        debugPrint('ApiService JSON error ($method): $e');
        return null;
      }
    } else {
      debugPrint(
        'ApiService error ($method): ${response.statusCode} - ${response.body}',
      );
      return null;
    }
  }

  // --- Profile ---
  static Future<Map<String, dynamic>?> getMe() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/users/profile'),
        headers: await _getHeaders(),
      );
      final res = _processResponse(response, 'getMe');
      if (res is Map) {
        final Map<String, dynamic> data = (res.containsKey('data'))
            ? res['data'] as Map<String, dynamic>
            : (res.containsKey('user'))
            ? res['user'] as Map<String, dynamic>
            : res as Map<String, dynamic>;
        // Sync with AuthService so app-wide cache is updated
        await AuthService().updateLocalProfile(data);
        return data;
      }
    } catch (e) {
      debugPrint('ApiService catch error (getMe): $e');
    }
    return null;
  }

  static Future<bool> updateProfile(Map<String, dynamic> data) async {
    try {
      final response = await http.put(
        Uri.parse('$baseUrl/users/profile'),
        headers: await _getHeaders(),
        body: jsonEncode(data),
      );
      return response.statusCode == 200;
    } catch (e) {
      debugPrint('ApiService error (updateProfile): $e');
      return false;
    }
  }

  static Future<List<dynamic>> getUsers() async {
    try {
      final firstResp = await http.get(
        Uri.parse('$baseUrl/users?page=1'),
        headers: await _getHeaders(),
      );
      final firstData = _processResponse(firstResp, 'getUsers p1');
      if (firstData == null) return [];

      final List<dynamic> all = List.from(_extractList(firstData));

      final int totalPages = (firstData is Map)
          ? int.tryParse(
                  firstData['totalPages']?.toString() ??
                      firstData['total_pages']?.toString() ??
                      '1',
                ) ??
                1
          : 1;
      final int totalUsers = (firstData is Map)
          ? int.tryParse(
                  firstData['totalUsers']?.toString() ??
                      firstData['total']?.toString() ??
                      '0',
                ) ??
                0
          : 0;

      debugPrint(
        'ApiService: getUsers totalPages=$totalPages totalUsers=$totalUsers, p1=${all.length}',
      );

      for (int page = 2; page <= totalPages; page++) {
        final resp = await http.get(
          Uri.parse('$baseUrl/users?page=$page'),
          headers: await _getHeaders(),
        );
        final pageData = _processResponse(resp, 'getUsers p$page');
        if (pageData != null) {
          all.addAll(_extractList(pageData));
        }
      }

      // Deduplicate by _id to remove any overlap between pages
      final seen = <String>{};
      final deduped = all.where((u) {
        final id = (u['_id'] ?? u['id'])?.toString() ?? '';
        if (id.isEmpty) return true;
        return seen.add(id);
      }).toList();

      // Cap at totalUsers if server reported it
      final result = (totalUsers > 0 && deduped.length > totalUsers)
          ? deduped.sublist(0, totalUsers)
          : deduped;

      debugPrint(
        'ApiService: getUsers FINAL=${result.length} (raw=${all.length}, deduped=${deduped.length})',
      );
      return result;
    } catch (e) {
      debugPrint('ApiService error (getUsers): $e');
    }
    return [];
  }

  static Future<Map<String, dynamic>> getPosts({
    int page = 1,
    int limit = 10,
  }) async {
    try {
      final resp = await http.get(
        Uri.parse('$baseUrl/posts/feed?page=$page&limit=$limit'),
        headers: await _getHeaders(),
      );
      final data = _processResponse(resp, 'getPosts p$page');
      if (data == null) return {'posts': [], 'totalPages': 1};

      final List<dynamic> rawPosts = _extractList(data);
      List<dynamic> posts = rawPosts;
      int totalPages = 1;

      // Handle case where server ignores pagination and returns all items
      if (rawPosts.length > limit) {
        final start = (page - 1) * limit;
        if (start >= rawPosts.length) {
          posts = [];
        } else {
          posts = rawPosts.skip(start).take(limit).toList();
        }
        totalPages = (rawPosts.length / limit).ceil();
      } else {
        if (data is Map) {
          final Map<String, dynamic> dataMap = Map<String, dynamic>.from(data);
          final dynamic totalPagesVal =
              dataMap['totalPages'] ??
              dataMap['total_pages'] ??
              dataMap['pages'] ??
              (dataMap['pagination'] is Map
                  ? dataMap['pagination']['pages']
                  : null) ??
              (dataMap['meta'] is Map && dataMap['meta']['pagination'] is Map
                  ? dataMap['meta']['pagination']['total_pages']
                  : null);

          totalPages = int.tryParse(totalPagesVal?.toString() ?? '1') ?? 1;

          if (totalPages <= 1) {
            final dynamic totalCount =
                dataMap['totalCount'] ??
                dataMap['total_count'] ??
                dataMap['total'] ??
                (dataMap['pagination'] is Map
                    ? dataMap['pagination']['total']
                    : null);
            if (totalCount != null) {
              final int count = int.tryParse(totalCount.toString()) ?? 10;
              totalPages = (count / limit).ceil();
            } else if (posts.isNotEmpty) {
              totalPages = page + 1;
            }
          }
        } else if (posts.isNotEmpty) {
          totalPages = page + 1;
        }
      }

      // Emulate loading so spinner spins long enough to be visible
      if (page > 1) {
        await Future.delayed(const Duration(seconds: 1));
      }

      return {'posts': posts, 'totalPages': totalPages};
    } catch (e) {
      debugPrint('ApiService getPosts error: $e');
      return {'posts': [], 'totalPages': 1};
    }
  }

  static Future<bool> createPost(Map<String, dynamic> data) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/posts'),
        headers: await _getHeaders(),
        body: jsonEncode(data),
      );
      debugPrint('ApiService createPost status: ${response.statusCode}');
      debugPrint('ApiService createPost response: ${response.body}');
      return response.statusCode == 201 || response.statusCode == 200;
    } catch (e) {
      debugPrint('ApiService error (createPost): $e');
      return false;
    }
  }

  static Future<bool> deletePost(String postId) async {
    try {
      final response = await http.delete(
        Uri.parse('$baseUrl/posts/$postId'),
        headers: await _getHeaders(),
      );
      debugPrint('ApiService deletePost status: ${response.statusCode}');
      debugPrint('ApiService deletePost response: ${response.body}');
      return response.statusCode == 200 || response.statusCode == 204;
    } catch (e) {
      debugPrint('ApiService error (deletePost): $e');
      return false;
    }
  }

  static Future<bool> addComment(
    String postId,
    Map<String, dynamic> data,
  ) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/comments/$postId'),
        headers: await _getHeaders(),
        body: jsonEncode(data),
      );
      debugPrint('ApiService addComment status: ${response.statusCode}');
      debugPrint('ApiService addComment response: ${response.body}');
      return response.statusCode == 201 || response.statusCode == 200;
    } catch (e) {
      debugPrint('ApiService error (addComment): $e');
      return false;
    }
  }

  static Future<List<dynamic>> getComments(String postId) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/comments/$postId'),
        headers: await _getHeaders(),
      );
      final res = _processResponse(response, 'getComments');
      return _extractList(res);
    } catch (e) {
      debugPrint('ApiService error (getComments): $e');
      return [];
    }
  }

  // --- Reels ---
  static Future<List<dynamic>> getReels() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/reels?limit=100'),
        headers: await _getHeaders(),
      );
      final res = _processResponse(response, 'getReels');
      final list = _extractList(res);
      debugPrint('ApiService: getReels list size: ${list.length}');
      return list;
    } catch (e) {
      debugPrint('ApiService error (getReels): $e');
    }
    return [];
  }

  static Future<bool> createReel(Map<String, dynamic> data) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/reels'),
        headers: await _getHeaders(),
        body: jsonEncode(data),
      );
      return response.statusCode == 201 || response.statusCode == 200;
    } catch (e) {
      debugPrint('ApiService error (createReel): $e');
      return false;
    }
  }

  /// Get comments for a reel
  static Future<List<dynamic>> getReelComments(String reelId) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/reels/$reelId/comments'),
        headers: await _getHeaders(),
      );
      final data = _processResponse(response, 'getReelComments');
      return _extractList(data);
    } catch (e) {
      debugPrint('ApiService error (getReelComments): $e');
    }
    return [];
  }

  /// Add a comment to a reel
  static Future<bool> addReelComment(
    String reelId,
    String text, {
    String? authorId,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/reels/$reelId/comments'),
        headers: await _getHeaders(),
        body: jsonEncode({
          "text": text,
          "reel": reelId,
          "post": null,
          "author": authorId,
          "status": "active",
        }),
      );
      debugPrint('ApiService addReelComment status: ${response.statusCode}');
      debugPrint('ApiService addReelComment response: ${response.body}');
      return response.statusCode == 201 || response.statusCode == 200;
    } catch (e) {
      debugPrint('ApiService error (addReelComment): $e');
      return false;
    }
  }

  /// Like / toggle reaction on a reel
  static Future<bool> likeReel(String reelId) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/reels/$reelId/react'),
        headers: await _getHeaders(),
        body: jsonEncode({'type': 'like'}),
      );
      return response.statusCode == 200 || response.statusCode == 201;
    } catch (e) {
      debugPrint('ApiService error (likeReel): $e');
      return false;
    }
  }

  // Removed duplicate getAuthHeaders
  static Future<List<dynamic>> getMusicList() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/music'),
        headers: await _getHeaders(),
      );
      final res = _processResponse(response, 'getMusicList');
      return _extractList(res);
    } catch (e) {
      debugPrint('ApiService error (getMusicList): $e');
      return [];
    }
  }

  static Future<bool> togglePostLike(String postId) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/posts/$postId/react'),
        headers: await _getHeaders(),
        body: jsonEncode({'type': 'like'}),
      );
      return response.statusCode == 200 || response.statusCode == 201;
    } catch (e) {
      debugPrint('ApiService error (togglePostLike): $e');
      return false;
    }
  }

  static Future<bool> toggleCommentLike(String commentId) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/comments/$commentId/react'),
        headers: await _getHeaders(),
        body: jsonEncode({'type': 'like'}),
      );
      return response.statusCode == 200 || response.statusCode == 201;
    } catch (e) {
      debugPrint('ApiService error (toggleCommentLike): $e');
      return false;
    }
  }

  static Future<String?> uploadImage(Uint8List bytes, String fileName) async {
    try {
      final request = http.MultipartRequest(
        'POST',
        Uri.parse('$baseUrl/images/upload'),
      );
      final token = AuthService().authToken.value;
      if (token != null) {
        request.headers['Authorization'] = 'Bearer $token';
      }

      final lowerName = fileName.toLowerCase();
      MediaType mediaType;
      if (lowerName.endsWith('.mp4')) {
        mediaType = MediaType('video', 'mp4');
      } else if (lowerName.endsWith('.mov')) {
        mediaType = MediaType('video', 'quicktime');
      } else if (lowerName.endsWith('.gif')) {
        mediaType = MediaType('image', 'gif');
      } else if (lowerName.endsWith('.jpg') || lowerName.endsWith('.jpeg')) {
        mediaType = MediaType('image', 'jpeg');
      } else {
        mediaType = MediaType('image', 'png');
      }

      request.files.add(
        http.MultipartFile.fromBytes(
          'image',
          bytes,
          filename: fileName.contains('.') ? fileName : '$fileName.png',
          contentType: mediaType,
        ),
      );

      final response = await request.send();
      final respStr = await response.stream.bytesToString();
      debugPrint('ApiService uploadImage status: ${response.statusCode}');
      debugPrint('ApiService uploadImage response: $respStr');
      if (response.statusCode >= 200 && response.statusCode < 300) {
        final data = jsonDecode(respStr);
        // Ưu tiên trích xuất từ server response giống như code JS
        if (data is Map && data['image'] is Map) {
          final image = data['image'];
          final String? id = (image['_id'] ?? image['id'])?.toString();
          if (id != null) return '$baseUrl/images/$id';
        }
        // Fallback
        return data['url'] ??
            data['data']?['url'] ??
            data['_id']?.toString() ??
            data['id']?.toString();
      } else {
        debugPrint(
          'ApiService uploadImage error: ${response.statusCode} - $respStr',
        );
      }
    } catch (e) {
      debugPrint('ApiService uploadImage exception: $e');
    }
    return null;
  }
}
