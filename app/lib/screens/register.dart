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
  final phone = TextEditingController();
  final pass = TextEditingController();
  final confirm = TextEditingController();
  bool busy = false;
  bool showPass = false;
  String? error;

  String _handle() {
    var p = phone.text.trim().replaceAll(RegExp(r'[\s\-.]'), '');
    if (p.startsWith('+84')) p = '0${p.substring(3)}';
    return p;
  }

  bool _validPhone(String p) => RegExp(r'^0\d{9}$').hasMatch(p);

  Future<void> _submit() async {
    final h = _handle();
    if (name.text.trim().isEmpty) {
      setState(() => error = 'Vui lòng nhập tên của bạn');
      return;
    }
    if (!_validPhone(h)) {
      setState(() => error = 'Số điện thoại chưa đúng (VD: 0912345678)');
      return;
    }
    if (pass.text.length < 6) {
      setState(() => error = 'Mật khẩu phải từ 6 ký tự trở lên');
      return;
    }
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
        'handle': h,
        'password': pass.text,
      });
      if (res['ok'] == true) {
        final d = res['data'] as Map<String, dynamic>;
        await Session.save(d['token'] as String, Map<String, dynamic>.from(d['user']));
        if (!mounted) return;
        Navigator.of(context).pushAndRemoveUntil(MaterialPageRoute(builder: (_) => const HomeScreen()), (_) => false);
      } else {
        setState(() => error = '${res['message'] ?? 'Đăng ký thất bại'}');
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
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Gia nhập Astra Telos', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
                        const SizedBox(height: 4),
                        const Text('Miễn phí, chỉ mất 30 giây', style: TextStyle(color: Colors.black54)),
                        const SizedBox(height: 16),
                        TextField(controller: name, textCapitalization: TextCapitalization.words, decoration: const InputDecoration(labelText: 'Tên của bạn', hintText: 'VD: Nguyễn An', prefixIcon: Icon(Icons.person_rounded))),
                        const SizedBox(height: 12),
                        TextField(controller: phone, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: 'Số điện thoại', hintText: 'VD: 0912345678', prefixIcon: Icon(Icons.smartphone_rounded))),
                        const SizedBox(height: 12),
                        TextField(
                          controller: pass,
                          obscureText: !showPass,
                          decoration: InputDecoration(
                            labelText: 'Mật khẩu (từ 6 ký tự)',
                            prefixIcon: const Icon(Icons.lock_rounded),
                            suffixIcon: IconButton(
                              icon: Icon(showPass ? Icons.visibility_off_rounded : Icons.visibility_rounded),
                              onPressed: () => setState(() => showPass = !showPass),
                            ),
                          ),
                        ),
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
                        GoldButton(label: 'Tạo tài khoản', busy: busy, onPressed: _submit),
                        const SizedBox(height: 8),
                        const Text(
                          'Khi đăng ký, bạn đồng ý với Điều khoản sử dụng của Astra Telos.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.black45, fontSize: 12),
                        ),
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
