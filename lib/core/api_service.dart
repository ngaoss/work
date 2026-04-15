import 'dart:convert';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;
import 'security.dart';

class ApiService {
  static const String siteUrl = 'https://work.deepcode.vn';
  static const String baseUrl = '$siteUrl/api';

  static IO.Socket? _socket;
  static final StreamController<Map<String, dynamic>> _chatStreamController =
      StreamController<Map<String, dynamic>>.broadcast();
  static Stream<Map<String, dynamic>> get newChatStream =>
      _chatStreamController.stream;

  static void initializeSocket() {
    if (_socket != null) return;

    final token = AuthService().authToken.value;
    final options = IO.OptionBuilder().setTransports([
      'websocket',
    ]).enableAutoConnect();

    if (token != null) {
      options.setAuth({'token': token});
      options.setExtraHeaders({'Authorization': 'Bearer $token'});
    }

    _socket = IO.io(siteUrl, options.build());

    _socket!.onConnect((_) {
      debugPrint('ApiService Socket connected!');
    });

    _socket!.onConnectError((err) {
      debugPrint('ApiService Socket ConnectError: $err');
    });

    _socket!.onAny((event, data) {
      if (data is Map &&
          data.containsKey('text') &&
          !event.toString().contains('newMessage')) {
        // Only broadcast other message-like events if they actually contain text/content
        _chatStreamController.add(Map<String, dynamic>.from(data));
      }
    });

    _socket!.on('newMessage', (data) {
      if (data is Map) {
        _chatStreamController.add(Map<String, dynamic>.from(data));
      }
    });

    _socket!.onDisconnect((_) {
      debugPrint('ApiService Socket disconnected');
    });
  }

  static void disposeSocket() {
    _socket?.disconnect();
    _socket?.dispose();
    _socket = null;
  }

  static String resolveUrl(dynamic path) {
    if (path == null) return '';
    final String s = path.toString().trim();
    if (s.isEmpty) return '';
    if (s.startsWith('http')) return Uri.encodeFull(s);
    final String cleanPath = s.startsWith('/') ? s.substring(1) : s;
    return Uri.encodeFull('$siteUrl/$cleanPath');
  }

  static String resolveImageUrl(dynamic path) {
    if (path == null) return '';
    final String s = path.toString().trim();
    if (s.isEmpty) return '';
    if (s.startsWith('http')) return Uri.encodeFull(s);
    if (RegExp(r'^[a-fA-F0-9]{24}$').hasMatch(s)) {
      return '$baseUrl/images/$s';
    }
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

  static Future<Map<String, String>> getAuthHeaders() => getAssetHeaders();

  static List<dynamic> _extractList(dynamic data) {
    if (data is List) return data;
    if (data is Map) {
      if (data.containsKey('data') && data['data'] is List) return data['data'];
      for (final key in [
        'users',
        'posts',
        'reels',
        'comments',
        'conversations',
        'messages',
        'chats',
        'notifications',
      ]) {
        if (data.containsKey(key) && data[key] is List) return data[key];
      }
    }
    return [];
  }

  static dynamic _processResponse(http.Response response, String method) {
    if (response.statusCode >= 200 && response.statusCode < 300) {
      try {
        final data = jsonDecode(response.body);
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
        await AuthService().updateLocalProfile(data);
        return data;
      }
    } catch (e) {
      debugPrint('ApiService error (getMe): $e');
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
      final response = await http.get(
        Uri.parse('$baseUrl/users?limit=1000'),
        headers: await _getHeaders(),
      );
      final data = _processResponse(response, 'getUsers');
      return _extractList(data);
    } catch (e) {
      debugPrint('ApiService error (getUsers): $e');
      return [];
    }
  }

  // --- Notifications ---
  static final ValueNotifier<int> notificationRefresh = ValueNotifier(0);

  // --- Search ---
  static Future<List<dynamic>> searchUsers(String query) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/users/search?q=$query'),
        headers: await _getHeaders(),
      );
      final data = _processResponse(response, 'searchUsers');
      return _extractList(data);
    } catch (e) {
      debugPrint('ApiService error (searchUsers): $e');
      return [];
    }
  }

  // --- Posts ---
  static Future<Map<String, dynamic>> getPosts({
    int page = 1,
    int limit = 10,
  }) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/posts/feed?page=$page&limit=$limit'),
        headers: await _getHeaders(),
      );
      final res = _processResponse(response, 'getPosts');
      if (res is Map<String, dynamic>) return res;
      return {'posts': _extractList(res), 'totalPages': 1};
    } catch (e) {
      debugPrint('ApiService error (getPosts): $e');
      return {'posts': [], 'totalPages': 0};
    }
  }

  static Future<bool> createPost(Map<String, dynamic> data) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/posts'),
        headers: await _getHeaders(),
        body: jsonEncode(data),
      );
      return response.statusCode == 201 || response.statusCode == 200;
    } catch (e) {
      debugPrint('ApiService error (createPost): $e');
      return false;
    }
  }

  static Future<Map<String, dynamic>> deletePost(String postId) async {
    try {
      final response = await http.delete(
        Uri.parse('$baseUrl/posts/$postId'),
        headers: await _getHeaders(),
      );
      if (response.statusCode >= 200 && response.statusCode < 300) {
        return {'success': true, 'message': 'Đã xóa bài viết'};
      }
      return {'success': false, 'message': 'Lỗi: ${response.statusCode}'};
    } catch (e) {
      debugPrint('ApiService error (deletePost): $e');
      return {'success': false, 'message': e.toString()};
    }
  }

  static Future<Map<String, dynamic>> updatePost(
    String postId,
    Map<String, dynamic> payload,
  ) async {
    try {
      final response = await http.patch(
        Uri.parse('$baseUrl/posts/$postId'),
        headers: await _getHeaders(),
        body: jsonEncode(payload),
      );
      if (response.statusCode >= 200 && response.statusCode < 300) {
        return {'success': true, 'message': 'Cập nhật thành công'};
      }
      return {'success': false, 'message': 'Lỗi: ${response.statusCode}'};
    } catch (e) {
      debugPrint('ApiService error (updatePost): $e');
      return {'success': false, 'message': e.toString()};
    }
  }

  static Future<bool> togglePostLike(String postId) async {
    try {
      final url = Uri.parse('$baseUrl/posts/$postId/like');
      var response = await http.post(url, headers: await _getHeaders());
      
      if (response.statusCode >= 200 && response.statusCode < 300) {
        debugPrint('DEBUG: togglePostLike SUCCESS (POST)');
        return true;
      }
      
      response = await http.patch(url, headers: await _getHeaders());
      if (response.statusCode >= 200 && response.statusCode < 300) {
        debugPrint('DEBUG: togglePostLike SUCCESS (PATCH)');
        return true;
      }
      
      debugPrint('DEBUG: togglePostLike failed for $postId: ${response.statusCode}');
      return false;
    } catch (e) {
      debugPrint('ApiService error (togglePostLike): $e');
      return false;
    }
  }

  // --- Comments ---
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
      return response.statusCode == 201 || response.statusCode == 200;
    } catch (e) {
      debugPrint('ApiService error (addComment): $e');
      return false;
    }
  }

  static Future<bool> toggleCommentLike(String commentId, {String? postId}) async {
    try {
      // Based on provided URL: /api/comments/like/:id
      final List<String> urlPatterns = [
        '$baseUrl/comments/like/$commentId',             // Pattern from user
        '$baseUrl/comments/$commentId/like',             // Traditional pattern
        '$baseUrl/comments/$commentId/reactions',        // Reaction pattern
      ];
      
      if (postId != null && postId.isNotEmpty) {
        urlPatterns.add('$baseUrl/posts/$postId/comments/$commentId/like');
        urlPatterns.add('$baseUrl/comments/$postId/$commentId/like');
      }

      bool success = false;
      for (String urlStr in urlPatterns) {
        final url = Uri.parse(urlStr);
        final headers = await _getHeaders();
        final body = urlStr.contains('reactions') ? jsonEncode({'type': 'like'}) : null;

        // Try POST
        var response = await http.post(url, headers: headers, body: body);
        if (response.statusCode >= 200 && response.statusCode < 300) {
          debugPrint('DEBUG: toggleCommentLike SUCCESS: $urlStr (POST)');
          success = true;
          break;
        }
        
        // Try PATCH
        response = await http.patch(url, headers: headers, body: body);
        if (response.statusCode >= 200 && response.statusCode < 300) {
          debugPrint('DEBUG: toggleCommentLike SUCCESS: $urlStr (PATCH)');
          success = true;
          break;
        }
      }
      
      return success;
    } catch (e) {
      debugPrint('ApiService error (toggleCommentLike): $e');
      return false;
    }
  }

  static Future<bool> toggleCommentReaction(
    String commentId, {
    String reactionType = 'like',
    String? postId,
  }) async {
    return toggleCommentLike(commentId, postId: postId);
  }

  // --- Reels ---
  static Future<List<dynamic>> getReels() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/reels?limit=100'),
        headers: await _getHeaders(),
      );
      final res = _processResponse(response, 'getReels');
      return _extractList(res);
    } catch (e) {
      debugPrint('ApiService error (getReels): $e');
      return [];
    }
  }

  static Future<List<dynamic>> getReelComments(String reelId) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/reels/$reelId/comments'),
        headers: await _getHeaders(),
      );
      final res = _processResponse(response, 'getReelComments');
      return _extractList(res);
    } catch (e) {
      debugPrint('ApiService error (getReelComments): $e');
      return [];
    }
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

  static Future<bool> likeReel(String reelId) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/reels/$reelId/like'),
        headers: await _getHeaders(),
      );
      return response.statusCode == 200;
    } catch (e) {
      debugPrint('ApiService error (likeReel): $e');
      return false;
    }
  }

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
          'text': text,
          if (authorId != null) 'author': authorId,
        }),
      );
      return response.statusCode == 201 || response.statusCode == 200;
    } catch (e) {
      debugPrint('ApiService error (addReelComment): $e');
      return false;
    }
  }

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

  // --- Assets ---
  static Future<String?> uploadImage(Uint8List bytes, String fileName) async {
    try {
      final request = http.MultipartRequest(
        'POST',
        Uri.parse('$baseUrl/images/upload'),
      );
      final token = AuthService().authToken.value;
      if (token != null) request.headers['Authorization'] = 'Bearer $token';

      final lowerName = fileName.toLowerCase();
      MediaType mediaType =
          lowerName.endsWith('.mp4') || lowerName.endsWith('.mov')
          ? MediaType('video', 'mp4')
          : MediaType('image', 'jpeg');

      request.files.add(
        http.MultipartFile.fromBytes(
          'image',
          bytes,
          filename: fileName,
          contentType: mediaType,
        ),
      );
      final response = await request.send();
      final respStr = await response.stream.bytesToString();
      if (response.statusCode >= 200 && response.statusCode < 300) {
        final data = jsonDecode(respStr);
        return (data['id'] ??
                data['_id'] ??
                data['data']?['id'] ??
                data['data']?['_id'])
            ?.toString();
      }
    } catch (e) {
      debugPrint('ApiService uploadImage error: $e');
    }
    return null;
  }

  // --- Notifications ---
  static Future<bool> addLocalNotification(Map<String, dynamic> data) async {
    // This is likely a local UI thing, but we can mock it or send back success
    debugPrint('ApiService addLocalNotification: $data');
    return true;
  }

  static Future<List<dynamic>> getNotifications() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/notifications'),
        headers: await _getHeaders(),
      );
      final res = _processResponse(response, 'getNotifications');
      return _extractList(res);
    } catch (e) {
      debugPrint('ApiService error (getNotifications): $e');
      return [];
    }
  }

  // --- Chats ---
  static Future<List<dynamic>> getChats() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/chats?sort=-1'),
        headers: await _getHeaders(),
      );
      final res = _processResponse(response, 'getChats');
      return _extractList(res);
    } catch (e) {
      debugPrint('ApiService error (getChats): $e');
      return [];
    }
  }

  static Future<dynamic> getMessages(
    String conversationId, {
    int page = 1,
    int limit = 20,
  }) async {
    try {
      final response = await http.get(
        Uri.parse(
          '$baseUrl/chats/$conversationId/messages?page=$page&limit=$limit&sort=-createdAt',
        ),
        headers: await _getHeaders(),
      );
      return _processResponse(response, 'getMessages');
    } catch (e) {
      debugPrint('ApiService error (getMessages): $e');
      return {};
    }
  }

  static Future<bool> sendMessage(String conversationId, String content) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/chats/$conversationId/messages'),
        headers: await _getHeaders(),
        body: jsonEncode({'content': content, 'type': 'text'}),
      );
      return response.statusCode >= 200 && response.statusCode < 300;
    } catch (e) {
      debugPrint('ApiService error (sendMessage): $e');
      return false;
    }
  }

  static Future<bool> markChatAsRead(String conversationId) async {
    if (conversationId.length > 25)
      return false; // Skip temporary timestamp IDs

    try {
      final List<String> endpoints = ['read', 'mark-read', 'markAsRead'];
      bool success = false;

      for (String endpoint in endpoints) {
        final url = Uri.parse('$baseUrl/chats/$conversationId/$endpoint');
        // Try POST
        var response = await http.post(url, headers: await _getHeaders());
        if (response.statusCode >= 200 && response.statusCode < 300) {
          // debugPrint('DEBUG: markChatAsRead SUCCESS with $endpoint (POST)');
          success = true;
          break;
        }

        // Try PUT as fallback
        response = await http.put(url, headers: await _getHeaders());
        if (response.statusCode >= 200 && response.statusCode < 300) {
          // debugPrint('DEBUG: markChatAsRead SUCCESS with $endpoint (PUT)');
          success = true;
          break;
        }
      }

      if (!success) {
        debugPrint(
          'DEBUG: markChatAsRead failed for all common endpoints/methods for $conversationId',
        );
      }
      return success;
    } catch (e) {
      debugPrint('ApiService error (markChatAsRead): $e');
      return false;
    }
  }
}
