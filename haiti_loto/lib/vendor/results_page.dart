import 'package:flutter/material.dart';
import '../config.dart';

class ResultsPage extends StatefulWidget {
  const ResultsPage({super.key});
  @override
  State<ResultsPage> createState() => _ResultsPageState();
}

class _ResultsPageState extends State<ResultsPage> {
  Future<List<Map<String, dynamic>>> _load() async {
    final r = await sb
        .from('results')
        .select('*, draws(name)')
        .order('draw_date', ascending: false)
        .limit(30);
    return List<Map<String, dynamic>>.from(r);
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<List<Map<String, dynamic>>>(
        future: _load(),
        builder: (c, s) {
          if (!s.hasData) return const Center(child: CircularProgressIndicator());
          if (s.data!.isEmpty) return const Center(child: Text('Pa gen rezilta ankò'));
          return ListView(padding: const EdgeInsets.all(12), children: [
            for (final r in s.data!)
              Card(
                color: kCard,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('${r['draws']['name']} • ${r['draw_date']}',
                        style: const TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Row(children: [
                      for (final k in ['first', 'second', 'third'])
                        if (r[k] != null) ball(r[k], kGreen),
                    ]),
                    const SizedBox(height: 6),
                    Text('3 chif: ${r['loto3'] ?? '-'}   4 chif: ${r['loto4'] ?? '-'}   5 chif: ${r['loto5'] ?? '-'}'),
                  ]),
                ),
              ),
          ]);
        },
      );
}
