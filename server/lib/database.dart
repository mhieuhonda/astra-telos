import 'dart:io';
import 'package:sqlite3/sqlite3.dart';

class AppDatabase {
  final Database db;
  AppDatabase(String path) : db = _open(path) {
    db.execute('PRAGMA journal_mode=WAL;');
    db.execute('PRAGMA synchronous=NORMAL;');
    _migrate();
  }

  static Database _open(String path) {
    final file = File(path);
    file.parent.createSync(recursive: true);
    return sqlite3.open(path);
  }

  void _migrate() {
    db.execute('''
      CREATE TABLE IF NOT EXISTS users(
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        handle TEXT NOT NULL UNIQUE,
        pass_hash TEXT NOT NULL,
        avatar TEXT DEFAULT '',
        status TEXT DEFAULT 'Xin chào, tôi đang dùng Astra Telos',
        last_seen INTEGER DEFAULT 0,
        created_at INTEGER NOT NULL
      );
    ''');
    db.execute('''
      CREATE TABLE IF NOT EXISTS conversations(
        id TEXT PRIMARY KEY,
        title TEXT DEFAULT '',
        kind TEXT DEFAULT 'direct',
        created_at INTEGER NOT NULL
      );
    ''');
    db.execute('''
      CREATE TABLE IF NOT EXISTS members(
        conv_id TEXT NOT NULL,
        user_id TEXT NOT NULL,
        joined_at INTEGER NOT NULL,
        PRIMARY KEY(conv_id, user_id)
      );
    ''');
    db.execute('''
      CREATE TABLE IF NOT EXISTS messages(
        id TEXT PRIMARY KEY,
        conv_id TEXT NOT NULL,
        sender_id TEXT NOT NULL,
        body TEXT DEFAULT '',
        kind TEXT DEFAULT 'text',
        file_url TEXT DEFAULT '',
        created_at INTEGER NOT NULL,
        seen_by TEXT DEFAULT '[]'
      );
    ''');
    db.execute('CREATE INDEX IF NOT EXISTS idx_msg_conv ON messages(conv_id, created_at);');
    db.execute('CREATE INDEX IF NOT EXISTS idx_member_user ON members(user_id);');
  }
}
