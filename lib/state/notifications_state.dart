import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../api/api_client.dart';
import '../models/models.dart';
import '../services/notifier.dart';

/// Notifications from the server (online/offline, alerts). Polled while the app is open.
class NotificationsState extends ChangeNotifier {
  NotificationsState(this.api);

  final ApiClient api;
  static const _storage = FlutterSecureStorage();
  static const _kLastShown = 'pew_last_notification';
  static const Duration _interval = Duration(seconds: 20);

  List<AppNotification> items = [];
  int unread = 0;
  bool loading = false;
  String? error;

  Timer? _timer;
  int? _lastShown;
  bool _busy = false;

  void start() {
    _timer?.cancel();
    _timer = Timer.periodic(_interval, (_) => fetch());
    fetch();
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
  }

  Future<void> fetch() async {
    if (_busy) return;
    _busy = true;
    loading = items.isEmpty;
    try {
      final res = await api.get('/notifications/');
      final raw = res['notifications'];
      items = raw is List
          ? raw.whereType<Map>().map((e) => AppNotification.fromJson(Map<String, dynamic>.from(e))).toList()
          : <AppNotification>[];
      final count = res['unread'];
      unread = count is num ? count.toInt() : items.where((n) => !n.read).length;
      error = null;
      await _showNew();
    } on ApiException catch (e) {
      error = e.message;
    } finally {
      _busy = false;
      loading = false;
      notifyListeners();
    }
  }

  /// Phone notifications for anything newer than what was already shown.
  Future<void> _showNew() async {
    if (items.isEmpty) return;
    if (_lastShown == null) {
      final saved = await _storage.read(key: _kLastShown);
      _lastShown = int.tryParse(saved ?? '');
    }
    final newest = items.map((n) => n.id).reduce((a, b) => a > b ? a : b);
    if (_lastShown == null) {
      // First run on this phone: do not flood with old messages.
      _lastShown = newest;
    } else {
      final fresh = items.where((n) => n.id > _lastShown! && !n.read).toList()..sort((a, b) => a.id.compareTo(b.id));
      for (final n in fresh.take(5)) {
        await Notifier.show(n.id, n.title, n.body, level: n.level);
      }
      if (newest > _lastShown!) _lastShown = newest;
    }
    await _storage.write(key: _kLastShown, value: '$_lastShown');
  }

  Future<void> markAllRead() async {
    for (final n in items) {
      n.read = true;
    }
    unread = 0;
    notifyListeners();
    try {
      await api.post('/notifications/read/', {'all': true});
    } catch (_) {}
  }

  void reset() {
    stop();
    items = [];
    unread = 0;
    notifyListeners();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}
