import 'dart:async';
import 'package:flutter/material.dart';
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
    super.dispose();
  }

  Future<void> _load({bool silent = false}) async {
    if (!silent) setState(() => loading = true);
    try {
      final res = await Api.get('/api/conversations');
      if (res['ok'] == true) {
        setState(() => items = res['data'] as List);
      }
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

  Future<void> _openWith(String peerId) async {
    final res = await Api.post('/api/conversations', {'peerId': peerId});
    if (res['ok'] == true) {
      final id = (res['data'] as Map)['id'];
      if (!mounted) return;
      await Navigator.of(context).push(MaterialPageRoute(builder: (_) => ChatScreen(convId: '$id')));
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

  @override
  Widget build(BuildContext context) {
    final me = Session.user ?? {};
    return Scaffold(
      appBar: AppBar(
        title: const Text('ASTRA TELOS'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout_rounded),
            tooltip: 'Đăng xuất',
            onPressed: () async {
              await Session.clear();
              SocketBus().close();
              if (!context.mounted) return;
              Navigator.of(context).pushAndRemoveUntil(MaterialPageRoute(builder: (_) => const LoginScreen()), (_) => false);
            },
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AstraTheme.gold,
        foregroundColor: AstraTheme.ink,
        onPressed: () => _newChatSheet(),
        icon: const Icon(Icons.add_comment_rounded),
        label: const Text('Nhắn mới', style: TextStyle(fontWeight: FontWeight.w800)),
      ),
      body: Column(
        children: [
          Container(
            color: const Color(0xFF101418),
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
            child: TextField(
              controller: searchCtl,
              onChanged: _search,
              decoration: InputDecoration(
                hintText: 'Tìm người dùng theo tên hoặc tài khoản...',
                prefixIcon: const Icon(Icons.search_rounded),
                suffixIcon: searching ? const Padding(padding: EdgeInsets.all(12), child: SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))) : null,
              ),
            ),
          ),
          if (searchCtl.text.trim().isNotEmpty)
            SizedBox(
              height: 72,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                itemCount: found.length,
                itemBuilder: (_, i) {
                  final u = found[i] as Map;
                  return GestureDetector(
                    onTap: () => _openWith('${u['id']}'),
                    child: Container(
                      margin: const EdgeInsets.only(right: 8),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: AstraTheme.gold.withValues(alpha: .5))),
                      child: Row(
                        children: [
                          CircleAvatar(backgroundColor: AstraTheme.ink, foregroundColor: AstraTheme.goldSoft, child: Text('${u['name']}'.isEmpty ? '?' : '${u['name']}'.substring(0, 1).toUpperCase())),
                          const SizedBox(width: 8),
                          Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                            Text('${u['name']}', style: const TextStyle(fontWeight: FontWeight.w700)),
                            Text('@${u['handle']}', style: const TextStyle(color: Colors.black54, fontSize: 12)),
                          ]),
                        ],
                      ),
                    ),
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
                          SizedBox(height: 80),
                          Icon(Icons.forum_rounded, size: 72, color: Colors.black26),
                          SizedBox(height: 12),
                          Text('Chưa có cuộc trò chuyện nào\nNhấn "Nhắn mới" để bắt đầu', textAlign: TextAlign.center, style: TextStyle(color: Colors.black54, fontSize: 15)),
                        ])
                      : ListView.separated(
                          padding: const EdgeInsets.all(12),
                          itemCount: items.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 8),
                          itemBuilder: (_, i) {
                            final c = Map<String, dynamic>.from(items[i] as Map);
                            final unread = (c['unread'] ?? 0) as int;
                            return InkWell(
                              borderRadius: BorderRadius.circular(18),
                              onTap: () async {
                                await Navigator.of(context).push(MaterialPageRoute(builder: (_) => ChatScreen(convId: '${c['id']}', title: _title(c))));
                                _load(silent: true);
                              },
                              child: Ink(
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(color: Theme.of(context).cardColor, borderRadius: BorderRadius.circular(18), boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: .05), blurRadius: 12, offset: const Offset(0, 4))]),
                                child: Row(
                                  children: [
                                    CircleAvatar(
                                      radius: 26,
                                      backgroundColor: AstraTheme.ink,
                                      foregroundColor: AstraTheme.goldSoft,
                                      child: Text(_title(c).isEmpty ? '?' : _title(c).substring(0, 1).toUpperCase(), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 20)),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                        Row(children: [
                                          Expanded(child: Text(_title(c), maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15))),
                                          if (unread > 0)
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                              decoration: BoxDecoration(color: AstraTheme.gold, borderRadius: BorderRadius.circular(99)),
                                              child: Text('$unread', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12)),
                                            ),
                                        ]),
                                        const SizedBox(height: 4),
                                        Text('${c['last_body'] ?? 'Bắt đầu trò chuyện'}', maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: unread > 0 ? Colors.black87 : Colors.black54, fontWeight: unread > 0 ? FontWeight.w700 : FontWeight.normal)),
                                      ]),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(color: Theme.of(context).cardColor, border: Border(top: BorderSide(color: Colors.black.withValues(alpha: .06)))),
            child: Row(children: [
              const CircleAvatar(backgroundColor: AstraTheme.gold, foregroundColor: AstraTheme.ink, child: Icon(Icons.person_rounded)),
              const SizedBox(width: 10),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('${me['name'] ?? ''}', style: const TextStyle(fontWeight: FontWeight.w800)),
                Text('@${me['handle'] ?? ''}', style: const TextStyle(color: Colors.black54, fontSize: 12)),
              ])),
              const Icon(Icons.verified_rounded, color: AstraTheme.gold),
            ]),
          ),
        ],
      ),
    );
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
              const Text('Cuộc trò chuyện mới', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
              const SizedBox(height: 10),
              TextField(
                controller: ctl,
                autofocus: true,
                decoration: const InputDecoration(hintText: 'Nhập tên hoặc tài khoản...', prefixIcon: Icon(Icons.search_rounded)),
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
                      leading: CircleAvatar(backgroundColor: AstraTheme.ink, foregroundColor: AstraTheme.goldSoft, child: Text('${u['name']}'.substring(0, 1).toUpperCase())),
                      title: Text('${u['name']}', style: const TextStyle(fontWeight: FontWeight.w700)),
                      subtitle: Text('@${u['handle']}'),
                      trailing: const Icon(Icons.chat_bubble_rounded, color: AstraTheme.gold),
                      onTap: () {
                        Navigator.of(ctx).pop();
                        _openWith('${u['id']}');
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
}
