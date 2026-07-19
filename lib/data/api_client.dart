import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../core/config.dart';
import 'session_store.dart';

class ApiException implements Exception {
  ApiException(this.message, {this.statusCode});
  final String message;
  final int? statusCode;
  @override
  String toString() => message;
}

/// Fires when a 401 from any authenticated request invalidates the session.
/// `main.dart` listens to this and drops the user back to the login screen.
final ValueNotifier<int> sessionExpiredSignal = ValueNotifier<int>(0);

class ApiClient {
  ApiClient._();
  static final instance = ApiClient._();

  static const Duration _timeout = Duration(seconds: 15);
  // Payment endpoints round-trip through Razorpay's API on the server
  // side, which can add several seconds. Use a longer timeout so a
  // slow Razorpay-us hop doesn't look like a network failure and get
  // retried (which risks a duplicate order).
  static const Duration _paymentTimeout = Duration(seconds: 30);

  Duration _timeoutFor(String path) {
    if (path.startsWith('/payments/') ||
        path.startsWith('/qr/') && (path.contains('/renew/') || path.endsWith('/create'))) {
      return _paymentTimeout;
    }
    return _timeout;
  }

  Uri _uri(String path) {
    final base = AppConfig.apiBase;
    return Uri.parse('$base$path');
  }

  Future<Map<String, String>> _headers({bool auth = false}) async {
    final h = <String, String>{
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };
    if (auth) {
      final t = await SessionStore.getToken();
      if (t != null && t.isNotEmpty) h['Authorization'] = 'Bearer $t';
    }
    return h;
  }

  Future<dynamic> get(String path, {bool auth = true}) async {
    final headers = await _headers(auth: auth);
    final res = await _send(path, () => http.get(_uri(path), headers: headers));
    return _decode(res);
  }

  Future<dynamic> post(String path, Map<String, dynamic> body, {bool auth = true}) async {
    final headers = await _headers(auth: auth);
    final res = await _send(path, () => http.post(
          _uri(path),
          headers: headers,
          body: jsonEncode(body),
        ));
    return _decode(res);
  }

  Future<dynamic> put(String path, Map<String, dynamic> body, {bool auth = true}) async {
    final headers = await _headers(auth: auth);
    final res = await _send(path, () => http.put(
          _uri(path),
          headers: headers,
          body: jsonEncode(body),
        ));
    return _decode(res);
  }

  Future<dynamic> delete(String path, {bool auth = true}) async {
    final headers = await _headers(auth: auth);
    final res = await _send(path, () => http.delete(_uri(path), headers: headers));
    return _decode(res);
  }

  Future<http.Response> _send(String path, Future<http.Response> Function() build) async {
    try {
      return await build().timeout(_timeoutFor(path));
    } on TimeoutException {
      throw ApiException(
        'Network timeout — could not reach ${AppConfig.apiBase}. '
        'Check that the backend is running and the device is on the same network.',
      );
    } on SocketException catch (e) {
      throw ApiException('Network error: ${e.message}');
    } on http.ClientException catch (e) {
      throw ApiException('Network error: ${e.message}');
    }
  }

  Future<dynamic> _decode(http.Response res) async {
    dynamic data;
    try {
      data = res.body.isEmpty ? null : jsonDecode(utf8.decode(res.bodyBytes));
    } catch (_) {
      data = res.body;
    }
    if (res.statusCode >= 200 && res.statusCode < 300) return data;
    if (res.statusCode == 401) {
      // Only clear the local session when the backend explicitly marks
      // this as a session failure (requireAuth middleware sets
      // `code: 'AUTH_INVALID'`). Any other 401 — e.g., a passthrough
      // from a third-party service like Razorpay — must not log the
      // user out; that's a server-side problem, not the user's problem.
      final isSessionFail = data is Map && data['code'] == 'AUTH_INVALID';
      if (isSessionFail) {
        await SessionStore.clear();
        sessionExpiredSignal.value++;
        throw ApiException('Session expired. Please log in again.',
            statusCode: 401);
      }
      final msg = data is Map && data['error'] != null
          ? data['error'].toString()
          : 'Request failed (401)';
      throw ApiException(msg, statusCode: 401);
    }
    final msg = data is Map && data['error'] != null
        ? data['error'].toString()
        : 'Request failed (${res.statusCode})';
    throw ApiException(msg, statusCode: res.statusCode);
  }
}
