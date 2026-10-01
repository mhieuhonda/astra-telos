import 'dart:convert';
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';
import 'database.dart';
import 'auth.dart';
import 'realtime.dart';
import 'storage.dart';

class ApiRoutes {
  final AppDatabase store;
  final AuthService auth;
  final RealtimeHub hub;
  final LocalStorage files;
  ApiRoutes(this.store, this.auth, this.hub, this.files);

  Router get router {
    final r = Router();
    r.post('/auth/register', _register);
    r.post('/auth/login', _login);
    r.get('/me', _me);
    r.put('/me', _updateMe);
    r.get('/users/search', _search);
    r.get('/conversations', _convs);
    r.post('/conversations', _createConv);
    r.get('/conversations/<id>/messages', _messages);
    r.post('/conversations/<id>/messages', _send);
    r.post('/conversations/<id>/seen', _seen);
    r.post('/upload', _upload);
    return r;
  }

  Future<Response> _body(Request req, Future<Response> Function(Map<String, dynamic>) run) async {
    try {
      final data = jsonDecode(await req.readAsString()) as Map<String, dynamic>;
      return await run(data);
    } catch (_) {
      return _err('Dữ liệu không hợp lệ');
    }
  }

  String? _uid(Request req) => auth.verify(req.headers['authorization']);

  Response _ok(Object data) => Response.ok(
        jsonEncode({'ok': true, 'data': data}),
        headers: {'Content-Type': 'application/json'},
      );

  Response _err(String message, [int code = 400]) => Response(
        code,
        body: jsonEncode({'ok': false, 'message': message}),
        headers: {'Content-Type': 'application/json'},
      );

  Future<Response> _register(Request req) => _body(req, (b) async {
        final res = await auth.register(
          '${b['name'] ?? ''}', '${b['handle'] ?? ''}', '${b['password'] ?? ''}');
        if (!res.ok) return _err(res.message);
        return _ok({'user': res.user ?? {}, 'token': res.token ?? ''});
      });

  Future<Response> _login(Request req) => _body(req, (b) async {
        final res = await auth.login('${b['handle'] ?? ''}', '${b['password'] ?? ''}');
        if (!res.ok) return _err(res.message, 401);
        return _ok({'user': res.user ?? {}, 'token': res.token ?? ''});
      });

  Future<Response> _me(Request req) async {
    final uid = _uid(req);
    if (uid == null) return _err('Chưa đăng nhập', 401);
    return _ok(auth.publicOf(uid) ?? {});
  }

  Future<Response> _updateMe(Request req) => _body(req, (b) async {
        final uid = _uid(req);
        if (uid == null) return _err('Chưa đăng nhập', 401);
        store.db.execute(
          'UPDATE users SET name=?, status=?, avatar=? WHERE id=?',
          ['${b['name'] ?? ''}', '${b['status'] ?? ''}', '${b['avatar'] ?? ''}', uid],
        );
        return _ok(auth.publicOf(uid) ?? {});
      });

  Future<Response> _search(Request req) async {
    final uid = _uid(req);
    if (uid == null) return _err('Chưa đăng nhập', 401);
    final q = (req.url.queryParameters['q'] ?? '').trim();
    if (q.isEmpty) return _ok([]);
    final rows = store.db.select(
      'SELECT id,name,handle,avatar,status FROM users WHERE handle LIKE ? OR name LIKE ? LIMIT 20',
      ['%$q%', '%$q%'],
    );
    return _ok(rows.where((e) => e['id'] != uid).toList());
  }

  Future<Response> _convs(Request req) async {
    final uid = _uid(req);
    if (uid == null) return _err('Chưa đăng nhập', 401);
    final rows = store.db.select('''
      SELECT c.id, c.title, c.kind,
        (SELECT body FROM messages WHERE conv_id=c.id ORDER BY created_at DESC LIMIT 1) AS last_body,
        (SELECT created_at FROM messages WHERE conv_id=c.id ORDER BY created_at DESC LIMIT 1) AS last_at,
        (SELECT COUNT(*) FROM messages WHERE conv_id=c.id AND instr(seen_by, ?) = 0 AND sender_id != ?) AS unread
      FROM conversations c JOIN members m ON m.conv_id=c.id
      WHERE m.user_id=? ORDER BY COALESCE(last_at, 0) DESC
    ''', ['"$uid"', uid, uid]);
    final out = <Map<String, dynamic>>[];
    for (final c in rows) {
      final peers = store.db.select(
        'SELECT u.id,u.name,u.handle,u.avatar FROM members m JOIN users u ON u.id=m.user_id WHERE m.conv_id=? AND m.user_id!=?',
        [c['id'], uid],
      );
      out.add({...Map<String, dynamic>.from(c), 'peers': peers});
    }
    return _ok(out);
  }

  Future<Response> _createConv(Request req) => _body(req, (b) async {
        final uid = _uid(req);
        if (uid == null) return _err('Chưa đăng nhập', 401);
        final peer = '${b['peerId'] ?? ''}';
        final title = '${b['title'] ?? ''}';
        final ids = ((b['memberIds'] as List?) ?? []).map((e) => '$e').toSet()..add(uid);
        if (peer.isNotEmpty) ids.add(peer);
        if (ids.length < 2) return _err('Chọn ít nhất một người trò chuyện');
        if (ids.length == 2 && peer.isNotEmpty) {
          final old = store.db.select('''
            SELECT conv_id FROM members GROUP BY conv_id HAVING COUNT(*)=2
            AND SUM(user_id=?) = 1 AND SUM(user_id=?) = 1
          ''', [uid, peer]);
          if (old.isNotEmpty) {
            hub.refresh(uid);
            return _ok({'id': old.first['conv_id']});
          }
        }
        final id = newId();
        final now = DateTime.now().millisecondsSinceEpoch;
        store.db.execute('INSERT INTO conversations(id,title,kind,created_at) VALUES(?,?,?,?)',
            [id, title, ids.length > 2 ? 'group' : 'direct', now]);
        for (final m in ids) {
          store.db.execute('INSERT INTO members(conv_id,user_id,joined_at) VALUES(?,?,?)', [id, m, now]);
        }
        hub.refresh(uid);
        return _ok({'id': id});
      });

  Future<Response> _messages(Request req, String id) async {
    final uid = _uid(req);
    if (uid == null) return _err('Chưa đăng nhập', 401);
    if (!_isMember(id, uid)) return _err('Không có quyền', 403);
    final before = int.tryParse(req.url.queryParameters['before'] ?? '') ?? 0;
    final rows = store.db.select(
      before > 0
          ? 'SELECT * FROM messages WHERE conv_id=? AND created_at<? ORDER BY created_at DESC LIMIT 40'
          : 'SELECT * FROM messages WHERE conv_id=? ORDER BY created_at DESC LIMIT 40',
      before > 0 ? [id, before] : [id],
    );
    return _ok(rows.reversed.toList());
  }

  Future<Response> _send(Request req, String id) => _body(req, (b) async {
        final uid = _uid(req);
        if (uid == null) return _err('Chưa đăng nhập', 401);
        if (!_isMember(id, uid)) return _err('Không có quyền', 403);
        final body = '${b['body'] ?? ''}'.trim();
        final kind = '${b['kind'] ?? 'text'}';
        final fileUrl = '${b['fileUrl'] ?? ''}';
        if (body.isEmpty && fileUrl.isEmpty) return _err('Tin nhắn trống');
        final mid = newId();
        final now = DateTime.now().millisecondsSinceEpoch;
        store.db.execute(
          'INSERT INTO messages(id,conv_id,sender_id,body,kind,file_url,created_at,seen_by) VALUES(?,?,?,?,?,?,?,?)',
          [mid, id, uid, body, kind, fileUrl, now, '["$uid"]'],
        );
        final msg = {'id': mid, 'conv_id': id, 'sender_id': uid, 'body': body, 'kind': kind, 'file_url': fileUrl, 'created_at': now, 'seen_by': '["$uid"]'};
        hub.emit(id, {'type': 'message', 'convId': id, 'message': msg});
        return _ok(msg);
      });

  Future<Response> _seen(Request req, String id) async {
    final uid = _uid(req);
    if (uid == null) return _err('Chưa đăng nhập', 401);
    final rows = store.db.select('SELECT id,seen_by FROM messages WHERE conv_id=?', [id]);
    for (final r in rows) {
      final seen = List<String>.from(jsonDecode(r['seen_by'] as String));
      if (!seen.contains(uid)) {
        seen.add(uid);
        store.db.execute('UPDATE messages SET seen_by=? WHERE id=?', [jsonEncode(seen), r['id']]);
      }
    }
    hub.emit(id, {'type': 'seen', 'convId': id, 'uid': uid});
    return _ok(true);
  }

  Future<Response> _upload(Request req) async {
    final uid = _uid(req);
    if (uid == null) return _err('Chưa đăng nhập', 401);
    final name = req.headers['x-file-name'] ?? 'tep-dinh-kem';
    final bytes = await req.read().expand((e) => e).toList();
    if (bytes.isEmpty || bytes.length > 25 * 1024 * 1024) {
      return _err('Tệp trống hoặc vượt quá 25MB');
    }
    final url = await files.save(name, bytes);
    return _ok({'url': url});
  }

  bool _isMember(String convId, String uid) {
    return store.db
        .select('SELECT 1 FROM members WHERE conv_id=? AND user_id=?', [convId, uid])
        .isNotEmpty;
  }
}
