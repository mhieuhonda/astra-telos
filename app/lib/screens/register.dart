import 'package:flutter/material.dart';
import '../core.dart';
import '../theme.dart';
import 'home.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});
  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final name = TextEditingController();
  final handle = TextEditingController();
  final pass = TextEditingController();
  final confirm = TextEditingController();
  bool busy = false;
  String? error;

  Future<void> _submit() async {
    if (pass.text != confirm.text) {
      setState(() => error = 'Mật khẩu nhập lại chưa khớp');
      return;
    }
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final res = await Api.post('/api/auth/register', {
        'name': name.text.trim(),
        'handle': handle.text.trim(),
        'password': pass.text,
      });
      if (res['ok'] == true) {
        final d = res['data'] as Map<String, dynamic>;
        await Session.save(Session.baseUrl, d['token'] as String, Map<String, dynamic>.from(d['user']));
        if (!mounted) return;
        Navigator.of(context).pushAndRemoveUntil(MaterialPageRoute(builder: (_) => const HomeScreen()), (_) => false);
      } else {
        setState(() => error = '${res['message'] ?? 'Đăng ký thất bại'}');
      }
    } catch (_) {
      setState(() => error = 'Không kết nối được máy chủ');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Tạo tài khoản Astra')),
      body: AstraBackground(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 430),
            child: ListView(
              padding: const EdgeInsets.all(22),
              children: [
                Card(
                  elevation: 12,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      children: [
                        const Text('Gia nhập Astra Telos', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
                        const SizedBox(height: 4),
                        const Text('Tên tài khoản viết thường, không dấu', style: TextStyle(color: Colors.black54)),
                        const SizedBox(height: 16),
                        TextField(controller: name, decoration: const InputDecoration(labelText: 'Tên hiển thị', prefixIcon: Icon(Icons.person_rounded))),
                        const SizedBox(height: 12),
                        TextField(controller: handle, decoration: const InputDecoration(labelText: 'Tên tài khoản', prefixIcon: Icon(Icons.alternate_email_rounded), hintText: 'vidu: anhtu_2000')),
                        const SizedBox(height: 12),
                        TextField(controller: pass, obscureText: true, decoration: const InputDecoration(labelText: 'Mật khẩu (tối thiểu 6 ký tự)', prefixIcon: Icon(Icons.lock_rounded))),
                        const SizedBox(height: 12),
                        TextField(controller: confirm, obscureText: true, decoration: const InputDecoration(labelText: 'Nhập lại mật khẩu', prefixIcon: Icon(Icons.verified_rounded)), onSubmitted: (_) => _submit()),
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
                        GoldButton(label: 'Đăng ký', busy: busy, onPressed: _submit),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
