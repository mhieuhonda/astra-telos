import 'dart:convert';
import 'dart:io';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:shelf_router/shelf_router.dart';
import 'package:astra_telos_server/database.dart';
import 'package:astra_telos_server/auth.dart';
import 'package:astra_telos_server/api.dart';
import 'package:astra_telos_server/realtime.dart';
import 'package:astra_telos_server/storage.dart';

Future<void> main(List<String> args) async {
  final port = int.tryParse(Platform.environment['ASTRA_PORT'] ?? '8085') ?? 8085;
  final dir = Directory(Directory.current.path);
  final dataDir = Directory('${dir.path}/data');
  final db = AppDatabase('${dataDir.path}/astra.db');
  final store = LocalStorage('${dataDir.path}/files');
  final auth = AuthService(db);
  final hub = RealtimeHub(db, auth);
  final api = ApiRoutes(db, auth, hub, store);

  final router = Router()
    ..mount('/api/', api.router.call)
    ..get('/ws', hub.upgrade)
    ..get('/files/<path|.*>', store.handler)
    ..get('/health', (_) => Response.ok(jsonEncode({'ok': true, 'app': 'astra-telos'})));

  final handler = const Pipeline()
      .addMiddleware(logRequests())
      .addMiddleware(cors())
      .addHandler(router.call);

  final server = await shelf_io.serve(handler, InternetAddress.anyIPv4, port);
  stdout.writeln('Astra Telos server: http://${server.address.host}:$port');
  stdout.writeln('Database: ${dataDir.path}/astra.db');
  stdout.writeln('Storage: ${dataDir.path}/files');
}

Middleware cors() {
  return (inner) {
    return (request) async {
      if (request.method == 'OPTIONS') {
        return Response.ok('', headers: _headers);
      }
      final res = await inner(request);
      return res.change(headers: {...res.headers, ..._headers});
    };
  };
}

const _headers = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Methods': 'GET, POST, PUT, DELETE, OPTIONS',
  'Access-Control-Allow-Headers': 'Content-Type, Authorization',
};
