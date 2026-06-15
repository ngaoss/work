import 'package:flutter/material.dart';
import '../api_service.dart';

class MentionSuggestionsOverlay extends StatefulWidget {
  final List<dynamic> suggestions;
  final int selectedIndex;
  final Function(Map<String, dynamic>) onSelect;
  final Color themeColor;

  const MentionSuggestionsOverlay({
    super.key,
    required this.suggestions,
    required this.selectedIndex,
    required this.onSelect,
    this.themeColor = const Color(0xFF3B82F6),
  });

  @override
  State<MentionSuggestionsOverlay> createState() =>
      _MentionSuggestionsOverlayState();
}

class _MentionSuggestionsOverlayState extends State<MentionSuggestionsOverlay> {
  final ScrollController _scrollController = ScrollController();

  @override
  void didUpdateWidget(MentionSuggestionsOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.selectedIndex != oldWidget.selectedIndex &&
        widget.suggestions.isNotEmpty) {
      _scrollToIndex(widget.selectedIndex);
    }
  }

  void _scrollToIndex(int index) {
    if (!_scrollController.hasClients) return;

    const itemHeight = 48.0; // Based on padding 6+6 and font size
    final viewportHeight = _scrollController.position.viewportDimension;
    final targetOffset = index * itemHeight;

    if (targetOffset < _scrollController.offset) {
      _scrollController.animateTo(
        targetOffset,
        duration: const Duration(milliseconds: 150),
        curve: Curves.easeOut,
      );
    } else if (targetOffset + itemHeight >
        _scrollController.offset + viewportHeight) {
      _scrollController.animateTo(
        targetOffset - viewportHeight + itemHeight,
        duration: const Duration(milliseconds: 150),
        curve: Curves.easeOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.suggestions.isEmpty) return const SizedBox.shrink();

    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      constraints: const BoxConstraints(maxHeight: 200),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF2C2C2C) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.3 : 0.08),
            blurRadius: 15,
            offset: const Offset(0, -4),
          ),
        ],
        border: Border.all(color: isDark ? const Color(0xFF444444) : Colors.grey.shade100),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: ListView.builder(
                controller: _scrollController,
                shrinkWrap: true,
                padding: EdgeInsets.zero,
                itemCount: widget.suggestions.length,
                itemBuilder: (context, index) {
                  final member = widget.suggestions[index];
                  final isSelected = index == widget.selectedIndex;
                  final name =
                      member['fullName'] ?? member['name'] ?? 'Unknown';
                  final avatar = member['profilePicture'] ?? member['avatar'];

                  return InkWell(
                    onTap: () => widget.onSelect(member),
                    child: Container(
                      margin: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? widget.themeColor.withOpacity(isDark ? 0.2 : 0.08)
                            : null,
                        borderRadius: BorderRadius.circular(8),
                        border: isSelected
                            ? Border.all(
                                color: isDark ? Colors.grey.withOpacity(0.4) : Colors.grey.withOpacity(0.2),
                                width: 1,
                              )
                            : null,
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 6,
                      ),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 14,
                            backgroundColor: widget.themeColor.withOpacity(0.1),
                            backgroundImage:
                                (avatar != null && avatar.isNotEmpty)
                                ? NetworkImage(
                                    ApiService.resolveImageUrl(avatar),
                                  )
                                : null,
                            child: (avatar == null || avatar.isEmpty)
                                ? Text(
                                    name.isNotEmpty
                                        ? name[0].toUpperCase()
                                        : '?',
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      color: widget.themeColor == Colors.white
                                          ? const Color(0xFF3B82F6)
                                          : widget.themeColor,
                                    ),
                                  )
                                : null,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              name,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: isSelected
                                    ? FontWeight.w700
                                    : FontWeight.w600,
                                color: isSelected
                                    ? (widget.themeColor == Colors.white
                                          ? const Color(0xFF3B82F6)
                                          : widget.themeColor)
                                    : (isDark ? Colors.white : const Color(0xFF1E293B)),
                              ),
                            ),
                          ),
                          if (member['role'] != null)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: isDark ? const Color(0xFF3A3A3A) : Colors.grey.shade100,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                member['role']!,
                                style: TextStyle(
                                  fontSize: 8,
                                  color: isDark ? Colors.grey.shade300 : Colors.grey.shade600,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
