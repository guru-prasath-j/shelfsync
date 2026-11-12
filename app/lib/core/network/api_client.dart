import 'dart:convert';

import 'package:dio/dio.dart';

import '../storage/key_value_store.dart';
import 'etag_cache_interceptor.dart';

class ApiClient {
  ApiClient({
    required String baseUrl,
    required KeyValueStore cache,
    HttpClientAdapter? adapter,
  })  : _cache = cache,
        dio = Dio(
          BaseOptions(
            baseUrl: baseUrl,
            connectTimeout: const Duration(seconds: 5),
            receiveTimeout: const Duration(seconds: 8),
            // 304 counts as success: the interceptor serves the cached body.
            validateStatus: (s) => s != null && (s < 300 || s == 304),
          ),
        ) {
    if (adapter != null) dio.httpClientAdapter = adapter;
    dio.interceptors.add(EtagCacheInterceptor(cache));
  }

  final Dio dio;
  final KeyValueStore _cache;

  Future<dynamic> getJson(String path) async =>
      (await dio.get<dynamic>(path)).data;

  Future<dynamic> postJson(String path, Object body) async =>
      (await dio.post<dynamic>(path, data: body)).data;

  /// Last good body for [path] without touching the network.
  dynamic cachedJson(String path) {
    final uri = RequestOptions(path: path, baseUrl: dio.options.baseUrl).uri;
    final raw = _cache.read(EtagCacheInterceptor.bodyKey(uri));
    return raw == null ? null : jsonDecode(raw);
  }
}
