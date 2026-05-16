import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:google_fonts/google_fonts.dart';

/// Lightweight regex-based syntax highlighter for code blocks.
/// Handles keywords, strings, numbers, and comments across common languages.
class CodeSyntaxHighlighter implements SyntaxHighlighter {
  final Brightness brightness;

  CodeSyntaxHighlighter({this.brightness = Brightness.light});

  // Token colors for light background
  static const _light = _Palette(
    base: Color(0xFF374151),
    keyword: Color(0xFF7C3AED),
    string: Color(0xFF059669),
    number: Color(0xFFD97706),
    comment: Color(0xFF9CA3AF),
    punctuation: Color(0xFF6B7280),
  );

  // Token colors for dark background
  static const _dark = _Palette(
    base: Color(0xFFCDD6F4),
    keyword: Color(0xFFCBA6F7),
    string: Color(0xFFA6E3A1),
    number: Color(0xFFFAB387),
    comment: Color(0xFF6C7086),
    punctuation: Color(0xFF9399B2),
  );

  _Palette get _colors => brightness == Brightness.dark ? _dark : _light;

  // Patterns ordered by priority (first match wins at each position)
  static final _patterns = [
    // Line comments: // # --
    _Pat(RegExp(r'//.*|#.*|--.*'), _Tok.comment),
    // Block comments
    _Pat(RegExp(r'/\*[\s\S]*?\*/'), _Tok.comment),
    // Triple-quoted strings
    _Pat(RegExp(r'"""[\s\S]*?"""|' "'''[\\s\\S]*?'''"), _Tok.string),
    // Double-quoted strings
    _Pat(RegExp(r'"(?:[^"\\]|\\.)*"'), _Tok.string),
    // Single-quoted strings
    _Pat(RegExp(r"'(?:[^'\\]|\\.)*'"), _Tok.string),
    // Backtick strings
    _Pat(RegExp(r'`[^`]*`'), _Tok.string),
    // Numbers (int, float, hex)
    _Pat(RegExp(r'\b0x[\da-fA-F]+\b|\b\d+\.?\d*(?:e[+-]?\d+)?\b'), _Tok.number),
    // Keywords (broad set covering common languages)
    _Pat(
      RegExp(
        r'\b(?:'
        // control flow
        r'if|else|elif|for|while|do|switch|case|break|continue|return|yield|'
        // declarations
        r'var|let|const|final|static|class|struct|enum|interface|trait|impl|'
        r'function|func|fn|def|fun|proc|sub|lambda|'
        r'import|from|export|module|package|require|include|use|'
        // OOP
        r'new|this|self|super|extends|implements|override|abstract|'
        // async
        r'async|await|then|'
        // error handling
        r'try|catch|except|finally|throw|raise|'
        // types & literals
        r'true|True|false|False|null|nil|None|undefined|void|'
        r'int|str|float|bool|string|double|char|byte|long|short|'
        r'print|println|printf|echo|console|'
        // shell
        r'sudo|apt|brew|pip|npm|yarn|cargo|go|git|docker|kubectl|'
        r'cd|ls|rm|cp|mv|mkdir|chmod|chown|grep|sed|awk|curl|wget'
        r')\b',
      ),
      _Tok.keyword,
    ),
    // Operators / punctuation
    _Pat(RegExp(r'[{}()\[\];,.<>!=+\-*/%&|^~?:@]'), _Tok.punctuation),
  ];

  @override
  TextSpan format(String source) {
    final spans = <TextSpan>[];
    final style = GoogleFonts.jetBrainsMono(fontSize: 12.5, height: 1.5);
    int pos = 0;

    while (pos < source.length) {
      Match? best;
      _Tok? bestType;

      for (final pat in _patterns) {
        final m = pat.regex.matchAsPrefix(source, pos);
        if (m != null) {
          best = m;
          bestType = pat.type;
          break;
        }
      }

      if (best != null) {
        if (best.start > pos) {
          spans.add(TextSpan(
            text: source.substring(pos, best.start),
            style: style.copyWith(color: _colors.base),
          ));
        }
        spans.add(TextSpan(
          text: best.group(0),
          style: style.copyWith(color: _colorFor(bestType!)),
        ));
        pos = best.end;
      } else {
        // Collect plain text until next potential match
        int end = pos + 1;
        while (end < source.length && !_anyMatch(source, end)) {
          end++;
        }
        spans.add(TextSpan(
          text: source.substring(pos, end),
          style: style.copyWith(color: _colors.base),
        ));
        pos = end;
      }
    }

    return TextSpan(children: spans);
  }

  bool _anyMatch(String source, int pos) {
    for (final pat in _patterns) {
      if (pat.regex.matchAsPrefix(source, pos) != null) return true;
    }
    return false;
  }

  Color _colorFor(_Tok type) {
    switch (type) {
      case _Tok.keyword:
        return _colors.keyword;
      case _Tok.string:
        return _colors.string;
      case _Tok.number:
        return _colors.number;
      case _Tok.comment:
        return _colors.comment;
      case _Tok.punctuation:
        return _colors.punctuation;
    }
  }
}

enum _Tok { keyword, string, number, comment, punctuation }

class _Pat {
  final RegExp regex;
  final _Tok type;
  const _Pat(this.regex, this.type);
}

class _Palette {
  final Color base;
  final Color keyword;
  final Color string;
  final Color number;
  final Color comment;
  final Color punctuation;
  const _Palette({
    required this.base,
    required this.keyword,
    required this.string,
    required this.number,
    required this.comment,
    required this.punctuation,
  });
}
