import 'dart:async';
import 'package:bcrypt/bcrypt.dart';
import 'package:dart_jsonwebtoken/dart_jsonwebtoken.dart';
import 'package:uuid/uuid.dart';
import 'database.dart';

class AuthService {
  final AppDatabase store;
  final SecretKey _key;
  AuthService(this.store)
      : _key = SecretKey(_loadSecret());

  static String _loadSecret() {
    final env = const bool.hasEnvironment('ASTRA_JWT')
        ? const String.fromEnvironment('ASTRA_JWT')
        : '';
    return env.isEmpty ? 'astra-telos-dev-secret-change-me' : env;
  }

  Future<({bool ok, String message, Map<String, dynamic>? user, String? token})>
      register(String name, String handle, String password) async {
    name = name.trim();
    handle = handle.trim().toLowerCase();
    if (name.isEmpty || handle.length < 3 || password.length < 6) {
      return (ok: false, message: 'Thông tin chưa hợp lệ', user: null, token: null);
    }
    if (!RegExp(r'^[a-z0-9_.]+$').hasMatch(handle)) {
      return (ok: false, message: 'Tên tài khoản chỉ gồm chữ, số, _ và .', user: null, token: null);
    }
    final exists = store.db.select('SELECT id FROM users WHERE handle=?', [handle]);
    if (exists.isNotEmpty) {
      return (ok: false, message: 'Tên tài khoản đã được sử dụng', user: null, token: null);
    }
    final id = const Uuid().v4();
    final now = DateTime.now().millisecondsSinceEpoch;
    final hash = BCrypt.hashpw(password, BCrypt.gensalt());
    store.db.execute(
      'INSERT INTO users(id,name,handle,pass_hash,created_at,last_seen) VALUES(?,?,?,?,?,?)',
      [id, name, handle, hash, now, now],
    );
    final user = _public(id);
    return (ok: true, message: 'Đăng ký thành công', user: user, token: issue(id));
  }

  Future<({bool ok, String message, Map<String, dynamic>? user, String? token})>
      login(String handle, String password) async {
    handle = handle.trim().toLowerCase();
    final rows = store.db.select('SELECT * FROM users WHERE handle=?', [handle]);
    if (rows.isEmpty) {
      return (ok: false, message: 'Tài khoản không tồn tại', user: null, token: null);
    }
    final row = rows.first;
    if (!BCrypt.checkpw(password, row['pass_hash'] as String)) {
      return (ok: false, message: 'Mật khẩu chưa đúng', user: null, token: null);
    }
    final now = DateTime.now().millisecondsSinceEpoch;
    store.db.execute('UPDATE users SET last_seen=? WHERE id=?', [now, row['id']]);
    return (ok: true, message: 'Đăng nhập thành công', user: _public(row['id'] as String), token: issue(row['id'] as String));
  }

  String issue(String userId) {
    final jwt = JWT({'uid': userId}, issuer: 'astra-telos');
    return jwt.sign(_key, expiresIn: const Duration(days: 30));
  }

  String? verify(String? header) {
    if (header == null || !header.startsWith('Bearer ')) return null;
    try {
      final jwt = JWT.verify(header.substring(7), _key);
      return jwt.payload['uid'] as String?;
    } catch (_) {
      return null;
    }
  }

  Map<String, dynamic>? _public(String id) {
    final rows = store.db.select(
      'SELECT id,name,handle,avatar,status,last_seen,created_at FROM users WHERE id=?',
      [id],
    );
    if (rows.isEmpty) return null;
    final r = rows.first;
    return {
      'id': r['id'],
      'name': r['name'],
      'handle': r['handle'],
      'avatar': r['avatar'],
      'status': r['status'],
      'lastSeen': r['last_seen'],
      'createdAt': r['created_at'],
    };
  }

  Map<String, dynamic>? publicOf(String id) => _public(id);
}
