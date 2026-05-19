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

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Calculatrix',
      debugShowCheckedModeBanner: false,
      scrollBehavior: const _CalculatrixScrollBehavior(),
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: _seedColor,
          brightness: Brightness.light,
        ),
        useMaterial3: true,
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: _seedColor,
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
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
