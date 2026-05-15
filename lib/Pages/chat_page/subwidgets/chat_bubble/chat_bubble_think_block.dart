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
      final thinkContent = content.substring(openIndex + openTag.length).trim();
      return ThinkBlockParser._(
        thinkContent: thinkContent,
        responseContent: '',
        isThinkingComplete: false,
      );
    } else {
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

/// Collapsible thinking block with tinted pill, sparkle icon, and duration.
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

class _ThinkBlockWidgetState extends State<ThinkBlockWidget>
    with TickerProviderStateMixin {
  bool? _userToggle;
  final Stopwatch _stopwatch = Stopwatch();
  late final bool _wasAlreadyComplete;
  int _elapsedSeconds = 0;
  late final AnimationController _pulseController;
  late final AnimationController _expandController;
  late final Animation<double> _expandAnimation;

  bool get _isExpanded {
    if (_userToggle != null) return _userToggle!;
    return !widget.isComplete;
  }

  @override
  void initState() {
    super.initState();
    _wasAlreadyComplete = widget.isComplete;
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _expandController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
      value: _wasAlreadyComplete ? 0.0 : 1.0,
    );
    _expandAnimation = CurvedAnimation(
      parent: _expandController,
      curve: Curves.easeOutCubic,
    );
    if (!widget.isComplete) {
      _stopwatch.start();
      _startTimer();
      _pulseController.repeat(reverse: true);
    }
  }

  void _startTimer() {
    Future.doWhile(() async {
      await Future.delayed(const Duration(seconds: 1));
      if (!mounted || !_stopwatch.isRunning) return false;
      setState(() {
        _elapsedSeconds = _stopwatch.elapsed.inSeconds;
      });
      return true;
    });
  }

  @override
  void didUpdateWidget(ThinkBlockWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!oldWidget.isComplete && widget.isComplete) {
      _stopwatch.stop();
      _elapsedSeconds = _stopwatch.elapsed.inSeconds;
      _pulseController.stop();
      if (_userToggle == null) {
        _userToggle = false;
        _expandController.reverse();
      }
    }
  }

  void _toggleExpand() {
    setState(() => _userToggle = !_isExpanded);
    if (_isExpanded) {
      _expandController.forward();
    } else {
      _expandController.reverse();
    }
  }

  @override
  void dispose() {
    _stopwatch.stop();
    _pulseController.dispose();
    _expandController.dispose();
    super.dispose();
  }

  String get _label {
    if (!widget.isComplete) {
      return _elapsedSeconds > 0
          ? 'Thinking... ${_elapsedSeconds}s'
          : 'Thinking...';
    }
    if (_wasAlreadyComplete) {
      return 'Thought';
    }
    return _elapsedSeconds > 0
        ? 'Thought for $_elapsedSeconds seconds'
        : 'Thought';
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final thinkColor = colorScheme.secondary;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header row — tap to toggle
        GestureDetector(
          onTap: _toggleExpand,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 6.0),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (!widget.isComplete)
                  FadeTransition(
                    opacity: Tween(begin: 0.4, end: 1.0)
                        .animate(_pulseController),
                    child: Icon(Icons.auto_awesome,
                        color: thinkColor, size: 16),
                  )
                else
                  Icon(Icons.auto_awesome, color: thinkColor, size: 16),
                const SizedBox(width: 6),
                Text(
                  _label,
                  style: TextStyle(
                    color: thinkColor,
                    fontWeight: FontWeight.w500,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(width: 2),
                Icon(
                  _isExpanded
                      ? Icons.keyboard_arrow_down
                      : Icons.keyboard_arrow_right,
                  color: thinkColor,
                  size: 18,
                ),
              ],
            ),
          ),
        ),
        // Expandable content — no background, just indented text
        ClipRect(
          child: SizeTransition(
            sizeFactor: _expandAnimation,
            axisAlignment: -1.0,
            child: FadeTransition(
              opacity: _expandAnimation,
              child: Padding(
                padding: const EdgeInsets.only(
                    left: 22.0, top: 2.0, bottom: 8.0),
                child: SelectableText(
                  widget.content,
                  style: TextStyle(
                    color: thinkColor.withValues(alpha: 0.7),
                    fontSize: 13,
                    height: 1.5,
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
