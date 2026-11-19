import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../config.dart';
import '../models/models.dart' show Json;

/// Error returned by the server (or a network problem), with a message fit for the user.
class ApiException implements Exception {
  ApiException(this.message, {this.status = 0, this.code = '', this.fieldErrors = const {}});

  final String message;
  final int status;
  final String code;

  /// Errors per form field, e.g. {"pin": ["Pin GPIO4 is already used on this device."]}.
  final Map<String, List<String>> fieldErrors;

  bool get isAuth => status == 401 || code == 'auth';
  bool get isNetwork => status == 0;

  String? field(String name) {
    final list = fieldErrors[name];
    return (list == null || list.isEmpty) ? null : list.join('\n');
  }

  /// Errors that are not tied to one field ("__all__").
  String? get general => field('__all__');

  @override
  String toString() => message;
}

/// Thin JSON client for /api/mobile/v1/.
class ApiClient {
  ApiClient({required this.server, this.token, http.Client? client}) : _http = client ?? http.Client();

  String server;
  String? token;
  final http.Client _http;

  /// Called when the server says the token is no longer valid.
  void Function()? onUnauthorized;

  Uri _uri(String path, [Map<String, String>? query]) {
    final base = server.endsWith('/') ? server.substring(0, server.length - 1) : server;
    final clean = path.startsWith('/') ? path : '/$path';
    return Uri.parse('$base${AppConfig.apiPath}$clean').replace(queryParameters: query);
  }

  Map<String, String> get _headers => {
        'Accept': 'application/json',
        'Content-Type': 'application/json; charset=utf-8',
        'User-Agent': 'PEWSmartHomeApp/1.0 (${Platform.operatingSystem})',
        if (token != null && token!.isNotEmpty) 'Authorization': 'Bearer $token',
      };

  Future<Json> get(String path, {Map<String, String>? query}) =>
      _send(() => _http.get(_uri(path, query), headers: _headers));

  Future<Json> post(String path, [Json? body]) =>
      _send(() => _http.post(_uri(path), headers: _headers, body: jsonEncode(body ?? const {})));

  Future<Json> patch(String path, Json body) =>
      _send(() => _http.patch(_uri(path), headers: _headers, body: jsonEncode(body)));

  Future<Json> delete(String path) => _send(() => _http.delete(_uri(path), headers: _headers));

  Future<Json> _send(Future<http.Response> Function() request) async {
    http.Response res;
    try {
      res = await request().timeout(AppConfig.requestTimeout);
    } on TimeoutException {
      throw ApiException('The server took too long to answer. It may be waking up, please try again.');
    } on SocketException {
      throw ApiException('No internet connection, or the server cannot be reached.');
    } on HandshakeException {
      throw ApiException('Secure connection failed. Check the server address.');
    } on http.ClientException catch (e) {
      throw ApiException('Connection problem: ${e.message}');
    }

    Json body;
    try {
      final decoded = jsonDecode(utf8.decode(res.bodyBytes));
      body = decoded is Map<String, dynamic> ? decoded : <String, dynamic>{'data': decoded};
    } catch (_) {
      if (res.statusCode >= 500) {
        throw ApiException('Server error (${res.statusCode}). Please try again shortly.', status: res.statusCode);
      }
      if (res.statusCode == 404) {
        throw ApiException('This server does not have the phone app API yet. Update the website.', status: 404);
      }
      throw ApiException('Unexpected answer from the server (${res.statusCode}).', status: res.statusCode);
    }

    if (res.statusCode >= 200 && res.statusCode < 300 && body['ok'] != false) {
      return body;
    }

    final errors = <String, List<String>>{};
    final raw = body['errors'];
    if (raw is Map) {
      raw.forEach((key, value) {
        if (value is List) {
          errors['$key'] = value.map((e) => '$e').toList();
        } else if (value != null) {
          errors['$key'] = ['$value'];
        }
      });
    }
    final error = ApiException(
      (body['error'] ?? 'Request failed (${res.statusCode}).').toString(),
      status: res.statusCode,
      code: (body['code'] ?? '').toString(),
      fieldErrors: errors,
    );
    if (error.isAuth) {
      onUnauthorized?.call();
    }
    throw error;
  }
}
