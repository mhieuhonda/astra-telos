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
  final server = TextEditingController(text: 'http://127.0.0.1:8085');
  final handle = TextEditingController();
  final pass = TextEditingController();
  bool busy = false;
  String? error;

  @override
  void initState() {
    super.initState();
    server.text = Session.baseUrl;
    if (Session.token != null && Session.user != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const HomeScreen()));
      });
    }
  }

  Future<void> _submit() async {
    setState(() {
      busy = true;
      error = null;
    });
    try {
      Session.baseUrl = server.text.trim().replaceAll(RegExp(r'/$'), '');
      final res = await Api.post('/api/auth/login', {'handle': handle.text.trim(), 'password': pass.text});
      if (res['ok'] == true) {
        final d = res['data'] as Map<String, dynamic>;
        await Session.save(Session.baseUrl, d['token'] as String, Map<String, dynamic>.from(d['user']));
        if (!mounted) return;
        Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const HomeScreen()));
      } else {
        setState(() => error = '${res['message'] ?? 'Đăng nhập thất bại'}');
      }
    } catch (_) {
      setState(() => error = 'Không kết nối được máy chủ. Kiểm tra địa chỉ server.');
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
                  const Text('Chào mừng trở lại', style: TextStyle(color: Colors.white, fontSize: 30, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 6),
                  const Text('Đăng nhập để tiếp tục trò chuyện trên Astra Telos', style: TextStyle(color: Colors.white70)),
                  const SizedBox(height: 22),
                  Card(
                    elevation: 12,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        children: [
                          TextField(controller: server, decoration: const InputDecoration(labelText: 'Địa chỉ máy chủ', prefixIcon: Icon(Icons.dns_rounded), hintText: 'http://127.0.0.1:8085')),
                          const SizedBox(height: 12),
                          TextField(controller: handle, decoration: const InputDecoration(labelText: 'Tên tài khoản', prefixIcon: Icon(Icons.alternate_email_rounded))),
                          const SizedBox(height: 12),
                          TextField(controller: pass, obscureText: true, decoration: const InputDecoration(labelText: 'Mật khẩu', prefixIcon: Icon(Icons.lock_rounded)), onSubmitted: (_) => _submit()),
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
                          TextButton(
                            onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const RegisterScreen())),
                            child: const Text('Chưa có tài khoản? Đăng ký ngay'),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  const Text('Máy chủ chạy trên máy tính của bạn · Dữ liệu lưu cục bộ an toàn', textAlign: TextAlign.center, style: TextStyle(color: Colors.black54, fontSize: 12)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
