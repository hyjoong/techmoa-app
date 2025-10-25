import 'dart:async';
import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

const _initialUrl = 'https://techmoa.dev';

class WebViewScreen extends StatefulWidget {
  const WebViewScreen({super.key});

  @override
  State<WebViewScreen> createState() => _WebViewScreenState();
}

class _WebViewScreenState extends State<WebViewScreen> {
  final GlobalKey _webViewKey = GlobalKey();
  final Connectivity _connectivity = Connectivity();
  InAppWebViewController? _controller;
  late final PullToRefreshController _pullToRefreshController;
  StreamSubscription<ConnectivityResult>? _connectivitySubscription;

  double _progress = 0;
  bool _isOffline = false;

  @override
  void initState() {
    super.initState();
    _pullToRefreshController = PullToRefreshController(
      options: PullToRefreshOptions(color: const Color(0xFF2563EB)),
      onRefresh: () async {
        if (_isOffline) {
          _pullToRefreshController.endRefreshing();
          return;
        }

        if (Platform.isAndroid) {
          await _controller?.reload();
        } else if (Platform.isIOS) {
          final currentUrl = await _controller?.getUrl();
          if (currentUrl != null) {
            await _controller?.loadUrl(urlRequest: URLRequest(url: currentUrl));
          } else {
            await _controller?.loadUrl(
              urlRequest: URLRequest(url: WebUri(_initialUrl)),
            );
          }
        }
      },
    );

    _initConnectivity();
    _connectivitySubscription = _connectivity.onConnectivityChanged.listen((
      result,
    ) async {
      final offline = await _isOfflineResult(result);
      if (!mounted) return;

      if (offline != _isOffline) {
        setState(() => _isOffline = offline);
      }

      if (!offline) {
        unawaited(_reloadCurrentPage());
      }
    });
  }

  @override
  void dispose() {
    _connectivitySubscription?.cancel();
    _pullToRefreshController.dispose();
    super.dispose();
  }

  Future<void> _initConnectivity() async {
    final result = await _connectivity.checkConnectivity();
    final offline = await _isOfflineResult(result);
    if (!mounted) return;
    setState(() => _isOffline = offline);
  }

  Future<bool> _isOfflineResult(ConnectivityResult result) async {
    return result == ConnectivityResult.none;
  }

  Future<void> _reloadCurrentPage() async {
    final controller = _controller;
    if (controller == null) return;

    final currentUrl = await controller.getUrl();
    if (currentUrl == null) {
      await controller.loadUrl(
        urlRequest: URLRequest(url: WebUri(_initialUrl)),
      );
      return;
    }
    await controller.loadUrl(urlRequest: URLRequest(url: currentUrl));
  }

  Future<void> _handleRetry() async {
    final result = await _connectivity.checkConnectivity();
    final offline = await _isOfflineResult(result);

    if (!mounted) return;
    setState(() => _isOffline = offline);

    if (!offline) {
      await _reloadCurrentPage();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Techmoa'), centerTitle: true),
      body: Column(
        children: [
          SizedBox(
            height: 3,
            child: AnimatedOpacity(
              opacity: !_isOffline && _progress < 1 ? 1 : 0,
              duration: const Duration(milliseconds: 160),
              child: LinearProgressIndicator(value: _progress.clamp(0, 1)),
            ),
          ),
          Expanded(
            child: Stack(
              children: [
                InAppWebView(
                  key: _webViewKey,
                  initialUrlRequest: URLRequest(url: WebUri(_initialUrl)),
                  initialSettings: InAppWebViewSettings(
                    javaScriptEnabled: true,
                    cacheEnabled: true,
                    supportZoom: false,
                    builtInZoomControls: false,
                    displayZoomControls: false,
                    allowsBackForwardNavigationGestures: true,
                    sharedCookiesEnabled: true,
                  ),
                  pullToRefreshController: _pullToRefreshController,
                  onWebViewCreated: (controller) {
                    _controller = controller;
                  },
                  onProgressChanged: (controller, progress) {
                    if (!mounted) return;
                    setState(() => _progress = progress / 100);
                    if (progress == 100) {
                      _pullToRefreshController.endRefreshing();
                    }
                  },
                  onLoadStop: (controller, url) async {
                    _pullToRefreshController.endRefreshing();
                  },
                  onLoadError: (controller, url, code, message) {
                    _pullToRefreshController.endRefreshing();
                  },
                ),
                if (_isOffline) _OfflineOverlay(onRetry: _handleRetry),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _OfflineOverlay extends StatelessWidget {
  const _OfflineOverlay({required this.onRetry});

  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;
    return Positioned.fill(
      child: ColoredBox(
        color: theme.colorScheme.surface,
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.wifi_off_rounded,
                  size: 56,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(height: 16),
                Text(
                  '인터넷 연결이 필요합니다.',
                  style: textTheme.titleMedium,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  '네트워크 상태를 확인하고 다시 시도하세요.',
                  style: textTheme.bodyMedium,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                ElevatedButton(onPressed: onRetry, child: const Text('재연결')),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
