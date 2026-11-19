import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// Phone notifications (status bar) for device and sensor events.
class Notifier {
  Notifier._();

  static final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();
  static bool _ready = false;

  static Future<void> init() async {
    if (_ready) return;
    try {
      const settings = InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: DarwinInitializationSettings(),
      );
      await _plugin.initialize(settings);
      await _plugin
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
          ?.requestNotificationsPermission();
      _ready = true;
    } catch (e) {
      debugPrint('Notifications not available: $e');
    }
  }

  /// level: info | success | warning | danger
  static Future<void> show(int id, String title, String body, {String level = 'info'}) async {
    if (!_ready) await init();
    if (!_ready) return;
    final urgent = level == 'danger' || level == 'warning';
    final details = NotificationDetails(
      android: AndroidNotificationDetails(
        urgent ? 'pew_alerts' : 'pew_status',
        urgent ? 'Alerts' : 'Device status',
        channelDescription: urgent ? 'Sensor alerts and devices going offline' : 'Devices online, setup messages',
        importance: urgent ? Importance.high : Importance.defaultImportance,
        priority: urgent ? Priority.high : Priority.defaultPriority,
      ),
      iOS: const DarwinNotificationDetails(),
    );
    try {
      await _plugin.show(id, title, body, details);
    } catch (e) {
      debugPrint('Could not show notification: $e');
    }
  }
}
