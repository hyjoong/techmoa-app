import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:techmoa_app/data/bookmark.dart';
import 'package:techmoa_app/data/bookmark_repository.dart';
import 'package:techmoa_app/webview_screen.dart';
import 'package:url_launcher/url_launcher.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  runApp(const TechmoaApp());
}

class TechmoaApp extends StatelessWidget {
  const TechmoaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Techmoa',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF2563EB)),
        useMaterial3: true,
      ),
      home: const TechmoaHome(),
    );
  }
}

class TechmoaHome extends StatefulWidget {
  const TechmoaHome({super.key});

  @override
  State<TechmoaHome> createState() => _TechmoaHomeState();
}

class _TechmoaHomeState extends State<TechmoaHome> {
  static const _pages = [WebViewScreen(), BookmarksScreen(), SettingsScreen()];

  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _currentIndex, children: _pages),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) => setState(() => _currentIndex = index),
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home_rounded), label: '홈'),
          BottomNavigationBarItem(
            icon: Icon(Icons.bookmark_rounded),
            label: '북마크',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.settings_rounded),
            label: '설정',
          ),
        ],
      ),
    );
  }
}

class BookmarksScreen extends StatefulWidget {
  const BookmarksScreen({super.key});

  @override
  State<BookmarksScreen> createState() => _BookmarksScreenState();
}

class _BookmarksScreenState extends State<BookmarksScreen> {
  final BookmarkRepository _repository = BookmarkRepository.instance;
  late Future<List<Bookmark>> _bookmarksFuture;
  StreamSubscription<void>? _changesSubscription;

  @override
  void initState() {
    super.initState();
    _bookmarksFuture = _repository.fetchBookmarks();
    _changesSubscription = _repository.changes.listen((_) {
      setState(() {
        _bookmarksFuture = _repository.fetchBookmarks();
      });
    });
  }

  @override
  void dispose() {
    _changesSubscription?.cancel();
    super.dispose();
  }

  Future<void> _refresh() async {
    final bookmarks = await _repository.fetchBookmarks();
    if (!mounted) return;
    setState(() {
      _bookmarksFuture = Future.value(bookmarks);
    });
  }

  Future<void> _removeBookmark(String id) async {
    await _repository.removeBookmark(id);
  }

  Future<void> _openBookmark(Bookmark bookmark) async {
    final uri = Uri.tryParse(bookmark.externalUrl);
    if (uri != null && await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('북마크')),
      body: FutureBuilder<List<Bookmark>>(
        future: _bookmarksFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final bookmarks = snapshot.data ?? [];
          if (bookmarks.isEmpty) {
            return RefreshIndicator(
              onRefresh: _refresh,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: const [
                  SizedBox(height: 120),
                  Icon(
                    Icons.bookmark_border_rounded,
                    size: 64,
                    color: Colors.grey,
                  ),
                  SizedBox(height: 16),
                  Center(child: Text('저장된 글이 없습니다.')),
                  SizedBox(height: 120),
                ],
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: _refresh,
            child: ListView.separated(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
              itemBuilder: (context, index) {
                final bookmark = bookmarks[index];
                return ListTile(
                  contentPadding: const EdgeInsets.symmetric(
                    vertical: 8,
                    horizontal: 12,
                  ),
                  leading: _BookmarkThumbnail(url: bookmark.thumbnailUrl),
                  title: Text(
                    bookmark.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (bookmark.author != null &&
                          bookmark.author!.isNotEmpty)
                        Text(
                          bookmark.author!,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      if (bookmark.publishedAt != null &&
                          bookmark.publishedAt!.isNotEmpty)
                        Text(
                          bookmark.publishedAt!,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                    ],
                  ),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete_outline_rounded),
                    onPressed: () => _removeBookmark(bookmark.id),
                  ),
                  onTap: () => _openBookmark(bookmark),
                );
              },
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemCount: bookmarks.length,
            ),
          );
        },
      ),
    );
  }
}

class _BookmarkThumbnail extends StatelessWidget {
  const _BookmarkThumbnail({this.url});

  final String? url;

  @override
  Widget build(BuildContext context) {
    if (url == null || url!.isEmpty) {
      return const _PlaceholderThumbnail();
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Image.network(
        url!,
        width: 56,
        height: 56,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => const _PlaceholderThumbnail(),
      ),
    );
  }
}

class _PlaceholderThumbnail extends StatelessWidget {
  const _PlaceholderThumbnail();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 56,
      height: 56,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        color: Theme.of(context).colorScheme.surfaceVariant,
      ),
      child: const Icon(Icons.article_outlined),
    );
  }
}

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('설정')),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: const [
          ListTile(
            leading: Icon(Icons.notifications_active_outlined),
            title: Text('알림 설정'),
            subtitle: Text('Techmoa 업데이트 알림을 관리하세요.'),
          ),
          Divider(),
          ListTile(
            leading: Icon(Icons.info_outline_rounded),
            title: Text('앱 정보'),
            subtitle: Text('Techmoa 앱 버전 및 저작권 안내.'),
          ),
        ],
      ),
    );
  }
}
