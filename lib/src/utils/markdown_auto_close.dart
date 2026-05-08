import 'package:flutter/foundation.dart';

/// Auto-close any unclosed inline markdown tokens so that partially streamed
/// text renders correctly (e.g. `**bold` → `**bold**`).
///
/// Strategy: first strip trailing marker characters that are incomplete
/// openers or partial closers (e.g. the lone `*` in `**bold*`), then
/// auto-close any remaining interior unclosed markers.
@visibleForTesting
String autoCloseMarkdown(String text) {
  if (text.isEmpty) return text;

  // --- Step 0: Identify list-marker positions on the original text ---
  // A `*` at the start of a line (with optional leading spaces) followed
  // by a space is a list bullet, not italic. We record these indices so
  // they are skipped regardless of later stripping.
  final listMarkerIndices = <int>{};
  for (int i = 0; i < text.length; i++) {
    if (text[i] == '*' && i + 1 < text.length && text[i + 1] == ' ') {
      int j = i - 1;
      while (j >= 0 && text[j] == ' ') {
        j--;
      }
      if (j < 0 || text[j] == '\n') {
        listMarkerIndices.add(i);
      }
    }
  }

  var result = text;

  // --- Step 1: Strip trailing marker characters ---
  // These are either incomplete openers with no content yet (e.g. `text **`)
  // or partial closers being typed (e.g. `**bold*`). In both cases, removing
  // them and then auto-closing interiors produces correct markdown.
  result = result.replaceFirst(RegExp(r'\*{1,3}$'), '');
  result = result.replaceFirst(RegExp(r'~{1,2}$'), '');
  result = result.replaceFirst(RegExp(r'`$'), '');

  // Strip trailing whitespace — markdown closers placed after a space
  // (e.g. `*50 *`) are invalid and render literally.
  result = result.replaceFirst(RegExp(r'[ \t]+$'), '');

  // Second pass: stripping whitespace may have exposed new trailing markers
  // (e.g. `* ` → strip ws → `*` → strip marker → empty).
  result = result.replaceFirst(RegExp(r'\*{1,3}$'), '');
  result = result.replaceFirst(RegExp(r'~{1,2}$'), '');
  result = result.replaceFirst(RegExp(r'`$'), '');

  if (result.isEmpty) return '';

  // --- Step 2: Auto-close remaining unclosed markers ---
  final buf = StringBuffer(result);

  // Bold (**) and italic (*) — skip list markers identified above
  int boldCount = 0;
  int italicCount = 0;
  for (int i = 0; i < result.length; i++) {
    if (result[i] == '*') {
      if (listMarkerIndices.contains(i)) continue;

      if (i + 1 < result.length && result[i + 1] == '*') {
        boldCount++;
        i++; // skip next *
      } else {
        italicCount++;
      }
    }
  }
  if (boldCount.isOdd) buf.write('**');
  if (italicCount.isOdd) buf.write('*');

  // Strikethrough (~~)
  int strikeCount = 0;
  for (int i = 0; i < result.length - 1; i++) {
    if (result[i] == '~' && result[i + 1] == '~') {
      strikeCount++;
      i++;
    }
  }
  if (strikeCount.isOdd) buf.write('~~');

  // Inline code (`)
  int backtickCount = 0;
  for (int i = 0; i < result.length; i++) {
    if (result[i] == '`') backtickCount++;
  }
  if (backtickCount.isOdd) buf.write('`');

  // Links: unclosed [text](url → close the parenthesis
  final lastBracket = result.lastIndexOf('[');
  if (lastBracket != -1) {
    final closeBracket = result.indexOf(']', lastBracket);
    if (closeBracket != -1 &&
        closeBracket + 1 < result.length &&
        result[closeBracket + 1] == '(') {
      final closeParen = result.indexOf(')', closeBracket + 2);
      if (closeParen == -1) {
        buf.write(')');
      }
    }
  }

  return buf.toString();
}
