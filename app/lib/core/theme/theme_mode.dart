import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers.dart';

/// Light / Dark / follow the phone. Saved on the device, so the choice
/// survives restarts and works offline.
class ThemeModeNotifier extends Notifier<ThemeMode> {
  static const _key = 'themeMode';

  @override
  ThemeMode build() {
    final saved = ref.watch(settingsStoreProvider).read(_key);
    return ThemeMode.values.firstWhere(
      (m) => m.name == saved,
      orElse: () => ThemeMode.system,
    );
  }

  Future<void> set(ThemeMode mode) async {
    state = mode;
    await ref.read(settingsStoreProvider).write(_key, mode.name);
  }
}

final themeModeProvider =
    NotifierProvider<ThemeModeNotifier, ThemeMode>(ThemeModeNotifier.new);

/// Bottom sheet with the three choices; shows which one is active.
Future<void> showThemePicker(BuildContext context, WidgetRef ref) {
  return showModalBottomSheet<void>(
    context: context,
    builder: (context) => Consumer(
      builder: (context, ref, _) {
        final current = ref.watch(themeModeProvider);
        Widget option(
          ThemeMode mode,
          IconData icon,
          String label,
          String hint,
        ) =>
            ListTile(
              leading: Icon(icon),
              title: Text(label),
              subtitle: Text(hint),
              trailing: current == mode
                  ? Icon(
                      Icons.check_circle,
                      color: Theme.of(context).colorScheme.primary,
                    )
                  : null,
              selected: current == mode,
              onTap: () {
                ref.read(themeModeProvider.notifier).set(mode);
                Navigator.pop(context);
              },
            );
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  'Appearance',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              option(
                ThemeMode.light,
                Icons.light_mode_outlined,
                'Light',
                'Bright background',
              ),
              option(
                ThemeMode.dark,
                Icons.dark_mode_outlined,
                'Dark',
                'Easier on the eyes at night',
              ),
              option(
                ThemeMode.system,
                Icons.brightness_auto_outlined,
                'Same as phone',
                'Follows your phone\'s setting',
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    ),
  );
}

IconData themeModeIcon(ThemeMode mode) => switch (mode) {
      ThemeMode.light => Icons.light_mode_outlined,
      ThemeMode.dark => Icons.dark_mode_outlined,
      ThemeMode.system => Icons.brightness_auto_outlined,
    };
