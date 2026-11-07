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
  DateTime fetched = DateTime.now();
  DateTime lastTry = DateTime.fromMillisecondsSinceEpoch(0);
  Timer? t;

  @override
  void initState() {
    super.initState();
    _load();
    t = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() {});
      if (draws.any((d) => _secs(d) <= 0) &&
          DateTime.now().difference(lastTry).inSeconds > 5) {
        _load();
      }
    });
  }

  @override
  void dispose() {
    t?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    lastTry = DateTime.now();
    try {
      final d = await loadDraws();
      if (mounted) {
        setState(() {
          draws = d;
          fetched = DateTime.now();
        });
      }
    } catch (_) {}
  }

  int _secs(Map<String, dynamic> d) =>
      (d['secs_left'] as num).toInt() - DateTime.now().difference(fetched).inSeconds;

  String _left(Map<String, dynamic> d) {
    var s = _secs(d);
    if (s < 0) s = 0;
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(s ~/ 3600)}:${two((s ~/ 60) % 60)}:${two(s % 60)}';
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
            for (final d in draws.take(3))
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
