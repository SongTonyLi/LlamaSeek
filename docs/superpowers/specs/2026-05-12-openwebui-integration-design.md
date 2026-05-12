# Open-webui Integration Design (v2 — WebView Hybrid)

## Problem

The Reins Flutter app connects directly to Ollama and lacks:
1. Thinking token streaming
2. Internet search
3. File attachments beyond images
4. LaTeX rendering
5. Artifact rendering (HTML/SVG code output)
6. Many other features open-webui already provides

## Solution: WebView Hybrid

Instead of reimplementing each feature natively in Flutter, embed open-webui's PWA in a WebView. Open-webui already runs locally, is mobile-optimized (PWA), and handles all rendering and features server-side.

The Flutter app becomes a **native iOS shell** around the open-webui web UI.

```
Before:  Flutter native UI  →  Ollama API
After:   Flutter shell  →  WebView (open-webui PWA)  →  Ollama
```

## What We Get For Free (from open-webui's PWA)

All of these work immediately with zero Flutter code:
- Thinking token streaming and display (collapsible blocks)
- Web search with 28+ providers
- File attachments (PDF, DOCX, CSV, TXT, code, etc.)
- Full Markdown + LaTeX (KaTeX) rendering
- Artifact rendering (HTML/SVG in sandboxed iframe)
- Code syntax highlighting
- Image generation (DALL-E, ComfyUI)
- Voice/video calls (STT/TTS)
- Multi-model conversations
- RAG with local documents
- Model management (create, configure)
- Chat history, folders, tags
- User authentication, RBAC
- Notes/persistent storage

## What Flutter Adds (native value)

- **App Store distribution** — iOS App Store presence
- **Native app lifecycle** — proper backgrounding, state restoration
- **Native file picker bridge** — enhanced file selection via `flutter_inappwebview`'s file upload handling
- **Native sharing** — share chat content via iOS share sheet
- **Persistent connection** — auto-reconnect, connection status indicators
- **Setup flow** — first-launch configuration for open-webui URL
- **App icon, splash screen** — existing native branding (already implemented)

## Architecture

### App Structure

```
┌─────────────────────────────┐
│  Flutter App Shell           │
│  ┌───────────────────────┐  │
│  │  Setup Page            │  │  ← First launch: enter open-webui URL
│  │  (native Flutter)      │  │
│  └───────────────────────┘  │
│  ┌───────────────────────┐  │
│  │  WebView Page          │  │  ← Main experience: full-screen WebView
│  │  (open-webui PWA)      │  │     loading open-webui at configured URL
│  │  ┌─────────────────┐  │  │
│  │  │ open-webui UI    │  │  │  ← All chat, rendering, features
│  │  │ (Svelte PWA)     │  │  │
│  │  └─────────────────┘  │  │
│  └───────────────────────┘  │
│  ┌───────────────────────┐  │
│  │  Connection Overlay    │  │  ← Shows when open-webui is unreachable
│  │  (native Flutter)      │  │
│  └───────────────────────┘  │
└─────────────────────────────┘
```

### Pages

1. **Setup Page** (native Flutter)
   - Shown on first launch or when no URL is configured
   - Text field for open-webui URL (default: `http://localhost:3000`)
   - "Connect" button that validates the URL (HEAD request)
   - Stores URL in Hive settings
   - Optional: open-webui API key field for authentication

2. **WebView Page** (main experience)
   - Full-screen `InAppWebView` loading the configured open-webui URL
   - Handles all navigation within open-webui
   - External links open in Safari
   - Pull-to-refresh support
   - JavaScript bridge for native features
   - Cookie persistence for login session

3. **Connection Overlay** (native Flutter)
   - Shown over WebView when open-webui is unreachable
   - Retry button, option to change server URL
   - Auto-dismiss when connection is restored

## Technical Details

### Package: `flutter_inappwebview`

Chosen over `webview_flutter` because it provides:
- File upload handling (crucial for attachments)
- Cookie persistence (login session)
- JavaScript injection and communication
- Custom URL scheme handling
- Download handling
- Camera/microphone permissions (for voice features)
- Pull-to-refresh
- Better iOS WKWebView integration

### WebView Configuration

```dart
InAppWebView(
  initialUrlRequest: URLRequest(url: WebUri(openwebuiUrl)),
  initialSettings: InAppWebViewSettings(
    // Allow file uploads
    allowFileAccessFromFileURLs: true,
    // Allow media playback
    mediaPlaybackRequiresUserGesture: false,
    // Allow inline media playback (for voice/video)
    allowsInlineMediaPlayback: true,
    // Allow JavaScript
    javaScriptEnabled: true,
    // Enable DOM storage for PWA
    domStorageEnabled: true,
    // Allow mixed content (if open-webui is HTTP)
    mixedContentMode: MixedContentMode.MIXED_CONTENT_ALWAYS_ALLOW,
    // User agent to identify as native app
    userAgent: 'Reins/1.4.0 (iOS; Flutter WebView)',
    // Transparent background during load
    transparentBackground: true,
  ),
)
```

### File Upload Handling

`flutter_inappwebview` handles `<input type="file">` natively on iOS via `onShowFileChooser`. This means open-webui's file upload button works out of the box — the WebView presents the native iOS file picker automatically.

### Cookie & Session Persistence

`CookieManager.instance()` from `flutter_inappwebview` persists cookies across app launches. User logs into open-webui once, stays logged in.

### Navigation Handling

```dart
shouldOverrideUrlLoading: (controller, action) {
  final url = action.request.url;
  // Keep open-webui navigation inside WebView
  if (url?.host == openwebuiHost) {
    return NavigationActionPolicy.ALLOW;
  }
  // External links open in Safari
  launchUrl(url!);
  return NavigationActionPolicy.CANCEL;
}
```

### Connection Health Check

Periodic HEAD request to the open-webui URL to detect disconnections:
```dart
Timer.periodic(Duration(seconds: 10), (_) async {
  try {
    await http.head(Uri.parse(openwebuiUrl)).timeout(Duration(seconds: 3));
    setState(() => isConnected = true);
  } catch (_) {
    setState(() => isConnected = false);
  }
});
```

### JavaScript Bridge (optional, for native enhancements)

```dart
webViewController.addJavaScriptHandler(
  handlerName: 'nativeShare',
  callback: (args) {
    Share.share(args[0] as String);
  },
);
```

## New Files

### `lib/Pages/webview_page.dart`
Main WebView page wrapping open-webui PWA. Handles:
- WebView initialization and configuration
- Navigation policy (internal vs external links)
- File upload delegation to native iOS picker
- Connection status monitoring
- Pull-to-refresh
- Back button navigation (WebView history)
- JavaScript bridge setup

### `lib/Pages/setup_page.dart`
First-launch setup page:
- Open-webui URL input with validation
- Connection test
- Stores config in Hive

### `lib/Widgets/connection_overlay.dart`
Overlay shown when open-webui is unreachable:
- "Cannot connect to server" message
- Retry button
- "Change server" button

## Modified Files

### `lib/main.dart`
- Route to setup page if no URL configured, otherwise WebView page
- Remove native chat providers if in open-webui mode (optional: keep for direct Ollama fallback)

### `lib/Pages/chat_page/chat_page.dart`
- Keep existing native chat as fallback for direct Ollama mode
- Or remove entirely if going all-in on open-webui

### `pubspec.yaml`
- Add `flutter_inappwebview: ^6.0.0`
- Keep existing dependencies (used by direct Ollama fallback, or remove if going all-in)

## Settings & Configuration

Hive settings keys:
- `openwebuiUrl` — URL string (default: `http://localhost:3000`)
- `hasCompletedSetup` — bool, controls first-launch routing

## Migration Path

### Phase 1 (this implementation)
- Add WebView page as the primary experience when open-webui URL is configured
- Keep existing native chat page as fallback for direct Ollama (no open-webui)
- User chooses mode in setup: "Connect to Open-webui" or "Connect to Ollama directly"

### Phase 2 (future, optional)
- Remove native chat UI entirely if open-webui mode proves sufficient
- Add deeper native integrations (push notifications via open-webui webhooks, Siri shortcuts, widgets)

## Error Handling

- **Open-webui unreachable**: Show connection overlay with retry
- **SSL errors**: Allow self-signed certs option in setup (common for local servers)
- **WebView crash**: Auto-reload with error message
- **Login expired**: WebView naturally shows open-webui login page

## Testing Plan

- Setup flow: enter URL, validate connection, proceed to WebView
- WebView loads: open-webui UI renders correctly on iOS simulator
- Thinking tokens: test with DeepSeek-R1, verify streaming + collapse in WebView
- Web search: toggle search in open-webui UI, verify results
- File attachments: tap upload in open-webui, verify native file picker appears
- LaTeX: send math question, verify KaTeX renders in WebView
- Artifacts: ask model to generate HTML, verify artifact panel renders
- Session persistence: close and reopen app, verify still logged in
- Connection loss: stop open-webui server, verify overlay appears, restart, verify auto-recovery
- Back navigation: iOS back swipe navigates WebView history correctly
- External links: links to external sites open in Safari
- iOS simulator: full end-to-end test of all features
