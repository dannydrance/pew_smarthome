import 'package:flutter_test/flutter_test.dart';
import 'package:pew_smarthome/models/models.dart';

void main() {
  test('parses a device with points from the API', () {
    final device = Device.fromJson({
      'id': 3,
      'name': 'Main controller',
      'display_name': 'Main controller',
      'location': 'Home, Kicukiro',
      'serial': 'PEW-ESP32-0012',
      'model': {'id': 1, 'name': 'ESP32 Smart Home Controller', 'code': 'PEW-ESP32-SH'},
      'enabled': true,
      'online': true,
      'token_masked': 'ab12••••••••ef90',
      'points': [
        {'id': 1, 'name': 'Front door', 'location': 'Front door', 'direction': 'input', 'signal': 'digital',
         'type': 'door', 'pin': 'GPIO4', 'min': 0, 'max': 1, 'value': 1, 'display': 'Open', 'state_on': true,
         'alert': true, 'percent': 100, 'enabled': true},
        {'id': 2, 'name': 'Lamp', 'location': 'Living room', 'direction': 'output', 'signal': 'analog',
         'type': 'dimmer', 'pin': 'GPIO22', 'unit': '%', 'min': 0, 'max': 100, 'value': 40, 'display': '40 %',
         'state_on': true, 'alert': false, 'percent': 40, 'enabled': true},
      ],
    });
    expect(device.inputs.length, 1);
    expect(device.outputs.length, 1);
    expect(device.model!.code, 'PEW-ESP32-SH');
    final lamp = device.outputs.first.withValue(75);
    expect(lamp.display, '75 %');
    expect(lamp.percent, 75);
  });

  test('model pin capabilities', () {
    final pin = ModelPin.fromJson({'pin': 'GPIO34', 'label': 'IN1', 'caps': ['digital_in', 'analog_in']});
    expect(pin.supports('input', 'analog'), isTrue);
    expect(pin.supports('output', 'digital'), isFalse);
  });

  test('output waiting for the device confirmation', () {
    final point = DevicePoint.fromJson({
      'id': 5, 'name': 'Gas valve', 'location': 'Kitchen', 'direction': 'output', 'signal': 'digital',
      'type': 'valve', 'pin': 'D5', 'min': 0, 'max': 1, 'value': 0, 'display': 'Closed', 'state_on': false,
      'enabled': true,
      'pending': {'id': 41, 'value': 1, 'status': 'sent', 'expires_at': '2026-11-18T10:00:30+02:00'},
    });
    expect(point.stateOn, isFalse); // still the confirmed state
    expect(point.pending!.id, 41);
    expect(point.pending!.status, 'sent');
    expect(point.waitingLabel(point.pending!.value), 'Opening…');
    expect(point.withValue(1).pending, isNull);
  });

  test('final answer about a change', () {
    final ok = CommandOutcome.fromJson({
      'command': {'id': 41, 'status': 'confirmed', 'ack_mode': 'device', 'final': true},
      'point': {'id': 5, 'name': 'Lamp', 'direction': 'output', 'signal': 'digital', 'type': 'switch', 'pin': 'D5',
                'value': 1, 'display': 'On', 'state_on': true, 'enabled': true},
    });
    expect(ok.confirmed, isTrue);
    expect(ok.point!.stateOn, isTrue);
    final failed = CommandOutcome.fromJson({'command': {'status': 'failed', 'error': 'Relay fault'}});
    expect(failed.confirmed, isFalse);
    expect(failed.error, 'Relay fault');
  });
}
