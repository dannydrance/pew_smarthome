import 'package:flutter/material.dart';

typedef Json = Map<String, dynamic>;

double? _d(dynamic v) => v == null ? null : (v is num ? v.toDouble() : double.tryParse('$v'));
int _i(dynamic v) => v is num ? v.toInt() : int.tryParse('$v') ?? 0;
String _s(dynamic v) => v == null ? '' : '$v';
bool _b(dynamic v) => v == true || v == 1 || v == 'true';
DateTime? _t(dynamic v) => v == null ? null : DateTime.tryParse('$v')?.toLocal();
List<Json> _list(dynamic v) => v is List ? v.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList() : <Json>[];

class AppUser {
  AppUser({
    required this.id,
    required this.username,
    required this.email,
    required this.fullName,
    required this.phone,
    required this.accountType,
    required this.accountTypeLabel,
    required this.isStaff,
  });

  factory AppUser.fromJson(Json j) => AppUser(
        id: _i(j['id']),
        username: _s(j['username']),
        email: _s(j['email']),
        fullName: _s(j['full_name']),
        phone: _s(j['phone']),
        accountType: _s(j['account_type']),
        accountTypeLabel: _s(j['account_type_label']),
        isStaff: _b(j['is_staff']),
      );

  final int id;
  final String username;
  final String email;
  final String fullName;
  final String phone;
  final String accountType;
  final String accountTypeLabel;
  final bool isStaff;

  String get firstName => (fullName.isEmpty ? username : fullName).split(' ').first;

  String get initials {
    final parts = (fullName.isEmpty ? username : fullName).trim().split(RegExp(r'\s+'));
    final letters = parts.where((p) => p.isNotEmpty).take(2).map((p) => p[0].toUpperCase()).join();
    return letters.isEmpty ? '?' : letters;
  }
}

/// One pin of a hardware model and what it can be used for.
class ModelPin {
  ModelPin({required this.pin, required this.label, required this.caps, this.capLabels = const [], this.usedById, this.usedByName});

  factory ModelPin.fromJson(Json j) {
    final used = j['used_by'];
    return ModelPin(
      pin: _s(j['pin']),
      label: _s(j['label']),
      caps: (j['caps'] is List) ? (j['caps'] as List).map((e) => '$e').toList() : <String>[],
      capLabels: (j['cap_labels'] is List) ? (j['cap_labels'] as List).map((e) => '$e').toList() : <String>[],
      usedById: used is Map ? _i(used['id']) : null,
      usedByName: used is Map ? _s(used['name']) : null,
    );
  }

  final String pin;
  final String label;
  final List<String> caps; // digital_in, analog_in, digital_out, analog_out
  final List<String> capLabels;
  final int? usedById;
  final String? usedByName;

  bool supports(String direction, String signal) =>
      caps.contains('${signal}_${direction == 'input' ? 'in' : 'out'}');

  String get capsText {
    const names = {'digital_in': 'DI', 'analog_in': 'AI', 'digital_out': 'DO', 'analog_out': 'PWM'};
    return caps.map((c) => names[c] ?? c).join(' · ');
  }
}

/// Hardware model defined by the administrator.
class DeviceModelSpec {
  DeviceModelSpec({
    required this.id,
    required this.name,
    required this.code,
    required this.manufacturer,
    required this.controller,
    required this.specification,
    required this.limits,
    required this.pins,
  });

  factory DeviceModelSpec.fromJson(Json j) {
    final limits = j['limits'] is Map ? Map<String, dynamic>.from(j['limits'] as Map) : <String, dynamic>{};
    return DeviceModelSpec(
      id: _i(j['id']),
      name: _s(j['name']),
      code: _s(j['code']),
      manufacturer: _s(j['manufacturer']),
      controller: _s(j['controller']),
      specification: _s(j['specification']),
      limits: limits.map((k, v) => MapEntry(k, _i(v))),
      pins: _list(j['pins']).map(ModelPin.fromJson).toList(),
    );
  }

  final int id;
  final String name;
  final String code;
  final String manufacturer;
  final String controller;
  final String specification;
  final Map<String, int> limits; // digital_in, analog_in, digital_out, analog_out
  final List<ModelPin> pins;

  int limit(String key) => limits[key] ?? 0;
}

class ModelBrief {
  ModelBrief({required this.id, required this.name, required this.code});

  factory ModelBrief.fromJson(Json j) => ModelBrief(id: _i(j['id']), name: _s(j['name']), code: _s(j['code']));

  final int id;
  final String name;
  final String code;
}

/// A sensor (input) or actuator (output) connected to a device pin.
class DevicePoint {
  DevicePoint({
    required this.id,
    required this.name,
    required this.location,
    required this.direction,
    required this.signal,
    required this.type,
    required this.typeLabel,
    required this.pin,
    required this.unit,
    required this.min,
    required this.max,
    required this.value,
    required this.display,
    required this.stateLabel,
    required this.stateOn,
    required this.alert,
    required this.percent,
    required this.enabled,
    required this.updated,
    required this.sortOrder,
    this.controlsId,
    this.controlsPin = '',
    this.controlsName = '',
    this.controlMode = '',
    this.pending,
  });

  factory DevicePoint.fromJson(Json j) => DevicePoint(
        id: _i(j['id']),
        name: _s(j['name']),
        location: _s(j['location']),
        direction: _s(j['direction']),
        signal: _s(j['signal']),
        type: _s(j['type']),
        typeLabel: _s(j['type_label']),
        pin: _s(j['pin']),
        unit: _s(j['unit']),
        min: _d(j['min']) ?? 0,
        max: _d(j['max']) ?? 100,
        value: _d(j['value']),
        display: _s(j['display']),
        stateLabel: _s(j['state_label']),
        stateOn: _b(j['state_on']),
        alert: _b(j['alert']),
        percent: _i(j['percent']),
        enabled: _b(j['enabled']),
        updated: _t(j['updated']),
        sortOrder: _i(j['sort_order']),
        controlsId: j['controls'] == null ? null : _i(j['controls']),
        controlsPin: _s(j['controls_pin']),
        controlsName: _s(j['controls_name']),
        controlMode: _s(j['control_mode']),
        pending: j['pending'] is Map ? PendingCommand.fromJson(Map<String, dynamic>.from(j['pending'] as Map)) : null,
      );

  final int id;
  final String name;
  final String location;
  final String direction;
  final String signal;
  final String type;
  final String typeLabel;
  final String pin;
  final String unit;
  final double min;
  final double max;
  final double? value;
  final String display;
  final String stateLabel;
  final bool stateOn;
  final bool alert;
  final int percent;
  final bool enabled;
  final DateTime? updated;
  final int sortOrder;
  final int? controlsId;
  final String controlsPin;
  final String controlsName;
  final String controlMode;

  /// A change sent to the device that it has not confirmed yet (null = nothing waiting).
  final PendingCommand? pending;

  bool get isInput => direction == 'input';
  bool get isOutput => direction == 'output';
  bool get isDigital => signal == 'digital';
  bool get isAnalog => signal == 'analog';

  IconData get icon => pointIcon(type);

  /// Text while a change is waiting for the device, e.g. "Turning on…" or "Closing…".
  String waitingLabel(double target) {
    if (isAnalog) {
      final v = target.toStringAsFixed(1).replaceAll(RegExp(r'\.0$'), '');
      return 'Setting to ${'$v $unit'.trim()}…';
    }
    final verbs = _verbs[type] ?? ('Turning on', 'Turning off');
    return '${target >= 0.5 ? verbs.$1 : verbs.$2}…';
  }

  static const Map<String, (String, String)> _verbs = {
    'switch': ('Turning on', 'Turning off'),
    'valve': ('Opening', 'Closing'),
    'lock': ('Locking', 'Unlocking'),
    'fan': ('Starting', 'Stopping'),
    'pump': ('Starting', 'Stopping'),
    'buzzer': ('Sounding', 'Silencing'),
  };

  /// Copy with a value the device has confirmed.
  DevicePoint withValue(double newValue) {
    final on = newValue >= 0.5;
    int pct = max == min ? 0 : (((newValue - min) / (max - min)) * 100).round();
    if (pct < 0) pct = 0;
    if (pct > 100) pct = 100;
    String text;
    if (isDigital) {
      text = on ? _onLabel(type) : _offLabel(type);
    } else {
      final v = newValue.toStringAsFixed(1).replaceAll(RegExp(r'\.0$'), '');
      text = '$v $unit'.trim();
    }
    return DevicePoint(
      id: id, name: name, location: location, direction: direction, signal: signal, type: type,
      typeLabel: typeLabel, pin: pin, unit: unit, min: min, max: max, value: newValue,
      display: text, stateLabel: isDigital ? text : stateLabel, stateOn: on, alert: alert,
      percent: pct, enabled: enabled, updated: DateTime.now(), sortOrder: sortOrder,
      controlsId: controlsId, controlsPin: controlsPin, controlsName: controlsName, controlMode: controlMode,
    );
  }

  static String _onLabel(String type) => _labels[type]?.$1 ?? 'On';
  static String _offLabel(String type) => _labels[type]?.$2 ?? 'Off';
  static const Map<String, (String, String)> _labels = {
    'switch': ('On', 'Off'),
    'valve': ('Open', 'Closed'),
    'fan': ('Running', 'Stopped'),
    'pump': ('Running', 'Stopped'),
    'lock': ('Locked', 'Unlocked'),
    'buzzer': ('Sounding', 'Silent'),
    'wall_switch': ('On', 'Off'),
    'push_button': ('Pressed', 'Released'),
    'motion': ('Motion', 'Clear'),
    'door': ('Open', 'Closed'),
    'gas': ('Detected', 'Normal'),
    'smoke': ('Detected', 'Normal'),
    'water': ('Leak', 'Dry'),
  };
}

IconData pointIcon(String type) {
  switch (type) {
    case 'temperature':
      return Icons.thermostat_rounded;
    case 'humidity':
      return Icons.water_drop_rounded;
    case 'motion':
      return Icons.directions_walk_rounded;
    case 'door':
      return Icons.door_front_door_rounded;
    case 'gas':
      return Icons.local_fire_department_rounded;
    case 'smoke':
      return Icons.cloud_rounded;
    case 'light':
      return Icons.wb_sunny_rounded;
    case 'water':
      return Icons.water_rounded;
    case 'level':
      return Icons.propane_tank_rounded;
    case 'voltage':
      return Icons.bolt_rounded;
    case 'current':
      return Icons.electric_meter_rounded;
    case 'switch':
      return Icons.lightbulb_rounded;
    case 'valve':
      return Icons.plumbing_rounded;
    case 'dimmer':
      return Icons.tune_rounded;
    case 'fan':
      return Icons.mode_fan_off_rounded;
    case 'pump':
      return Icons.autorenew_rounded;
    case 'lock':
      return Icons.lock_rounded;
    case 'buzzer':
      return Icons.notifications_active_rounded;
    case 'generic_out':
      return Icons.toggle_on_rounded;
    case 'wall_switch':
      return Icons.toggle_off_rounded;
    case 'push_button':
      return Icons.radio_button_checked_rounded;
    default:
      return Icons.sensors_rounded;
  }
}

class Device {
  Device({
    required this.id,
    required this.name,
    required this.displayName,
    required this.location,
    required this.serial,
    required this.model,
    required this.enabled,
    required this.online,
    required this.lastSeen,
    required this.lastIp,
    required this.firmware,
    required this.createdAt,
    required this.tokenMasked,
    required this.token,
    required this.pendingDeletion,
    required this.purgeDueAt,
    required this.points,
    required this.alerts,
    required this.outputsOn,
    this.localIp = '',
  });

  factory Device.fromJson(Json j) => Device(
        id: _i(j['id']),
        name: _s(j['name']),
        displayName: _s(j['display_name']),
        location: _s(j['location']),
        serial: _s(j['serial']),
        model: j['model'] is Map ? ModelBrief.fromJson(Map<String, dynamic>.from(j['model'] as Map)) : null,
        enabled: _b(j['enabled']),
        online: _b(j['online']),
        lastSeen: _t(j['last_seen']),
        lastIp: _s(j['last_ip']),
        firmware: _s(j['firmware']),
        createdAt: _t(j['created_at']),
        tokenMasked: _s(j['token_masked']),
        token: j['token'] == null ? null : _s(j['token']),
        pendingDeletion: _b(j['pending_deletion']),
        purgeDueAt: _t(j['purge_due_at']),
        points: _list(j['points']).map(DevicePoint.fromJson).toList(),
        alerts: _i(j['alerts']),
        outputsOn: _i(j['outputs_on']),
        localIp: _s(j['local_ip']),
      );

  final int id;
  final String name;
  final String displayName;
  final String location;
  final String serial;
  final ModelBrief? model;
  final bool enabled;
  final bool online;
  final DateTime? lastSeen;
  final String lastIp;
  final String firmware;
  final DateTime? createdAt;
  final String tokenMasked;
  final String? token;
  final bool pendingDeletion;
  final DateTime? purgeDueAt;
  final List<DevicePoint> points;
  final int alerts;
  final int outputsOn;
  final String localIp;

  List<DevicePoint> get inputs => points.where((p) => p.isInput).toList();
  List<DevicePoint> get outputs => points.where((p) => p.isOutput).toList();

  Device copyWith({List<DevicePoint>? points, bool? online, bool? enabled, DateTime? lastSeen}) {
    final list = points ?? this.points;
    return Device(
      id: id, name: name, displayName: displayName, location: location, serial: serial, model: model,
      enabled: enabled ?? this.enabled, online: online ?? this.online, lastSeen: lastSeen ?? this.lastSeen,
      lastIp: lastIp, firmware: firmware, createdAt: createdAt, tokenMasked: tokenMasked, token: token,
      pendingDeletion: pendingDeletion, purgeDueAt: purgeDueAt, points: list,
      alerts: list.where((p) => p.alert && p.enabled).length,
      outputsOn: list.where((p) => p.isOutput && p.stateOn && p.enabled).length,
      localIp: localIp,
    );
  }
}

class DashboardStats {
  DashboardStats({this.devices = 0, this.online = 0, this.sensors = 0, this.actuators = 0, this.alerts = 0, this.outputsOn = 0});

  factory DashboardStats.fromJson(Json j) => DashboardStats(
        devices: _i(j['devices']),
        online: _i(j['online']),
        sensors: _i(j['sensors']),
        actuators: _i(j['actuators']),
        alerts: _i(j['alerts']),
        outputsOn: _i(j['outputs_on']),
      );

  factory DashboardStats.fromDevices(List<Device> devices) {
    final points = devices.expand((d) => d.points).toList();
    return DashboardStats(
      devices: devices.length,
      online: devices.where((d) => d.online).length,
      sensors: points.where((p) => p.isInput).length,
      actuators: points.where((p) => p.isOutput).length,
      alerts: points.where((p) => p.alert && p.enabled).length,
      outputsOn: points.where((p) => p.isOutput && p.stateOn && p.enabled).length,
    );
  }

  final int devices;
  final int online;
  final int sensors;
  final int actuators;
  final int alerts;
  final int outputsOn;
}

class Capacity {
  Capacity({required this.direction, required this.signal, required this.label, required this.used, required this.limit});

  factory Capacity.fromJson(Json j) => Capacity(
        direction: _s(j['direction']),
        signal: _s(j['signal']),
        label: _s(j['label']),
        used: _i(j['used']),
        limit: _i(j['limit']),
      );

  final String direction;
  final String signal;
  final String label;
  final int used;
  final int limit;

  int get left => limit - used < 0 ? 0 : limit - used;
  bool get full => used >= limit;
}

/// Everything the configuration screen needs.
class DeviceConfig {
  DeviceConfig({required this.device, required this.model, required this.pins, required this.capacity, required this.syncUrl});

  factory DeviceConfig.fromJson(Json j) => DeviceConfig(
        device: Device.fromJson(Map<String, dynamic>.from(j['device'] as Map)),
        model: j['model'] is Map ? DeviceModelSpec.fromJson(Map<String, dynamic>.from(j['model'] as Map)) : null,
        pins: _list(j['pins']).map(ModelPin.fromJson).toList(),
        capacity: _list(j['capacity']).map(Capacity.fromJson).toList(),
        syncUrl: _s(j['sync_url']),
      );

  final Device device;
  final DeviceModelSpec? model;
  final List<ModelPin> pins;
  final List<Capacity> capacity;
  final String syncUrl;

  Capacity? capacityFor(String direction, String signal) {
    for (final c in capacity) {
      if (c.direction == direction && c.signal == signal) return c;
    }
    return null;
  }
}

class Choice {
  Choice(this.key, this.label);

  factory Choice.fromJson(Json j) => Choice(_s(j['key']), _s(j['label']));

  final String key;
  final String label;
}

class AppMeta {
  AppMeta({required this.sensorTypes, required this.actuatorTypes, required this.pollSeconds});

  factory AppMeta.fromJson(Json j) => AppMeta(
        sensorTypes: _list(j['sensor_types']).map(Choice.fromJson).toList(),
        actuatorTypes: _list(j['actuator_types']).map(Choice.fromJson).toList(),
        pollSeconds: _i(j['poll_seconds']) == 0 ? 5 : _i(j['poll_seconds']),
      );

  final List<Choice> sensorTypes;
  final List<Choice> actuatorTypes;
  final int pollSeconds;
}

/// Message from the server: device online/offline, sensor alerts, setup.
class AppNotification {
  AppNotification({
    required this.id,
    required this.kind,
    required this.level,
    required this.title,
    required this.body,
    required this.read,
    required this.deviceId,
    required this.createdAt,
  });

  factory AppNotification.fromJson(Json j) => AppNotification(
        id: _i(j['id']),
        kind: _s(j['kind']),
        level: _s(j['level']),
        title: _s(j['title']),
        body: _s(j['body']),
        read: _b(j['read']),
        deviceId: j['device'] == null ? null : _i(j['device']),
        createdAt: _t(j['created_at']),
      );

  final int id;
  final String kind;
  final String level;
  final String title;
  final String body;
  bool read;
  final int? deviceId;
  final DateTime? createdAt;

  IconData get icon {
    switch (kind) {
      case 'online':
        return Icons.wifi_rounded;
      case 'offline':
        return Icons.wifi_off_rounded;
      case 'alert':
        return Icons.warning_amber_rounded;
      case 'alert_clear':
        return Icons.check_circle_rounded;
      case 'config':
        return Icons.tune_rounded;
      case 'local':
        return Icons.router_rounded;
      default:
        return Icons.notifications_rounded;
    }
  }
}


/// An output change waiting for the device's confirmation.
class PendingCommand {
  PendingCommand({required this.id, required this.value, this.status = 'pending', this.expiresAt});

  factory PendingCommand.fromJson(Json j) => PendingCommand(
        id: _i(j['id']),
        value: _d(j['value']) ?? 0,
        status: _s(j['status']),
        expiresAt: _t(j['expires_at']),
      );

  final int id;
  final double value;

  /// sending (app only) | pending | sent
  final String status;
  final DateTime? expiresAt;
}

/// Final answer about an output change.
class CommandOutcome {
  CommandOutcome({required this.status, this.error = '', this.ackMode = '', this.point});

  factory CommandOutcome.fromJson(Json res) {
    final c = res['command'] is Map ? Map<String, dynamic>.from(res['command'] as Map) : <String, dynamic>{};
    return CommandOutcome(
      status: _s(c['status']),
      error: _s(c['error']),
      ackMode: _s(c['ack_mode']),
      point: res['point'] is Map ? DevicePoint.fromJson(Map<String, dynamic>.from(res['point'] as Map)) : null,
    );
  }

  /// confirmed | failed | expired | superseded | unknown (no answer in time)
  final String status;
  final String error;

  /// device (pin read back) | delivery (old firmware, no confirmation) | local
  final String ackMode;
  final DevicePoint? point;

  bool get confirmed => status == 'confirmed';
}
