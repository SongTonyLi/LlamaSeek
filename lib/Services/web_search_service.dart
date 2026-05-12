import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class WebSearchResult {
  final String title;
  final String snippet;
  final String url;
  String? pageContent; // Full page text, fetched after search

  WebSearchResult({
    required this.title,
    required this.snippet,
    required this.url,
    this.pageContent,
  });
}

class WebSearchService {
  static const _baseUrl = 'https://html.duckduckgo.com/html/';
  static const _maxPageContentLength = 4000; // chars per page
  static const _fetchTimeout = Duration(seconds: 8);

  /// Full search pipeline matching open-webui's process_web_search():
  /// 1. Search DuckDuckGo for results
  /// 2. Fetch full page content from each result URL
  /// 3. Return enriched results
  Future<List<WebSearchResult>> searchAndFetch(String query,
      {int maxResults = 3}) async {
    final results = await search(query, maxResults: maxResults);
    if (results.isEmpty) return results;

    // Fetch page content in parallel (like open-webui's get_web_loader)
    await Future.wait(
      results.map((r) => _fetchPageContent(r)),
      eagerError: false,
    );

    return results;
  }

  /// Searches DuckDuckGo and returns top results (titles + snippets only).
  Future<List<WebSearchResult>> search(String query,
      {int maxResults = 5}) async {
    final response = await http
        .post(
          Uri.parse(_baseUrl),
          headers: {
            'Content-Type': 'application/x-www-form-urlencoded',
            'User-Agent':
                'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36',
          },
          body: 'q=${Uri.encodeComponent(query)}',
        )
        .timeout(const Duration(seconds: 10));

    if (response.statusCode != 200) return [];

    return _parseResults(response.body, maxResults);
  }

  /// Fetches and extracts text content from a result URL.
  /// Mirrors open-webui's web loader that fetches full page content.
  Future<void> _fetchPageContent(WebSearchResult result) async {
    try {
      final response = await http.get(
        Uri.parse(result.url),
        headers: {
          'User-Agent':
              'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36',
          'Accept': 'text/html',
        },
      ).timeout(_fetchTimeout);

      if (response.statusCode == 200) {
        result.pageContent = _extractTextFromHtml(response.body);
      }
    } catch (e) {
      debugPrint('[WebSearch] Failed to fetch ${result.url}: $e');
      // Keep snippet as fallback — don't fail the whole search
    }
  }

  /// Extracts readable text from HTML, stripping tags and boilerplate.
  /// Similar to open-webui's BSHTMLLoader / web content extraction.
  String _extractTextFromHtml(String html) {
    // Remove script and style blocks entirely
    var text = html
        .replaceAll(RegExp(r'<script[^>]*>.*?</script>', dotAll: true), '')
        .replaceAll(RegExp(r'<style[^>]*>.*?</style>', dotAll: true), '')
        .replaceAll(RegExp(r'<nav[^>]*>.*?</nav>', dotAll: true), '')
        .replaceAll(RegExp(r'<footer[^>]*>.*?</footer>', dotAll: true), '')
        .replaceAll(RegExp(r'<header[^>]*>.*?</header>', dotAll: true), '')
        .replaceAll(RegExp(r'<!--.*?-->', dotAll: true), '');

    // Strip all HTML tags
    text = _stripHtml(text);

    // Collapse whitespace
    text = text.replaceAll(RegExp(r'\s+'), ' ').trim();

    // Truncate to reasonable size
    if (text.length > _maxPageContentLength) {
      text = text.substring(0, _maxPageContentLength);
    }

    return text;
  }

  List<WebSearchResult> _parseResults(String html, int maxResults) {
    final results = <WebSearchResult>[];

    final resultPattern = RegExp(
      r'<a[^>]*class="result__a"[^>]*href="([^"]*)"[^>]*>(.*?)</a>.*?'
      r'<a[^>]*class="result__snippet"[^>]*>(.*?)</a>',
      dotAll: true,
    );

    for (final match in resultPattern.allMatches(html)) {
      if (results.length >= maxResults) break;

      final rawUrl = match.group(1) ?? '';
      final title = _stripHtml(match.group(2) ?? '');
      final snippet = _stripHtml(match.group(3) ?? '');
      final actualUrl = _extractUrl(rawUrl);

      if (title.isNotEmpty && actualUrl.isNotEmpty) {
        results.add(WebSearchResult(
          title: title,
          snippet: snippet,
          url: actualUrl,
        ));
      }
    }

    return results;
  }

  String _stripHtml(String html) {
    return html
        .replaceAll(RegExp(r'<[^>]*>'), '')
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&quot;', '"')
        .replaceAll('&#x27;', "'")
        .replaceAll('&nbsp;', ' ')
        .trim();
  }

  String _extractUrl(String ddgUrl) {
    final uddgMatch = RegExp(r'uddg=([^&]+)').firstMatch(ddgUrl);
    if (uddgMatch != null) {
      return Uri.decodeComponent(uddgMatch.group(1)!);
    }
    if (ddgUrl.startsWith('http')) return ddgUrl;
    return '';
  }

  /// Formats search results as RAG context using open-webui's source tag format.
  /// Uses full page content when available, falls back to snippet.
  static String formatResultsAsContext(
      List<WebSearchResult> results, String query) {
    if (results.isEmpty) return '';

    final sourceContext = StringBuffer();
    for (var i = 0; i < results.length; i++) {
      final r = results[i];
      // Use full page content if fetched, otherwise snippet
      final content = r.pageContent ?? '${r.title}\n${r.snippet}';
      sourceContext.writeln(
          '<source id="${i + 1}" name="${r.url}" resource-type="web_search">');
      sourceContext.writeln(content);
      sourceContext.writeln('</source>');
    }

    // open-webui's DEFAULT_RAG_TEMPLATE
    return '''### Task:
Respond to the user query using the provided context, incorporating inline citations in the format [id] **only when the <source> tag includes an explicit id attribute** (e.g., <source id="1">).

### Guidelines:
- If you don't know the answer, clearly state that.
- If uncertain, ask the user for clarification.
- Respond in the same language as the user's query.
- **Only include inline citations using [id] when the <source> tag includes an id attribute.**

<context>
${sourceContext.toString().trim()}
</context>
''';
  }
}
