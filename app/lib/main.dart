import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_ce_flutter/hive_flutter.dart';

import 'core/providers.dart';
import 'core/storage/key_value_store.dart';
import 'core/theme/app_theme.dart';
import 'features/home/presentation/home_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Hive.initFlutter();
  final httpCache = await Hive.openBox<String>('http_cache');
  final cart = await Hive.openBox<String>('cart');

  runApp(
    ProviderScope(
      overrides: [
        httpCacheStoreProvider.overrideWithValue(HiveStore(httpCache)),
        cartStoreProvider.overrideWithValue(HiveStore(cart)),
      ],
      child: const ShelfSyncApp(),
    ),
  );
}

class ShelfSyncApp extends StatelessWidget {
  const ShelfSyncApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ShelfSync',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(Brightness.light),
      darkTheme: buildTheme(Brightness.dark),
      home: const HomeScreen(),
    );
  }
}
