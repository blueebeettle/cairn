import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'data/providers/database_provider.dart';
import 'features/navigation/presentation/navigation_shell.dart';
import 'theme/app_theme.dart';

/// Focus Stack main application widget.
///
/// Wires [AppTheme.light] and [AppTheme.dark] into MaterialApp,
/// responds to [themeModeProvider], and mounts [NavigationShell].
class FocusStackApp extends ConsumerWidget {
  const FocusStackApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);

    return MaterialApp(
      title: 'Cairn',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: themeMode,
      home: const NavigationShell(),
    );
  }
}
