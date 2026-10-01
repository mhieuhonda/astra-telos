import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

class Cloud {
  static const baseUrl = 'https://vector-principle-behavior-compare.trycloudflare.com';
}

class Session {
  static String? token;
  static Map<String, dynamic>? user;

  static Future<void> load() async {
    final p = await SharedPreferences.getInstance();
    token = p.getString('token');
    final u = p.getString('user');
    user = u == null ? null : jsonDecode(u) as Map<String, dynamic>;
  }

  static Future<void> save(String t, Map<String, dynamic> u) async {
    final p = await SharedPreferences.getInstance();
    token = t;
    user = u;
    await p.setString('token', t);
    await p.setString('user', jsonEncode(u));
  }

  static Future<void> clear() async {
    final p = await SharedPreferences.getInstance();
    token = null;
    user = null;
    await p.remove('token');
    await p.remove('user');
  }
}

class Api {
  static Map<String, String> get headers => {
        'Content-Type': 'application/json',
        if (Session.token != null) 'Authorization': 'Bearer ${Session.token}',
      };

  static Future<Map<String, dynamic>> post(String path, Map<String, dynamic> body) async {
    final r = await http
        .post(Uri.parse('${Cloud.baseUrl}$path'), headers: headers, body: jsonEncode(body))
        .timeout(const Duration(seconds: 20));
    return _decode(r.body);
  }

  static Future<Map<String, dynamic>> put(String path, Map<String, dynamic> body) async {
    final r = await http
        .put(Uri.parse('${Cloud.baseUrl}$path'), headers: headers, body: jsonEncode(body))
        .timeout(const Duration(seconds: 20));
    return _decode(r.body);
  }

  static Future<Map<String, dynamic>> get(String path) async {
    final r = await http
        .get(Uri.parse('${Cloud.baseUrl}$path'), headers: headers)
        .timeout(const Duration(seconds: 20));
    return _decode(r.body);
  }

  static Map<String, dynamic> _decode(String body) {
    return jsonDecode(body) as Map<String, dynamic>;
  }
}

class SocketBus {
  static final SocketBus _i = SocketBus._();
  factory SocketBus() => _i;
  SocketBus._();
  WebSocketChannel? _ch;
  final _ctl = StreamController<Map<String, dynamic>>.broadcast();
  Stream<Map<String, dynamic>> get stream => _ctl.stream;
  Timer? _timer;

  void connect() {
    close();
    if (Session.token == null) return;
    final ws = Cloud.baseUrl.replaceFirst('https', 'wss').replaceFirst('http', 'ws');
    _ch = WebSocketChannel.connect(Uri.parse('$ws/ws?token=${Session.token}'));
    _ch!.stream.listen((e) {
      try {
        _ctl.add(jsonDecode(e as String) as Map<String, dynamic>);
      } catch (_) {}
    }, onDone: _retry, onError: (_) => _retry());
    _timer = Timer.periodic(const Duration(seconds: 25), (_) {
      try {
        _ch?.sink.add(jsonEncode({'type': 'ping'}));
      } catch (_) {}
    });
  }

  void _retry() {
    Future.delayed(const Duration(seconds: 3), () {
      if (Session.token != null) connect();
    });
  }

  void typing(String convId) {
    try {
      _ch?.sink.add(jsonEncode({'type': 'typing', 'convId': convId}));
    } catch (_) {}
  }

  void close() {
    _timer?.cancel();
    try {
      _ch?.sink.close();
    } catch (_) {}
    _ch = null;
  }
}
