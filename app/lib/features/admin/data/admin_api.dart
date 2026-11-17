import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/app_config.dart';

class AdminException implements Exception {
  const AdminException(this.message, {this.sessionExpired = false});
  final String message;
  final bool sessionExpired;
  @override
  String toString() => message;
}

class AdminStatus {
  const AdminStatus({required this.passwordSet, required this.canSetup});
  final bool passwordSet;

  /// First-time setup is only allowed from the PC or a USB-connected phone.
  final bool canSetup;
}

/// Talks to the CMS admin endpoints. Deliberately separate from the shopper
/// ApiClient: no ETag cache, so admin data never lands in the offline cache.
class AdminApi {
  AdminApi(String baseUrl, {HttpClientAdapter? adapter})
      : _dio = Dio(
          BaseOptions(
            baseUrl: baseUrl,
            connectTimeout: const Duration(seconds: 5),
            receiveTimeout: const Duration(seconds: 10),
            contentType: Headers.jsonContentType,
          ),
        ) {
    if (adapter != null) _dio.httpClientAdapter = adapter;
  }

  final Dio _dio;

  Options _auth(String token) =>
      Options(headers: {'Authorization': 'Bearer $token'});

  Future<Map<String, dynamic>> _run(
    Future<Response<dynamic>> Function() call,
  ) async {
    try {
      final res = await call();
      return (res.data as Map).cast<String, dynamic>();
    } on DioException catch (e) {
      final data = e.response?.data;
      final serverMsg = data is Map ? data['error'] as String? : null;
      if (serverMsg != null) {
        throw AdminException(
          serverMsg,
          sessionExpired: e.response?.statusCode == 401 &&
              serverMsg == 'Please log in again',
        );
      }
      throw const AdminException(
        'Can\'t reach the store server. Check that the CMS is running.',
      );
    }
  }

  Future<AdminStatus> status() async {
    final j = await _run(() => _dio.get<dynamic>('admin/status'));
    return AdminStatus(
      passwordSet: j['passwordSet'] == true,
      canSetup: j['canSetup'] == true,
    );
  }

  Future<String> setup(String password) async => (await _run(
        () => _dio.post<dynamic>('admin/setup', data: {'password': password}),
      ))['token'] as String;

  Future<String> login(String password) async => (await _run(
        () => _dio.post<dynamic>('admin/login', data: {'password': password}),
      ))['token'] as String;

  Future<void> logout(String token) async {
    try {
      await _run(
        () => _dio.post<dynamic>('admin/logout', options: _auth(token)),
      );
    } on AdminException {
      // Already logged out or offline: forgetting the token locally is enough.
    }
  }

  /// Returns a fresh token; the server signs out every other session.
  Future<String> changePassword(
    String token, {
    required String current,
    required String next,
  }) async =>
      (await _run(
        () => _dio.post<dynamic>(
          'admin/password',
          data: {'current': current, 'next': next},
          options: _auth(token),
        ),
      ))['token'] as String;

  /// Raw layout source: product grids keep `productIds`; expired and unknown
  /// blocks are included so nothing is lost on publish.
  Future<Map<String, dynamic>> fetchLayout(String token) =>
      _run(() => _dio.get<dynamic>('admin/layout/home', options: _auth(token)));

  Future<void> publishLayout(String token, Map<String, dynamic> layout) => _run(
        () => _dio.put<dynamic>(
          'admin/layout/home',
          data: layout,
          options: _auth(token),
        ),
      );
}

final adminApiProvider =
    Provider<AdminApi>((ref) => AdminApi(AppConfig.baseUrl));

/// The admin session token. Kept in memory only: closing the app logs out,
/// so a shared store phone never stays signed in as admin.
class AdminSession extends Notifier<String?> {
  @override
  String? build() => null;

  void signIn(String token) => state = token;
  void signOut() => state = null;
}

final adminSessionProvider =
    NotifierProvider<AdminSession, String?>(AdminSession.new);
