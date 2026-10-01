import 'package:flutter/material.dart';
import 'theme.dart';
import 'screens/splash.dart';

void main() {
  runApp(const AstraTelos());
}

class AstraTelos extends StatelessWidget {
  const AstraTelos({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Astra Telos',
      debugShowCheckedModeBanner: false,
      theme: AstraTheme.light(),
      darkTheme: AstraTheme.dark(),
      themeMode: ThemeMode.system,
      home: const SplashScreen(),
    );
  }
}
