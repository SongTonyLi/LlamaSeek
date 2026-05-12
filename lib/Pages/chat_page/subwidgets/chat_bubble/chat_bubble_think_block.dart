import 'package:flutter/material.dart';

/// Parses message content into thinking and response parts.
class ThinkBlockParser {
  final String thinkContent;
  final String responseContent;
  final bool isThinkingComplete;

  ThinkBlockParser._({
    required this.thinkContent,
    required this.responseContent,
    required this.isThinkingComplete,
  });

  /// Returns null if content has no <think> block.
  static ThinkBlockParser? tryParse(String content) {
    if (!content.trimLeft().startsWith('<think>')) return null;

    final openTag = '<think>';
    final closeTag = '</think>';
    final openIndex = content.indexOf(openTag);
    final closeIndex = content.indexOf(closeTag);

    if (closeIndex == -1) {
      // Still thinking — no closing tag yet
      final thinkContent = content.substring(openIndex + openTag.length).trim();
      return ThinkBlockParser._(
        thinkContent: thinkContent,
        responseContent: '',
        isThinkingComplete: false,
      );
    } else {
      // Thinking is complete
      final thinkContent =
          content.substring(openIndex + openTag.length, closeIndex).trim();
      final responseContent =
          content.substring(closeIndex + closeTag.length).trim();
      return ThinkBlockParser._(
        thinkContent: thinkContent,
        responseContent: responseContent,
        isThinkingComplete: true,
      );
    }
  }
}

/// Collapsible thinking block widget.
class ThinkBlockWidget extends StatefulWidget {
  final String content;
  final bool isComplete;

  const ThinkBlockWidget({
    super.key,
    required this.content,
    required this.isComplete,
  });

  @override
  State<ThinkBlockWidget> createState() => _ThinkBlockWidgetState();
}

class _ThinkBlockWidgetState extends State<ThinkBlockWidget> {
  bool? _userToggle;

  bool get _isExpanded {
    if (_userToggle != null) return _userToggle!;
    // Auto: expanded while streaming, collapsed when complete
    return !widget.isComplete;
  }

  @override
  void didUpdateWidget(ThinkBlockWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Auto-collapse when thinking completes (only if user hasn't toggled)
    if (!oldWidget.isComplete && widget.isComplete && _userToggle == null) {
      _userToggle = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.secondary;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: () {
            setState(() => _userToggle = !_isExpanded);
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4.0),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  _isExpanded
                      ? Icons.keyboard_arrow_down
                      : Icons.keyboard_arrow_right,
                  color: color,
                  size: 20,
                ),
                const SizedBox(width: 4),
                Text(
                  widget.isComplete ? 'Thought' : 'Thinking...',
                  style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
        if (_isExpanded)
          Padding(
            padding: const EdgeInsets.only(left: 24.0, top: 4.0, bottom: 8.0),
            child: SelectableText(
              widget.content,
              style: TextStyle(color: color, fontSize: 13, height: 1.4),
            ),
          ),
      ],
    );
  }
}
