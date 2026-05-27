import 'package:flutter/material.dart';
import '../api_service.dart';

class ReactionUtils {
  static Map<String, dynamic>? resolveUser(dynamic reaction, [List<dynamic>? usersList]) {
    String? userId;
    if (reaction is String) {
      userId = reaction;
    } else if (reaction is Map) {
      final u = reaction['user'] ?? reaction['userId'] ?? reaction['user_id'];
      if (u is String) {
        userId = u;
      } else if (u is Map) {
        if (u['fullName'] != null || u['name'] != null) {
          return u as Map<String, dynamic>;
        }
        userId = u['_id']?.toString() ?? u['id']?.toString();
      } else if (reaction['fullName'] != null || reaction['name'] != null) {
        return reaction as Map<String, dynamic>;
      } else {
        userId = reaction['_id']?.toString() ?? reaction['id']?.toString();
      }
    }
    
    if (userId != null && usersList != null && usersList.isNotEmpty) {
      try {
        return usersList.firstWhere((u) => u['_id']?.toString() == userId || u['id']?.toString() == userId) as Map<String, dynamic>;
      } catch (_) {}
    }
    
    return null;
  }

  static void showReactionList(BuildContext context, List<dynamic> reactions, [List<dynamic>? usersList]) {
    if (reactions.isEmpty) return;

    showDialog(
      context: context,
      builder: (ctx) {
        return FutureBuilder<List<dynamic>>(
          future: usersList != null ? Future.value(usersList) : ApiService.getUsers(),
          builder: (context, snapshot) {
            final List<dynamic> availableUsers = snapshot.data ?? [];
            return AlertDialog(
              title: const Text("Người đã bày tỏ cảm xúc", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              contentPadding: const EdgeInsets.only(top: 16, bottom: 8),
              content: SizedBox(
                width: 300,
                height: 400,
                child: ListView.builder(
                  itemCount: reactions.length,
                  itemBuilder: (context, index) {
                    final resolvedUser = resolveUser(reactions[index], availableUsers);
                    final String name = resolvedUser?['fullName'] ?? resolvedUser?['name'] ?? 'Người dùng';
                    final String? avatarId = resolvedUser?['profilePicture'] ?? resolvedUser?['avatar'];

                    return ListTile(
                      leading: FutureBuilder<Map<String, String>>(
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
                            child: avatarId == null
                                ? const Icon(Icons.person, color: Colors.white)
                                : null,
                          );
                        },
                      ),
                      title: Text(
                        name,
                        style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 14),
                      ),
                    );
                  },
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text("Đóng"),
                ),
              ],
            );
          },
        );
      },
    );
  }
}
