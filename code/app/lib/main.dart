import 'dart:ui' show PointerDeviceKind;

import 'package:flutter/material.dart';
import 'modules/calc/view.dart';

void main() {
  runApp(const CalculatrixApp());
}

/// Root widget for the Calculatrix application.
class CalculatrixApp extends StatelessWidget {
  const CalculatrixApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Calculatrix',
      debugShowCheckedModeBanner: false,
      scrollBehavior: const _CalculatrixScrollBehavior(),
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.blueGrey,
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
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
