import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shelfsync/core/providers.dart';
import 'package:shelfsync/core/storage/key_value_store.dart';
import 'package:shelfsync/core/theme/app_theme.dart';
import 'package:shelfsync/core/theme/theme_mode.dart';

void main() {
  test('theme choice is saved and restored on the next launch', () async {
    final store = MemoryStore();
    final first = ProviderContainer(
      overrides: [settingsStoreProvider.overrideWithValue(store)],
    );
    expect(first.read(themeModeProvider), ThemeMode.system);
    await first.read(themeModeProvider.notifier).set(ThemeMode.dark);
    first.dispose();

    final next = ProviderContainer(
      overrides: [settingsStoreProvider.overrideWithValue(store)],
    );
    expect(next.read(themeModeProvider), ThemeMode.dark);
    next.dispose();
  });

  test('dark theme uses the readable dark palette', () {
    expect(
      buildTheme(Brightness.dark).extension<AppPalette>(),
      AppPalette.dark,
    );
    expect(
      buildTheme(Brightness.light).extension<AppPalette>(),
      AppPalette.light,
    );
  });
}
