import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:share_plus/share_plus.dart';
import 'package:techmoa_app/data/bookmark.dart';
import 'package:techmoa_app/data/bookmark_repository.dart';
import 'package:techmoa_app/services/notification_service.dart';

const _initialUrl = 'https://techmoa.dev';

class WebViewScreen extends StatefulWidget {
  const WebViewScreen({super.key});

  @override
  State<WebViewScreen> createState() => _WebViewScreenState();
}

class _WebViewScreenState extends State<WebViewScreen> {
  final GlobalKey _webViewKey = GlobalKey();
  final Connectivity _connectivity = Connectivity();
  final BookmarkRepository _bookmarkRepository = BookmarkRepository.instance;
  final NotificationService _notificationService = NotificationService.instance;
  InAppWebViewController? _controller;
  late final PullToRefreshController _pullToRefreshController;
  StreamSubscription<ConnectivityResult>? _connectivitySubscription;
  StreamSubscription<Map<String, dynamic>>? _notificationSubscription;

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

    // 알림 탭 리스너 등록
    _notificationSubscription = _notificationService.onNotificationTap.listen(
      (data) => _handleNotificationUrl(data),
    );
  }

  @override
  void dispose() {
    _connectivitySubscription?.cancel();
    _notificationSubscription?.cancel();
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

  /// 알림에서 받은 URL로 이동
  Future<void> _handleNotificationUrl(Map<String, dynamic> data) async {
    final url = data['url'] as String?;
    if (url == null || url.isEmpty) return;

    print('📱 알림 URL로 이동: $url');

    // 웹뷰 컨트롤러가 준비될 때까지 대기
    if (_controller == null) {
      await Future.delayed(const Duration(milliseconds: 500));
    }

    try {
      await _controller?.loadUrl(
        urlRequest: URLRequest(url: WebUri(url)),
      );
    } catch (e) {
      print('URL 로드 실패: $e');
    }
  }

  void _registerJavaScriptBridge(InAppWebViewController controller) {
    controller.addJavaScriptHandler(
      handlerName: 'saveBookmark',
      callback: (args) async {
        return await _handleSaveBookmark(args);
      },
    );
    controller.addJavaScriptHandler(
      handlerName: 'removeBookmark',
      callback: (args) async {
        return await _handleRemoveBookmark(args);
      },
    );
    controller.addJavaScriptHandler(
      handlerName: 'checkBookmark',
      callback: (args) async {
        return await _handleCheckBookmark(args);
      },
    );
    controller.addJavaScriptHandler(
      handlerName: 'shareArticle',
      callback: (args) async {
        return await _handleShareArticle(args);
      },
    );
    controller.addJavaScriptHandler(
      handlerName: 'getDeviceInfo',
      callback: (args) async => _handleGetDeviceInfo(),
    );
  }

  Future<Map<String, dynamic>> _handleSaveBookmark(List<dynamic> args) async {
    try {
      final payload = _parsePayload(args);
      final bookmark = Bookmark.fromJson(payload);
      final success = await _bookmarkRepository.saveBookmark(bookmark);
      return {'success': success};
    } catch (_) {
      return {'success': false};
    }
  }

  Future<Map<String, dynamic>> _handleRemoveBookmark(List<dynamic> args) async {
    try {
      final payload = _parsePayload(args);
      final id = payload['id']?.toString();
      if (id == null || id.isEmpty) {
        return {'success': false};
      }
      final success = await _bookmarkRepository.removeBookmark(id);
      return {'success': success};
    } catch (_) {
      return {'success': false};
    }
  }

  Future<Map<String, dynamic>> _handleCheckBookmark(List<dynamic> args) async {
    try {
      final payload = _parsePayload(args);
      final id = payload['id']?.toString();
      if (id == null || id.isEmpty) {
        return {'isBookmarked': false};
      }
      final bookmarked = await _bookmarkRepository.isBookmarked(id);
      return {'isBookmarked': bookmarked};
    } catch (_) {
      return {'isBookmarked': false};
    }
  }

  Future<Map<String, dynamic>> _handleShareArticle(List<dynamic> args) async {
    try {
      final payload = _parsePayload(args);
      final title = payload['title']?.toString();
      final url = payload['url']?.toString();
      if (url == null || url.isEmpty) {
        return {'success': false};
      }
      final shareText = title != null && title.isNotEmpty
          ? '$title\n$url'
          : url;
      await Share.share(shareText);
      return {'success': true};
    } catch (_) {
      return {'success': false};
    }
  }

  Future<Map<String, dynamic>> _handleGetDeviceInfo() async {
    try {
      final info = await PackageInfo.fromPlatform();
      final os = Platform.operatingSystem;
      final device = Platform.isIOS
          ? 'ios'
          : Platform.isAndroid
          ? 'android'
          : 'unknown';
      return {'version': info.version, 'os': os, 'device': device};
    } catch (_) {
      return {
        'version': 'unknown',
        'os': Platform.operatingSystem,
        'device': 'unknown',
      };
    }
  }

  Map<String, dynamic> _parsePayload(List<dynamic> args) {
    if (args.isEmpty) return {};
    final value = args.first;
    if (value is Map) {
      return value.map((key, value) => MapEntry(key.toString(), value));
    }
    if (value is String) {
      try {
        final decoded = jsonDecode(value);
        if (decoded is Map) {
          return decoded.map((key, value) => MapEntry(key.toString(), value));
        }
      } catch (_) {
        return {};
      }
    }
    return {};
  }

  Future<bool> _handleBackPress() async {
    final controller = _controller;
    if (controller == null) return true;

    // WebView에서 뒤로 갈 수 있는지 확인
    if (await controller.canGoBack()) {
      await controller.goBack();
      return false; // 앱 종료 방지
    }

    return true; // 뒤로 갈 곳이 없으면 앱 종료 허용
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;

        final shouldPop = await _handleBackPress();
        if (shouldPop && context.mounted) {
          Navigator.of(context).pop();
        }
      },
      child: Scaffold(
        body: SafeArea(
          child: Column(
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
                        _registerJavaScriptBridge(controller);
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
                      onReceivedError: (controller, request, error) {
                        _pullToRefreshController.endRefreshing();
                      },
                    ),
                    if (_isOffline) _OfflineOverlay(onRetry: _handleRetry),
                  ],
                ),
              ),
            ],
          ),
        ),
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
