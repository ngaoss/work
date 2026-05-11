import 'package:flutter/material.dart';

/// A [TextEditingController] that highlights @mention words in blue.
class MentionTextEditingController extends TextEditingController {
  final Color mentionColor;
  final FontWeight mentionFontWeight;
  final Color mentionBackgroundColor;

  MentionTextEditingController({
    String? text,
    this.mentionColor = const Color(0xFF2563EB),
    this.mentionFontWeight = FontWeight.w600,
    this.mentionBackgroundColor = const Color(0xFFDBEAFE),
  }) : super(text: text);

  // Regex to find @mention tokens including fullname words.
  // - initial @handle can be any non-space string
  // - additional words are included only when they begin with an uppercase letter
  //   so comment text after the fullname is not accidentally consumed.
  static final RegExp _mentionRegex = RegExp(
    r'@\S+(?:\s+(?![a-z])[^ \s@:;!?,]+)*',
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
      final matches = _mentionRegex.allMatches(oldText);
      for (final match in matches) {
        // If the cursor is now within what was a mention, or exactly at the end of what was deleted
        // basically if any character of the mention was in the deleted range
        if (selectionStart >= match.start && selectionStart < match.end) {
          // Atomic deletion: remove the whole mention
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
    super.value = newValue;
  }

  @override
  TextSpan buildTextSpan({
    required BuildContext context,
    TextStyle? style,
    required bool withComposing,
  }) {
    final TextStyle effectiveStyle = (style ?? const TextStyle(color: Colors.black87)).copyWith(
      color: style?.color ?? Colors.black87,
    );
    final String fullText = value.text;
    final List<InlineSpan> spans = [];

    int lastIndex = 0;

    for (final match in _mentionRegex.allMatches(fullText)) {
      // Text before the mention
      if (match.start > lastIndex) {
        spans.add(
          TextSpan(
            text: fullText.substring(lastIndex, match.start),
            style: effectiveStyle,
          ),
        );
      }
      // The @mention in blue with background
      spans.add(
        WidgetSpan(
          alignment: PlaceholderAlignment.middle,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 2),
            decoration: BoxDecoration(
              color: mentionBackgroundColor,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              match.group(0)!,
              style: effectiveStyle.copyWith(
                color: mentionColor,
                fontWeight: mentionFontWeight,
              ),
            ),
          ),
        ),
      );
      lastIndex = match.end;
    }

    // Remaining text after last mention
    if (lastIndex < fullText.length) {
      spans.add(TextSpan(text: fullText.substring(lastIndex), style: effectiveStyle));
    }

    if (spans.isEmpty) {
      return TextSpan(text: fullText, style: effectiveStyle);
    }

    return TextSpan(children: spans);
  }

  /// Helper static method to parse text and return a [List<InlineSpan>] for rendering.
  static List<InlineSpan> buildSpans(
    String fullText, {
    TextStyle? style,
    Color mentionColor = const Color(0xFF2563EB),
    FontWeight mentionFontWeight = FontWeight.w600,
    Color mentionBackgroundColor = const Color(0xFFDBEAFE),
  }) {
    final TextStyle effectiveStyle = (style ?? const TextStyle(color: Colors.black87)).copyWith(
      color: style?.color ?? Colors.black87,
    );
    final List<InlineSpan> spans = [];

    int lastIndex = 0;

    for (final match in _mentionRegex.allMatches(fullText)) {
      // Text before the mention
      if (match.start > lastIndex) {
        spans.add(
          TextSpan(
            text: fullText.substring(lastIndex, match.start),
            style: effectiveStyle,
          ),
        );
      }
      // The @mention in blue with background
      spans.add(
        WidgetSpan(
          alignment: PlaceholderAlignment.middle,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 2),
            decoration: BoxDecoration(
              color: mentionBackgroundColor,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              match.group(0)!,
              style: effectiveStyle.copyWith(
                color: mentionColor,
                fontWeight: mentionFontWeight,
              ),
            ),
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
      spans.add(TextSpan(text: fullText, style: style));
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

  const MentionText({
    super.key,
    required this.text,
    this.style,
    this.maxLines,
    this.overflow,
    this.fontFamilyFallback,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveStyle = DefaultTextStyle.of(context).style.merge(style).copyWith(
      fontFamilyFallback: fontFamilyFallback,
      color: style?.color ?? Colors.black87,
    );

    final spans = MentionTextEditingController.buildSpans(
      text,
      style: effectiveStyle,
    );

    if (spans.length == 1 && spans[0] is TextSpan) {
      final textSpan = spans[0] as TextSpan;
      return Text(
        textSpan.text ?? "",
        style: effectiveStyle.copyWith(letterSpacing: 0),
        maxLines: maxLines,
        overflow: overflow ?? TextOverflow.clip,
        textAlign: TextAlign.start,
      );
    }

    return Text.rich(
      TextSpan(children: spans),
      maxLines: maxLines,
      overflow: overflow ?? TextOverflow.clip,
      textAlign: TextAlign.start,
    );
  }
}
