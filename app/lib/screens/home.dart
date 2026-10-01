import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../core.dart';
import '../theme.dart';
import 'chat.dart';
import 'login.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int tab = 0;
  List items = [];
  bool loading = true;
  StreamSubscription? sub;
  final searchCtl = TextEditingController();
  List found = [];
  bool searching = false;

  @override
  void initState() {
    super.initState();
    SocketBus().connect();
    _load();
    sub = SocketBus().stream.listen((e) {
      if (e['type'] == 'message' || e['type'] == 'seen') _load(silent: true);
    });
  }

  @override
  void dispose() {
    sub?.cancel();
    searchCtl.dispose();
    super.dispose();
  }

  Future<void> _load({bool silent = false}) async {
    if (!silent) setState(() => loading = true);
    try {
      final res = await Api.get('/api/conversations');
      if (res['ok'] == true) setState(() => items = res['data'] as List);
    } catch (_) {}
    if (mounted) setState(() => loading = false);
  }

  Future<void> _search(String q) async {
    if (q.trim().isEmpty) {
      setState(() {
        found = [];
        searching = false;
      });
      return;
    }
    setState(() => searching = true);
    try {
      final res = await Api.get('/api/users/search?q=${Uri.encodeComponent(q.trim())}');
      if (res['ok'] == true) setState(() => found = res['data'] as List);
    } catch (_) {}
    if (mounted) setState(() => searching = false);
  }

  Future<void> _openWith(String peerId, String name) async {
    final res = await Api.post('/api/conversations', {'peerId': peerId});
    if (res['ok'] == true) {
      final id = (res['data'] as Map)['id'];
      if (!mounted) return;
      await Navigator.of(context).push(MaterialPageRoute(builder: (_) => ChatScreen(convId: '$id', title: name)));
      _load(silent: true);
    }
  }

  String _title(Map c) {
    final t = '${c['title'] ?? ''}';
    if (t.isNotEmpty) return t;
    final peers = (c['peers'] as List?) ?? [];
    if (peers.isEmpty) return 'Cuộc trò chuyện';
    if (peers.length == 1) return '${peers.first['name']}';
    return peers.take(3).map((e) => '${e['name']}').join(', ');
  }

  String _time(int? ms) {
    if (ms == null || ms == 0) return '';
    final dt = DateTime.fromMillisecondsSinceEpoch(ms);
    final now = DateTime.now();
    if (now.difference(dt).inDays == 0) return DateFormat('HH:mm').format(dt);
    if (now.difference(dt).inDays < 7) return DateFormat('EEE').format(dt);
    return DateFormat('dd/MM').format(dt);
  }

  @override
  Widget build(BuildContext context) {
    final me = Session.user ?? {};
    return Scaffold(
      appBar: AppBar(
        title: Text(['Tin nhắn', 'Danh bạ', 'Hồ sơ'][tab]),
        actions: [
          if (tab == 0)
            IconButton(icon: const Icon(Icons.edit_square), tooltip: 'Tin nhắn mới', onPressed: _newChatSheet),
        ],
      ),
      body: [_chatsTab(), _contactsTab(), _profileTab(me)][tab],
      bottomNavigationBar: NavigationBar(
        selectedIndex: tab,
        onDestinationSelected: (i) => setState(() => tab = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.chat_bubble_rounded), selectedIcon: Icon(Icons.chat_bubble), label: 'Tin nhắn'),
          NavigationDestination(icon: Icon(Icons.contacts_rounded), selectedIcon: Icon(Icons.contacts), label: 'Danh bạ'),
          NavigationDestination(icon: Icon(Icons.person_rounded), selectedIcon: Icon(Icons.person), label: 'Hồ sơ'),
        ],
      ),
    );
  }

  Widget _chatsTab() {
    return Column(children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 6),
        child: TextField(
          controller: searchCtl,
          onChanged: _search,
          decoration: InputDecoration(
            hintText: 'Tìm kiếm',
            prefixIcon: const Icon(Icons.search_rounded),
            suffixIcon: searching
                ? const Padding(padding: EdgeInsets.all(12), child: SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)))
                : null,
          ),
        ),
      ),
      if (searchCtl.text.trim().isNotEmpty && found.isNotEmpty)
        SizedBox(
          height: 150,
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            itemCount: found.length,
            itemBuilder: (_, i) {
              final u = found[i] as Map;
              return ListTile(
                leading: _avatar('${u['name']}', 20),
                title: Text('${u['name']}', style: const TextStyle(fontWeight: FontWeight.w700)),
                subtitle: Text('${u['handle']}'),
                trailing: const Icon(Icons.chat_bubble_outline_rounded, color: AstraTheme.gold),
                onTap: () => _openWith('${u['id']}', '${u['name']}'),
              );
            },
          ),
        ),
      Expanded(
        child: RefreshIndicator(
          onRefresh: () => _load(),
          child: loading
              ? const Center(child: CircularProgressIndicator())
              : items.isEmpty
                  ? ListView(children: const [
                      SizedBox(height: 70),
                      Icon(Icons.forum_rounded, size: 72, color: Colors.black26),
                      SizedBox(height: 12),
                      Text('Chưa có tin nhắn nào\nNhấn biểu tượng soạn tin để bắt đầu', textAlign: TextAlign.center, style: TextStyle(color: Colors.black54, fontSize: 15)),
                    ])
                  : ListView.separated(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      itemCount: items.length,
                      separatorBuilder: (_, __) => const Divider(height: 1, indent: 78),
                      itemBuilder: (_, i) {
                        final c = Map<String, dynamic>.from(items[i] as Map);
                        final unread = (c['unread'] ?? 0) as int;
                        return ListTile(
                          leading: _avatar(_title(c), 26),
                          title: Row(children: [
                            Expanded(child: Text(_title(c), maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700))),
                            Text(_time(c['last_at'] as int?), style: const TextStyle(color: Colors.black45, fontSize: 12)),
                          ]),
                          subtitle: Row(children: [
                            Expanded(child: Text('${c['last_body'] ?? 'Bắt đầu trò chuyện'}', maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: unread > 0 ? Colors.black87 : Colors.black54, fontWeight: unread > 0 ? FontWeight.w700 : FontWeight.normal))),
                            if (unread > 0)
                              Container(
                                margin: const EdgeInsets.only(left: 8),
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(color: AstraTheme.gold, borderRadius: BorderRadius.circular(99)),
                                child: Text('$unread', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12)),
                              ),
                          ]),
                          onTap: () async {
                            await Navigator.of(context).push(MaterialPageRoute(builder: (_) => ChatScreen(convId: '${c['id']}', title: _title(c))));
                            _load(silent: true);
                          },
                        );
                      },
                    ),
        ),
      ),
    ]);
  }

  Widget _contactsTab() {
    final peers = <Map<String, dynamic>>[];
    for (final c in items) {
      for (final p in ((c as Map)['peers'] as List?) ?? []) {
        if (!peers.any((e) => '${e['id']}' == '${(p as Map)['id']}')) {
          peers.add(Map<String, dynamic>.from(p as Map));
        }
      }
    }
    peers.addAll(found.map((e) => Map<String, dynamic>.from(e as Map)).where((e) => !peers.any((p) => '${p['id']}' == '${e['id']}')));
    if (peers.isEmpty) {
      return const Center(child: Text('Tìm bạn bè bằng số điện thoại\nở ô tìm kiếm bên Tin nhắn', textAlign: TextAlign.center, style: TextStyle(color: Colors.black54)));
    }
    return ListView.separated(
      itemCount: peers.length,
      separatorBuilder: (_, __) => const Divider(height: 1, indent: 78),
      itemBuilder: (_, i) {
        final u = peers[i];
        return ListTile(
          leading: _avatar('${u['name']}', 24),
          title: Text('${u['name']}', style: const TextStyle(fontWeight: FontWeight.w700)),
          subtitle: Text('${u['handle']}'),
          trailing: IconButton(icon: const Icon(Icons.chat_bubble_outline_rounded, color: AstraTheme.gold), onPressed: () => _openWith('${u['id']}', '${u['name']}')),
          onTap: () => _openWith('${u['id']}', '${u['name']}'),
        );
      },
    );
  }

  Widget _profileTab(Map me) {
    return ListView(padding: const EdgeInsets.all(18), children: [
      Center(
        child: Column(children: [
          _avatar('${me['name'] ?? '?'}', 44),
          const SizedBox(height: 12),
          Text('${me['name'] ?? ''}', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
          Text('${me['handle'] ?? ''}', style: const TextStyle(color: Colors.black54, fontSize: 15)),
          const SizedBox(height: 4),
          Text('${me['status'] ?? ''}', style: const TextStyle(color: Colors.black45, fontSize: 13)),
        ]),
      ),
      const SizedBox(height: 20),
      Card(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        child: Column(children: [
          ListTile(
            leading: const Icon(Icons.edit_rounded, color: AstraTheme.gold),
            title: const Text('Đổi tên hiển thị'),
            onTap: () => _editProfile(me),
          ),
          const Divider(height: 1, indent: 56),
          ListTile(
            leading: const Icon(Icons.logout_rounded, color: Colors.redAccent),
            title: const Text('Đăng xuất', style: TextStyle(color: Colors.redAccent)),
            onTap: () async {
              final nav = Navigator.of(context);
              await Session.clear();
              SocketBus().close();
              nav.pushAndRemoveUntil(MaterialPageRoute(builder: (_) => const LoginScreen()), (_) => false);
            },
          ),
        ]),
      ),
      const SizedBox(height: 12),
      const Text('Astra Telos v1.0.0 · Kết nối đám mây bảo mật', textAlign: TextAlign.center, style: TextStyle(color: Colors.black38, fontSize: 12)),
    ]);
  }

  Widget _avatar(String name, double r) {
    final ch = name.trim().isEmpty ? '?' : name.trim().substring(0, 1).toUpperCase();
    return CircleAvatar(radius: r, backgroundColor: AstraTheme.ink, foregroundColor: AstraTheme.goldSoft, child: Text(ch, style: TextStyle(fontWeight: FontWeight.w800, fontSize: r * .8)));
  }

  void _newChatSheet() {
    final ctl = TextEditingController();
    List results = [];
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => StatefulBuilder(builder: (ctx, setS) {
        return Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom, left: 18, right: 18, top: 18),
          child: SizedBox(
            height: 420,
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Tin nhắn mới', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
              const SizedBox(height: 4),
              const Text('Nhập số điện thoại hoặc tên bạn bè', style: TextStyle(color: Colors.black54)),
              const SizedBox(height: 10),
              TextField(
                controller: ctl,
                autofocus: true,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(hintText: 'VD: 0912345678', prefixIcon: Icon(Icons.search_rounded)),
                onChanged: (v) async {
                  final res = await Api.get('/api/users/search?q=${Uri.encodeComponent(v.trim())}');
                  if (res['ok'] == true) setS(() => results = res['data'] as List);
                },
              ),
              const SizedBox(height: 10),
              Expanded(
                child: ListView.builder(
                  itemCount: results.length,
                  itemBuilder: (_, i) {
                    final u = results[i] as Map;
                    return ListTile(
                      leading: _avatar('${u['name']}', 20),
                      title: Text('${u['name']}', style: const TextStyle(fontWeight: FontWeight.w700)),
                      subtitle: Text('${u['handle']}'),
                      trailing: const Icon(Icons.chat_bubble_rounded, color: AstraTheme.gold),
                      onTap: () {
                        Navigator.of(ctx).pop();
                        _openWith('${u['id']}', '${u['name']}');
                      },
                    );
                  },
                ),
              ),
            ]),
          ),
        );
      }),
    );
  }

  void _editProfile(Map me) {
    final nameCtl = TextEditingController(text: '${me['name'] ?? ''}');
    final statusCtl = TextEditingController(text: '${me['status'] ?? ''}');
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Đổi thông tin'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: nameCtl, decoration: const InputDecoration(labelText: 'Tên hiển thị')),
          const SizedBox(height: 10),
          TextField(controller: statusCtl, decoration: const InputDecoration(labelText: 'Trạng thái')),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Hủy')),
          FilledButton(
            onPressed: () async {
              final res = await Api.put('/api/me', {'name': nameCtl.text.trim(), 'status': statusCtl.text.trim(), 'avatar': ''});
              if (res['ok'] == true && Session.token != null) {
                await Session.save(Session.token!, Map<String, dynamic>.from(res['data'] as Map));
                if (context.mounted) setState(() {});
              }
              if (ctx.mounted) Navigator.of(ctx).pop();
            },
            child: const Text('Lưu'),
          ),
        ],
      ),
    );
  }
}
