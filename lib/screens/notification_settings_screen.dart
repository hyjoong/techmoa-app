import 'package:flutter/material.dart';
import 'package:techmoa_app/services/notification_service.dart';

/// 알림 설정 화면
class NotificationSettingsScreen extends StatefulWidget {
  const NotificationSettingsScreen({super.key});

  @override
  State<NotificationSettingsScreen> createState() =>
      _NotificationSettingsScreenState();
}

class _NotificationSettingsScreenState
    extends State<NotificationSettingsScreen> {
  final NotificationService _notificationService = NotificationService.instance;
  late Future<List<String>> _subscribedTopicsFuture;
  final Set<String> _subscribedTopics = {};

  @override
  void initState() {
    super.initState();
    _subscribedTopicsFuture = _loadSubscribedTopics();
  }

  Future<List<String>> _loadSubscribedTopics() async {
    final topics = await _notificationService.getSubscribedTopics();
    setState(() {
      _subscribedTopics.addAll(topics);
    });
    return topics;
  }

  Future<void> _toggleTopic(String topicId, bool subscribe) async {
    setState(() {
      if (subscribe) {
        _subscribedTopics.add(topicId);
      } else {
        _subscribedTopics.remove(topicId);
      }
    });

    if (subscribe) {
      await _notificationService.subscribeToTopic(topicId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$topicId 알림 구독 완료'),
            duration: const Duration(seconds: 1),
          ),
        );
      }
    } else {
      await _notificationService.unsubscribeFromTopic(topicId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$topicId 알림 구독 해제'),
            duration: const Duration(seconds: 1),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('알림 설정')),
      body: FutureBuilder<List<String>>(
        future: _subscribedTopicsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          return ListView(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
            children: [
              const _SectionHeader(
                title: '알림 받을 블로그 선택',
                subtitle: '관심 있는 블로그의 새 글 알림을 받아보세요.',
              ),
              const SizedBox(height: 16),
              ...NotificationService.availableTopics.map((topic) {
                final topicId = topic['id']!;
                final topicName = topic['name']!;
                final isSubscribed = _subscribedTopics.contains(topicId);

                return _TopicTile(
                  topicId: topicId,
                  topicName: topicName,
                  isSubscribed: isSubscribed,
                  onChanged: (value) => _toggleTopic(topicId, value),
                );
              }),
              const SizedBox(height: 24),
              const _InfoCard(),
            ],
          );
        },
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
            color: theme.colorScheme.primary,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          subtitle,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

class _TopicTile extends StatelessWidget {
  const _TopicTile({
    required this.topicId,
    required this.topicName,
    required this.isSubscribed,
    required this.onChanged,
  });

  final String topicId;
  final String topicName;
  final bool isSubscribed;
  final ValueChanged<bool> onChanged;

  IconData _getTopicIcon(String topicId) {
    if (topicId == 'all_blogs') return Icons.notifications_active_rounded;
    if (topicId == 'daily_summary') return Icons.summarize_rounded;
    return Icons.business_rounded;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: SwitchListTile(
        value: isSubscribed,
        onChanged: onChanged,
        secondary: Icon(
          _getTopicIcon(topicId),
          color: theme.colorScheme.primary,
        ),
        title: Text(topicName),
        subtitle: topicId == 'all_blogs'
            ? const Text('모든 블로그의 새 글 알림')
            : topicId == 'daily_summary'
            ? const Text('하루 한 번 요약 알림')
            : Text('$topicName 블로그의 새 글 알림'),
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      color: theme.colorScheme.primaryContainer.withValues(alpha: 0.3),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.info_outline_rounded,
                  size: 20,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  '알림 정보',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.primary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              '• 즉시 알림: 토스, 카카오, 우아한형제들 등 인기 블로그\n'
              '• 일일 요약: 나머지 블로그들의 하루 요약\n'
              '• "모든 블로그" 선택 시 모든 알림을 받습니다',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
