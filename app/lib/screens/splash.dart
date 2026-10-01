import 'package:flutter/material.dart';
import '../core.dart';
import '../theme.dart';
import 'login.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});
  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _boot();
  }

  Future<void> _boot() async {
    await Session.load();
    await Future.delayed(const Duration(milliseconds: 1400));
    if (!mounted) return;
    Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const LoginScreen()));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF101418),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 96,
              height: 96,
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [Color(0xFFC9A227), Color(0xFFE8CF7A)]),
                borderRadius: BorderRadius.circular(28),
                boxShadow: [BoxShadow(color: AstraTheme.gold.withValues(alpha: .45), blurRadius: 32)],
              ),
              child: const Icon(Icons.bolt_rounded, size: 52, color: Color(0xFF101418)),
            ),
            const SizedBox(height: 22),
            const Text('ASTRA TELOS', style: TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w800, letterSpacing: 4)),
            const SizedBox(height: 8),
            const Text('Nhắn tin nhanh · Sang trọng · Mượt mà', style: TextStyle(color: Color(0xFFE8CF7A), fontSize: 14)),
            const SizedBox(height: 26),
            const SizedBox(width: 30, height: 30, child: CircularProgressIndicator(color: AstraTheme.gold, strokeWidth: 3)),
          ],
        ),
      ),
    );
  }
}
