import 'package:flutter/material.dart';
import 'modules/calc/calc.dart';

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
