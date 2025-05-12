import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:device_info_plus/device_info_plus.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Adaptive WebView App',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      home: const MyHomePage(),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({Key? key}) : super(key: key);

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  WebViewController? _controller;
  final FocusNode _keyboardFocusNode = FocusNode();
  final String _url = 'https://libretv-3c1.pages.dev';
  bool _isLoading = true;
  String? _errorMessage;
  bool _isTV = false;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    final info = await DeviceInfoPlugin().androidInfo;
    setState(() {
      _isTV = info.systemFeatures.contains('android.hardware.type.television');
    });
    _setupUI();
    _createWebViewController();
    if (_isTV) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _keyboardFocusNode.requestFocus();
      });
    }
  }

  void _setupUI() {
    if (_isTV) {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    } else {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    }
  }

  void _createWebViewController() {
    final controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0x00000000))
      ..setNavigationDelegate(
        NavigationDelegate(
          onProgress: (progress) => setState(() => _isLoading = progress < 100),
          onPageStarted: (_) => setState(() {
            _isLoading = true;
            _errorMessage = null;
          }),
          onPageFinished: (_) => setState(() => _isLoading = false),
          onWebResourceError: (e) => setState(() {
            _isLoading = false;
            _errorMessage = '加载失败: ${e.description}';
          }),
        ),
      )
      ..loadRequest(Uri.parse(_url));
    setState(() {
      _controller = controller;
    });
  }

  void _scrollWebView(int dx, int dy) {
    _controller?.runJavaScript('window.scrollBy($dx, $dy);');
  }

  void _tapCenter() {
    const js = r"""
      (function() {
        const x = window.innerWidth / 2;
        const y = window.innerHeight / 2;
        const el = document.elementFromPoint(x, y);
        if (el) el.click();
      })();
    """;
    _controller?.runJavaScript(js);
  }

  void _dispatchTab(bool reverse) {
    final js = reverse
        ? "document.dispatchEvent(new KeyboardEvent('keydown', {key: 'Tab', keyCode: 9, which: 9, shiftKey: true, bubbles: true}));"
        : "document.dispatchEvent(new KeyboardEvent('keydown', {key: 'Tab', keyCode: 9, which: 9, bubbles: true}));";
    _controller?.runJavaScript(js);
  }

  void _handleTVKey(RawKeyEvent event) {
    if (event is RawKeyDownEvent) {
      final key = event.logicalKey;
      debugPrint('TV Key pressed: key=${key.debugName}');
      if (key == LogicalKeyboardKey.arrowDown || key == LogicalKeyboardKey.arrowRight) {
        debugPrint('Action: tab forward');
        _dispatchTab(false);
      } else if (key == LogicalKeyboardKey.arrowUp || key == LogicalKeyboardKey.arrowLeft) {
        debugPrint('Action: tab backward');
        _dispatchTab(true);
      } else if (key == LogicalKeyboardKey.select || key == LogicalKeyboardKey.enter) {
        debugPrint('Action: tap center');
        _tapCenter();
      } else {
        debugPrint('Unhandled key');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    Widget content;
    if (controller == null) {
      content = const Center(child: CircularProgressIndicator());
    } else {
      content = WebViewWidget(controller: controller);
    }

    if (_isTV) {
      return RawKeyboardListener(
        focusNode: _keyboardFocusNode,
        autofocus: true,
        onKey: _handleTVKey,
        child: Scaffold(
          body: Stack(
            children: [
              content,
              if (_errorMessage != null)
                Positioned(
                  top: 20,
                  left: 0,
                  right: 0,
                  child: Container(
                    color: Colors.red.withOpacity(0.7),
                    padding: const EdgeInsets.all(8),
                    child: Text(
                      _errorMessage!,
                      style: const TextStyle(color: Colors.white),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      body: Stack(
        children: [
          content,
          if (_errorMessage != null)
            Positioned(
              top: 20,
              left: 0,
              right: 0,
              child: Container(
                color: Colors.red.withOpacity(0.7),
                padding: const EdgeInsets.all(8),
                child: Text(
                  _errorMessage!,
                  style: const TextStyle(color: Colors.white),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
        ],
      ),
      floatingActionButton: controller != null
          ? FloatingActionButton(
        onPressed: () => controller.reload(),
        child: const Icon(Icons.refresh),
      )
          : null,
    );
  }

  @override
  void dispose() {
    _keyboardFocusNode.dispose();
    super.dispose();
  }
}
