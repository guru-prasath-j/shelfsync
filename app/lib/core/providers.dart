import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'config/app_config.dart';
import 'network/api_client.dart';
import 'storage/key_value_store.dart';

/// Overridden in main() with Hive-backed stores, and in tests with MemoryStore.
final httpCacheStoreProvider = Provider<KeyValueStore>(
  (ref) => throw UnimplementedError('Override httpCacheStoreProvider'),
);
final cartStoreProvider = Provider<KeyValueStore>(
  (ref) => throw UnimplementedError('Override cartStoreProvider'),
);

/// Small app preferences (theme). Falls back to memory, so widgets and
/// tests that don't override it still work.
final settingsStoreProvider = Provider<KeyValueStore>((ref) => MemoryStore());

final apiClientProvider = Provider<ApiClient>(
  (ref) => ApiClient(
    baseUrl: AppConfig.baseUrl,
    cache: ref.watch(httpCacheStoreProvider),
  ),
);

final connectivityProvider = StreamProvider<List<ConnectivityResult>>(
  (ref) => Connectivity().onConnectivityChanged,
);
