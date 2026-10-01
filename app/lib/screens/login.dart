import 'package:flutter/material.dart';
import '../core.dart';
import '../theme.dart';
import 'register.dart';
import 'home.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final phone = TextEditingController();
  final pass = TextEditingController();
  bool busy = false;
  bool showPass = false;
  String? error;

  @override
  void initState() {
    super.initState();
    if (Session.token != null && Session.user != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const HomeScreen()));
      });
    }
  }

  String _handle() {
    var p = phone.text.trim().replaceAll(RegExp(r'[\s\-.]'), '');
    if (p.startsWith('+84')) p = '0${p.substring(3)}';
    return p;
  }

  Future<void> _submit() async {
    final h = _handle();
    if (h.length < 9) {
      setState(() => error = 'Vui lòng nhập đúng số điện thoại');
      return;
    }
    if (pass.text.isEmpty) {
      setState(() => error = 'Vui lòng nhập mật khẩu');
      return;
    }
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final res = await Api.post('/api/auth/login', {'handle': h, 'password': pass.text});
      if (res['ok'] == true) {
        final d = res['data'] as Map<String, dynamic>;
        await Session.save(d['token'] as String, Map<String, dynamic>.from(d['user']));
        if (!mounted) return;
        Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const HomeScreen()));
      } else {
        setState(() => error = '${res['message'] ?? 'Số điện thoại hoặc mật khẩu chưa đúng'}');
      }
    } catch (_) {
      setState(() => error = 'Mất kết nối mạng. Vui lòng thử lại.');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AstraBackground(
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 430),
              child: ListView(
                padding: const EdgeInsets.fromLTRB(22, 26, 22, 22),
                children: [
                  const SizedBox(height: 10),
                  Row(children: [
                    Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(colors: [Color(0xFFC9A227), Color(0xFFE8CF7A)]),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Icon(Icons.bolt_rounded, size: 30, color: Color(0xFF101418)),
                    ),
                    const SizedBox(width: 12),
                    const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('Astra Telos', style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w800)),
                      Text('Nhắn tin nhanh cho mọi người', style: TextStyle(color: Colors.white70, fontSize: 13)),
                    ]),
                  ]),
                  const SizedBox(height: 24),
                  Card(
                    elevation: 12,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Đăng nhập', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
                          const SizedBox(height: 4),
                          const Text('Chào mừng bạn quay trở lại', style: TextStyle(color: Colors.black54)),
                          const SizedBox(height: 16),
                          TextField(
                            controller: phone,
                            keyboardType: TextInputType.phone,
                            decoration: const InputDecoration(
                              labelText: 'Số điện thoại',
                              hintText: 'VD: 0912345678',
                              prefixIcon: Icon(Icons.smartphone_rounded),
                            ),
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            controller: pass,
                            obscureText: !showPass,
                            decoration: InputDecoration(
                              labelText: 'Mật khẩu',
                              prefixIcon: const Icon(Icons.lock_rounded),
                              suffixIcon: IconButton(
                                icon: Icon(showPass ? Icons.visibility_off_rounded : Icons.visibility_rounded),
                                onPressed: () => setState(() => showPass = !showPass),
                              ),
                            ),
                            onSubmitted: (_) => _submit(),
                          ),
                          if (error != null) ...[
                            const SizedBox(height: 12),
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(color: const Color(0xFFFDECEA), borderRadius: BorderRadius.circular(12)),
                              child: Text(error!, style: const TextStyle(color: Color(0xFFB3261E))),
                            ),
                          ],
                          const SizedBox(height: 18),
                          GoldButton(label: 'Đăng nhập', busy: busy, onPressed: _submit),
                          const SizedBox(height: 8),
                          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                            const Text('Chưa có tài khoản?', style: TextStyle(color: Colors.black54)),
                            TextButton(
                              onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const RegisterScreen())),
                              child: const Text('Đăng ký ngay', style: TextStyle(fontWeight: FontWeight.w800)),
                            ),
                          ]),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
