#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Patch chat_detail_screen.dart to add:
1. Message recall (thu hoi tin nhan)
2. Message reply (phan hoi tin nhan)
"""

import re

FILE = r"lib\features\chat\presentation\pages\chat_detail_screen.dart"

with open(FILE, "rb") as f:
    raw = f.read()

# Detect line ending
if b"\r\n" in raw:
    LE = b"\r\n"
    content = raw.decode("utf-8").replace("\r\n", "\n")
else:
    LE = b"\n"
    content = raw.decode("utf-8")

# ─── PATCH 1: Add _replyingTo field after _editingMessageId ─────────────────
OLD1 = "  int? _editingMessageId;\n\n  // Pagination"
NEW1 = "  int? _editingMessageId;\n  Map<String, dynamic>? _replyingTo;\n  bool _isOtherTyping = false;\n  Timer? _typingDebounce;\n\n  // Pagination"
if OLD1 in content:
    content = content.replace(OLD1, NEW1, 1)
    print("PATCH 1 applied: added _replyingTo, _isOtherTyping, _typingDebounce")
else:
    print("PATCH 1 SKIPPED (already applied or not found)")

# ─── PATCH 2: dispose – add _typingDebounce.cancel() ────────────────────────
OLD2 = "    _chatSubscription?.cancel();\n    _pollingTimer?.cancel();\n    _scrollController.dispose();"
NEW2 = "    _chatSubscription?.cancel();\n    _pollingTimer?.cancel();\n    _typingDebounce?.cancel();\n    _scrollController.dispose();"
if OLD2 in content:
    content = content.replace(OLD2, NEW2, 1)
    print("PATCH 2 applied: dispose _typingDebounce")
else:
    print("PATCH 2 SKIPPED")

# ─── PATCH 3: _parseMessage – add isRecalled + replyTo ──────────────────────
OLD3 = '      "text": msgData["text"] ?? msgData["content"] ?? "",\n      "isSender": isSender,\n      "imagePath":'
NEW3 = '      "text": msgData["text"] ?? msgData["content"] ?? "",\n      "isSender": isSender,\n      "isRecalled": msgData["isRecalled"] == true || msgData["status"] == "recalled",\n      "replyTo": msgData["replyTo"] ?? msgData["parentMessage"],\n      "imagePath":'
if OLD3 in content:
    content = content.replace(OLD3, NEW3, 1)
    print("PATCH 3 applied: _parseMessage isRecalled + replyTo")
else:
    print("PATCH 3 SKIPPED")

# ─── PATCH 4: _sendMessage – add replyTo support ────────────────────────────
OLD4 = (
    "        // Optimistic update\n"
    "        final tempId = DateTime.now().millisecondsSinceEpoch.toString();\n"
    "        setState(() {\n"
    "          _messages.insert(0, {\n"
    '            "id": tempId,\n'
    '            "text": text,\n'
    '            "isSender": true,\n'
    '            "isEdited": false,\n'
    '            "time":\n'
    '                "${DateTime.now().hour}:${DateTime.now().minute.toString().padLeft(2, \'0\')}",\n'
    '            "senderName": "Bạn",\n'
    "          });\n"
    "          _controller.clear();\n"
    "          _showEmoji = false;\n"
    "        });\n"
    "\n"
    "        final success = await ApiService.sendMessage(\n"
    "          _activeConversationId!,\n"
    "          text,\n"
    "        );"
)
NEW4 = (
    "        final replyMsg = _replyingTo;\n"
    "        final replyToId = replyMsg?[\"id\"]?.toString();\n"
    "\n"
    "        // Optimistic update\n"
    "        final tempId = DateTime.now().millisecondsSinceEpoch.toString();\n"
    "        setState(() {\n"
    "          _messages.insert(0, {\n"
    '            "id": tempId,\n'
    '            "text": text,\n'
    '            "isSender": true,\n'
    '            "isEdited": false,\n'
    '            "replyTo": replyMsg != null ? {\n'
    '              "_id": replyMsg["id"],\n'
    '              "text": replyMsg["text"],\n'
    '              "sender": {"fullName": replyMsg["senderName"]},\n'
    "            } : null,\n"
    '            "time":\n'
    '                "${DateTime.now().hour}:${DateTime.now().minute.toString().padLeft(2, \'0\')}",\n'
    '            "senderName": "Bạn",\n'
    "          });\n"
    "          _controller.clear();\n"
    "          _replyingTo = null;\n"
    "          _showEmoji = false;\n"
    "        });\n"
    "\n"
    "        final success = await ApiService.sendMessage(\n"
    "          _activeConversationId!,\n"
    "          text,\n"
    "          replyTo: replyToId,\n"
    "        );"
)
if OLD4 in content:
    content = content.replace(OLD4, NEW4, 1)
    print("PATCH 4 applied: _sendMessage with replyTo")
else:
    print("PATCH 4 SKIPPED")

# ─── PATCH 5: Replace _deleteMessage + _startEditing + _showOptions ──────────
OLD5 = (
    "  void _deleteMessage(int id) {\n"
    "    setState(() {\n"
    '      _messages.removeWhere((m) => m["id"] == id);\n'
    "    });\n"
    "    ScaffoldMessenger.of(\n"
    '      context,\n'
    '    ).showSnackBar(const SnackBar(content: Text("Đã xóa tin nhắn")));\n'
    "  }\n"
    "\n"
    "  void _startEditing(Map<String, dynamic> msg) {\n"
    '    if (msg["imagePath"] != null) return;\n'
    "    setState(() {\n"
    '      _editingMessageId = msg["id"];\n'
    '      _controller.text = msg["text"] ?? "";\n'
    "      _showEmoji = false;\n"
    "    });\n"
    "    _focusNode.requestFocus();\n"
    "  }\n"
    "\n"
    "  void _showOptions(BuildContext context, Map<String, dynamic> msg) {\n"
    '    if (!msg["isSender"]) return;\n'
    "\n"
    "    showModalBottomSheet(\n"
    "      context: context,\n"
    "      builder: (context) => Wrap(\n"
    "        children: [\n"
    '          if (msg["imagePath"] == null)\n'
    "            ListTile(\n"
    "              leading: const Icon(Icons.edit_outlined, color: Colors.blue),\n"
    "              title: const Text(\n"
    '                "Chỉnh sửa tin nhắn",\n'
    "                style: TextStyle(color: Colors.blue),\n"
    "              ),\n"
    "              onTap: () {\n"
    "                Navigator.pop(context);\n"
    "                _startEditing(msg);\n"
    "              },\n"
    "            ),\n"
    "          ListTile(\n"
    "            leading: const Icon(Icons.delete_outline, color: Colors.red),\n"
    "            title: const Text(\n"
    '              "Xóa tin nhắn",\n'
    "              style: TextStyle(color: Colors.red),\n"
    "            ),\n"
    "            onTap: () {\n"
    "              Navigator.pop(context);\n"
    '              _deleteMessage(msg["id"]);\n'
    "            },\n"
    "          ),\n"
    "          ListTile(\n"
    "            leading: const Icon(Icons.copy_outlined),\n"
    '            title: const Text("Sao chép"),\n'
    "            onTap: () => Navigator.pop(context),\n"
    "          ),\n"
    "        ],\n"
    "      ),\n"
    "    );\n"
    "  }"
)

NEW5 = (
    "  void _recallMessage(Map<String, dynamic> msg) async {\n"
    '    final msgId = msg["id"]?.toString();\n'
    "    if (msgId == null || _activeConversationId == null) return;\n"
    "\n"
    "    // Optimistic update\n"
    "    setState(() {\n"
    '      final index = _messages.indexWhere((m) => m["id"].toString() == msgId);\n'
    "      if (index != -1) {\n"
    '        _messages[index]["isRecalled"] = true;\n'
    '        _messages[index]["text"] = "Tin nhắn đã được thu hồi";\n'
    '        _messages[index]["imagePath"] = null;\n'
    '        _messages[index]["fileName"] = null;\n'
    "      }\n"
    "    });\n"
    "\n"
    "    final success = await ApiService.recallMessage(_activeConversationId!, msgId);\n"
    "    if (!success && mounted) {\n"
    "      // Rollback on failure\n"
    "      setState(() {\n"
    '        final index = _messages.indexWhere((m) => m["id"].toString() == msgId);\n'
    "        if (index != -1) {\n"
    '          _messages[index]["isRecalled"] = false;\n'
    '          _messages[index]["text"] = msg["text"] ?? "";\n'
    '          _messages[index]["imagePath"] = msg["imagePath"];\n'
    '          _messages[index]["fileName"] = msg["fileName"];\n'
    "        }\n"
    "      });\n"
    "      ScaffoldMessenger.of(context).showSnackBar(\n"
    '        const SnackBar(content: Text("Thu hồi tin nhắn thất bại")),\n'
    "      );\n"
    "    }\n"
    "  }\n"
    "\n"
    "  void _startReplying(Map<String, dynamic> msg) {\n"
    "    setState(() {\n"
    "      _replyingTo = msg;\n"
    "      _editingMessageId = null;\n"
    "      _controller.clear();\n"
    "    });\n"
    "    _focusNode.requestFocus();\n"
    "  }\n"
    "\n"
    "  void _startEditing(Map<String, dynamic> msg) {\n"
    '    if (msg["imagePath"] != null) return;\n'
    "    setState(() {\n"
    '      _editingMessageId = msg["id"];\n'
    "      _replyingTo = null;\n"
    '      _controller.text = msg["text"] ?? "";\n'
    "      _showEmoji = false;\n"
    "    });\n"
    "    _focusNode.requestFocus();\n"
    "  }\n"
    "\n"
    "  void _showOptions(BuildContext context, Map<String, dynamic> msg) {\n"
    '    final bool isRecalled = msg["isRecalled"] == true;\n'
    "    if (isRecalled) return;\n"
    "\n"
    "    showModalBottomSheet(\n"
    "      context: context,\n"
    "      shape: const RoundedRectangleBorder(\n"
    "        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),\n"
    "      ),\n"
    "      builder: (context) => Wrap(\n"
    "        children: [\n"
    "          ListTile(\n"
    "            leading: const Icon(Icons.reply_outlined, color: Colors.blueGrey),\n"
    '            title: const Text("Phản hồi"),\n'
    "            onTap: () {\n"
    "              Navigator.pop(context);\n"
    "              _startReplying(msg);\n"
    "            },\n"
    "          ),\n"
    '          if (msg["isSender"] == true) ...[\n'
    '            if (msg["imagePath"] == null)\n'
    "              ListTile(\n"
    "                leading: const Icon(Icons.edit_outlined, color: Colors.blue),\n"
    "                title: const Text(\n"
    '                  "Chỉnh sửa tin nhắn",\n'
    "                  style: TextStyle(color: Colors.blue),\n"
    "                ),\n"
    "                onTap: () {\n"
    "                  Navigator.pop(context);\n"
    "                  _startEditing(msg);\n"
    "                },\n"
    "              ),\n"
    "            ListTile(\n"
    "              leading: const Icon(Icons.undo_outlined, color: Colors.orange),\n"
    "              title: const Text(\n"
    '                "Thu hồi tin nhắn",\n'
    "                style: TextStyle(color: Colors.orange),\n"
    "              ),\n"
    "              onTap: () {\n"
    "                Navigator.pop(context);\n"
    "                _recallMessage(msg);\n"
    "              },\n"
    "            ),\n"
    "          ],\n"
    "          ListTile(\n"
    "            leading: const Icon(Icons.copy_outlined),\n"
    '            title: const Text("Sao chép"),\n'
    "            onTap: () => Navigator.pop(context),\n"
    "          ),\n"
    "        ],\n"
    "      ),\n"
    "    );\n"
    "  }"
)

if OLD5 in content:
    content = content.replace(OLD5, NEW5, 1)
    print("PATCH 5 applied: _recallMessage + _startReplying + updated _showOptions")
else:
    print("PATCH 5 SKIPPED")

# ─── PATCH 6: itemBuilder – pass isRecalled, replyTo to _ChatBubble ──────────
OLD6 = (
    "                    final msg = _messages[index];\n"
    "                    return GestureDetector(\n"
    "                      onLongPress: () => _showOptions(context, msg),\n"
    "                      child: _ChatBubble(\n"
    '                        message: msg["text"] ?? "",\n'
    '                        isSender: msg["isSender"],\n'
    '                        isSystem: msg["isSystem"] ?? false,\n'
    '                        isEdited: msg["isEdited"] ?? false,\n'
    '                        imagePath: msg["imagePath"],\n'
    '                        fileName: msg["fileName"],\n'
    '                        fileSize: msg["fileSize"],\n'
    '                        senderName: msg["isSender"]\n'
    '                            ? "Bạn"\n'
    '                            : (msg["senderName"] ?? _currentName),\n'
    '                        senderInitials: msg["isSender"]\n'
    '                            ? "ME"\n'
    '                            : (msg["senderInitials"] ??\n'
    "                                  (widget.initials ??\n"
    "                                      _currentName.substring(0, 1))),\n"
    '                        senderAvatarPath: msg["isSender"]\n'
    "                            ? ApiService.resolveImageUrl(\n"
    "                                AuthService()\n"
    '                                        .userProfile\n'
    '                                        .value?["profilePicture"] ??\n'
    '                                    AuthService().userProfile.value?["avatar"],\n'
    "                              )\n"
    '                            : msg["senderAvatarPath"],\n'
    "                        bubbleColor: _currentColor ?? Colors.blue,\n"
    '                        time: msg["time"] ?? "Vừa xong",\n'
    "                      ),\n"
    "                    );"
)
NEW6 = (
    "                    final msg = _messages[index];\n"
    "                    // Build replyTo preview if present\n"
    "                    Map<String, dynamic>? replyData;\n"
    '                    final rawReply = msg["replyTo"];\n'
    "                    if (rawReply is Map) {\n"
    '                      final replyText = (rawReply["text"] ?? rawReply["content"] ?? "").toString();\n'
    '                      final replySender = (rawReply["sender"]?["fullName"] ?? rawReply["sender"]?["name"] ?? "").toString();\n'
    "                      replyData = {\n"
    '                        "id": (rawReply["_id"] ?? rawReply["id"])?.toString(),\n'
    '                        "text": replyText,\n'
    '                        "senderName": replySender,\n'
    "                      };\n"
    "                    }\n"
    "                    return GestureDetector(\n"
    "                      onLongPress: () => _showOptions(context, msg),\n"
    "                      child: _ChatBubble(\n"
    '                        message: msg["isRecalled"] == true\n'
    '                            ? "Tin nhắn đã được thu hồi"\n'
    '                            : (msg["text"] ?? ""),\n'
    '                        isSender: msg["isSender"],\n'
    '                        isSystem: msg["isSystem"] ?? false,\n'
    '                        isEdited: msg["isEdited"] ?? false,\n'
    '                        isRecalled: msg["isRecalled"] == true,\n'
    '                        imagePath: msg["isRecalled"] == true ? null : msg["imagePath"],\n'
    '                        fileName: msg["isRecalled"] == true ? null : msg["fileName"],\n'
    '                        fileSize: msg["fileSize"],\n'
    "                        replyTo: replyData,\n"
    '                        senderName: msg["isSender"]\n'
    '                            ? "Bạn"\n'
    '                            : (msg["senderName"] ?? _currentName),\n'
    '                        senderInitials: msg["isSender"]\n'
    '                            ? "ME"\n'
    '                            : (msg["senderInitials"] ??\n'
    "                                  (widget.initials ??\n"
    "                                      _currentName.substring(0, 1))),\n"
    '                        senderAvatarPath: msg["isSender"]\n'
    "                            ? ApiService.resolveImageUrl(\n"
    "                                AuthService()\n"
    '                                        .userProfile\n'
    '                                        .value?["profilePicture"] ??\n'
    '                                    AuthService().userProfile.value?["avatar"],\n'
    "                              )\n"
    '                            : msg["senderAvatarPath"],\n'
    "                        bubbleColor: _currentColor ?? Colors.blue,\n"
    '                        time: msg["time"] ?? "Vừa xong",\n'
    "                      ),\n"
    "                    );"
)
if OLD6 in content:
    content = content.replace(OLD6, NEW6, 1)
    print("PATCH 6 applied: itemBuilder with isRecalled + replyTo")
else:
    print("PATCH 6 SKIPPED")

# ─── PATCH 7: Add reply banner below editing banner ───────────────────────────
OLD7 = (
    "            if (_editingMessageId != null)\n"
    "              _EditingBanner(\n"
    "                themeColor: _currentColor ?? const Color(0xFF3B82F6),\n"
    "                onCancel: () => setState(() {\n"
    "                  _editingMessageId = null;\n"
    "                  _controller.clear();\n"
    "                }),\n"
    "              ),\n"
    "\n"
    "            _ChatInputArea("
)
NEW7 = (
    "            if (_editingMessageId != null)\n"
    "              _EditingBanner(\n"
    "                themeColor: _currentColor ?? const Color(0xFF3B82F6),\n"
    "                onCancel: () => setState(() {\n"
    "                  _editingMessageId = null;\n"
    "                  _controller.clear();\n"
    "                }),\n"
    "              ),\n"
    "            if (_replyingTo != null)\n"
    "              _ReplyBanner(\n"
    "                themeColor: _currentColor ?? const Color(0xFF3B82F6),\n"
    '                replyToName: _replyingTo!["senderName"] ?? "Người dùng",\n'
    '                replyToText: _replyingTo!["text"] ?? "",\n'
    "                onCancel: () => setState(() => _replyingTo = null),\n"
    "              ),\n"
    "\n"
    "            _ChatInputArea("
)
if OLD7 in content:
    content = content.replace(OLD7, NEW7, 1)
    print("PATCH 7 applied: _ReplyBanner widget call")
else:
    print("PATCH 7 SKIPPED")

# ─── PATCH 8: Update _ChatBubble class & constructor ──────────────────────────
OLD8 = (
    "class _ChatBubble extends StatelessWidget {\n"
    "  final String message;\n"
    "  final bool isSender;\n"
    "  final bool isEdited;\n"
    "  final bool isSystem;\n"
    "  final String? imagePath;\n"
    "  final String? fileName;\n"
    "  final String? fileSize;\n"
    "  final String? senderName;\n"
    "  final String? senderInitials;\n"
    "  final String? senderAvatarPath;\n"
    "  final Color bubbleColor;\n"
    "  final String time;\n"
    "  const _ChatBubble({\n"
    "    required this.message,\n"
    "    required this.isSender,\n"
    "    this.isSystem = false,\n"
    "    this.isEdited = false,\n"
    "    this.imagePath,\n"
    "    this.fileName,\n"
    "    this.fileSize,\n"
    "    this.senderName,\n"
    "    this.senderInitials,\n"
    "    this.senderAvatarPath,\n"
    "    this.bubbleColor = const Color(0xFF3B82F6),\n"
    "    required this.time,\n"
    "  });"
)
NEW8 = (
    "class _ChatBubble extends StatelessWidget {\n"
    "  final String message;\n"
    "  final bool isSender;\n"
    "  final bool isEdited;\n"
    "  final bool isSystem;\n"
    "  final bool isRecalled;\n"
    "  final String? imagePath;\n"
    "  final String? fileName;\n"
    "  final String? fileSize;\n"
    "  final Map<String, dynamic>? replyTo;\n"
    "  final String? senderName;\n"
    "  final String? senderInitials;\n"
    "  final String? senderAvatarPath;\n"
    "  final Color bubbleColor;\n"
    "  final String time;\n"
    "  const _ChatBubble({\n"
    "    required this.message,\n"
    "    required this.isSender,\n"
    "    this.isSystem = false,\n"
    "    this.isEdited = false,\n"
    "    this.isRecalled = false,\n"
    "    this.imagePath,\n"
    "    this.fileName,\n"
    "    this.fileSize,\n"
    "    this.replyTo,\n"
    "    this.senderName,\n"
    "    this.senderInitials,\n"
    "    this.senderAvatarPath,\n"
    "    this.bubbleColor = const Color(0xFF3B82F6),\n"
    "    required this.time,\n"
    "  });"
)
if OLD8 in content:
    content = content.replace(OLD8, NEW8, 1)
    print("PATCH 8 applied: _ChatBubble class fields + constructor")
else:
    print("PATCH 8 SKIPPED")

# ─── PATCH 9: Replace plain text bubble with recalled/reply aware version ────
OLD9 = (
    "                else\n"
    "                  Container(\n"
    "                    padding: const EdgeInsets.symmetric(\n"
    "                      horizontal: 16,\n"
    "                      vertical: 14,\n"
    "                    ),\n"
    "                    constraints: BoxConstraints(\n"
    "                      maxWidth: MediaQuery.of(context).size.width * 0.72,\n"
    "                    ),\n"
    "                    decoration: BoxDecoration(\n"
    "                      color: isSender ? bubbleColor : Colors.white,\n"
    "                      borderRadius: BorderRadius.circular(20),\n"
    "                      border: Border.all(\n"
    "                        color: isSender\n"
    "                            ? Colors.transparent\n"
    "                            : Colors.grey.shade200,\n"
    "                      ),\n"
    "                      boxShadow: isSender\n"
    "                          ? null\n"
    "                          : [\n"
    "                              BoxShadow(\n"
    "                                color: Colors.black.withOpacity(0.04),\n"
    "                                blurRadius: 14,\n"
    "                                offset: const Offset(0, 3),\n"
    "                              ),\n"
    "                            ],\n"
    "                    ),\n"
    "                    child: Text(\n"
    "                      message,\n"
    "                      style: TextStyle(\n"
    "                        color: isSender ? Colors.white : Colors.black87,\n"
    "                        fontSize: 14,\n"
    "                        fontWeight: FontWeight.w500,\n"
    "                        fontFamily: 'sans-serif',\n"
    "                        height: 1.5,\n"
    "                      ),\n"
    "                    ),\n"
    "                  ),"
)
NEW9 = (
    "                else\n"
    "                  Container(\n"
    "                    padding: const EdgeInsets.symmetric(\n"
    "                      horizontal: 16,\n"
    "                      vertical: 14,\n"
    "                    ),\n"
    "                    constraints: BoxConstraints(\n"
    "                      maxWidth: MediaQuery.of(context).size.width * 0.72,\n"
    "                    ),\n"
    "                    decoration: BoxDecoration(\n"
    "                      color: isRecalled\n"
    "                          ? Colors.grey.shade100\n"
    "                          : (isSender ? bubbleColor : Colors.white),\n"
    "                      borderRadius: BorderRadius.circular(20),\n"
    "                      border: Border.all(\n"
    "                        color: isRecalled\n"
    "                            ? Colors.grey.shade300\n"
    "                            : (isSender\n"
    "                                ? Colors.transparent\n"
    "                                : Colors.grey.shade200),\n"
    "                      ),\n"
    "                      boxShadow: (isSender || isRecalled)\n"
    "                          ? null\n"
    "                          : [\n"
    "                              BoxShadow(\n"
    "                                color: Colors.black.withOpacity(0.04),\n"
    "                                blurRadius: 14,\n"
    "                                offset: const Offset(0, 3),\n"
    "                              ),\n"
    "                            ],\n"
    "                    ),\n"
    "                    child: Column(\n"
    "                      crossAxisAlignment: CrossAxisAlignment.start,\n"
    "                      mainAxisSize: MainAxisSize.min,\n"
    "                      children: [\n"
    "                        if (replyTo != null && !isRecalled)\n"
    "                          Container(\n"
    "                            margin: const EdgeInsets.only(bottom: 8),\n"
    "                            padding: const EdgeInsets.symmetric(\n"
    "                              horizontal: 10,\n"
    "                              vertical: 6,\n"
    "                            ),\n"
    "                            decoration: BoxDecoration(\n"
    "                              color: isSender\n"
    "                                  ? Colors.white.withOpacity(0.2)\n"
    "                                  : Colors.grey.shade100,\n"
    "                              borderRadius: BorderRadius.circular(10),\n"
    "                              border: Border(\n"
    "                                left: BorderSide(\n"
    "                                  color: isSender\n"
    "                                      ? Colors.white.withOpacity(0.7)\n"
    "                                      : bubbleColor,\n"
    "                                  width: 3,\n"
    "                                ),\n"
    "                              ),\n"
    "                            ),\n"
    "                            child: Column(\n"
    "                              crossAxisAlignment: CrossAxisAlignment.start,\n"
    "                              children: [\n"
    "                                Text(\n"
    '                                  replyTo!["senderName"] ?? "",\n'
    "                                  style: TextStyle(\n"
    "                                    fontSize: 11,\n"
    "                                    fontWeight: FontWeight.bold,\n"
    "                                    color: isSender\n"
    "                                        ? Colors.white.withOpacity(0.9)\n"
    "                                        : bubbleColor,\n"
    "                                  ),\n"
    "                                ),\n"
    "                                const SizedBox(height: 2),\n"
    "                                Text(\n"
    '                                  replyTo!["text"] ?? "",\n'
    "                                  maxLines: 2,\n"
    "                                  overflow: TextOverflow.ellipsis,\n"
    "                                  style: TextStyle(\n"
    "                                    fontSize: 11,\n"
    "                                    color: isSender\n"
    "                                        ? Colors.white.withOpacity(0.75)\n"
    "                                        : Colors.grey.shade600,\n"
    "                                  ),\n"
    "                                ),\n"
    "                              ],\n"
    "                            ),\n"
    "                          ),\n"
    "                        Text(\n"
    "                          message,\n"
    "                          style: TextStyle(\n"
    "                            color: isRecalled\n"
    "                                ? Colors.grey.shade500\n"
    "                                : (isSender ? Colors.white : Colors.black87),\n"
    "                            fontSize: 14,\n"
    "                            fontWeight:\n"
    "                                isRecalled ? FontWeight.w400 : FontWeight.w500,\n"
    "                            fontStyle: isRecalled\n"
    "                                ? FontStyle.italic\n"
    "                                : FontStyle.normal,\n"
    "                            fontFamily: 'sans-serif',\n"
    "                            height: 1.5,\n"
    "                          ),\n"
    "                        ),\n"
    "                      ],\n"
    "                    ),\n"
    "                  ),"
)
if OLD9 in content:
    content = content.replace(OLD9, NEW9, 1)
    print("PATCH 9 applied: text bubble with recall + replyTo preview")
else:
    print("PATCH 9 SKIPPED")

# ─── PATCH 10: Add _ReplyBanner widget after _EditingBanner class ─────────────
OLD10 = "class _HeaderAvatar extends StatelessWidget {"
NEW10 = (
    "class _ReplyBanner extends StatelessWidget {\n"
    "  final VoidCallback onCancel;\n"
    "  final Color themeColor;\n"
    "  final String replyToName;\n"
    "  final String replyToText;\n"
    "  const _ReplyBanner({\n"
    "    required this.onCancel,\n"
    "    required this.themeColor,\n"
    "    required this.replyToName,\n"
    "    required this.replyToText,\n"
    "  });\n"
    "\n"
    "  @override\n"
    "  Widget build(BuildContext context) {\n"
    "    return Container(\n"
    "      decoration: BoxDecoration(\n"
    "        color: themeColor.withOpacity(0.05),\n"
    "        border: Border(\n"
    "          left: BorderSide(color: themeColor, width: 3),\n"
    "        ),\n"
    "      ),\n"
    "      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),\n"
    "      child: Row(\n"
    "        children: [\n"
    "          Icon(Icons.reply_outlined, size: 16, color: themeColor),\n"
    "          const SizedBox(width: 8),\n"
    "          Expanded(\n"
    "            child: Column(\n"
    "              crossAxisAlignment: CrossAxisAlignment.start,\n"
    "              children: [\n"
    "                Text(\n"
    "                  replyToName,\n"
    "                  style: TextStyle(\n"
    "                    color: themeColor,\n"
    "                    fontSize: 11,\n"
    "                    fontWeight: FontWeight.bold,\n"
    "                  ),\n"
    "                ),\n"
    "                Text(\n"
    '                  replyToText.isNotEmpty ? replyToText : "[Ảnh hoặc tệp]",\n'
    "                  maxLines: 1,\n"
    "                  overflow: TextOverflow.ellipsis,\n"
    "                  style: TextStyle(\n"
    "                    color: Colors.grey.shade600,\n"
    "                    fontSize: 11,\n"
    "                  ),\n"
    "                ),\n"
    "              ],\n"
    "            ),\n"
    "          ),\n"
    "          IconButton(\n"
    "            icon: const Icon(Icons.close, size: 16),\n"
    "            constraints: const BoxConstraints(),\n"
    "            padding: EdgeInsets.zero,\n"
    "            onPressed: onCancel,\n"
    "          ),\n"
    "        ],\n"
    "      ),\n"
    "    );\n"
    "  }\n"
    "}\n"
    "\n"
    "class _HeaderAvatar extends StatelessWidget {"
)
if OLD10 in content:
    content = content.replace(OLD10, NEW10, 1)
    print("PATCH 10 applied: _ReplyBanner widget class")
else:
    print("PATCH 10 SKIPPED")

# ─── Write back with original line endings ────────────────────────────────────
if LE == b"\r\n":
    output = content.replace("\n", "\r\n").encode("utf-8")
else:
    output = content.encode("utf-8")

with open(FILE, "wb") as f:
    f.write(output)

print("\nDone! File written successfully.")
