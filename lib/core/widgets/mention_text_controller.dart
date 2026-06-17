import 'package:flutter/material.dart';

/// A [TextEditingController] that highlights @mention words in blue.
class MentionTextEditingController extends TextEditingController {
  final Color mentionColor;
  final FontWeight mentionFontWeight;
  final Color mentionBackgroundColor;

  MentionTextEditingController({
    String? text,
    this.mentionColor = const Color(0xFF0EA5E9),
    this.mentionFontWeight = FontWeight.w700,
    this.mentionBackgroundColor = const Color(0xFFEBEFFF),
  }) : super(text: text);

  // Regex to find URLs and @mentions including fullname words.
  static final RegExp _combinedRegex = RegExp(
    r'(([hH][tT][tT][pP][sS]?:\/\/|[wW][wW][wW]\.)[^\s\/$.?#].[^\s]*)|' // URL
    r'((?<!\S)@\S+(?:\s+[^ \s@:;!?,]+)*\u200B|(?<!\S)@\S+(?:\s+[A-ZÀ-Ỹ][^ \s@:;!?,]*)*)', // Mentions
  );

  @override
  set value(TextEditingValue newValue) {
    // If the text is being cleared completely, allow it.
    if (newValue.text.isEmpty) {
      super.value = newValue;
      return;
    }

    // If we're deleting (new text is shorter)
    if (newValue.text.length < value.text.length) {
      final int selectionStart = newValue.selection.start;
      final String oldText = value.text;

      // Find matches in the OLD text
      final matches = _combinedRegex.allMatches(oldText);
      for (final match in matches) {
        // If the cursor is now within what was a mention, or exactly at the end of what was deleted
        // basically if any character of the mention was in the deleted range
        if (selectionStart >= match.start && selectionStart < match.end) {
          final matchText = match.group(0) ?? '';
          // Only delete atomically if it's a "full" mention (has \u200B)
          if (matchText.contains('\u200B')) {
            final String newText = oldText.replaceRange(
              match.start,
              match.end,
              '',
            );
            super.value = TextEditingValue(
              text: newText,
              selection: TextSelection.collapsed(offset: match.start),
            );
            return;
          }
        }
      }
    }
    super.value = newValue;
  }

  @override
  TextSpan buildTextSpan({
    required BuildContext context,
    TextStyle? style,
    required bool withComposing,
  }) {
    final TextStyle effectiveStyle =
        (style ?? const TextStyle(color: Colors.black87)).copyWith(
          color: style?.color ?? Colors.black87,
        );
    final String fullText = value.text;
    final List<InlineSpan> spans = [];

    int lastIndex = 0;

    for (final match in _combinedRegex.allMatches(fullText)) {
      if (match.start > lastIndex) {
        spans.add(
          TextSpan(
            text: fullText.substring(lastIndex, match.start),
            style: effectiveStyle,
          ),
        );
      }

      final matchText = match.group(0)!;
      if (matchText.startsWith('@')) {
        // Mentions Style - In editor, keep the \u200b to avoid character length mismatch
        // which causes duplication bugs on some platforms (Windows/Web).
        spans.add(
          TextSpan(
            text: matchText,
            style: effectiveStyle.copyWith(
              color: mentionColor,
              fontWeight: mentionFontWeight,
              backgroundColor: mentionBackgroundColor.withOpacity(0.3),
            ),
          ),
        );
      } else {
        // URL Style
        spans.add(
          TextSpan(
            text: matchText,
            style: effectiveStyle.copyWith(
              color: Colors.blue,
              decoration: TextDecoration.underline,
            ),
          ),
        );
      }
      lastIndex = match.end;
    }

    if (lastIndex < fullText.length) {
      spans.add(
        TextSpan(text: fullText.substring(lastIndex), style: effectiveStyle),
      );
    }

    if (spans.isEmpty) {
      return TextSpan(text: fullText, style: effectiveStyle);
    }
    return TextSpan(children: spans);
  }

  static List<InlineSpan> buildSpans(
    String fullText, {
    TextStyle? style,
    Color mentionColor = const Color(0xFF0EA5E9),
    FontWeight mentionFontWeight = FontWeight.w700,
    Color mentionBackgroundColor = const Color(0xFFEBEFFF),
  }) {
    final TextStyle effectiveStyle =
        (style ?? const TextStyle(color: Colors.black87)).copyWith(
          color: style?.color ?? Colors.black87,
        );
    final List<InlineSpan> spans = [];
    int lastIndex = 0;

    for (final match in _combinedRegex.allMatches(fullText)) {
      if (match.start > lastIndex) {
        spans.add(
          TextSpan(
            text: fullText.substring(lastIndex, match.start),
            style: effectiveStyle,
          ),
        );
      }

      final matchText = match.group(0)!;
      if (matchText.startsWith('@')) {
        // Mentions Style - Plain blue bold text, no background chip
        spans.add(
          TextSpan(
            text: matchText.replaceAll('\u200b', ''),
            style: effectiveStyle.copyWith(
              color: mentionColor,
              fontWeight: mentionFontWeight,
            ),
          ),
        );
      } else {
        // URL Style
        spans.add(
          TextSpan(
            text: matchText,
            style: effectiveStyle.copyWith(
              color: Colors.blue,
              decoration: TextDecoration.underline,
            ),
          ),
        );
      }
      lastIndex = match.end;
    }

    if (lastIndex < fullText.length) {
      spans.add(
        TextSpan(text: fullText.substring(lastIndex), style: effectiveStyle),
      );
    }

    if (spans.isEmpty) {
      spans.add(TextSpan(text: fullText, style: effectiveStyle));
    }

    return spans;
  }
}

class MentionText extends StatelessWidget {
  final String text;
  final TextStyle? style;
  final int? maxLines;
  final TextOverflow? overflow;
  final List<String>? fontFamilyFallback;
  final TextAlign textAlign;

  const MentionText({
    super.key,
    required this.text,
    this.style,
    this.maxLines,
    this.overflow,
    this.fontFamilyFallback,
    this.textAlign = TextAlign.start,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveStyle = (style ?? DefaultTextStyle.of(context).style)
        .copyWith(
          fontFamilyFallback: fontFamilyFallback,
          color: style?.color ?? Colors.black87,
        );

    return Text.rich(
      TextSpan(
        children: MentionTextEditingController.buildSpans(
          text,
          style: effectiveStyle,
        ),
      ),
      textAlign: textAlign,
      maxLines: maxLines,
      overflow: overflow,
      softWrap: true,
    );
  }
}
