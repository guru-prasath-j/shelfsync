import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../../core/providers.dart';
import '../domain/layout_block.dart';

class LayoutResult {
  const LayoutResult(this.layout, {required this.isStale});
  final HomeLayout layout;

  /// True once a refresh failed and we are showing the last saved copy.
  final bool isStale;
}

/// Stale-while-revalidate: emit the cached layout instantly, then the
/// fresh one. Offline with a cache = stale content, never a blank screen.
class LayoutRepository {
  LayoutRepository(this._api);
  final ApiClient _api;
  static const _path = 'layout/home';

  Stream<LayoutResult> watchHome() async* {
    final cached = _api.cachedJson(_path);
    if (cached is Map<String, dynamic>) {
      // Instant paint from disk while the network request is in flight.
      yield LayoutResult(HomeLayout.fromJson(cached), isStale: false);
    }
    try {
      final fresh = await _api.getJson(_path) as Map<String, dynamic>;
      yield LayoutResult(HomeLayout.fromJson(fresh), isStale: false);
    } on DioException {
      if (cached is! Map<String, dynamic>) rethrow;
      yield LayoutResult(HomeLayout.fromJson(cached), isStale: true);
    }
  }
}

final layoutRepositoryProvider = Provider<LayoutRepository>(
  (ref) => LayoutRepository(ref.watch(apiClientProvider)),
);

final homeLayoutProvider = StreamProvider.autoDispose<LayoutResult>(
  (ref) => ref.watch(layoutRepositoryProvider).watchHome(),
);
