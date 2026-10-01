import 'dart:async';
import 'dart:convert';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import '../core.dart';
import '../theme.dart';

class ChatScreen extends StatefulWidget {
  final String convId;
  final String title;
  const ChatScreen({super.key, required this.convId, this.title = 'Trò chuyện'});
  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final ctl = TextEditingController();
  final scroll = ScrollController();
  List msgs = [];
  bool loading = true;
  bool sending = false;
  bool typing = false;
  Timer? typingTimer;
  StreamSubscription? sub;

  @override
  void initState() {
    super.initState();
    _load();
    sub = SocketBus().stream.listen((e) {
      if (e['convId'] != widget.convId) return;
      if (e['type'] == 'message') {
        setState(() => msgs.add(e['message']));
        _jump();
        Api.post('/api/conversations/${widget.convId}/seen', {});
      } else if (e['type'] == 'typing' && '${e['uid']}' != '${Session.user?['id']}') {
        setState(() => typing = true);
        typingTimer?.cancel();
        typingTimer = Timer(const Duration(seconds: 2), () {
          if (mounted) setState(() => typing = false);
        });
      }
    });
  }

  @override
  void dispose() {
    sub?.cancel();
    typingTimer?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final res = await Api.get('/api/conversations/${widget.convId}/messages');
      if (res['ok'] == true) setState(() => msgs = res['data'] as List);
      await Api.post('/api/conversations/${widget.convId}/seen', {});
    } catch (_) {}
    if (mounted) {
      setState(() => loading = false);
      _jump();
    }
  }

  void _jump() {
    Future.delayed(const Duration(milliseconds: 120), () {
      if (!scroll.hasClients) return;
      scroll.animateTo(scroll.position.maxScrollExtent, duration: const Duration(milliseconds: 260), curve: Curves.easeOutCubic);
    });
  }

  Future<void> _send() async {
    final text = ctl.text.trim();
    if (text.isEmpty || sending) return;
    setState(() => sending = true);
    ctl.clear();
    try {
      final res = await Api.post('/api/conversations/${widget.convId}/messages', {'body': text, 'kind': 'text'});
      if (res['ok'] == true) {
        setState(() => msgs.add(res['data']));
        _jump();
      } else {
        ctl.text = text;
      }
    } catch (_) {
      ctl.text = text;
    } finally {
      if (mounted) setState(() => sending = false);
    }
  }

  Future<void> _attach() async {
    final pick = await FilePicker.platform.pickFiles(withData: true);
    if (pick == null || pick.files.isEmpty) return;
    final f = pick.files.first;
    final bytes = f.bytes;
    if (bytes == null) return;
    final isImage = (f.extension ?? '').toLowerCase().contains(RegExp(r'png|jpg|jpeg|gif|webp'));
    final req = http.Request('POST', Uri.parse('${Cloud.baseUrl}/api/upload'));
    req.headers['Authorization'] = 'Bearer ${Session.token}';
    req.headers['X-File-Name'] = Uri.encodeComponent(f.name);
    req.bodyBytes = bytes;
    final streamed = await req.send();
    final body = await streamed.stream.bytesToString();
    final decoded = jsonDecode(body) as Map<String, dynamic>;
    if (decoded['ok'] == true) {
      final url = (decoded['data'] as Map)['url'] as String;
      await Api.post('/api/conversations/${widget.convId}/messages', {
        'body': f.name,
        'kind': isImage ? 'image' : 'file',
        'fileUrl': url,
      });
      _load();
    }
  }

  String _time(int ms) {
    return DateFormat('HH:mm').format(DateTime.fromMillisecondsSinceEpoch(ms));
  }

  @override
  Widget build(BuildContext context) {
    final myId = '${Session.user?['id']}';
    return Scaffold(
      appBar: AppBar(
        title: Column(children: [
          Text(widget.title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
          Text(typing ? 'Đang nhập...' : 'Trực tuyến', style: const TextStyle(fontSize: 12, color: Color(0xFFE8CF7A))),
        ]),
      ),
      body: Column(
        children: [
          Expanded(
            child: loading
                ? const Center(child: CircularProgressIndicator())
                : ListView.builder(
                    controller: scroll,
                    padding: const EdgeInsets.fromLTRB(12, 12, 12, 6),
                    itemCount: msgs.length,
                    itemBuilder: (_, i) {
                      final m = Map<String, dynamic>.from(msgs[i] as Map);
                      final mine = '${m['sender_id']}' == myId;
                      final kind = '${m['kind'] ?? 'text'}';
                      final fileUrl = '${m['file_url'] ?? ''}';
                      return Align(
                        alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
                        child: Container(
                          constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * .76),
                          margin: const EdgeInsets.symmetric(vertical: 4),
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          decoration: BoxDecoration(
                            gradient: mine ? const LinearGradient(colors: [Color(0xFF101418), Color(0xFF233246)]) : null,
                            color: mine ? null : Theme.of(context).cardColor,
                            borderRadius: BorderRadius.only(
                              topLeft: const Radius.circular(18),
                              topRight: const Radius.circular(18),
                              bottomLeft: Radius.circular(mine ? 18 : 4),
                              bottomRight: Radius.circular(mine ? 4 : 18),
                            ),
                            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: .06), blurRadius: 10, offset: const Offset(0, 3))],
                          ),
                          child: Column(
                            crossAxisAlignment: mine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                            children: [
                              if (kind == 'image' && fileUrl.isNotEmpty)
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(12),
                                  child: CachedNetworkImage(imageUrl: '${Cloud.baseUrl}$fileUrl', httpHeaders: {'Authorization': 'Bearer ${Session.token}'}, width: 220, fit: BoxFit.cover),
                                )
                              else if (kind == 'file' && fileUrl.isNotEmpty)
                                Row(mainAxisSize: MainAxisSize.min, children: [
                                  const Icon(Icons.insert_drive_file_rounded, color: AstraTheme.gold),
                                  const SizedBox(width: 8),
                                  Flexible(child: Text('${m['body']}', style: TextStyle(color: mine ? Colors.white : null, fontWeight: FontWeight.w600))),
                                ])
                              else
                                Text('${m['body']}', style: TextStyle(color: mine ? Colors.white : null, fontSize: 15, height: 1.35)),
                              const SizedBox(height: 4),
                              Text(_time((m['created_at'] ?? 0) as int), style: TextStyle(color: mine ? Colors.white60 : Colors.black45, fontSize: 11)),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
          SafeArea(
            child: Container(
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
              decoration: BoxDecoration(color: Theme.of(context).cardColor, border: Border(top: BorderSide(color: Colors.black.withValues(alpha: .06)))),
              child: Row(
                children: [
                  IconButton(onPressed: _attach, icon: const Icon(Icons.add_circle_rounded, color: AstraTheme.gold, size: 30)),
                  Expanded(
                    child: TextField(
                      controller: ctl,
                      minLines: 1,
                      maxLines: 4,
                      onChanged: (_) => SocketBus().typing(widget.convId),
                      onSubmitted: (_) => _send(),
                      decoration: const InputDecoration(hintText: 'Nhắn tin...', border: InputBorder.none, filled: false),
                    ),
                  ),
                  GestureDetector(
                    onTap: _send,
                    child: Container(
                      width: 46,
                      height: 46,
                      decoration: BoxDecoration(gradient: const LinearGradient(colors: [Color(0xFFC9A227), Color(0xFFE8CF7A)]), shape: BoxShape.circle, boxShadow: [BoxShadow(color: AstraTheme.gold.withValues(alpha: .4), blurRadius: 12)]),
                      child: sending
                          ? const Padding(padding: EdgeInsets.all(12), child: CircularProgressIndicator(strokeWidth: 2.4, color: Color(0xFF101418)))
                          : const Icon(Icons.send_rounded, color: Color(0xFF101418)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
