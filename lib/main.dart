import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:techmoa_app/offline_bookmarks_screen.dart';
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
      debugShowCheckedModeBanner: false,
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
  static const _pages = [
    WebViewScreen(),
    OfflineBookmarksScreen(),
    SettingsScreen(),
  ];

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

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: _SettingsContent());
  }
}

class _SettingsContent extends StatefulWidget {
  const _SettingsContent();

  @override
  State<_SettingsContent> createState() => _SettingsContentState();
}

class _SettingsContentState extends State<_SettingsContent> {
  late Future<String> _versionFuture;

  @override
  void initState() {
    super.initState();
    _versionFuture = _loadVersion();
  }

  Future<String> _loadVersion() async {
    try {
      final info = await PackageInfo.fromPlatform();
      return '${info.version} (${info.buildNumber})';
    } catch (_) {
      return '알 수 없음';
    }
  }

  Future<void> _openUrl(String url) async {
    final uri = Uri.parse(url);
    final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!launched && mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('열 수 없습니다: $url')));
    }
  }

  Future<void> _sendEmail() async {
    const email = 'hyjoong12@gmail.com';
    final uri = Uri(
      scheme: 'mailto',
      path: email,
      queryParameters: {'subject': 'Techmoa 피드백'},
    );
    final launched = await launchUrl(uri);
    if (!launched && mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('메일 앱을 열 수 없습니다. 주소: $email')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        children: [
          const _SectionHeader(title: '일반'),
          ListTile(
            leading: const Icon(Icons.info_outline_rounded),
            title: const Text('앱 버전'),
            subtitle: FutureBuilder<String>(
              future: _versionFuture,
              builder: (context, snapshot) {
                final text = snapshot.data ?? '불러오는 중...';
                return Text(text);
              },
            ),
          ),
          ListTile(
            leading: const Icon(Icons.language_rounded),
            title: const Text('Techmoa 웹사이트 열기'),
            onTap: () => _openUrl('https://techmoa.dev'),
          ),
          const SizedBox(height: 24),
          const _SectionHeader(title: '지원'),
          ListTile(
            leading: const Icon(Icons.privacy_tip_outlined),
            title: const Text('개인정보 처리방침'),
            onTap: () => _openUrl('https://techmoa.dev/privacy'),
          ),
          ListTile(
            leading: const Icon(Icons.description_outlined),
            title: const Text('서비스 이용약관'),
            onTap: () => _openUrl('https://techmoa.dev/terms'),
          ),
          ListTile(
            leading: const Icon(Icons.mail_outline_rounded),
            title: const Text('피드백 보내기'),
            subtitle: const Text('hyjoong12@gmail.com'),
            onTap: _sendEmail,
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        title,
        style: theme.textTheme.labelLarge?.copyWith(
          color: theme.colorScheme.primary,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
