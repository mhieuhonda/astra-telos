import 'dart:io';
import 'package:mime/mime.dart';
import 'package:path/path.dart' as p;
import 'package:shelf/shelf.dart';

class LocalStorage {
  final String root;
  LocalStorage(this.root) {
    Directory(root).createSync(recursive: true);
  }

  Response handler(Request request) {
    final rel = request.url.path.replaceFirst('files/', '');
    final file = File(p.join(root, rel));
    final absRoot = p.normalize(Directory(root).absolute.path);
    final absFile = p.normalize(file.absolute.path);
    if (!absFile.startsWith(absRoot) || !file.existsSync()) {
      return Response.notFound('Không tìm thấy tệp');
    }
    final type = lookupMimeType(file.path) ?? 'application/octet-stream';
    return Response.ok(file.openRead(), headers: {'Content-Type': type});
  }

  Future<String> save(String name, List<int> bytes) async {
    final safe = name.replaceAll(RegExp(r'[^\w.\- ]'), '_');
    final key = '${DateTime.now().millisecondsSinceEpoch}_$safe';
    final file = File(p.join(root, key));
    await file.writeAsBytes(bytes);
    return '/files/$key';
  }
}
