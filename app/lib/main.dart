import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_ce_flutter/hive_flutter.dart';

import 'core/providers.dart';
import 'core/storage/key_value_store.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/theme_mode.dart';
import 'features/home/presentation/home_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Hive.initFlutter();
  final httpCache = await Hive.openBox<String>('http_cache');
  final cart = await Hive.openBox<String>('cart');
  final settings = await Hive.openBox<String>('settings');

  runApp(
    ProviderScope(
      overrides: [
        httpCacheStoreProvider.overrideWithValue(HiveStore(httpCache)),
        cartStoreProvider.overrideWithValue(HiveStore(cart)),
        settingsStoreProvider.overrideWithValue(HiveStore(settings)),
      ],
      child: const ShelfSyncApp(),
    ),
  );
}

class ShelfSyncApp extends ConsumerWidget {
  const ShelfSyncApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp(
      title: 'ShelfSync',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(Brightness.light),
      darkTheme: buildTheme(Brightness.dark),
      themeMode: ref.watch(themeModeProvider),
      // Phone-first: on tablets/desktop the app sits in a centred column
      // instead of stretching banners and grids across the whole window.
      builder: (context, child) => ColoredBox(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: kMaxContentWidth),
            child: child,
          ),
        ),
      ),
      home: const HomeScreen(),
    );
  }
}
