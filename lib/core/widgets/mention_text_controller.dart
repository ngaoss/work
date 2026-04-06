import 'package:flutter/material.dart';

/// A [TextEditingController] that highlights @mention words in blue.
class MentionTextEditingController extends TextEditingController {
  final Color mentionColor;
  final FontWeight mentionFontWeight;

  MentionTextEditingController({
    String? text,
    this.mentionColor = const Color(0xFF2563EB),
    this.mentionFontWeight = FontWeight.w600,
  }) : super(text: text);

  @override
  TextSpan buildTextSpan({
    required BuildContext context,
    TextStyle? style,
    required bool withComposing,
  }) {
    final String fullText = value.text;
    final List<InlineSpan> spans = [];

    // Regex to find @mention tokens (word boundary after @)
    final RegExp mentionRegex = RegExp(r'@\S+');
    int lastIndex = 0;

    for (final match in mentionRegex.allMatches(fullText)) {
      // Text before the mention
      if (match.start > lastIndex) {
        spans.add(
          TextSpan(
            text: fullText.substring(lastIndex, match.start),
            style: style,
          ),
        );
      }
      // The @mention in blue
      spans.add(
        TextSpan(
          text: match.group(0),
          style: (style ?? const TextStyle()).copyWith(
            color: mentionColor,
            fontWeight: mentionFontWeight,
          ),
        ),
      );
      lastIndex = match.end;
    }

    // Remaining text after last mention
    if (lastIndex < fullText.length) {
      spans.add(TextSpan(text: fullText.substring(lastIndex), style: style));
    }

    if (spans.isEmpty) {
      return TextSpan(text: fullText, style: style);
    }

    return TextSpan(children: spans);
  }
}
