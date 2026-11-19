import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../api/api_client.dart';
import '../config.dart';
import '../models/models.dart';

enum AuthStatus { loading, signedOut, signedIn }

/// Holds the server address, the sign-in token (in secure storage) and the signed-in user.
class AuthState extends ChangeNotifier {
  AuthState() : api = ApiClient(server: AppConfig.defaultServer) {
    api.onUnauthorized = _expired;
  }

  static const _storage = FlutterSecureStorage();
  static const _kToken = 'pew_token';
  static const _kServer = 'pew_server';
  static const _kUser = 'pew_username';

  final ApiClient api;
  AuthStatus status = AuthStatus.loading;
  AppUser? user;
  String lastUsername = '';
  String? notice;

  String get server => api.server;

  Future<void> init() async {
    try {
      final server = await _storage.read(key: _kServer);
      if (server != null && server.isNotEmpty) api.server = server;
      lastUsername = await _storage.read(key: _kUser) ?? '';
      api.token = await _storage.read(key: _kToken);
    } catch (_) {
      api.token = null;
    }
    if (api.token == null || api.token!.isEmpty) {
      status = AuthStatus.signedOut;
      notifyListeners();
      return;
    }
    status = AuthStatus.signedIn;
    notifyListeners();
    try {
      final res = await api.get('/me/');
      user = AppUser.fromJson(Map<String, dynamic>.from(res['user'] as Map));
      notifyListeners();
    } on ApiException catch (e) {
      if (e.isAuth) await _clear();
      // Network problems: stay signed in, the dashboard will show the error and retry.
    }
  }

  Future<void> setServer(String value) async {
    var clean = value.trim();
    if (clean.isEmpty) clean = AppConfig.defaultServer;
    if (!clean.startsWith('http://') && !clean.startsWith('https://')) clean = 'https://$clean';
    while (clean.endsWith('/')) {
      clean = clean.substring(0, clean.length - 1);
    }
    api.server = clean;
    await _storage.write(key: _kServer, value: clean);
    notifyListeners();
  }

  Future<void> login(String username, String password) async {
    final res = await api.post('/auth/login/', {
      'username': username.trim(),
      'password': password,
      'device_name': 'Phone app (${defaultTargetPlatform.name})',
    });
    api.token = '${res['token']}';
    user = AppUser.fromJson(Map<String, dynamic>.from(res['user'] as Map));
    lastUsername = username.trim();
    notice = null;
    await _storage.write(key: _kToken, value: api.token);
    await _storage.write(key: _kUser, value: lastUsername);
    status = AuthStatus.signedIn;
    notifyListeners();
  }

  Future<void> logout() async {
    try {
      await api.post('/auth/logout/');
    } catch (_) {
      // Signing out locally is enough if the server cannot be reached.
    }
    await _clear();
  }

  void _expired() {
    if (status != AuthStatus.signedIn) return;
    notice = 'Your session ended. Please sign in again.';
    _clear();
  }

  Future<void> _clear() async {
    api.token = null;
    user = null;
    status = AuthStatus.signedOut;
    try {
      await _storage.delete(key: _kToken);
    } catch (_) {}
    notifyListeners();
  }
}
