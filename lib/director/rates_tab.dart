import 'package:flutter/material.dart';
import '../config.dart';

// ---------------- PRI (to peman) ----------------
class RatesTab extends StatefulWidget {
  const RatesTab({super.key});
  @override
  State<RatesTab> createState() => _RatesTabState();
}

class _RatesTabState extends State<RatesTab> {
  static const items = [
    {'game': 'BOLET', 'pos': 1, 'label': 'Bòlèt - 1ye lo', 'def': '50'},
    {'game': 'BOLET', 'pos': 2, 'label': 'Bòlèt - 2yèm lo', 'def': '20'},
    {'game': 'BOLET', 'pos': 3, 'label': 'Bòlèt - 3yèm lo', 'def': '10'},
    {'game': 'MARYAJ', 'pos': 1, 'label': 'Maryaj', 'def': '500'},
    {'game': 'LOTO3', 'pos': 1, 'label': '3 Chif', 'def': '750'},
    {'game': 'LOTO4', 'pos': 1, 'label': '4 Chif', 'def': '5000'},
    {'game': 'LOTO5', 'pos': 1, 'label': '5 Chif', 'def': '0'},
  ];
  late final ctl = [for (final i in items) TextEditingController(text: i['def'] as String)];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final r = await sb.from('payout_rates').select().eq('director_id', sb.auth.currentUser!.id);
    for (final row in r) {
      final i = items.indexWhere((x) => x['game'] == row['game'] && x['pos'] == row['pos']);
      if (i >= 0) ctl[i].text = '${row['multiplier']}'.replaceAll(RegExp(r'\.0+$'), '');
    }
    if (mounted) setState(() {});
  }

  Future<void> _save() async {
    final rows = <Map<String, dynamic>>[];
    for (var i = 0; i < items.length; i++) {
      final v = double.tryParse(ctl[i].text.replaceAll(',', '.'));
      if (v == null || v < 0) return toast(context, 'Pri pa valid: ${items[i]['label']}');
      rows.add({
        'director_id': sb.auth.currentUser!.id,
        'game': items[i]['game'],
        'pos': items[i]['pos'],
        'multiplier': v,
      });
    }
    try {
      await sb.from('payout_rates').upsert(rows, onConflict: 'director_id,game,pos');
      if (mounted) toast(context, 'Pri yo anrejistre');
    } catch (e) {
      if (mounted) toast(context, errMsg(e));
    }
  }

  @override
  Widget build(BuildContext context) => ListView(padding: const EdgeInsets.all(14), children: [
        Text('Pou chak 1 $cur ki mize, vandè a peye:',
            style: const TextStyle(fontStyle: FontStyle.italic)),
        for (var i = 0; i < items.length; i++)
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: TextField(
              controller: ctl[i],
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                  labelText: items[i]['label'] as String,
                  suffixText: '$cur',
                  border: const OutlineInputBorder()),
            ),
          ),
        const SizedBox(height: 14),
        SizedBox(height: 48, child: FilledButton(onPressed: _save, child: const Text('Anrejistre'))),
      ]);
}

// ---------------- TIRAJ (lè) ----------------
class DrawsTab extends StatefulWidget {
  const DrawsTab({super.key});
  @override
  State<DrawsTab> createState() => _DrawsTabState();
}

class _DrawsTabState extends State<DrawsTab> {
  List<Map<String, dynamic>> draws = [];
  Map<int, Map<String, dynamic>> today = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final r = await sb.from('draws').select().order('draw_time');
    Map<int, Map<String, dynamic>> t = {};
    try {
      for (final d in await loadDraws()) {
        t[d['id'] as int] = d;
      }
    } catch (_) {}
    if (mounted) {
      setState(() {
        draws = List<Map<String, dynamic>>.from(r);
        today = t;
      });
    }
  }

  Future<void> _edit(Map<String, dynamic> d) async {
    final r = await askFields(
      context,
      d['name'],
      ['Lè tiraj (HH:MM, lè Etazini ET)', 'Fèmen avan (minit)'],
      initial: [(d['draw_time'] as String).substring(0, 5), '${d['close_before_minutes']}'],
      kb: TextInputType.text,
    );
    if (r == null) return;
    if (!RegExp(r'^\d{1,2}:\d{2}$').hasMatch(r[0])) return toast(context, 'Lè a dwe tankou 12:29');
    try {
      await sb.from('draws').update({
        'draw_time': r[0],
        'close_before_minutes': int.tryParse(r[1]) ?? 10,
      }).eq('id', d['id']);
      _load();
    } catch (e) {
      if (mounted) toast(context, errMsg(e));
    }
  }

  @override
  Widget build(BuildContext context) => RefreshIndicator(
        onRefresh: _load,
        child: ListView(children: [
          const Padding(
            padding: EdgeInsets.all(12),
            child: Text(
                'Lè tiraj yo antre nan lè Etazini (ET). App la konvèti yo otomatikman an lè Brezil, '
                'menm lè Etazini chanje pou ete/ivè.',
                style: TextStyle(fontStyle: FontStyle.italic)),
          ),
          for (final d in draws)
            ListTile(
              title: Text(d['name']),
              subtitle: Text(
                  'Tiraj ${(d['draw_time'] as String).substring(0, 5)} ET  •  fèmen ${d['close_before_minutes']} min avan'
                  '${today[d['id']] != null ? '\nBrezil: tiraj ${hm(today[d['id']]!['draw_local'])}, fèmen ${hm(today[d['id']]!['close_local'])}' : ''}'),
              isThreeLine: today[d['id']] != null,
              trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                IconButton(icon: const Icon(Icons.edit), onPressed: () => _edit(d)),
                Switch(
                  value: d['active'] == true,
                  onChanged: (x) async {
                    await sb.from('draws').update({'active': x}).eq('id', d['id']);
                    _load();
                  },
                ),
              ]),
            ),
        ]),
      );
}
