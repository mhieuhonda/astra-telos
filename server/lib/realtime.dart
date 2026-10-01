import 'dart:convert';
import 'package:shelf/shelf.dart';
import 'package:shelf_web_socket/shelf_web_socket.dart';
import 'package:uuid/uuid.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'database.dart';
import 'auth.dart';

class RealtimeHub {
  final AppDatabase store;
  final AuthService auth;
  final Map<String, Set<WebSocketChannel>> _rooms = {};
  final Map<WebSocketChannel, String> _owners = {};
  RealtimeHub(this.store, this.auth);

  Handler get upgrade => _guarded;

  Future<Response> _guarded(Request request) async {
    final token = request.url.queryParameters['token'] ?? '';
    final uid = auth.verify('Bearer $token');
    if (uid == null) return Response.forbidden('Token không hợp lệ');
    return _ws(request, uid);
  }

  Future<Response> _ws(Request request, String uid) async {
    return webSocketHandler((WebSocketChannel socket, String? protocol) {
      _owners[socket] = uid;
      for (final c in _convsOf(uid)) {
        _rooms.putIfAbsent(c, () => {}).add(socket);
      }
      touch(uid);
      socket.stream.listen(
        (data) => _onMessage(socket, uid, data),
        onDone: () => _leave(socket),
        onError: (_) => _leave(socket),
        cancelOnError: true,
      );
      socket.sink.add(jsonEncode({'type': 'hello', 'uid': uid}));
    })(request);
  }

  List<String> _convsOf(String uid) {
    return store.db
        .select('SELECT conv_id FROM members WHERE user_id=?', [uid])
        .map((e) => e['conv_id'] as String)
        .toList();
  }

  void touch(String uid) {
    store.db.execute('UPDATE users SET last_seen=? WHERE id=?',
        [DateTime.now().millisecondsSinceEpoch, uid]);
  }

  void refresh(String uid) {
    for (final set in _rooms.values) {
      set.removeWhere((s) => _owners[s] == uid);
    }
    final owner = _owners.entries.where((e) => e.value == uid).map((e) => e.key);
    for (final s in owner) {
      for (final c in _convsOf(uid)) {
        _rooms.putIfAbsent(c, () => {}).add(s);
      }
    }
  }

  void emit(String convId, Map<String, dynamic> event) {
    final data = jsonEncode(event);
    for (final s in _rooms[convId] ?? <WebSocketChannel>{}) {
      try {
        s.sink.add(data);
      } catch (_) {}
    }
  }

  void _onMessage(WebSocketChannel socket, String uid, dynamic data) {
    try {
      final msg = jsonDecode(data as String) as Map<String, dynamic>;
      if (msg['type'] == 'ping') {
        socket.sink.add(jsonEncode({'type': 'pong'}));
        touch(uid);
      } else if (msg['type'] == 'typing') {
        emit(msg['convId'] as String, {'type': 'typing', 'convId': msg['convId'], 'uid': uid});
      }
    } catch (_) {}
  }

  void _leave(WebSocketChannel socket) {
    _owners.remove(socket);
    for (final set in _rooms.values) {
      set.remove(socket);
    }
  }
}

String newId() => const Uuid().v4();
