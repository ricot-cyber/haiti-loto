import 'dart:async';
import 'package:flutter/material.dart';
import '../config.dart';
import 'play_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});
  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  List<Map<String, dynamic>> draws = [];
  Timer? t;

  @override
  void initState() {
    super.initState();
    _load();
    t = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    t?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    final r = await sb.from('draws').select().eq('active', true).order('close_time');
    if (mounted) setState(() => draws = List<Map<String, dynamic>>.from(r));
  }

  String _left(Map<String, dynamic> d) {
    var c = closeToday(d['close_time'] as String);
    if (c.isBefore(DateTime.now())) c = c.add(const Duration(days: 1));
    final x = c.difference(DateTime.now());
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(x.inHours)}:${two(x.inMinutes % 60)}:${two(x.inSeconds % 60)}';
  }

  @override
  Widget build(BuildContext context) => ListView(padding: const EdgeInsets.all(12), children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: kCard, borderRadius: BorderRadius.circular(10)),
          child: Column(children: [
            const Row(children: [
              Expanded(child: Text('PWOCHEN TIRAJ', style: TextStyle(fontSize: 12))),
              Text('HRS  MIN  SEC', style: TextStyle(fontSize: 12)),
            ]),
            for (final d in draws)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Row(children: [
                  Expanded(
                      child: Text(d['name'],
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600))),
                  Text(_left(d), style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                ]),
              ),
          ]),
        ),
        const SizedBox(height: 24),
        for (final e in games.entries)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: SizedBox(
              height: 62,
              child: FilledButton(
                style: FilledButton.styleFrom(
                    backgroundColor: e.value['color'] as Color,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4))),
                onPressed: () => Navigator.push(
                    context, MaterialPageRoute(builder: (_) => PlayPage(game: e.key))),
                child: Text(e.value['label'] as String,
                    style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
              ),
            ),
          ),
      ]);
}
