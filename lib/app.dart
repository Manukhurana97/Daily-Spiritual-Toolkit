import 'package:flutter/material.dart';

import 'core/theme/app_theme.dart';
import 'screens/home_shell.dart';

class NaamJapApp extends StatelessWidget {
  const NaamJapApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Naam Jap',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      home: const HomeShell(),
    );
  }
}
