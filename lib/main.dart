import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:techmoa_app/webview_screen.dart';

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

class BookmarksScreen extends StatelessWidget {
  const BookmarksScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    return Scaffold(
      appBar: AppBar(title: const Text('북마크')),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.bookmark_border_rounded, size: 48, color: primary),
            const SizedBox(height: 12),
            const Text('저장된 글이 없습니다.'),
          ],
        ),
      ),
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
