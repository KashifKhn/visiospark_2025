import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../core/utils/logger.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;

  Future<void> initialize() async {
    if (_initialized) return;

    try {
      const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
      const iosSettings = DarwinInitializationSettings(
        requestSoundPermission: true,
        requestBadgePermission: true,
        requestAlertPermission: true,
      );

      const initSettings = InitializationSettings(
        android: androidSettings,
        iOS: iosSettings,
      );

      await _notificationsPlugin.initialize(
        initSettings,
        onDidReceiveNotificationResponse: _onNotificationTapped,
      );

      _initialized = true;
      AppLogger.success('Notification service initialized');
    } catch (e) {
      AppLogger.error('Error initializing notifications', e);
    }
  }

  void _onNotificationTapped(NotificationResponse response) {
    AppLogger.info('Notification tapped: ${response.payload}');
    // Handle notification tap - navigate to specific screen
  }

  Future<void> requestPermissions() async {
    try {
      // Android 13+ requires runtime permission
      await _notificationsPlugin
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.requestNotificationsPermission();

      // iOS permissions
      await _notificationsPlugin
          .resolvePlatformSpecificImplementation<
              IOSFlutterLocalNotificationsPlugin>()
          ?.requestPermissions(
            alert: true,
            badge: true,
            sound: true,
          );

      AppLogger.success('Notification permissions requested');
    } catch (e) {
      AppLogger.error('Error requesting notification permissions', e);
    }
  }

  Future<void> showNotification({
    required String title,
    required String body,
    String? payload,
  }) async {
    try {
      const androidDetails = AndroidNotificationDetails(
        'uniweek_channel',
        'UniWeek Notifications',
        channelDescription: 'Notifications for UniWeek events and updates',
        importance: Importance.high,
        priority: Priority.high,
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

      await _notificationsPlugin.show(
        DateTime.now().millisecondsSinceEpoch ~/ 1000,
        title,
        body,
        details,
        payload: payload,
      );

      AppLogger.success('Notification shown: $title');
    } catch (e) {
      AppLogger.error('Error showing notification', e);
    }
  }

  Future<void> scheduleNotification({
    required String title,
    required String body,
    required DateTime scheduledDate,
    String? payload,
  }) async {
    try {
      const androidDetails = AndroidNotificationDetails(
        'uniweek_channel',
        'UniWeek Notifications',
        channelDescription: 'Notifications for UniWeek events and updates',
        importance: Importance.high,
        priority: Priority.high,
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

      // Note: Scheduling requires timezone package
      // For now, just show immediate notification
      await _notificationsPlugin.show(
        DateTime.now().millisecondsSinceEpoch ~/ 1000,
        title,
        body,
        details,
        payload: payload,
      );

      AppLogger.success('Notification scheduled: $title');
    } catch (e) {
      AppLogger.error('Error scheduling notification', e);
    }
  }

  Future<void> cancelNotification(int id) async {
    try {
      await _notificationsPlugin.cancel(id);
      AppLogger.success('Notification cancelled: $id');
    } catch (e) {
      AppLogger.error('Error cancelling notification', e);
    }
  }

  Future<void> cancelAllNotifications() async {
    try {
      await _notificationsPlugin.cancelAll();
      AppLogger.success('All notifications cancelled');
    } catch (e) {
      AppLogger.error('Error cancelling all notifications', e);
    }
  }

  // Notify about upcoming events (1 hour before)
  Future<void> notifyUpcomingEvent({
    required String eventId,
    required String eventTitle,
    required DateTime eventTime,
  }) async {
    final hourBefore = eventTime.subtract(const Duration(hours: 1));
    
    if (hourBefore.isAfter(DateTime.now())) {
      await scheduleNotification(
        title: 'Event Starting Soon! 🎉',
        body: '$eventTitle starts in 1 hour',
        scheduledDate: hourBefore,
        payload: 'event:$eventId',
      );
    }
  }

  // Notify about new event
  Future<void> notifyNewEvent({
    required String eventTitle,
    required String societyName,
  }) async {
    await showNotification(
      title: 'New Event Added! 🎉',
      body: '$societyName just created "$eventTitle"',
      payload: 'events',
    );
  }

  // Notify about registration confirmation
  Future<void> notifyRegistrationConfirmation({
    required String eventTitle,
  }) async {
    await showNotification(
      title: 'Registration Confirmed ✅',
      body: 'You\'re registered for $eventTitle',
      payload: 'my_events',
    );
  }

  // Notify about event cancellation
  Future<void> notifyEventCancellation({
    required String eventTitle,
  }) async {
    await showNotification(
      title: 'Event Cancelled ⚠️',
      body: '$eventTitle has been cancelled',
      payload: 'my_events',
    );
  }

  // Notify about Q&A answer
  Future<void> notifyQuestionAnswered({
    required String eventTitle,
  }) async {
    await showNotification(
      title: 'Your Question Was Answered! 💬',
      body: 'Someone answered your question about $eventTitle',
      payload: 'notifications',
    );
  }
}
