import 'dart:async';
import 'dart:io';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 백그라운드 메시지 핸들러 (최상위 함수여야 함)
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  print('📱 백그라운드 메시지 수신: ${message.notification?.title}');
}

/// 푸시 알림 서비스
class NotificationService {
  NotificationService._internal();
  static final NotificationService instance = NotificationService._internal();

  final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  /// 알림 탭 시 호출되는 콜백
  final StreamController<Map<String, dynamic>> _notificationTapController =
      StreamController<Map<String, dynamic>>.broadcast();

  Stream<Map<String, dynamic>> get onNotificationTap =>
      _notificationTapController.stream;

  /// 사용 가능한 블로그 토픽 목록
  static const List<Map<String, String>> availableTopics = [
    {'id': 'all_blogs', 'name': '모든 블로그'},
    {'id': 'blog_toss', 'name': '토스'},
    {'id': 'blog_kakao', 'name': '카카오'},
    {'id': 'blog_woowahan', 'name': '우아한형제들'},
    {'id': 'blog_naver', 'name': '네이버'},
    {'id': 'blog_danggeun', 'name': '당근'},
    {'id': 'blog_coupang', 'name': '쿠팡'},
    {'id': 'blog_line', 'name': '라인'},
    {'id': 'blog_musinsa', 'name': '무신사'},
    {'id': 'blog_oliveyoung', 'name': '올리브영'},
    {'id': 'blog_marketkurly', 'name': '마켓컬리'},
    {'id': 'daily_summary', 'name': '일일 요약'},
  ];

  /// 알림 서비스 초기화
  Future<void> initialize() async {
    // 백그라운드 메시지 핸들러 등록
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

    // 로컬 알림 초기화
    await _initializeLocalNotifications();

    // 알림 권한 요청
    await _requestPermission();

    // 포그라운드 메시지 수신 리스너
    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

    // 백그라운드에서 알림 탭 시 리스너
    FirebaseMessaging.onMessageOpenedApp.listen(_handleNotificationTap);

    // 앱이 종료된 상태에서 알림 탭으로 앱이 실행된 경우
    final initialMessage = await _firebaseMessaging.getInitialMessage();
    if (initialMessage != null) {
      _handleNotificationTap(initialMessage);
    }

    // 기본 토픽 구독 (처음 설치 시)
    await _subscribeToDefaultTopics();

    // FCM 토큰 가져오기 (디버깅용)
    final token = await _firebaseMessaging.getToken();
    print('📱 FCM 토큰: $token');
  }

  /// 로컬 알림 초기화
  Future<void> _initializeLocalNotifications() async {
    const androidSettings = AndroidInitializationSettings(
      '@mipmap/ic_launcher',
    );
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );

    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _localNotifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (details) {
        // 로컬 알림 탭 시
        if (details.payload != null) {
          try {
            _notificationTapController.add({'url': details.payload});
          } catch (e) {
            print('알림 탭 처리 오류: $e');
          }
        }
      },
    );

    // Android 알림 채널 생성
    if (Platform.isAndroid) {
      const channel = AndroidNotificationChannel(
        'techmoa_high_importance', // id
        '테크모아 알림', // name
        description: '새 기술 블로그 글 알림',
        importance: Importance.high,
        playSound: true,
      );

      await _localNotifications
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >()
          ?.createNotificationChannel(channel);
    }
  }

  /// 알림 권한 요청
  Future<void> _requestPermission() async {
    final settings = await _firebaseMessaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );

    print('📱 알림 권한: ${settings.authorizationStatus}');

    // iOS에서 포그라운드 알림 설정
    if (Platform.isIOS) {
      await _firebaseMessaging.setForegroundNotificationPresentationOptions(
        alert: true,
        badge: true,
        sound: true,
      );
    }
  }

  /// 포그라운드 메시지 처리
  Future<void> _handleForegroundMessage(RemoteMessage message) async {
    print('📱 포그라운드 메시지 수신: ${message.notification?.title}');

    // 로컬 알림으로 표시
    final notification = message.notification;
    if (notification != null) {
      await _showLocalNotification(
        title: notification.title ?? 'Techmoa',
        body: notification.body ?? '',
        payload: message.data['url'] ?? '',
      );
    }
  }

  /// 알림 탭 처리
  void _handleNotificationTap(RemoteMessage message) {
    print('📱 알림 탭: ${message.data}');

    final url = message.data['url'];
    if (url != null && url.isNotEmpty) {
      _notificationTapController.add({
        'url': url,
        'blog_id': message.data['blog_id'],
        'author': message.data['author'],
        'type': message.data['type'],
      });
    }
  }

  /// 로컬 알림 표시
  Future<void> _showLocalNotification({
    required String title,
    required String body,
    String payload = '',
  }) async {
    const androidDetails = AndroidNotificationDetails(
      'techmoa_high_importance',
      '테크모아 알림',
      channelDescription: '새 기술 블로그 글 알림',
      importance: Importance.high,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _localNotifications.show(
      DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title,
      body,
      details,
      payload: payload,
    );
  }

  /// 기본 토픽 구독 (처음 설치 시)
  Future<void> _subscribeToDefaultTopics() async {
    final prefs = await SharedPreferences.getInstance();
    final isFirstLaunch = prefs.getBool('is_first_launch') ?? true;

    if (isFirstLaunch) {
      await prefs.setBool('is_first_launch', false);
      await prefs.setStringList('subscribed_topics', <String>[]);
      print('📱 기본 토픽 구독 없이 시작합니다');
    }
  }

  /// 토픽 구독
  Future<void> subscribeToTopic(String topic) async {
    try {
      await _firebaseMessaging.subscribeToTopic(topic);
      print('📱 토픽 구독: $topic');

      // SharedPreferences에 저장
      final prefs = await SharedPreferences.getInstance();
      final topics = prefs.getStringList('subscribed_topics') ?? [];
      if (!topics.contains(topic)) {
        topics.add(topic);
        await prefs.setStringList('subscribed_topics', topics);
      }
    } catch (e) {
      print('토픽 구독 오류: $e');
    }
  }

  /// 토픽 구독 해제
  Future<void> unsubscribeFromTopic(String topic) async {
    try {
      await _firebaseMessaging.unsubscribeFromTopic(topic);
      print('📱 토픽 구독 해제: $topic');

      // SharedPreferences에서 제거
      final prefs = await SharedPreferences.getInstance();
      final topics = prefs.getStringList('subscribed_topics') ?? [];
      topics.remove(topic);
      await prefs.setStringList('subscribed_topics', topics);
    } catch (e) {
      print('토픽 구독 해제 오류: $e');
    }
  }

  /// 현재 구독 중인 토픽 목록 가져오기
  Future<List<String>> getSubscribedTopics() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList('subscribed_topics') ?? <String>[];
  }

  /// 토픽 구독 상태 확인
  Future<bool> isSubscribedToTopic(String topic) async {
    final topics = await getSubscribedTopics();
    return topics.contains(topic);
  }

  /// 리소스 정리
  void dispose() {
    _notificationTapController.close();
  }
}
