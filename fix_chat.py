import os

file_path = r'lib\features\chat\presentation\pages\chat_detail_screen.dart'

with open(file_path, 'r', encoding='utf-8') as f:
    lines = f.readlines()

# Clean up duplicate _ReplyBanner at the end
# We want to keep only one _ReplyBanner class.
# It starts with 'class _ReplyBanner extends StatelessWidget {'
# And ends with '}' before 'class _HeaderAvatar'

# Find all blocks of _ReplyBanner
blocks = []
in_block = False
start_idx = -1
for i, line in enumerate(lines):
    if 'class _ReplyBanner extends StatelessWidget {' in line:
        in_block = True
        start_idx = i
    if in_block and line.strip() == '}' and i + 1 < len(lines) and ('class _HeaderAvatar' in lines[i+1] or 'class _ReplyBanner' in lines[i+1] or i == len(lines)-1):
         blocks.append((start_idx, i))
         in_block = False

if len(blocks) > 1:
    # Remove all but the first one
    for start, end in reversed(blocks[1:]):
        del lines[start:end+1]
    print(f"Removed {len(blocks)-1} duplicate _ReplyBanner blocks")

content = "".join(lines)

# Fix _sendMessage with replyTo
old_send = '''      if (_activeConversationId != null) {
        // Optimistic update
        final tempId = DateTime.now().millisecondsSinceEpoch.toString();
        setState(() {
          _messages.insert(0, {
            "id": tempId,
            "text": text,
            "isSender": true,
            "isEdited": false,
            "time": "${DateTime.now().hour}:${DateTime.now().minute.toString().padLeft(2, \'0\')}",
            "senderName": "Bạn",
          });
          _controller.clear();
          _showEmoji = false;
        });

        final success = await ApiService.sendMessage(_activeConversationId!, text);'''

new_send = '''      if (_activeConversationId != null) {
        final replyMsg = _replyingTo;
        final replyToId = replyMsg?["id"]?.toString();

        // Optimistic update
        final tempId = DateTime.now().millisecondsSinceEpoch.toString();
        setState(() {
          _messages.insert(0, {
            "id": tempId,
            "text": text,
            "isSender": true,
            "isEdited": false,
            "replyTo": replyMsg != null ? {
              "_id": replyMsg["id"],
              "text": replyMsg["text"],
              "sender": {"fullName": replyMsg["senderName"]},
            } : null,
            "time": "${DateTime.now().hour}:${DateTime.now().minute.toString().padLeft(2, \'0\')}",
            "senderName": "Bạn",
          });
          _controller.clear();
          _replyingTo = null;
          _showEmoji = false;
        });

        final success = await ApiService.sendMessage(_activeConversationId!, text, replyTo: replyToId);'''

if old_send in content:
    content = content.replace(old_send, new_send)
    print("Updated _sendMessage")

# Update itemBuilder
old_item = '''                      final msg = _messages[index];
                      return GestureDetector(
                        onLongPress: () => _showOptions(context, msg),
                        child: _ChatBubble(
                          message: msg["text"] ?? "",
                          isSender: msg["isSender"],
                          isSystem: msg["isSystem"] ?? false,
                          isEdited: msg["isEdited"] ?? false,
                          imagePath: msg["imagePath"],
                          fileName: msg["fileName"],
                          fileSize: msg["fileSize"],'''

new_item = '''                      final msg = _messages[index];
                      // Build replyTo preview if present
                      Map<String, dynamic>? replyData;
                      final rawReply = msg["replyTo"];
                      if (rawReply is Map) {
                        final replyText = (rawReply["text"] ?? rawReply["content"] ?? "").toString();
                        final replySender = (rawReply["sender"]?["fullName"] ?? rawReply["sender"]?["name"] ?? "").toString();
                        replyData = {
                          "id": (rawReply["_id"] ?? rawReply["id"])?.toString(),
                          "text": replyText,
                          "senderName": replySender,
                        };
                      }
                      return GestureDetector(
                        onLongPress: () => _showOptions(context, msg),
                        child: _ChatBubble(
                          message: msg["isRecalled"] == true ? "Tin nhắn đã được thu hồi" : (msg["text"] ?? ""),
                          isSender: msg["isSender"],
                          isSystem: msg["isSystem"] ?? false,
                          isEdited: msg["isEdited"] ?? false,
                          isRecalled: msg["isRecalled"] == true,
                          imagePath: msg["isRecalled"] == true ? null : msg["imagePath"],
                          fileName: msg["isRecalled"] == true ? null : msg["fileName"],
                          fileSize: msg["fileSize"],
                          replyTo: replyData,'''

if old_item in content:
    content = content.replace(old_item, new_item)
    print("Updated itemBuilder")

# Update _ChatBubble class signature
old_bubble_class = '''class _ChatBubble extends StatelessWidget {
  final String message;
  final bool isSender;
  final bool isEdited;
  final bool isSystem;
  final String? imagePath;
  final String? fileName;
  final String? fileSize;
  final String? senderName;
  final String? senderInitials;
  final String? senderAvatarPath;
  final Color bubbleColor;
  final String time;
  const _ChatBubble({
    required this.message,
    required this.isSender,
    this.isSystem = false,
    this.isEdited = false,
    this.imagePath,
    this.fileName,
    this.fileSize,
    this.senderName,
    this.senderInitials,
    this.senderAvatarPath,
    this.bubbleColor = const Color(0xFF3B82F6),
    required this.time,
  });'''

new_bubble_class = '''class _ChatBubble extends StatelessWidget {
  final String message;
  final bool isSender;
  final bool isEdited;
  final bool isSystem;
  final bool isRecalled;
  final String? imagePath;
  final String? fileName;
  final String? fileSize;
  final Map<String, dynamic>? replyTo;
  final String? senderName;
  final String? senderInitials;
  final String? senderAvatarPath;
  final Color bubbleColor;
  final String time;
  const _ChatBubble({
    required this.message,
    required this.isSender,
    this.isSystem = false,
    this.isEdited = false,
    this.isRecalled = false,
    this.imagePath,
    this.fileName,
    this.fileSize,
    this.replyTo,
    this.senderName,
    this.senderInitials,
    this.senderAvatarPath,
    this.bubbleColor = const Color(0xFF3B82F6),
    required this.time,
  });'''

if old_bubble_class in content:
    content = content.replace(old_bubble_class, new_bubble_class)
    print("Updated _ChatBubble class")

# Update _ChatBubble body (text Container)
old_bubble_body = '''                else
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                    constraints: BoxConstraints(
                      maxWidth: MediaQuery.of(context).size.width * 0.72,
                    ),
                    decoration: BoxDecoration(
                      color: isSender ? bubbleColor : Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: isSender
                            ? Colors.transparent
                            : Colors.grey.shade200,
                      ),
                      boxShadow: isSender
                          ? null
                          : [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.04),
                                blurRadius: 14,
                                offset: const Offset(0, 3),
                              ),
                            ],
                    ),
                    child: Text(
                      message,
                      style: TextStyle(
                        color: isSender ? Colors.white : Colors.black87,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        fontFamily: 'sans-serif',
                        height: 1.5,
                      ),
                    ),
                  ),'''

new_bubble_body = '''                else
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                    constraints: BoxConstraints(
                      maxWidth: MediaQuery.of(context).size.width * 0.72,
                    ),
                    decoration: BoxDecoration(
                      color: isRecalled
                          ? Colors.grey.shade100
                          : (isSender ? bubbleColor : Colors.white),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: isRecalled
                            ? Colors.grey.shade300
                            : (isSender ? Colors.transparent : Colors.grey.shade200),
                      ),
                      boxShadow: (isSender || isRecalled)
                          ? null
                          : [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.04),
                                blurRadius: 14,
                                offset: const Offset(0, 3),
                              ),
                            ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (replyTo != null && !isRecalled)
                          Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: isSender
                                  ? Colors.white.withOpacity(0.2)
                                  : Colors.grey.shade100,
                              borderRadius: BorderRadius.circular(10),
                              border: Border(
                                left: BorderSide(
                                  color: isSender
                                      ? Colors.white.withOpacity(0.7)
                                      : bubbleColor,
                                  width: 3,
                                ),
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  replyTo!["senderName"] ?? "",
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: isSender
                                        ? Colors.white.withOpacity(0.9)
                                        : bubbleColor,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  replyTo!["text"] ?? "",
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: isSender
                                        ? Colors.white.withOpacity(0.75)
                                        : Colors.grey.shade600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        Text(
                          message,
                          style: TextStyle(
                            color: isRecalled
                                ? Colors.grey.shade500
                                : (isSender ? Colors.white : Colors.black87),
                            fontSize: 14,
                            fontWeight: isRecalled ? FontWeight.w400 : FontWeight.w500,
                            fontStyle: isRecalled ? FontStyle.italic : FontStyle.normal,
                            fontFamily: 'sans-serif',
                            height: 1.5,
                          ),
                        ),
                      ],
                    ),
                  ),'''

if old_bubble_body in content:
    content = content.replace(old_bubble_body, new_bubble_body)
    print("Updated _ChatBubble body")

# Write back with CRLF if it originally had it
with open(file_path, 'wb') as f:
    f.write(content.replace('\n', '\r\n').encode('utf-8'))

print("All done!")
