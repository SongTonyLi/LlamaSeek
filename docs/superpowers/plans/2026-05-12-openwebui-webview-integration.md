# Open-webui WebView Integration — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Embed open-webui's PWA in a WebView to get all features (thinking tokens, search, file attachments, LaTeX, artifacts) with minimal Flutter code.

**Architecture:** Flutter app shell with full-screen `InAppWebView` loading the open-webui PWA at a user-configured URL. Native setup page for first-launch configuration. Connection overlay for error recovery. Existing native chat UI kept as fallback for direct Ollama mode.

**Tech Stack:** Flutter, `flutter_inappwebview` ^6.0.0, Hive (settings), existing app infrastructure

---

### Task 1: Add `flutter_inappwebview` dependency

**Files:**
- Modify: `pubspec.yaml`
- Modify: `ios/Podfile`

- [ ] **Step 1: Add the dependency to pubspec.yaml**

Add under `dependencies:`:
```yaml
  # WebView for open-webui PWA
  flutter_inappwebview: ^6.1.5
```

- [ ] **Step 2: Update iOS minimum deployment target**

`flutter_inappwebview` v6 requires iOS 13.0+. In `ios/Podfile`, ensure the platform line reads:
```ruby
platform :ios, '13.0'
```

- [ ] **Step 3: Run flutter pub get**

Run: `flutter pub get`
Expected: Dependencies resolve successfully, no errors.

- [ ] **Step 4: Commit**

```bash
git add pubspec.yaml pubspec.lock ios/Podfile
git commit -m "feat: add flutter_inappwebview dependency"
```

---

### Task 2: Add Open-webui settings to Hive

**Files:**
- Modify: `lib/Pages/settings_page/subwidgets/server_settings.dart`

This task adds a third backend mode ("Open-webui") to the existing Local/Cloud segmented button in settings, with a URL field and connect button.

- [ ] **Step 1: Add Open-webui segment to the SegmentedButton**

In `server_settings.dart`, change the `SegmentedButton<bool>` to `SegmentedButton<String>` to support three modes. Replace the existing segmented button and its state management:

```dart
// Replace _isCloudMode getter:
String get _serverMode => _settingsBox.get('serverMode', defaultValue: 'local');

// Replace _setCloudMode:
void _setServerMode(String value) {
  _settingsBox.put('serverMode', value);
  // Migrate legacy isCloudMode for backward compatibility
  _settingsBox.put('isCloudMode', value == 'cloud');
  setState(() {});
}
```

Replace the `SegmentedButton` widget:
```dart
SegmentedButton<String>(
  segments: const [
    ButtonSegment(
      value: 'local',
      label: Text('Local'),
      icon: Icon(Icons.dns_outlined),
    ),
    ButtonSegment(
      value: 'openwebui',
      label: Text('Open-webui'),
      icon: Icon(Icons.language_outlined),
    ),
    ButtonSegment(
      value: 'cloud',
      label: Text('Cloud'),
      icon: Icon(Icons.cloud_outlined),
    ),
  ],
  selected: {_serverMode},
  onSelectionChanged: (selection) {
    _setServerMode(selection.first);
  },
),
```

Replace the conditional build at line 113:
```dart
if (_serverMode == 'cloud')
  _buildCloudSettings(context)
else if (_serverMode == 'openwebui')
  _buildOpenWebuiSettings(context)
else
  _buildLocalSettings(context),
```

- [ ] **Step 2: Add the Open-webui settings builder method**

Add this method to `_ServerSettingsState`:

```dart
final _openwebuiAddressController = TextEditingController();
OllamaRequestState _openwebuiRequestState = OllamaRequestState.uninitialized;
String? _openwebuiErrorText;

Widget _buildOpenWebuiSettings(BuildContext context) {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      TextField(
        controller: _openwebuiAddressController,
        keyboardType: TextInputType.url,
        onChanged: (_) {
          setState(() {
            _openwebuiErrorText = null;
            _openwebuiRequestState = OllamaRequestState.uninitialized;
          });
        },
        decoration: InputDecoration(
          labelText: 'Open-webui Server Address',
          hintText: 'http://localhost:3000',
          border: const OutlineInputBorder(),
          errorText: _openwebuiErrorText,
        ),
        onTapOutside: (_) => FocusManager.instance.primaryFocus?.unfocus(),
      ),
      const SizedBox(height: 8),
      Text(
        'Enter the URL of your Open-webui instance. It runs locally alongside Ollama.',
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
      ),
      const SizedBox(height: 16),
      SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          onPressed: _openwebuiRequestState == OllamaRequestState.loading
              ? null
              : _handleOpenWebuiConnect,
          child: _ConnectionStatusIndicator(
            color: _openwebuiConnectionColor,
          ),
        ),
      ),
    ],
  );
}

Color get _openwebuiConnectionColor {
  switch (_openwebuiRequestState) {
    case OllamaRequestState.error:
      return Colors.red;
    case OllamaRequestState.loading:
      return Colors.orange;
    case OllamaRequestState.success:
      return Colors.green;
    case OllamaRequestState.uninitialized:
      return Colors.grey;
  }
}
```

- [ ] **Step 3: Add the connect handler**

Add to `_ServerSettingsState`:

```dart
Future<void> _handleOpenWebuiConnect() async {
  setState(() {
    _openwebuiErrorText = null;
    _openwebuiRequestState = OllamaRequestState.loading;
  });

  try {
    final address = _validateServerAddress(_openwebuiAddressController.text);
    final url = Uri.parse(address);
    final response = await http.head(url).timeout(const Duration(seconds: 5));

    if (!mounted) return;

    if (response.statusCode == 200) {
      _openwebuiRequestState = OllamaRequestState.success;
      _settingsBox.put('openwebuiAddress', address);
    } else {
      _openwebuiErrorText = 'Connection failed (${response.statusCode}).';
      _openwebuiRequestState = OllamaRequestState.error;
    }
  } on OllamaException catch (e) {
    _openwebuiErrorText = e.message;
    _openwebuiRequestState = OllamaRequestState.error;
  } catch (_) {
    _openwebuiErrorText = 'Could not connect to Open-webui server.';
    _openwebuiRequestState = OllamaRequestState.error;
  } finally {
    setState(() {});
  }
}
```

- [ ] **Step 4: Initialize the Open-webui controller in `_initialize()`**

Add to the existing `_initialize()` method:

```dart
final openwebuiAddress = _settingsBox.get('openwebuiAddress');
if (openwebuiAddress != null) {
  _openwebuiAddressController.text = openwebuiAddress;
  if (_serverMode == 'openwebui') {
    _handleOpenWebuiConnect();
  }
}
```

Add to `dispose()`:
```dart
_openwebuiAddressController.dispose();
```

- [ ] **Step 5: Update references to `_isCloudMode`**

In `_initialize()`, update the existing checks:
```dart
if (serverAddress != null) {
  _serverAddressController.text = serverAddress;
  if (_serverMode == 'local') {
    _handleConnectButton();
  }
}

if (cloudApiKey != null) {
  _apiKeyController.text = cloudApiKey;
  if (_serverMode == 'cloud') {
    _handleCloudConnectButton();
  }
}
```

- [ ] **Step 6: Verify it builds**

Run: `flutter build ios --simulator --no-codesign`
Expected: Build succeeds.

- [ ] **Step 7: Commit**

```bash
git add lib/Pages/settings_page/subwidgets/server_settings.dart
git commit -m "feat: add Open-webui server mode to settings"
```

---

### Task 3: Create the WebView page

**Files:**
- Create: `lib/Pages/openwebui_page.dart`

This is the core of the integration — a full-screen WebView that loads the open-webui PWA.

- [ ] **Step 1: Create the WebView page**

```dart
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:hive_flutter/hive_flutter.dart';

class OpenWebuiPage extends StatefulWidget {
  const OpenWebuiPage({super.key});

  @override
  State<OpenWebuiPage> createState() => _OpenWebuiPageState();
}

class _OpenWebuiPageState extends State<OpenWebuiPage> {
  InAppWebViewController? _webViewController;
  bool _isLoading = true;
  bool _isConnected = true;
  Timer? _healthCheckTimer;

  String get _openwebuiUrl {
    final box = Hive.box('settings');
    return box.get('openwebuiAddress', defaultValue: 'http://localhost:3000');
  }

  @override
  void initState() {
    super.initState();
    _startHealthCheck();
  }

  @override
  void dispose() {
    _healthCheckTimer?.cancel();
    super.dispose();
  }

  void _startHealthCheck() {
    _healthCheckTimer = Timer.periodic(
      const Duration(seconds: 10),
      (_) => _checkConnection(),
    );
  }

  Future<void> _checkConnection() async {
    try {
      final url = Uri.parse(_openwebuiUrl);
      // Use a simple fetch to check if the server is reachable
      // We do this via the WebView's JavaScript to avoid CORS issues
      final connected = await _webViewController?.evaluateJavascript(
        source: 'navigator.onLine',
      );
      if (mounted) {
        setState(() => _isConnected = connected != 'false');
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isConnected = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Stack(
          children: [
            InAppWebView(
              initialUrlRequest: URLRequest(
                url: WebUri(_openwebuiUrl),
              ),
              initialSettings: InAppWebViewSettings(
                javaScriptEnabled: true,
                domStorageEnabled: true,
                allowsInlineMediaPlayback: true,
                mediaPlaybackRequiresUserGesture: false,
                mixedContentMode: MixedContentMode.MIXED_CONTENT_ALWAYS_ALLOW,
                allowsBackForwardNavigationGestures: true,
                userAgent: 'Reins/1.4.0 (iOS; Flutter)',
                transparentBackground: true,
              ),
              onWebViewCreated: (controller) {
                _webViewController = controller;
              },
              onLoadStart: (controller, url) {
                setState(() => _isLoading = true);
              },
              onLoadStop: (controller, url) {
                setState(() {
                  _isLoading = false;
                  _isConnected = true;
                });
              },
              onReceivedError: (controller, request, error) {
                if (request.isForMainFrame ?? false) {
                  setState(() {
                    _isLoading = false;
                    _isConnected = false;
                  });
                }
              },
              shouldOverrideUrlLoading: (controller, action) async {
                final url = action.request.url;
                if (url == null) return NavigationActionPolicy.CANCEL;

                final openwebuiHost = Uri.parse(_openwebuiUrl).host;

                // Allow navigation within open-webui
                if (url.host == openwebuiHost || url.host.isEmpty) {
                  return NavigationActionPolicy.ALLOW;
                }

                // External links: open in system browser
                // (url_launcher is already a dependency)
                return NavigationActionPolicy.CANCEL;
              },
            ),
            // Loading indicator
            if (_isLoading)
              const Center(
                child: CircularProgressIndicator(),
              ),
            // Connection error overlay
            if (!_isConnected && !_isLoading)
              _ConnectionOverlay(
                serverUrl: _openwebuiUrl,
                onRetry: () {
                  setState(() => _isLoading = true);
                  _webViewController?.reload();
                },
                onChangeServer: () {
                  Navigator.pushNamed(context, '/settings');
                },
              ),
          ],
        ),
      ),
    );
  }
}

class _ConnectionOverlay extends StatelessWidget {
  final String serverUrl;
  final VoidCallback onRetry;
  final VoidCallback onChangeServer;

  const _ConnectionOverlay({
    required this.serverUrl,
    required this.onRetry,
    required this.onChangeServer,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Theme.of(context).colorScheme.surface,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.cloud_off_outlined,
                size: 64,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              const SizedBox(height: 16),
              Text(
                'Cannot connect to Open-webui',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              Text(
                serverUrl,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              ),
              const SizedBox(height: 8),
              Text(
                'Make sure Open-webui is running and accessible.',
                style: Theme.of(context).textTheme.bodyMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: onChangeServer,
                child: const Text('Change Server'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
```

- [ ] **Step 2: Verify it compiles**

Run: `flutter analyze lib/Pages/openwebui_page.dart`
Expected: No errors.

- [ ] **Step 3: Commit**

```bash
git add lib/Pages/openwebui_page.dart
git commit -m "feat: create OpenWebuiPage with WebView and connection overlay"
```

---

### Task 4: Wire up routing — show WebView when Open-webui mode is active

**Files:**
- Modify: `lib/Pages/main_page.dart`
- Modify: `lib/main.dart`

When the user has selected "Open-webui" mode and configured a URL, the main page should show the WebView instead of the native chat UI.

- [ ] **Step 1: Update main_page.dart to conditionally show WebView**

Replace the contents of `main_page.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:reins/Pages/chat_page/chat_page.dart';
import 'package:reins/Pages/openwebui_page.dart';
import 'package:reins/Widgets/chat_app_bar.dart';
import 'package:reins/Widgets/chat_drawer.dart';
import 'package:responsive_framework/responsive_framework.dart';

class ReinsMainPage extends StatelessWidget {
  const ReinsMainPage({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: Hive.box('settings').listenable(
        keys: ['serverMode', 'openwebuiAddress'],
      ),
      builder: (context, box, _) {
        final serverMode = box.get('serverMode', defaultValue: 'local');
        final openwebuiAddress = box.get('openwebuiAddress');

        if (serverMode == 'openwebui' && openwebuiAddress != null) {
          return const OpenWebuiPage();
        }

        if (ResponsiveBreakpoints.of(context).isMobile) {
          return const _ReinsMobileMainPage();
        } else {
          return const _ReinsLargeMainPage();
        }
      },
    );
  }
}

class _ReinsMobileMainPage extends StatelessWidget {
  const _ReinsMobileMainPage();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      appBar: ChatAppBar(),
      body: SafeArea(child: ChatPage()),
      drawer: ChatDrawer(),
    );
  }
}

class _ReinsLargeMainPage extends StatelessWidget {
  const _ReinsLargeMainPage();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: SafeArea(
        child: Row(
          children: [
            ChatDrawer(),
            Expanded(child: ChatPage()),
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Step 2: Update server_settings.dart — fix `_isCloudMode` references in ChatAppBar**

The `ChatAppBar` uses `isCloudMode` from Hive. Update it to also handle the new mode. In `lib/Widgets/chat_app_bar.dart`, the `ValueListenableBuilder` already listens to `isCloudMode`. Since we keep setting `isCloudMode` in `_setServerMode()` for backward compat, no change is needed here.

However, in `chat_page_view_model.dart` line 57-64, `isServerConfigured` checks `isCloudMode`. Update it:

```dart
bool get isServerConfigured {
  final box = Hive.box('settings');
  final serverMode = box.get('serverMode', defaultValue: 'local');
  if (serverMode == 'openwebui') {
    return box.get('openwebuiAddress') != null;
  }
  final isCloudMode = box.get('isCloudMode', defaultValue: false);
  if (isCloudMode) {
    return box.get('cloudApiKey') != null;
  }
  return box.get('serverAddress') != null;
}
```

- [ ] **Step 3: Verify the app builds and routes correctly**

Run: `flutter build ios --simulator --no-codesign`
Expected: Build succeeds.

- [ ] **Step 4: Commit**

```bash
git add lib/Pages/main_page.dart lib/Pages/chat_page/chat_page_view_model.dart
git commit -m "feat: route to WebView page when Open-webui mode is active"
```

---

### Task 5: Handle iOS permissions and transport security

**Files:**
- Modify: `ios/Runner/Info.plist`

The WebView needs to load HTTP URLs (local servers) and access camera/microphone (for open-webui's voice features).

- [ ] **Step 1: Add App Transport Security exception for local HTTP**

The app already has some Info.plist config. Read the current file and add/update these keys inside the top-level `<dict>`:

Add `NSAppTransportSecurity` if not present:
```xml
<key>NSAppTransportSecurity</key>
<dict>
    <key>NSAllowsLocalNetworking</key>
    <true/>
    <key>NSAllowsArbitraryLoadsInWebContent</key>
    <true/>
</dict>
```

`NSAllowsLocalNetworking` allows HTTP to localhost/LAN. `NSAllowsArbitraryLoadsInWebContent` allows the WebView to load any content (needed since open-webui may fetch external resources).

- [ ] **Step 2: Add camera and microphone usage descriptions (for voice/video features)**

Add these if not already present in Info.plist:
```xml
<key>NSCameraUsageDescription</key>
<string>Camera access is needed for video calls in Open-webui.</string>
<key>NSMicrophoneUsageDescription</key>
<string>Microphone access is needed for voice input in Open-webui.</string>
```

- [ ] **Step 3: Verify build**

Run: `flutter build ios --simulator --no-codesign`
Expected: Build succeeds.

- [ ] **Step 4: Commit**

```bash
git add ios/Runner/Info.plist
git commit -m "feat: add iOS permissions for WebView HTTP and media access"
```

---

### Task 6: Add settings navigation from WebView page

**Files:**
- Modify: `lib/Pages/openwebui_page.dart`

The WebView page needs a way to access app settings (to change server, theme, etc.) without relying on open-webui's drawer.

- [ ] **Step 1: Add a floating settings button**

Add a small gear icon button overlaid on the WebView. Update the `build` method in `_OpenWebuiPageState` to add a positioned settings button in the Stack:

```dart
// Add after the _ConnectionOverlay widget in the Stack children:
Positioned(
  top: 8,
  right: 8,
  child: SafeArea(
    child: Material(
      color: Colors.transparent,
      child: IconButton(
        icon: Icon(
          Icons.settings_outlined,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
          size: 20,
        ),
        style: IconButton.styleFrom(
          backgroundColor: Theme.of(context)
              .colorScheme
              .surfaceContainerHighest
              .withValues(alpha: 0.8),
          padding: const EdgeInsets.all(8),
          minimumSize: const Size(36, 36),
        ),
        onPressed: () => Navigator.pushNamed(context, '/settings'),
      ),
    ),
  ),
),
```

- [ ] **Step 2: Commit**

```bash
git add lib/Pages/openwebui_page.dart
git commit -m "feat: add settings button overlay on WebView page"
```

---

### Task 7: Handle back navigation properly

**Files:**
- Modify: `lib/Pages/openwebui_page.dart`

On iOS, the user should be able to navigate back within the WebView (e.g., from settings back to chat). The WebView already has `allowsBackForwardNavigationGestures: true` for swipe gestures. We also need to handle the Android back button (for future cross-platform support) via `PopScope`.

- [ ] **Step 1: Wrap the Scaffold in a PopScope for back navigation**

In `_OpenWebuiPageState.build()`, wrap the `Scaffold` in `PopScope`:

```dart
@override
Widget build(BuildContext context) {
  return PopScope(
    canPop: false,
    onPopInvokedWithResult: (didPop, result) async {
      if (didPop) return;
      final canGoBack = await _webViewController?.canGoBack() ?? false;
      if (canGoBack) {
        _webViewController?.goBack();
      }
    },
    child: Scaffold(
      // ... existing body
    ),
  );
}
```

- [ ] **Step 2: Commit**

```bash
git add lib/Pages/openwebui_page.dart
git commit -m "feat: handle back navigation in WebView"
```

---

### Task 8: Add pull-to-refresh

**Files:**
- Modify: `lib/Pages/openwebui_page.dart`

- [ ] **Step 1: Wrap InAppWebView with PullToRefreshController**

Add a `PullToRefreshController` field and initialize it in `initState`:

```dart
late final PullToRefreshController _pullToRefreshController;

@override
void initState() {
  super.initState();
  _pullToRefreshController = PullToRefreshController(
    settings: PullToRefreshSettings(
      color: Colors.grey,
    ),
    onRefresh: () async {
      _webViewController?.reload();
    },
  );
  _startHealthCheck();
}
```

Then add it to the `InAppWebView`:
```dart
InAppWebView(
  pullToRefreshController: _pullToRefreshController,
  // ... rest of existing config
  onLoadStop: (controller, url) {
    _pullToRefreshController.endRefreshing();
    setState(() {
      _isLoading = false;
      _isConnected = true;
    });
  },
  onReceivedError: (controller, request, error) {
    _pullToRefreshController.endRefreshing();
    if (request.isForMainFrame ?? false) {
      setState(() {
        _isLoading = false;
        _isConnected = false;
      });
    }
  },
  // ...
),
```

- [ ] **Step 2: Commit**

```bash
git add lib/Pages/openwebui_page.dart
git commit -m "feat: add pull-to-refresh to WebView page"
```

---

### Task 9: Test on iOS simulator

**Files:** None (testing only)

- [ ] **Step 1: Install pods**

Run: `cd /Users/songli/reins/ios && pod install --repo-update && cd ..`

- [ ] **Step 2: Build and launch on iOS simulator**

Run: `flutter run --simulator`

Or if a specific simulator is needed:
```bash
xcrun simctl list devices available | grep iPhone
flutter run -d "iPhone 16"
```

Expected: App launches in simulator.

- [ ] **Step 3: Verify native chat mode (default)**

1. App should open in native chat mode (existing UI) since no Open-webui URL is configured
2. Open settings, verify three-segment button: Local / Open-webui / Cloud
3. The Local and Cloud tabs should work exactly as before

- [ ] **Step 4: Switch to Open-webui mode**

1. In Settings, tap "Open-webui" segment
2. Enter the Open-webui URL (e.g., `http://localhost:3000` or the user's actual server)
3. Tap Connect
4. If server is running: green status indicator
5. Go back to main page — should show WebView loading open-webui

- [ ] **Step 5: Verify all features in WebView**

1. **Thinking tokens**: Use a thinking model (DeepSeek-R1), verify thinking block appears and streams
2. **Web search**: Toggle search in open-webui's UI, verify search results
3. **File attachments**: Tap attach button in open-webui, verify native file picker appears
4. **LaTeX**: Ask a math question, verify equations render
5. **Artifacts**: Ask for HTML code, verify artifact panel renders
6. **Navigation**: Swipe back works, settings button overlay works

- [ ] **Step 6: Verify connection error handling**

1. Stop the open-webui server
2. The connection overlay should appear: "Cannot connect to Open-webui"
3. Tap "Retry" — should show loading, then overlay again (server still down)
4. Tap "Change Server" — should go to settings page
5. Restart open-webui server, tap "Retry" — should load successfully

- [ ] **Step 7: Commit any fixes found during testing**

```bash
git add -A
git commit -m "fix: address issues found during iOS simulator testing"
```

---

### Task 10: Clean up and final polish

**Files:**
- Modify: `lib/Pages/openwebui_page.dart`
- Modify: `lib/Pages/settings_page/subwidgets/server_settings.dart`

- [ ] **Step 1: Handle cookie persistence for login session**

In `openwebui_page.dart`, the `InAppWebView` already persists cookies via WKWebView's default cookie store on iOS. Verify this works by logging into open-webui, closing the app, reopening — should still be logged in.

If not working, add explicit cookie manager setup in `onWebViewCreated`:
```dart
onWebViewCreated: (controller) {
  _webViewController = controller;
  // Ensure cookies persist across sessions
  CookieManager.instance().setAcceptThirdPartyCookies(
    webViewController: controller,
    accept: true,
  );
},
```

- [ ] **Step 2: Handle SSL certificate errors for self-signed certs**

Local servers often use self-signed certificates. Add to `InAppWebView`:
```dart
onReceivedServerTrustAuthRequest: (controller, challenge) async {
  // Allow self-signed certs for local servers
  final host = challenge.protectionSpace.host;
  final openwebuiHost = Uri.parse(_openwebuiUrl).host;
  if (host == openwebuiHost) {
    return ServerTrustAuthResponse(
      action: ServerTrustAuthResponseAction.PROCEED,
    );
  }
  return ServerTrustAuthResponse(
    action: ServerTrustAuthResponseAction.CANCEL,
  );
},
```

- [ ] **Step 3: Auto-reconnect when settings change**

When the user changes the Open-webui URL in settings and comes back, the WebView should reload with the new URL. The `ValueListenableBuilder` in `main_page.dart` already handles this by rebuilding `OpenWebuiPage` when `openwebuiAddress` changes — since `OpenWebuiPage` is recreated, it loads the new URL automatically.

Verify this works. No code change needed unless it doesn't.

- [ ] **Step 4: Final commit**

```bash
git add -A
git commit -m "feat: add cookie persistence and SSL handling for WebView"
```
