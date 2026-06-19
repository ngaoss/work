import 'dart:convert';
import 'dart:io';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;
import 'security.dart';

class ApiService {
  static const String siteUrl = 'https://work.deepcode.vn';
  static const String baseUrl = '$siteUrl/api';

  static String _normalizePath(String path) {
    String p = path.replaceAll('/var/www/deepcode-work-assets/', '');
    if (p.startsWith('/')) p = p.substring(1);
    return p;
  }

  static bool isObjectId(String? id) {
    if (id == null) return false;
    return RegExp(r'^[a-fA-F0-9]{24}$').hasMatch(id);
  }

  static IO.Socket? _socket;
  static final StreamController<Map<String, dynamic>> _chatStreamController =
      StreamController<Map<String, dynamic>>.broadcast();
  static Stream<Map<String, dynamic>> get newChatStream =>
      _chatStreamController.stream;

  static final StreamController<Map<String, dynamic>> _userStatusController =
      StreamController<Map<String, dynamic>>.broadcast();
  static Stream<Map<String, dynamic>> get userStatusStream =>
      _userStatusController.stream;

  static final ValueNotifier<int> unreadChatCount = ValueNotifier<int>(0);

  static String? activeChatId = null;

  static bool _listenerAdded = false;

  static void initializeSocket() {
    // Add listener to re-init if token changes (only once)
    if (!_listenerAdded) {
      AuthService().authToken.addListener(() {
        debugPrint('Socket: Token changed, re-initializing...');
        disposeSocket();
        initializeSocket();
      });
      _listenerAdded = true;
    }

    if (_socket != null) return;

    final token = AuthService().authToken.value;
    final options = IO.OptionBuilder()
        .setTransports([
          'websocket',
        ]) // Stick to websocket as polling might be timing out
        .setAuth({'token': token})
        .enableForceNew()
        .enableAutoConnect()
        .setReconnectionAttempts(30)
        .setReconnectionDelay(2000);

    if (token != null) {
      options.setAuth({'token': token});
      options.setExtraHeaders({'Authorization': 'Bearer $token'});
    }

    _socket = IO.io(siteUrl, options.build());

    _socket!.onConnect((_) {
      debugPrint('ApiService Socket connected! (ID: ${_socket!.id})');
      isGlobalServerError.value = false;
    });

    _socket!.onConnectError((err) {
      debugPrint('ApiService Socket ConnectError: $err');
    });

    _socket!.onReconnect((_) {
      debugPrint('ApiService Socket Reconnected');
      isGlobalServerError.value = false;
    });

    _socket!.onReconnectAttempt((attempt) {
      debugPrint('ApiService Socket Reconnect Attempt: $attempt');
      if (attempt >= 2) {
        isGlobalServerError.value = true;
      }
    });

    _socket!.onReconnectError((err) {
      debugPrint('ApiService Socket ReconnectError: $err');
    });

    _socket!.onAny((event, data) {
      if (data is Map &&
          (data.containsKey('text') ||
              data.containsKey('content') ||
              data.containsKey('message')) &&
          !event.toString().contains('newMessage') &&
          !event.toString().contains('new_message') &&
          !event.toString().contains('newConversation') &&
          !event.toString().contains('new_conversation')) {
        // Broadcast any event that looks like a message or update
        final mapData = Map<String, dynamic>.from(data);
        mapData['_socketEvent'] = event.toString();
        _chatStreamController.add(mapData);
      }
    });

    _socket!.on('new_message', (data) {
      if (data is Map) {
        try {
          final mapData = Map<String, dynamic>.from(data);
          mapData['_socketEvent'] = 'new_message';
          _chatStreamController.add(mapData);
        } catch (e) {
          debugPrint('Socket: Error broadcasting new_message: $e');
        }
      }
    });

    _socket!.on('newMessage', (data) {
      if (data is Map) {
        try {
          final mapData = Map<String, dynamic>.from(data);
          mapData['_socketEvent'] = 'newMessage';
          _chatStreamController.add(mapData);
        } catch (e) {
          debugPrint('Socket: Error broadcasting newMessage: $e');
        }
      }
    });

    _socket!.on('new_conversation', (data) {
      if (data is Map) {
        _chatStreamController.add({
          ...Map<String, dynamic>.from(data),
          'isNewConversation': true,
        });
      }
    });

    _socket!.on('newConversation', (data) {
      if (data is Map) {
        _chatStreamController.add({
          ...Map<String, dynamic>.from(data),
          'isNewConversation': true,
        });
      }
    });

    _socket!.on('update_conversation', (data) {
      if (data is Map) {
        _chatStreamController.add({
          ...Map<String, dynamic>.from(data),
          'isUpdateConversation': true,
        });
      }
    });

    _socket!.on('updateConversation', (data) {
      if (data is Map) {
        _chatStreamController.add({
          ...Map<String, dynamic>.from(data),
          'isUpdateConversation': true,
        });
      }
    });

    _socket!.on('display_typing', (data) {
      if (data is Map) {
        _chatStreamController.add({
          ...Map<String, dynamic>.from(data),
          'type': 'typing',
        });
      }
    });

    _socket!.on('user_online', (data) {
      if (data is Map) {
        _userStatusController.add({
          ...Map<String, dynamic>.from(data),
          'status': 'online',
          'isOnline': true,
        });
      }
    });

    _socket!.on('user_offline', (data) {
      if (data is Map) {
        _userStatusController.add({
          ...Map<String, dynamic>.from(data),
          'status': 'offline',
          'isOnline': false,
        });
      }
    });

    _socket!.on('survey_updated', (data) {
      if (data is Map) {
        try {
          _chatStreamController.add({
            ...Map<String, dynamic>.from(data),
            'socketEventType': 'survey_updated',
          });
        } catch (e) {
          debugPrint('Socket: Error broadcasting survey_updated: $e');
        }
      }
    });

    _socket!.on('message_reaction_updated', (data) {
      if (data is Map) {
        try {
          _chatStreamController.add({
            ...Map<String, dynamic>.from(data),
            'socketEventType': 'message_reaction_updated',
          });
        } catch (e) {
          debugPrint('Socket: Error broadcasting message_reaction_updated: $e');
        }
      }
    });

    _socket!.on('chat_updated', (data) {
      if (data is Map) {
        _chatStreamController.add({
          ...Map<String, dynamic>.from(data),
          'socketEventType': 'chat_updated',
        });
      }
    });

    _socket!.on('messages_read_updated', (data) {
      if (data is Map) {
        try {
          _chatStreamController.add({
            ...Map<String, dynamic>.from(data),
            'socketEventType': 'messages_read_updated',
          });
        } catch (e) {
          debugPrint('Socket: Error broadcasting messages_read_updated: $e');
        }
      }
    });

    _socket!.onDisconnect((reason) {
      debugPrint('ApiService Socket disconnected: $reason');
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
    return Uri.encodeFull('$siteUrl/${_normalizePath(s)}');
  }

  static String resolveImageUrl(dynamic path) {
    if (path == null) return '';
    final String s = path.toString().trim();
    if (s.isEmpty) return '';
    if (s.startsWith('http')) return Uri.encodeFull(s);
    if (RegExp(r'^[a-fA-F0-9]{24}$').hasMatch(s)) {
      return '$baseUrl/images/$s';
    }
    return Uri.encodeFull('$siteUrl/${_normalizePath(s)}');
  }

  static String resolveFileUrl(dynamic path, {String? fileName}) {
    if (path == null) return '';
    final String s = path.toString().trim();
    if (s.isEmpty) return '';
    if (s.startsWith('http')) return Uri.encodeFull(s);

    final token = AuthService().authToken.value;
    String finalUrl = "";
    if (RegExp(r'^[a-fA-F0-9]{24}$').hasMatch(s)) {
      final ext = (fileName ?? s).split('.').last.toLowerCase();
      final isImage = ['jpg', 'jpeg', 'png', 'gif', 'webp'].contains(ext);
      if (isImage) {
        finalUrl = '$baseUrl/images/$s';
      } else {
        finalUrl = '$baseUrl/documents/download/$s';
      }
    } else {
      finalUrl = '$siteUrl/${_normalizePath(s)}';
    }

    if (token != null && token.isNotEmpty) {
      final lowerUrl = finalUrl.toLowerCase();
      final isImg =
          lowerUrl.contains('/images/') ||
          lowerUrl.endsWith('.jpg') ||
          lowerUrl.endsWith('.jpeg') ||
          lowerUrl.endsWith('.png') ||
          lowerUrl.endsWith('.gif');
      if (!isImg) {
        final sep = finalUrl.contains('?') ? '&' : '?';
        return Uri.encodeFull('$finalUrl${sep}token=$token');
      }
    }
    return Uri.encodeFull(finalUrl);
  }

  static Future<Map<String, String>> getAssetHeaders() async {
    final token = AuthService().authToken.value;
    return {if (token != null) 'Authorization': 'Bearer $token'};
  }

  static final ValueNotifier<bool> isGlobalServerError = ValueNotifier(false);

  static Future<Map<String, String>> _getHeaders() async {
    final token = AuthService().authToken.value;
    return {
      'Content-Type': 'application/json; charset=UTF-8',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  static Future<Map<String, String>> getAuthHeaders() => getAssetHeaders();

  static List<dynamic> extractList(dynamic data) {
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
        'documents',
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
      if (data == null) return [{'error': true}];
      return extractList(data);
    } catch (e) {
      debugPrint('ApiService error (getUsers): $e');
      return [{'error': true}];
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
      return extractList(data);
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
      if (res == null) return {'posts': [], 'totalPages': 0, 'error': true};
      if (res is Map<String, dynamic>) {
        return {
          'posts': extractList(res),
          'totalPages':
              int.tryParse(res['totalPages']?.toString() ?? '') ??
              int.tryParse(res['pages']?.toString() ?? '') ??
              int.tryParse(res['total_pages']?.toString() ?? '') ??
              1,
        };
      }
      return {'posts': extractList(res), 'totalPages': 1};
    } catch (e) {
      debugPrint('ApiService error (getPosts): $e');
      return {'posts': [], 'totalPages': 0, 'error': true};
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

      debugPrint(
        'DEBUG: togglePostLike failed for $postId: ${response.statusCode}',
      );
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
      return extractList(res);
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

  static Future<bool> toggleCommentLike(
    String commentId, {
    String? postId,
  }) async {
    try {
      // Based on provided URL: /api/comments/like/:id
      final List<String> urlPatterns = [
        '$baseUrl/comments/like/$commentId', // Pattern from user
        '$baseUrl/comments/$commentId/like', // Traditional pattern
        '$baseUrl/comments/$commentId/reactions', // Reaction pattern
      ];

      if (postId != null && postId.isNotEmpty) {
        urlPatterns.add('$baseUrl/posts/$postId/comments/$commentId/like');
        urlPatterns.add('$baseUrl/comments/$postId/$commentId/like');
      }

      bool success = false;
      for (String urlStr in urlPatterns) {
        final url = Uri.parse(urlStr);
        final headers = await _getHeaders();
        final body = urlStr.contains('reactions')
            ? jsonEncode({'type': 'like'})
            : null;

        // Try POST
        var response = await http.post(url, headers: headers, body: body);
        if (response.statusCode >= 200 && response.statusCode < 300) {
          // debugPrint('DEBUG: toggleCommentLike SUCCESS: $urlStr (POST)');
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
      if (res == null) return [{'error': true}];
      return extractList(res);
    } catch (e) {
      debugPrint('ApiService error (getReels): $e');
      return [{'error': true}];
    }
  }

  static Future<List<dynamic>> getReelComments(String reelId) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/reels/$reelId/comments'),
        headers: await _getHeaders(),
      );
      final res = _processResponse(response, 'getReelComments');
      return extractList(res);
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
      return response.statusCode >= 200 && response.statusCode < 300;
    } catch (e) {
      debugPrint('ApiService error (createReel): $e');
      return false;
    }
  }

  static Future<Map<String, dynamic>> deleteReel(String id) async {
    try {
      final response = await http.delete(
        Uri.parse('$baseUrl/reels/$id'),
        headers: await _getHeaders(),
      );
      if (response.statusCode >= 200 && response.statusCode < 300) {
        return {'success': true, 'message': 'Đã xóa reel thành công'};
      }
      return {'success': false, 'message': 'Lỗi máy chủ (${response.statusCode})'};
    } catch (e) {
      debugPrint('ApiService error (deleteReel): $e');
      return {'success': false, 'message': e.toString()};
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
      return extractList(res);
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
      debugPrint('uploadImage status=${response.statusCode} body=$respStr');

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final data = jsonDecode(respStr);
        // Server trả về: {"image": {"_id": "...", "filename": "..."}}
        final id =
            (data['image']?['_id'] ??
                    data['image']?['id'] ??
                    data['_id'] ??
                    data['id'] ??
                    data['data']?['_id'] ??
                    data['data']?['id'] ??
                    data['url'] ??
                    data['imageUrl'] ??
                    data['path'])
                ?.toString();
        debugPrint('uploadImage parsed id=$id');
        return id;
      }
    } catch (e) {
      debugPrint('ApiService uploadImage error: $e');
    }
    return null;
  }

  // --- Attendance ---
  static Future<Map<String, dynamic>> getMyAttendance({
    String? period,
    String? from,
    String? to,
  }) async {
    try {
      String url = '$baseUrl/attendance/me';
      List<String> queryParams = [];
      if (period != null) queryParams.add('period=$period');
      if (from != null) queryParams.add('from=$from');
      if (to != null) queryParams.add('to=$to');
      if (queryParams.isNotEmpty) {
        url += '?${queryParams.join('&')}';
      }

      final response = await http.get(
        Uri.parse(url),
        headers: await _getHeaders(),
      );
      final res = _processResponse(response, 'getMyAttendance');
      if (res is Map<String, dynamic>) {
        return res;
      }
      if (res is List && res.isNotEmpty) {
        return {'history': res};
      }
      return {'history': []};
    } catch (e) {
      debugPrint('ApiService error (getMyAttendance): $e');
      return {'history': []};
    }
  }

  static Future<bool> toggleAttendance(
    bool isCheckIn, {
    double? lat,
    double? lon,
    String? address,
  }) async {
    try {
      final endpoint = '/attendance/check';

      final body = <String, dynamic>{
        'type': isCheckIn ? 'checkin' : 'checkout',
      };
      if (lat != null) body['lat'] = lat;
      if (lon != null) body['lon'] = lon;
      if (address != null) body['address'] = address;

      final response = await http.post(
        Uri.parse('$baseUrl$endpoint'),
        headers: await _getHeaders(),
        body: jsonEncode(body),
      );

      return response.statusCode >= 200 && response.statusCode < 300;
    } catch (e) {
      debugPrint('ApiService error (toggleAttendance): $e');
      return false;
    }
  }

  // --- Documents ---
  static Future<Map<String, dynamic>> getDocuments({String? parentId}) async {
    try {
      final queryParams = parentId != null ? '?parentId=$parentId' : '';
      final response = await http.get(
        Uri.parse('$baseUrl/documents$queryParams'),
        headers: await _getHeaders(),
      );
      final res = _processResponse(response, 'getDocuments');

      if (res is Map<String, dynamic> &&
          (res.containsKey('folders') || res.containsKey('files'))) {
        if (res['folders'] is List || res['files'] is List) {
          return res;
        }
      }

      final allItems = extractList(res);
      return {
        'folders': allItems
            .where((e) => e is Map && e['type'] == 'folder')
            .toList(),
        'files': allItems
            .where(
              (e) => e is Map && (e['type'] == 'file' || e['type'] == null),
            )
            .toList(),
      };
    } catch (e) {
      debugPrint('ApiService error (getDocuments): $e');
      return {'folders': [], 'files': []};
    }
  }

  static Future<Map<String, dynamic>?> createFolder(
    String name, {
    String? parentId,
  }) async {
    try {
      final body = <String, dynamic>{'name': name};
      if (parentId != null) body['parentId'] = parentId;
      final response = await http.post(
        Uri.parse('$baseUrl/documents/folder'),
        headers: await _getHeaders(),
        body: jsonEncode(body),
      );
      if (response.statusCode == 201 || response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data;
      }
      return null;
    } catch (e) {
      debugPrint('ApiService error (createFolder): $e');
      return null;
    }
  }

  static Future<dynamic> uploadDocuments(
    List<String> filePaths, {
    String? parentId,
  }) async {
    try {
      final request = http.MultipartRequest(
        'POST',
        Uri.parse('$baseUrl/documents/upload'),
      );
      final token = AuthService().authToken.value;
      if (token != null) request.headers['Authorization'] = 'Bearer $token';
      if (parentId != null) request.fields['parentId'] = parentId;

      for (final path in filePaths) {
        final file = await http.MultipartFile.fromPath('documents', path);
        request.files.add(file);
      }

      final streamedResponse = await request.send();
      final respStr = await streamedResponse.stream.bytesToString();
      debugPrint(
        'uploadDocuments status=${streamedResponse.statusCode} body=$respStr',
      );

      if (streamedResponse.statusCode >= 200 &&
          streamedResponse.statusCode < 300) {
        return jsonDecode(respStr);
      }
      return null;
    } catch (e) {
      debugPrint('ApiService error (uploadDocuments): $e');
      return null;
    }
  }

  static Future<bool> renameDocument(String id, String newName) async {
    try {
      final response = await http.put(
        Uri.parse('$baseUrl/documents/$id'),
        headers: await _getHeaders(),
        body: jsonEncode({'name': newName}),
      );
      // debugPrint(
      //   'renameDocument status: ${response.statusCode} - ${response.body}',
      // );
      if (response.statusCode >= 200 && response.statusCode < 300) return true;

      final response2 = await http.put(
        Uri.parse('$baseUrl/documents/rename/$id'),
        headers: await _getHeaders(),
        body: jsonEncode({'newName': newName}),
      );
      // debugPrint(
      //   'renameDocument (fallback) status: ${response2.statusCode} - ${response2.body}',
      // );
      return response2.statusCode >= 200 && response2.statusCode < 300;
    } catch (e) {
      debugPrint('ApiService error (renameDocument): $e');
      return false;
    }
  }

  static Future<bool> deleteDocument(String id) async {
    try {
      final response = await http.delete(
        Uri.parse('$baseUrl/documents/$id'),
        headers: await _getHeaders(),
      );
      return response.statusCode >= 200 && response.statusCode < 300;
    } catch (e) {
      debugPrint('ApiService error (deleteDocument): $e');
      return false;
    }
  }

  static Future<bool> shareDocument(String docId, List<String> userIds) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/documents/share/$docId'),
        headers: await _getHeaders(),
        body: jsonEncode({'userIds': userIds}),
      );
      return response.statusCode >= 200 && response.statusCode < 300;
    } catch (e) {
      debugPrint('ApiService error (shareDocument): $e');
      return false;
    }
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
      return extractList(res);
    } catch (e) {
      debugPrint('ApiService error (getNotifications): $e');
      return [];
    }
  }

  static Future<bool> markNotificationsAsRead() async {
    try {
      final response = await http.put(
        Uri.parse('$baseUrl/notifications/mark-all-read'),
        headers: await _getHeaders(),
      );
      return response.statusCode >= 200 && response.statusCode < 300;
    } catch (e) {
      debugPrint('ApiService error (markNotificationsAsRead): $e');
      return false;
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
      return extractList(res);
    } catch (e) {
      debugPrint('ApiService error (getChats): $e');
      return [];
    }
  }

  static Future<Map<String, dynamic>?> getChatDetails(String id) async {
    try {
      final chats = await getChats();
      for (var chat in chats) {
        if (chat['_id']?.toString() == id || chat['id']?.toString() == id) {
          return chat as Map<String, dynamic>;
        }
      }
      return null;
    } catch (e) {
      debugPrint('ApiService error (getChatDetails workaround): $e');
      return null;
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

  /// Send message via Socket (matches backend 'send_message' event).
  /// Falls back to REST if socket is unavailable.
  static Future<bool> sendMessage(
    String conversationId,
    String content, {
    String? replyTo,
    List<Map<String, dynamic>>? media,
    Map<String, dynamic>? survey,
    String type = 'text',
  }) async {
    // Prefer socket if connected
    if (_socket != null && (_socket!.connected)) {
      try {
        final payload = {
          'conversationId': conversationId,
          'text': content,
          'type': type,
          if (replyTo != null) 'replyTo': replyTo,
          if (media != null) 'media': media,
          if (survey != null) 'survey': survey,
        };
        // debugPrint(
        //   'DEBUG [Socket SendMessage]: Emit send_message with payload: $payload',
        // );
        _socket!.emit('send_message', payload);
        return true;
      } catch (e) {
        debugPrint('Socket sendMessage error, falling back to REST: $e');
      }
    }

    // Fallback: REST API
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/chats/$conversationId/messages'),
        headers: await _getHeaders(),
        body: jsonEncode({
          'text': content,
          'content': content,
          'type': type,
          if (replyTo != null) 'replyTo': replyTo,
          if (media != null) 'media': media,
        }),
      );
      return response.statusCode >= 200 && response.statusCode < 300;
    } catch (e) {
      debugPrint('ApiService error (sendMessage REST): $e');
      return false;
    }
  }

  /// Send a message with image/media attachment.
  static Future<bool> sendMediaMessage(
    String conversationId, {
    required String imageId,
    required String imageUrl,
    String type = 'image',
  }) async {
    // Prefer socket
    if (_socket != null && _socket!.connected) {
      try {
        _socket!.emit('send_message', {
          'conversationId': conversationId,
          'chatId': conversationId,
          'text': '',
          'content': '',
          'type': type,
          'media': [
            {'url': imageUrl, 'type': type, '_id': imageId},
          ],
          'images': [imageUrl],
          'imageUrl': imageUrl,
        });
        return true;
      } catch (e) {
        debugPrint('Socket sendMediaMessage error, falling back to REST: $e');
      }
    }

    // Fallback: REST
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/chats/$conversationId/messages'),
        headers: await _getHeaders(),
        body: jsonEncode({
          'text': '',
          'content': '',
          'type': type,
          'media': [
            {'url': imageUrl, 'type': type, '_id': imageId},
          ],
          'images': [imageUrl],
          'imageUrl': imageUrl,
        }),
      );
      return response.statusCode >= 200 && response.statusCode < 300;
    } catch (e) {
      debugPrint('ApiService error (sendMediaMessage REST): $e');
      return false;
    }
  }

  /// Vote in a survey
  static Future<bool> voteSurvey(String messageId, int optionIndex) async {
    try {
      final response = await http.put(
        Uri.parse('$baseUrl/chats/messages/$messageId/vote'),
        headers: await _getHeaders(),
        body: jsonEncode({'optionIndex': optionIndex}),
      );
      return response.statusCode >= 200 && response.statusCode < 300;
    } catch (e) {
      debugPrint('ApiService error (voteSurvey): $e');
      return false;
    }
  }

  /// Recalls a message (soft delete)
  static Future<bool> recallMessage(
    String conversationId,
    String messageId,
  ) async {
    // Luôn ưu tiên gọi REST API (vì React dùng REST để xóa trên DB),
    // không return sớm ở đây chỉ với socket emit.
    try {
      // 0. The EXACT endpoint from React frontend
      final reactRes = await http.put(
        Uri.parse('$baseUrl/chats/messages/$messageId/recall'),
        headers: await _getHeaders(),
      );
      if (reactRes.statusCode >= 200 && reactRes.statusCode < 300) return true;

      // 1. DELETE .../recall
      final r1 = await http.delete(
        Uri.parse('$baseUrl/chats/$conversationId/messages/$messageId/recall'),
        headers: await _getHeaders(),
      );
      if (r1.statusCode >= 200 && r1.statusCode < 300) return true;

      // 2. POST .../recall
      final r2 = await http.post(
        Uri.parse('$baseUrl/chats/$conversationId/messages/$messageId/recall'),
        headers: await _getHeaders(),
      );
      if (r2.statusCode >= 200 && r2.statusCode < 300) return true;

      // 3. DELETE generic
      final r3 = await http.delete(
        Uri.parse('$baseUrl/chats/$conversationId/messages/$messageId'),
        headers: await _getHeaders(),
      );
      if (r3.statusCode >= 200 && r3.statusCode < 300) return true;

      // 4. PATCH status
      final r4 = await http.patch(
        Uri.parse('$baseUrl/chats/$conversationId/messages/$messageId'),
        headers: await _getHeaders(),
        body: jsonEncode({
          'status': 'recalled',
          'isRecalled': true,
          'text': 'Tin nhắn đã được thu hồi',
        }),
      );
      if (r4.statusCode >= 200 && r4.statusCode < 300) return true;

      // 5. Try without conversationId prefix (global message ID)
      final r5 = await http.delete(
        Uri.parse('$baseUrl/messages/$messageId'),
        headers: await _getHeaders(),
      );
      if (r5.statusCode >= 200 && r5.statusCode < 300) return true;

      return false;
    } catch (e) {
      debugPrint('ApiService error (recallMessage): $e');
      return false;
    }
  }

  static Future<bool> reactToMessage(String messageId, String emoji) async {
    // Safety check for temporary IDs
    if (messageId.length > 25) {
      debugPrint('ApiService: Skipping reaction for temporary ID: $messageId');
      return false;
    }

    try {
      final List<String> endpoints = [
        '$baseUrl/chats/messages/$messageId/react',
        '$baseUrl/messages/$messageId/react',
        '$baseUrl/chats/$messageId/react',
      ];

      for (String urlStr in endpoints) {
        final res = await http.put(
          Uri.parse(urlStr),
          headers: await _getHeaders(),
          body: jsonEncode({'emoji': emoji}),
        );

        if (res.statusCode >= 200 && res.statusCode < 300) {
          // debugPrint('ApiService: reactToMessage SUCCESS at $urlStr');
          return true;
        }
        debugPrint(
          'ApiService: reactToMessage FAILED at $urlStr (${res.statusCode}): ${res.body}',
        );
      }
      return false;
    } catch (e) {
      debugPrint('ApiService error (reactToMessage): $e');
      return false;
    }
  }

  /// Emit typing status to other participants in the conversation.
  static void sendTyping(String conversationId, bool isTyping) {
    _socket?.emit('typing', {
      'conversationId': conversationId,
      'isTyping': isTyping,
    });
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

  /// Update Group Settings (Theme Color, Name, etc.)
  static Future<bool> updateGroupInfo(
    String conversationId,
    Map<String, dynamic> updates,
  ) async {
    try {
      debugPrint('ApiService: updateGroupInfo start. id: $conversationId, updates: $updates');
      final response = await http.put(
        Uri.parse('$baseUrl/chats/$conversationId'),
        headers: await _getHeaders(),
        body: jsonEncode(updates),
      );
      debugPrint('ApiService: updateGroupInfo response status: ${response.statusCode}');
      debugPrint('ApiService: updateGroupInfo response body: ${response.body}');
      return response.statusCode >= 200 && response.statusCode < 300;
    } catch (e) {
      debugPrint('ApiService error (updateGroupInfo): $e');
      return false;
    }
  }

  /// Add members to a group
  static Future<bool> addMembers(
    String conversationId,
    List<String> userIds,
  ) async {
    try {
      final response = await http.put(
        Uri.parse('$baseUrl/chats/$conversationId/add-members'),
        headers: await _getHeaders(),
        body: jsonEncode({'newUserIds': userIds}),
      );
      return response.statusCode >= 200 && response.statusCode < 300;
    } catch (e) {
      debugPrint('ApiService error (addMembers): $e');
      return false;
    }
  }

  /// Remove a member from a group
  static Future<bool> removeMember(
    String conversationId,
    String memberId,
  ) async {
    try {
      final response = await http.put(
        Uri.parse('$baseUrl/chats/$conversationId/remove-member'),
        headers: await _getHeaders(),
        body: jsonEncode({'memberId': memberId}),
      );
      return response.statusCode >= 200 && response.statusCode < 300;
    } catch (e) {
      debugPrint('ApiService error (removeMember): $e');
      return false;
    }
  }

  /// Delete a Group
  static Future<bool> deleteGroup(String conversationId) async {
    try {
      final response = await http.delete(
        Uri.parse('$baseUrl/chats/$conversationId'),
        headers: await _getHeaders(),
      );
      return response.statusCode >= 200 && response.statusCode < 300;
    } catch (e) {
      debugPrint('ApiService error (deleteGroup): $e');
      return false;
    }
  }

  /// Create a New Chat / Group
  static Future<Map<String, dynamic>?> createChat(
    List<String> userIds, {
    bool isGroup = false,
    String groupName = "Nhóm mới",
  }) async {
    try {
      if (isGroup) {
        // Create Group Chat: POST /api/chats/group
        debugPrint('ApiService: Creating group chat with members: $userIds');
        final response = await http.post(
          Uri.parse('$baseUrl/chats/group'),
          headers: await _getHeaders(),
          body: jsonEncode({'name': groupName, 'participantIds': userIds}),
        );
        debugPrint(
          'ApiService: createChat group response ${response.statusCode} - ${response.body}',
        );
        if (response.statusCode >= 200 && response.statusCode < 300) {
          final data = jsonDecode(response.body);
          if (data is Map<String, dynamic>) {
            // Normalize keys for frontend compatibility
            if (data.containsKey('groupName') && !data.containsKey('name')) {
              data['name'] = data['groupName'];
            }
            if (data.containsKey('members') &&
                !data.containsKey('participants')) {
              data['participants'] = data['members'];
            }
          }
          return data;
        }

        if (response.statusCode != 404) {
          debugPrint(
            'ApiService: createChat group failed with ${response.statusCode}, returning null instead of fallback',
          );
          return null;
        }
      } else {
        // Create Private 1-1 Chat: POST /api/chats/private
        debugPrint(
          'ApiService: Creating private chat with targetUserId: ${userIds.first}',
        );
        final response = await http.post(
          Uri.parse('$baseUrl/chats/private'),
          headers: await _getHeaders(),
          body: jsonEncode({'targetUserId': userIds.first}),
        );
        debugPrint(
          'ApiService: createChat private response ${response.statusCode} - ${response.body}',
        );
        if (response.statusCode >= 200 && response.statusCode < 300) {
          final data = jsonDecode(response.body);
          if (data is Map<String, dynamic>) {
            // Normalize keys for frontend compatibility
            if (data.containsKey('members') &&
                !data.containsKey('participants')) {
              data['participants'] = data['members'];
            }
          }
          return data;
        }
        if (response.statusCode != 404) {
          debugPrint(
            'ApiService: createChat private failed with ${response.statusCode}, returning null instead of fallback',
          );
          return null;
        }
      }

      // Fallback: Old endpoint /api/chats (if new endpoints failed with 404)
      debugPrint('ApiService: Falling back to old /api/chats endpoint');
      final payload = isGroup
          ? {'isGroup': true, 'name': groupName, 'users': jsonEncode(userIds)}
          : {'userId': userIds.first};

      final fallbackResponse = await http.post(
        Uri.parse('$baseUrl/chats'),
        headers: await _getHeaders(),
        body: jsonEncode(payload),
      );

      debugPrint(
        'ApiService: fallback createChat response ${fallbackResponse.statusCode} - ${fallbackResponse.body}',
      );
      if (fallbackResponse.statusCode >= 200 &&
          fallbackResponse.statusCode < 300) {
        return jsonDecode(fallbackResponse.body);
      }
      return null;
    } catch (e) {
      debugPrint('ApiService error (createChat): $e');
      return null;
    }
  }

  static Future<List<dynamic>> getGroups() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/groups'),
        headers: await _getHeaders(),
      );
      if (response.statusCode >= 200 && response.statusCode < 300) {
        final decoded = jsonDecode(response.body);
        if (decoded is List) return decoded;
        if (decoded is Map && decoded.containsKey('data')) {
          return decoded['data'] as List<dynamic>;
        }
        return [];
      }
      return [];
    } catch (e) {
      debugPrint('ApiService error (getGroups): $e');
      return [];
    }
  }

  /// Uploads a document/file to the server.
  static Future<Map<String, dynamic>?> uploadDocument(
    File file, {
    String? conversationId,
  }) async {
    try {
      final url = Uri.parse('$baseUrl/documents/upload');
      final request = http.MultipartRequest('POST', url);
      request.headers.addAll(await _getHeaders());

      request.files.add(
        await http.MultipartFile.fromPath('documents', file.path),
      );
      if (conversationId != null) {
        request.fields['conversationId'] = conversationId;
      }

      final responseStream = await request.send();
      final responseBody = await responseStream.stream.bytesToString();

      if (responseStream.statusCode >= 200 && responseStream.statusCode < 300) {
        final decoded = jsonDecode(responseBody);
        if (decoded is List) {
          return decoded.isNotEmpty
              ? decoded[0] as Map<String, dynamic>
              : {'success': false, 'message': 'Empty list from server'};
        }
        return decoded as Map<String, dynamic>;
      } else {
        debugPrint(
          'ApiService error (uploadDocument): ${responseStream.statusCode} $responseBody',
        );
      }
      return null;
    } catch (e) {
      debugPrint('ApiService error (uploadDocument): $e');
      return null;
    }
  }
}
