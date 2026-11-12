import 'dart:convert';

import 'package:dio/dio.dart';

import '../storage/key_value_store.dart';

/// HTTP-level cache for GET requests using ETags.
///
/// * Stores the body and ETag of every 200 response.
/// * Sends `If-None-Match` on the next request for the same URL.
/// * Turns a 304 into a normal 200 response built from the cached body, so
///   callers never deal with 304s. `response.extra['fromCache']` tells them
///   the content did not change.
class EtagCacheInterceptor extends Interceptor {
  EtagCacheInterceptor(this._store);
  final KeyValueStore _store;

  static String etagKey(Uri uri) => 'etag:$uri';
  static String bodyKey(Uri uri) => 'body:$uri';

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    if (options.method == 'GET') {
      final etag = _store.read(etagKey(options.uri));
      final hasBody = _store.read(bodyKey(options.uri)) != null;
      if (etag != null && hasBody) {
        options.headers['If-None-Match'] = etag;
      }
    }
    handler.next(options);
  }

  @override
  Future<void> onResponse(
    Response<dynamic> response,
    ResponseInterceptorHandler handler,
  ) async {
    final options = response.requestOptions;
    if (options.method != 'GET') {
      handler.next(response);
      return;
    }

    if (response.statusCode == 304) {
      final cached = _store.read(bodyKey(options.uri));
      if (cached != null) {
        handler.next(
          Response<dynamic>(
            requestOptions: options,
            statusCode: 200,
            data: jsonDecode(cached),
            headers: response.headers,
            extra: {...response.extra, 'fromCache': true},
          ),
        );
        return;
      }
    }

    final etag = response.headers.value('etag');
    if (response.statusCode == 200 && etag != null) {
      await _store.write(etagKey(options.uri), etag);
      await _store.write(bodyKey(options.uri), jsonEncode(response.data));
    }
    handler.next(response);
  }
}
