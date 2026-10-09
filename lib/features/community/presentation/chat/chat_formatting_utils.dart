import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Parses markdown text styles into [InlineSpan]s for chat bubbles:
/// - **bold**
/// - *italic*
/// - ~~strikethrough~~
/// - `code`
/// - http(s) URLs
/// - @mentions
List<InlineSpan> parseChatFormattedText(
  String text, {
  required TextStyle baseStyle,
  required bool isDarkBubble,
}) {
  if (text.isEmpty) return const [];

  final spans = <InlineSpan>[];
  final regex = RegExp(
    r'(https?:\/\/[^\s]+)|'
    r'(@[a-zA-Z0-9_.-]+)|'
    r'(\*\*([^*]+)\*\*)|'
    r'(\*([^*]+)\*)|'
    r'(~~([^~]+)~~)|'
    r'(`([^`]+)`)',
  );

  int lastMatchEnd = 0;
  for (final match in regex.allMatches(text)) {
    if (match.start > lastMatchEnd) {
      spans.add(TextSpan(
        text: text.substring(lastMatchEnd, match.start),
        style: baseStyle,
      ));
    }

    final fullMatch = match.group(0)!;
    if (match.group(1) != null) {
      // URL
      spans.add(TextSpan(
        text: fullMatch,
        style: baseStyle.copyWith(
          decoration: TextDecoration.underline,
          fontWeight: FontWeight.w700,
          color: isDarkBubble ? Colors.white : const Color(0xFF216BFF),
        ),
      ));
    } else if (match.group(2) != null) {
      // Mention @user
      spans.add(WidgetSpan(
        alignment: PlaceholderAlignment.middle,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
          margin: const EdgeInsets.symmetric(horizontal: 2),
          decoration: BoxDecoration(
            color: isDarkBubble
                ? Colors.white.withValues(alpha: 0.25)
                : Colors.black12,
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            fullMatch,
            style: baseStyle.copyWith(
              fontSize: (baseStyle.fontSize ?? 12) * 0.9,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ));
    } else if (match.group(3) != null) {
      // Bold **content**
      final content = match.group(4)!;
      spans.add(TextSpan(
        text: content,
        style: baseStyle.copyWith(fontWeight: FontWeight.w800),
      ));
    } else if (match.group(5) != null) {
      // Italic *content*
      final content = match.group(6)!;
      spans.add(TextSpan(
        text: content,
        style: baseStyle.copyWith(fontStyle: FontStyle.italic),
      ));
    } else if (match.group(7) != null) {
      // Strikethrough ~~content~~
      final content = match.group(8)!;
      spans.add(TextSpan(
        text: content,
        style: baseStyle.copyWith(decoration: TextDecoration.lineThrough),
      ));
    } else if (match.group(9) != null) {
      // Code `content`
      final content = match.group(10)!;
      spans.add(WidgetSpan(
        alignment: PlaceholderAlignment.middle,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
          margin: const EdgeInsets.symmetric(horizontal: 2),
          decoration: BoxDecoration(
            color: isDarkBubble ? Colors.black26 : const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(5),
            border: Border.all(
              color: isDarkBubble ? Colors.white24 : Colors.black26,
              width: 1,
            ),
          ),
          child: Text(
            content,
            style: GoogleFonts.jetBrainsMono(
              fontSize: (baseStyle.fontSize ?? 12) * 0.9,
              fontWeight: FontWeight.w600,
              color: baseStyle.color,
            ),
          ),
        ),
      ));
    }

    lastMatchEnd = match.end;
  }

  if (lastMatchEnd < text.length) {
    spans.add(TextSpan(
      text: text.substring(lastMatchEnd),
      style: baseStyle,
    ));
  }

  return spans;
}

/// Applies text formatting around selected or current cursor position
void applyChatFormatting(
  TextEditingController controller,
  String prefix,
  String suffix,
) {
  final text = controller.text;
  final selection = controller.selection;
  if (!selection.isValid || selection.isCollapsed) {
    final cursor = selection.isValid ? selection.start : text.length;
    final newText = text.replaceRange(cursor, cursor, '$prefix$suffix');
    controller.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: cursor + prefix.length),
    );
  } else {
    final selectedText = text.substring(selection.start, selection.end);
    final replacement = '$prefix$selectedText$suffix';
    final newText =
        text.replaceRange(selection.start, selection.end, replacement);
    controller.value = TextEditingValue(
      text: newText,
      selection: TextSelection(
        baseOffset: selection.start + prefix.length,
        extentOffset: selection.start + prefix.length + selectedText.length,
      ),
    );
  }
}

/// Neo-Brutalist Formatting Toolbar for chat message inputs
class ChatFormattingToolbar extends StatelessWidget {
  const ChatFormattingToolbar({
    super.key,
    required this.onApplyFormat,
    this.onClose,
  });

  final void Function(String prefix, String suffix) onApplyFormat;
  final VoidCallback? onClose;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: const BoxDecoration(
        color: Color(0xFFFFF8F3),
        border: Border(
          top: BorderSide(color: Colors.black, width: 2),
        ),
      ),
      child: Row(
        children: [
          _formatBtn(
            label: 'B',
            isBold: true,
            tooltip: 'Bold (**text**)',
            onTap: () => onApplyFormat('**', '**'),
          ),
          const SizedBox(width: 8),
          _formatBtn(
            label: 'I',
            isItalic: true,
            tooltip: 'Italic (*text*)',
            onTap: () => onApplyFormat('*', '*'),
          ),
          const SizedBox(width: 8),
          _formatBtn(
            label: 'S',
            isStrike: true,
            tooltip: 'Strikethrough (~~text~~)',
            onTap: () => onApplyFormat('~~', '~~'),
          ),
          const SizedBox(width: 8),
          _formatBtn(
            label: '< >',
            isCode: true,
            tooltip: 'Code (`code`)',
            onTap: () => onApplyFormat('`', '`'),
          ),
          const SizedBox(width: 8),
          _formatBtn(
            label: '“ ”',
            tooltip: 'Quote (> text)',
            onTap: () => onApplyFormat('> ', ''),
          ),
          const Spacer(),
          if (onClose != null)
            GestureDetector(
              onTap: onClose,
              behavior: HitTestBehavior.opaque,
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.black, width: 1.5),
                  boxShadow: const [
                    BoxShadow(
                      color: Colors.black,
                      offset: Offset(1, 1),
                      blurRadius: 0,
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.close_rounded,
                  size: 14,
                  color: Colors.black87,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _formatBtn({
    required String label,
    required VoidCallback onTap,
    required String tooltip,
    bool isBold = false,
    bool isItalic = false,
    bool isStrike = false,
    bool isCode = false,
  }) {
    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Container(
          width: 32,
          height: 30,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.black, width: 1.8),
            boxShadow: const [
              BoxShadow(
                color: Colors.black,
                offset: Offset(1.5, 1.5),
                blurRadius: 0,
              ),
            ],
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isBold ? FontWeight.w900 : FontWeight.w700,
                fontStyle: isItalic ? FontStyle.italic : FontStyle.normal,
                decoration: isStrike ? TextDecoration.lineThrough : null,
                fontFamily: isCode ? 'monospace' : null,
                color: Colors.black,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Formatting action row for long-press context menu bottom sheet
Widget buildChatFormattingActionRow({
  required void Function(String prefix, String suffix) onFormat,
}) {
  return Padding(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _sheetFormatBtn(
          label: 'Bold',
          iconText: 'B',
          isBold: true,
          onTap: () => onFormat('**', '**'),
        ),
        _sheetFormatBtn(
          label: 'Italic',
          iconText: 'I',
          isItalic: true,
          onTap: () => onFormat('*', '*'),
        ),
        _sheetFormatBtn(
          label: 'Strike',
          iconText: 'S',
          isStrike: true,
          onTap: () => onFormat('~~', '~~'),
        ),
        _sheetFormatBtn(
          label: 'Code',
          iconText: '< >',
          isCode: true,
          onTap: () => onFormat('`', '`'),
        ),
      ],
    ),
  );
}

Widget _sheetFormatBtn({
  required String label,
  required String iconText,
  required VoidCallback onTap,
  bool isBold = false,
  bool isItalic = false,
  bool isStrike = false,
  bool isCode = false,
}) {
  return GestureDetector(
    onTap: onTap,
    behavior: HitTestBehavior.opaque,
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 40,
          height: 38,
          decoration: BoxDecoration(
            color: const Color(0xFFF9FAFB),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.black, width: 1.8),
            boxShadow: const [
              BoxShadow(
                color: Colors.black,
                offset: Offset(2, 2),
                blurRadius: 0,
              ),
            ],
          ),
          child: Center(
            child: Text(
              iconText,
              style: TextStyle(
                fontSize: 13,
                fontWeight: isBold ? FontWeight.w900 : FontWeight.w700,
                fontStyle: isItalic ? FontStyle.italic : FontStyle.normal,
                decoration: isStrike ? TextDecoration.lineThrough : null,
                fontFamily: isCode ? 'monospace' : null,
                color: Colors.black,
              ),
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: GoogleFonts.poppins(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            color: Colors.black54,
          ),
        ),
      ],
    ),
  );
}
