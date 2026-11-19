import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

/// Talks directly to a device on the same Wi-Fi (local mode, no internet needed).
/// The device answers on http://<local-ip>/api/... and checks the device token.
class LocalClient {
  LocalClient({http.Client? client}) : _http = client ?? http.Client();

  final http.Client _http;
  static const Duration _timeout = Duration(milliseconds: 1500);

  Uri _uri(String ip, String path) => Uri.parse('http://$ip$path');

  /// Current values of every pin, or null when the device cannot be reached locally.
  Future<Map<String, dynamic>?> state(String ip, String token) async {
    if (ip.isEmpty || token.isEmpty) return null;
    try {
      final res = await _http.get(_uri(ip, '/api/state'), headers: {'X-Device-Token': token}).timeout(_timeout);
      if (res.statusCode != 200) return null;
      final body = jsonDecode(utf8.decode(res.bodyBytes));
      return body is Map<String, dynamic> && body['ok'] == true ? body : null;
    } catch (_) {
      return null;
    }
  }

  /// Change an output directly on the device and get the state the device read back from the pin.
  /// Returns null when the device cannot be reached locally (then the app uses the internet).
  Future<LocalSetResult?> setValue(String ip, String token, String pin, double value) async {
    if (ip.isEmpty || token.isEmpty) return null;
    try {
      final res = await _http
          .post(
            _uri(ip, '/api/set'),
            headers: {'X-Device-Token': token, 'Content-Type': 'application/json'},
            body: jsonEncode({'pin': pin, 'value': value}),
          )
          .timeout(_timeout);
      dynamic body;
      try {
        body = jsonDecode(utf8.decode(res.bodyBytes));
      } catch (_) {
        body = null;
      }
      final map = body is Map ? Map<String, dynamic>.from(body) : <String, dynamic>{};
      if (res.statusCode == 200 && map['ok'] == true) {
        final reported = map['value'];
        // Firmware 3.x reads the pin back ("confirmed"); 2.x answers after applying the change.
        return LocalSetResult(
          confirmed: map['confirmed'] != false,
          value: reported is num ? reported.toDouble() : value,
        );
      }
      return LocalSetResult(
        confirmed: false,
        value: map['value'] is num ? (map['value'] as num).toDouble() : null,
        error: '${map['error'] ?? 'The device refused the change (${res.statusCode}).'}',
      );
    } catch (_) {
      return null;
    }
  }
}

/// Answer of the device on the local network.
class LocalSetResult {
  LocalSetResult({required this.confirmed, this.value, this.error});

  final bool confirmed;

  /// State of the output as reported by the device.
  final double? value;
  final String? error;
}
