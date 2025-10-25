import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:techmoa_app/data/bookmark.dart';
import 'package:techmoa_app/data/bookmark_repository.dart';
import 'package:url_launcher/url_launcher.dart';

class OfflineBookmarksScreen extends StatefulWidget {
  const OfflineBookmarksScreen({super.key});

  @override
  State<OfflineBookmarksScreen> createState() => _OfflineBookmarksScreenState();
}

class _OfflineBookmarksScreenState extends State<OfflineBookmarksScreen> {
  final BookmarkRepository _repository = BookmarkRepository.instance;
  final TextEditingController _searchController = TextEditingController();
  final Connectivity _connectivity = Connectivity();

  late StreamSubscription<void> _bookmarkSubscription;
  StreamSubscription<ConnectivityResult>? _connectivitySubscription;

  List<Bookmark> _bookmarks = const <Bookmark>[];
  List<Bookmark> _filtered = const <Bookmark>[];
  bool _isLoading = true;
  bool _isOffline = false;

  @override
  void initState() {
    super.initState();
    _loadBookmarks();
    _bookmarkSubscription = _repository.changes.listen((_) => _loadBookmarks());
    _searchController.addListener(_applyFilter);
    _initConnectivity();
  }

  @override
  void dispose() {
    _bookmarkSubscription.cancel();
    _connectivitySubscription?.cancel();
    _searchController
      ..removeListener(_applyFilter)
      ..dispose();
    super.dispose();
  }

  Future<void> _initConnectivity() async {
    final initial = await _connectivity.checkConnectivity();
    _setOffline(initial == ConnectivityResult.none);
    _connectivitySubscription = _connectivity.onConnectivityChanged.listen((
      result,
    ) {
      _setOffline(result == ConnectivityResult.none);
    });
  }

  void _setOffline(bool value) {
    if (_isOffline != value && mounted) {
      setState(() => _isOffline = value);
    }
  }

  Future<void> _loadBookmarks() async {
    setState(() => _isLoading = true);
    final items = await _repository.fetchBookmarks();
    items.sort(
      (a, b) => _parseDate(b.publishedAt).compareTo(_parseDate(a.publishedAt)),
    );
    if (!mounted) return;
    setState(() {
      _bookmarks = items;
      _applyFilter();
      _isLoading = false;
    });
  }

  DateTime _parseDate(String? value) {
    if (value == null || value.isEmpty) {
      return DateTime.fromMillisecondsSinceEpoch(0);
    }
    return DateTime.tryParse(value) ?? DateTime.fromMillisecondsSinceEpoch(0);
  }

  void _applyFilter() {
    final keyword = _searchController.text.trim().toLowerCase();
    if (keyword.isEmpty) {
      setState(() => _filtered = List<Bookmark>.from(_bookmarks));
      return;
    }
    setState(() {
      _filtered = _bookmarks.where((bookmark) {
        final titleMatch = bookmark.title.toLowerCase().contains(keyword);
        final authorMatch = (bookmark.author ?? '').toLowerCase().contains(
          keyword,
        );
        return titleMatch || authorMatch;
      }).toList();
    });
  }

  Future<void> _removeBookmark(String id) async {
    await _repository.removeBookmark(id);
  }

  Future<void> _openBookmark(Bookmark bookmark, LaunchMode mode) async {
    final uri = Uri.tryParse(bookmark.externalUrl);
    if (uri == null) return;
    final launched = await launchUrl(uri, mode: mode);
    if (!launched && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('링크를 열 수 없습니다: ${uri.toString()}')),
      );
    }
  }

  Future<void> _showOpenSheet(Bookmark bookmark) async {
    if (!mounted) return;
    final mode = await showModalBottomSheet<LaunchMode>(
      context: context,
      showDragHandle: true,
      builder: (_) => _OpenOptionsSheet(bookmark: bookmark),
    );
    if (mode != null) {
      await _openBookmark(bookmark, mode);
    }
  }

  Future<void> _openWebHome() async {
    await _openBookmark(
      Bookmark(
        id: 'techmoa-home',
        title: 'Techmoa',
        externalUrl: 'https://techmoa.dev',
      ),
      LaunchMode.externalApplication,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('북마크')),
      body: Column(
        children: [
          if (_isOffline) const _OfflineBanner(),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.search_rounded),
                hintText: '제목 또는 작성자로 검색',
                isDense: true,
                filled: true,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _filtered.isEmpty
                ? _EmptyState(onOpenWeb: _openWebHome)
                : RefreshIndicator(
                    onRefresh: _loadBookmarks,
                    child: ListView.separated(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                      itemBuilder: (context, index) {
                        final bookmark = _filtered[index];
                        return Dismissible(
                          key: ValueKey(bookmark.id),
                          direction: DismissDirection.endToStart,
                          background: _DismissibleBackground.neutral(context),
                          secondaryBackground: _DismissibleBackground.delete(
                            context,
                          ),
                          onDismissed: (_) => _removeBookmark(bookmark.id),
                          child: _BookmarkTile(
                            bookmark: bookmark,
                            onTap: () => _showOpenSheet(bookmark),
                          ),
                        );
                      },
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemCount: _filtered.length,
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

class _BookmarkTile extends StatelessWidget {
  const _BookmarkTile({required this.bookmark, required this.onTap});

  final Bookmark bookmark;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: theme.colorScheme.surface,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _BookmarkThumbnail(url: bookmark.thumbnailUrl),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      bookmark.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleMedium,
                    ),
                    const SizedBox(height: 4),
                    if (bookmark.author != null &&
                        bookmark.author!.trim().isNotEmpty)
                      Text(
                        bookmark.author!.trim(),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.primary,
                        ),
                      ),
                    const SizedBox(height: 4),
                    Text(
                      bookmark.publishedAt ?? '',
                      style: theme.textTheme.bodySmall,
                    ),
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

class _BookmarkThumbnail extends StatelessWidget {
  const _BookmarkThumbnail({this.url});

  final String? url;

  @override
  Widget build(BuildContext context) {
    final borderRadius = BorderRadius.circular(10);
    if (url == null || url!.isEmpty) {
      return _PlaceholderThumbnail(borderRadius: borderRadius);
    }

    return ClipRRect(
      borderRadius: borderRadius,
      child: Image.network(
        url!,
        width: 72,
        height: 72,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) =>
            _PlaceholderThumbnail(borderRadius: borderRadius),
      ),
    );
  }
}

class _PlaceholderThumbnail extends StatelessWidget {
  const _PlaceholderThumbnail({required this.borderRadius});

  final BorderRadius borderRadius;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: 72,
      height: 72,
      decoration: BoxDecoration(
        borderRadius: borderRadius,
        color: theme.colorScheme.surfaceVariant,
      ),
      alignment: Alignment.center,
      child: Icon(
        Icons.article_outlined,
        color: theme.colorScheme.onSurfaceVariant,
      ),
    );
  }
}

class _OpenOptionsSheet extends StatelessWidget {
  const _OpenOptionsSheet({required this.bookmark});

  final Bookmark bookmark;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              bookmark.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 16),
            ListTile(
              leading: const Icon(Icons.open_in_browser_rounded),
              title: const Text('외부 브라우저로 열기'),
              onTap: () =>
                  Navigator.of(context).pop(LaunchMode.externalApplication),
            ),
            ListTile(
              leading: const Icon(Icons.open_in_new_rounded),
              title: const Text('인앱 웹뷰로 열기'),
              onTap: () =>
                  Navigator.of(context).pop(LaunchMode.inAppBrowserView),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.onOpenWeb});

  final Future<void> Function() onOpenWeb;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.bookmark_outline_rounded,
              size: 64,
              color: theme.colorScheme.primary,
            ),
            const SizedBox(height: 16),
            const Text(
              '저장된 북마크가 없습니다.',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            const Text(
              'Techmoa 웹에서 관심 있는 글을 북마크로 저장해보세요.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: onOpenWeb,
              icon: const Icon(Icons.open_in_browser_rounded),
              label: const Text('웹으로 이동'),
            ),
          ],
        ),
      ),
    );
  }
}

class _OfflineBanner extends StatelessWidget {
  const _OfflineBanner();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      color: theme.colorScheme.errorContainer,
      child: Text(
        '오프라인 모드 - 저장된 북마크만 사용 가능',
        style: theme.textTheme.bodyMedium?.copyWith(
          color: theme.colorScheme.onErrorContainer,
        ),
      ),
    );
  }
}

class _DismissibleBackground extends StatelessWidget {
  const _DismissibleBackground({
    required this.icon,
    required this.alignment,
    required this.color,
    required this.iconColor,
  });

  factory _DismissibleBackground.neutral(BuildContext context) {
    final theme = Theme.of(context);
    return _DismissibleBackground(
      icon: Icons.keyboard_arrow_left_rounded,
      alignment: Alignment.centerLeft,
      color: theme.colorScheme.surfaceVariant,
      iconColor: theme.colorScheme.onSurfaceVariant,
    );
  }

  factory _DismissibleBackground.delete(BuildContext context) {
    final theme = Theme.of(context);
    return _DismissibleBackground(
      icon: Icons.delete_outline_rounded,
      alignment: Alignment.centerRight,
      color: theme.colorScheme.error,
      iconColor: theme.colorScheme.onError,
    );
  }

  final IconData icon;
  final Alignment alignment;
  final Color color;
  final Color iconColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      alignment: alignment,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(icon, color: iconColor),
    );
  }
}
