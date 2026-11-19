import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../api/api_client.dart';
import '../api/local_client.dart';
import '../models/models.dart';

/// How the app reaches a device right now.
enum LinkMode { local, cloud, offline }

/// Devices of the signed-in user, live values and controls.
class DevicesState extends ChangeNotifier {
  DevicesState(this.api);

  final ApiClient api;
  final LocalClient local = LocalClient();
  static const _storage = FlutterSecureStorage();
  static const _kCache = 'pew_dashboard_cache';

  /// Connection mode per device id.
  final Map<int, LinkMode> modes = {};
  final Set<int> _announcedLocal = {};

  /// Called when a device becomes reachable on the local Wi-Fi (for a phone notification).
  void Function(Device device)? onLocalConnected;

  /// True when the data comes from the saved copy because the server could not be reached.
  bool fromCache = false;

  List<Device> devices = [];
  List<Device> pending = [];
  DashboardStats stats = DashboardStats();
  AppMeta? meta;
  List<DeviceModelSpec>? models;

  bool loading = false;
  bool loadedOnce = false;
  String? error;
  DateTime? updatedAt;
  int pollSeconds = 5;

  /// Devices currently opened on screen; only these are polled.
  final Set<int> watched = {};
  final Set<int> _busyPoints = {};

  /// Changes this phone sent that the device has not confirmed yet (point id -> command).
  final Map<int, PendingCommand> _waiting = {};

  /// How long to wait for a device confirmation when the server gives no deadline.
  static const Duration _confirmWait = Duration(seconds: 40);
  Timer? _timer;
  bool _paused = false;
  bool _polling = false;

  bool isBusy(int pointId) => _busyPoints.contains(pointId);

  /// The change waiting for the device on this output (sent from this phone or from elsewhere).
  PendingCommand? pendingFor(DevicePoint point) => _waiting[point.id] ?? point.pending;

  LinkMode modeOf(int deviceId) => modes[deviceId] ?? LinkMode.offline;

  void _setMode(Device device, LinkMode mode) {
    final old = modes[device.id];
    if (old == mode) return;
    modes[device.id] = mode;
    if (mode == LinkMode.local && !_announcedLocal.contains(device.id)) {
      _announcedLocal.add(device.id);
      onLocalConnected?.call(device);
    }
    if (mode != LinkMode.local) _announcedLocal.remove(device.id);
  }

  Device? byId(int id) {
    for (final d in devices) {
      if (d.id == id) return d;
    }
    return null;
  }

  Future<void> refresh({bool silent = false}) async {
    if (loading) return;
    loading = true;
    if (!silent) {
      error = null;
      notifyListeners();
    }
    try {
      final res = await api.get('/dashboard/');
      _applyDashboard(res);
      fromCache = false;
      _saveCache(res);
      error = null;
      updatedAt = DateTime.now();
      loadedOnce = true;
    } on ApiException catch (e) {
      error = e.message;
      if (devices.isEmpty) await _loadCache();
      for (final d in devices) {
        if (modes[d.id] != LinkMode.local) modes[d.id] = LinkMode.offline;
      }
    } finally {
      loading = false;
      notifyListeners();
    }
    _schedule();
    _probeLocal();
  }

  void _applyDashboard(Map<String, dynamic> res) {
      devices = _devices(res['devices']);
      pending = _devices(res['pending']);
      stats = res['stats'] is Map
          ? DashboardStats.fromJson(Map<String, dynamic>.from(res['stats'] as Map))
          : DashboardStats.fromDevices(devices);
      final poll = res['poll_seconds'];
      if (poll is num && poll > 0) pollSeconds = poll.toInt();
      for (final d in devices) {
        if (modes[d.id] != LinkMode.local) _setMode(d, d.online ? LinkMode.cloud : LinkMode.offline);
      }
  }

  Future<void> _saveCache(Map<String, dynamic> res) async {
    try {
      await _storage.write(key: _kCache, value: jsonEncode(res));
    } catch (_) {}
  }

  /// Without internet: show the last known devices so local mode still works.
  Future<void> _loadCache() async {
    try {
      final raw = await _storage.read(key: _kCache);
      if (raw == null || raw.isEmpty) return;
      final res = jsonDecode(raw);
      if (res is Map<String, dynamic>) {
        _applyDashboard(res);
        fromCache = true;
        loadedOnce = true;
      }
    } catch (_) {}
  }

  /// Check which devices answer on the local Wi-Fi.
  Future<void> _probeLocal() async {
    var changed = false;
    for (final d in List<Device>.from(devices)) {
      final token = d.token ?? '';
      if (d.localIp.isEmpty || token.isEmpty) continue;
      final state = await local.state(d.localIp, token);
      final before = modes[d.id];
      if (state != null) {
        _mergeLocal(d.id, state);
        _setMode(d, LinkMode.local);
      } else if (before == LinkMode.local) {
        _setMode(d, d.online ? LinkMode.cloud : LinkMode.offline);
      }
      if (before != modes[d.id]) changed = true;
    }
    if (changed) notifyListeners();
  }

  /// Put values read directly from the device into the points (matched by pin).
  void _mergeLocal(int deviceId, Map<String, dynamic> state) {
    final raw = state['points'];
    if (raw is! List) return;
    final values = <String, double>{};
    for (final item in raw.whereType<Map>()) {
      final v = item['value'];
      if (v is num) values['${item['pin']}'.toUpperCase()] = v.toDouble();
    }
    _replace(deviceId, (d) => d.copyWith(
          online: true,
          points: d.points.map((p) {
            final v = values[p.pin.toUpperCase()];
            if (v == null || _busyPoints.contains(p.id)) return p;
            if (p.value != null && (p.value! - v).abs() < 0.0001) return p;
            return p.withValue(v);
          }).toList(),
        ));
  }

  List<Device> _devices(dynamic raw) => raw is List
      ? raw.whereType<Map>().map((e) => Device.fromJson(Map<String, dynamic>.from(e))).toList()
      : <Device>[];

  Future<AppMeta> loadMeta() async {
    if (meta != null) return meta!;
    final res = await api.get('/meta/');
    meta = AppMeta.fromJson(res);
    return meta!;
  }

  Future<List<DeviceModelSpec>> loadModels({bool force = false}) async {
    if (models != null && !force) return models!;
    final res = await api.get('/models/');
    final raw = res['models'];
    models = raw is List
        ? raw.whereType<Map>().map((e) => DeviceModelSpec.fromJson(Map<String, dynamic>.from(e))).toList()
        : <DeviceModelSpec>[];
    return models!;
  }

  // ------------------------------------------------------------------ polling

  void watch(int deviceId) {
    watched.add(deviceId);
    _schedule();
    _pollOnce();
  }

  void unwatch(int deviceId) {
    watched.remove(deviceId);
    _schedule();
  }

  void setPaused(bool paused) {
    _paused = paused;
    if (paused) {
      _timer?.cancel();
      _timer = null;
    } else {
      refresh(silent: true);
    }
  }

  void _schedule() {
    _timer?.cancel();
    _timer = null;
    if (_paused || watched.isEmpty) return;
    _timer = Timer.periodic(Duration(seconds: pollSeconds), (_) => _pollOnce());
  }

  Future<void> _pollOnce() async {
    if (_polling || _paused) return;
    _polling = true;
    try {
      for (final id in watched.toList()) {
        final device = byId(id);
        final token = device?.token ?? '';
        if (device != null && device.localIp.isNotEmpty && token.isNotEmpty) {
          final state = await local.state(device.localIp, token);
          if (state != null) {
            _mergeLocal(id, state);
            _setMode(device, LinkMode.local);
            continue;
          }
          if (modes[id] == LinkMode.local) _setMode(device, device.online ? LinkMode.cloud : LinkMode.offline);
        }
        try {
          final res = await api.get('/devices/$id/state/');
          final points = res['points'] is List
              ? (res['points'] as List).whereType<Map>().map((e) => DevicePoint.fromJson(Map<String, dynamic>.from(e))).toList()
              : <DevicePoint>[];
          _replace(id, (d) {
            // The server only changes a value after the device confirmed it, so it is always the truth.
            return d.copyWith(
              points: points,
              online: res['online'] == true,
              enabled: res['enabled'] == true,
              lastSeen: res['last_seen'] == null ? null : DateTime.tryParse('${res['last_seen']}')?.toLocal(),
            );
          });
          final updated = byId(id);
          if (updated != null) _setMode(updated, updated.online ? LinkMode.cloud : LinkMode.offline);
        } on ApiException catch (e) {
          if (e.status == 404 || e.status == 409) watched.remove(id);
          if (device != null && e.isNetwork) _setMode(device, LinkMode.offline);
        }
      }
      updatedAt = DateTime.now();
      stats = DashboardStats.fromDevices(devices);
      notifyListeners();
    } finally {
      _polling = false;
    }
  }

  void _replace(int id, Device Function(Device) change) {
    final index = devices.indexWhere((d) => d.id == id);
    if (index >= 0) devices[index] = change(devices[index]);
  }

  // ------------------------------------------------------------------ controls

  /// Change an output. The shown state changes only when the device confirms the change:
  ///  - local mode: the device answers with the state it read back from the pin;
  ///  - internet: the server keeps a command until the device acknowledges it.
  /// Throws ApiException with a clear message if the device refuses or does not confirm in time.
  Future<void> setPoint(Device device, DevicePoint point, double value) async {
    if (_busyPoints.contains(point.id)) return;
    _busyPoints.add(point.id);
    _waiting[point.id] = PendingCommand(id: 0, value: value, status: 'sending');
    notifyListeners();
    try {
      final current = byId(device.id) ?? device;
      final token = current.token ?? '';
      if (modeOf(device.id) == LinkMode.local && current.localIp.isNotEmpty && token.isNotEmpty) {
        final result = await local.setValue(current.localIp, token, point.pin, value);
        if (result != null) {
          if (!result.confirmed) {
            throw ApiException(result.error ?? 'The device did not confirm the change. Nothing was changed.',
                code: 'not_confirmed');
          }
          _swapPoint(device.id, _currentPoint(device.id, point).withValue(result.value ?? value));
          return;
        }
        // Not reachable on the Wi-Fi any more: use the internet.
        _setMode(current, current.online ? LinkMode.cloud : LinkMode.offline);
      }

      final res = await api.post('/points/${point.id}/set/', {'value': value});
      final command = PendingCommand.fromJson(Map<String, dynamic>.from(res['command'] as Map));
      _waiting[point.id] = command;
      notifyListeners();

      final outcome = await _waitForDevice(command);
      if (outcome.point != null) _swapPoint(device.id, outcome.point!);
      switch (outcome.status) {
        case 'confirmed':
        case 'superseded':
          return;
        case 'failed':
          throw ApiException('${outcome.error.isEmpty ? 'The device refused the change.' : outcome.error} Nothing was changed.',
              code: 'command_failed');
        case 'expired':
          throw ApiException('The device did not confirm the change in time. Nothing was changed.', code: 'command_expired');
        default:
          throw ApiException('No answer from the device yet. Check its power and Wi-Fi.', code: 'no_answer');
      }
    } finally {
      _busyPoints.remove(point.id);
      _waiting.remove(point.id);
      stats = DashboardStats.fromDevices(devices);
      notifyListeners();
    }
  }

  /// Ask the server until the command is final (confirmed, failed, expired or replaced).
  Future<CommandOutcome> _waitForDevice(PendingCommand command) async {
    final now = DateTime.now();
    var deadline = now.add(_confirmWait);
    final expires = command.expiresAt;
    if (expires != null) {
      final serverDeadline = expires.add(const Duration(seconds: 5));
      if (serverDeadline.isBefore(deadline) && serverDeadline.isAfter(now)) deadline = serverDeadline;
    }
    while (DateTime.now().isBefore(deadline)) {
      await Future<void>.delayed(const Duration(milliseconds: 700));
      try {
        final res = await api.get('/commands/${command.id}/');
        final c = res['command'];
        if (c is Map && c['final'] == true) return CommandOutcome.fromJson(res);
      } on ApiException catch (e) {
        if (e.status == 404) return CommandOutcome(status: 'failed', error: 'This change is no longer known.');
        // network hiccup: keep waiting until the deadline
      }
    }
    return CommandOutcome(status: 'unknown');
  }

  DevicePoint _currentPoint(int deviceId, DevicePoint fallback) {
    final d = byId(deviceId);
    if (d == null) return fallback;
    return d.points.firstWhere((p) => p.id == fallback.id, orElse: () => fallback);
  }

  void _swapPoint(int deviceId, DevicePoint point) {
    _replace(deviceId, (d) => d.copyWith(points: d.points.map((p) => p.id == point.id ? point : p).toList()));
  }

  // ------------------------------------------------------------------ device management

  Future<Device> addDevice({required int modelId, required String name, required String location, required String serial}) async {
    final res = await api.post('/devices/', {
      'model': modelId,
      'name': name,
      'location': location,
      'serialnumber': serial,
    });
    final device = Device.fromJson(Map<String, dynamic>.from(res['device'] as Map));
    await refresh(silent: true);
    return device;
  }

  Future<Device> getDevice(int id) async {
    final res = await api.get('/devices/$id/');
    return Device.fromJson(Map<String, dynamic>.from(res['device'] as Map));
  }

  Future<Device> updateDevice(int id, Map<String, dynamic> changes) async {
    final res = await api.patch('/devices/$id/', changes);
    await refresh(silent: true);
    return Device.fromJson(Map<String, dynamic>.from(res['device'] as Map));
  }

  Future<Device> toggleDevice(int id, bool enabled) async {
    final res = await api.post('/devices/$id/toggle/', {'enabled': enabled});
    await refresh(silent: true);
    return Device.fromJson(Map<String, dynamic>.from(res['device'] as Map));
  }

  Future<String> requestDelete(int id) async {
    final res = await api.post('/devices/$id/delete/');
    watched.remove(id);
    await refresh(silent: true);
    return '${res['message'] ?? 'Deletion requested.'}';
  }

  Future<void> restore(int id) async {
    await api.post('/devices/$id/restore/');
    await refresh(silent: true);
  }

  Future<Device> regenerateToken(int id) async {
    final res = await api.post('/devices/$id/token/');
    return Device.fromJson(Map<String, dynamic>.from(res['device'] as Map));
  }

  // ------------------------------------------------------------------ sensors & actuators

  Future<DeviceConfig> loadConfig(int deviceId, {int? editing}) async {
    final res = await api.get('/devices/$deviceId/config/', query: editing == null ? null : {'editing': '$editing'});
    return DeviceConfig.fromJson(res);
  }

  Future<void> savePoint(int deviceId, Map<String, dynamic> data, {int? pointId}) async {
    if (pointId == null) {
      await api.post('/devices/$deviceId/points/', data);
    } else {
      await api.patch('/points/$pointId/', data);
    }
    await refresh(silent: true);
  }

  Future<void> togglePoint(int pointId, bool enabled) async {
    await api.post('/points/$pointId/toggle/', {'enabled': enabled});
    await refresh(silent: true);
  }

  Future<void> deletePoint(int pointId) async {
    await api.delete('/points/$pointId/');
    await refresh(silent: true);
  }

  void reset() {
    _timer?.cancel();
    _timer = null;
    devices = [];
    pending = [];
    stats = DashboardStats();
    watched.clear();
    modes.clear();
    _announcedLocal.clear();
    _storage.delete(key: _kCache).catchError((_) {});
    models = null;
    meta = null;
    loadedOnce = false;
    error = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}
