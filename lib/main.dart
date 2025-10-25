import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

const _initialUrl = 'https://techmoa.dev';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  runApp(const TechmoaApp());
}

class TechmoaApp extends StatelessWidget {
  const TechmoaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Techmoa',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF1E88E5)),
        useMaterial3: true,
      ),
      home: const TechmoaWebViewPage(),
    );
  }
}

class TechmoaWebViewPage extends StatefulWidget {
  const TechmoaWebViewPage({super.key});

  @override
  State<TechmoaWebViewPage> createState() => _TechmoaWebViewPageState();
}

class _TechmoaWebViewPageState extends State<TechmoaWebViewPage> {
  final GlobalKey _webViewKey = GlobalKey();
  late final PullToRefreshController _pullToRefreshController;
  InAppWebViewController? _controller;

  @override
  void initState() {
    super.initState();
    _pullToRefreshController = PullToRefreshController(
      options: PullToRefreshOptions(color: const Color(0xFF1E88E5)),
      onRefresh: () async {
        if (Platform.isAndroid) {
          await _controller?.reload();
        } else if (Platform.isIOS) {
          final url = await _controller?.getUrl();
          if (url != null) {
            await _controller?.loadUrl(urlRequest: URLRequest(url: url));
          }
        }
      },
    );
  }

  @override
  void dispose() {
    _pullToRefreshController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Techmoa'), centerTitle: true),
      body: SafeArea(
        child: InAppWebView(
          key: _webViewKey,
          initialUrlRequest: URLRequest(url: WebUri(_initialUrl)),
          initialSettings: InAppWebViewSettings(
            javaScriptEnabled: true,
            mediaPlaybackRequiresUserGesture: false,
          ),
          pullToRefreshController: _pullToRefreshController,
          onWebViewCreated: (controller) {
            _controller = controller;
          },
          onLoadStop: (controller, url) async {
            _pullToRefreshController.endRefreshing();
          },
          onLoadError: (controller, url, code, message) {
            _pullToRefreshController.endRefreshing();
          },
        ),
      ),
    );
  }
}
