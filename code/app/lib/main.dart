import 'dart:ui' show PointerDeviceKind;

import 'package:flutter/material.dart';
import 'modules/calc/view.dart';

void main() {
  runApp(const CalculatrixApp());
}

/// Root widget for the Calculatrix application.
class CalculatrixApp extends StatelessWidget {
  const CalculatrixApp({super.key});

  static const Color _seedColor = Color(0xFF4FC3F7);
  static const String _mathFontFamily = 'JetBrainsMono';

  ThemeData _buildTheme(Brightness brightness) {
    final ThemeData base = ThemeData(
      colorScheme: ColorScheme.fromSeed(
        seedColor: _seedColor,
        brightness: brightness,
      ),
      useMaterial3: true,
    );

    final TextTheme textTheme = base.textTheme.apply(
      fontFamily: _mathFontFamily,
      bodyColor: base.colorScheme.onSurface,
      displayColor: base.colorScheme.onSurface,
    );

    return base.copyWith(
      textTheme: textTheme,
      primaryTextTheme: textTheme,
    );
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Calculatrix',
      debugShowCheckedModeBanner: false,
      scrollBehavior: const _CalculatrixScrollBehavior(),
      theme: _buildTheme(Brightness.light),
      darkTheme: _buildTheme(Brightness.dark),
      themeMode: ThemeMode.system,
      home: const CalculatorView(),
    );
  }
}

class _CalculatrixScrollBehavior extends MaterialScrollBehavior {
  const _CalculatrixScrollBehavior();

  @override
  Set<PointerDeviceKind> get dragDevices => <PointerDeviceKind>{
        ...super.dragDevices,
        PointerDeviceKind.mouse,
      };
}
