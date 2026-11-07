import 'package:flutter/material.dart';
import '../config.dart';
import 'play_page.dart';

class ChooseDrawPage extends StatefulWidget {
  final List<Line> lines;
  const ChooseDrawPage({super.key, required this.lines});
  @override
  State<ChooseDrawPage> createState() => _ChooseDrawPageState();
}

class _ChooseDrawPageState extends State<ChooseDrawPage> {
  List<Map<String, dynamic>> draws = [];
  final sel = <int>{};
  bool loading = true, busy = false;

  double get lineTotal => widget.lines.fold(0.0, (s, l) => s + l.amount);

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    List<Map<String, dynamic>> r = [];
    try {
      r = await loadDraws();
    } catch (e) {
      if (mounted) toast(context, errMsg(e));
    }
    if (mounted) {
      setState(() {
        draws = r;
        loading = false;
      });
    }
  }

  String _n(double v) => v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(1);

  Future<void> _confirm() async {
    if (sel.isEmpty) return toast(context, 'Chwazi omwen yon tiraj');
    setState(() => busy = true);
    final ids = <int>[];
    String? err;
    for (final d in draws.where((d) => sel.contains(d['id']))) {
      try {
        final t = await sb.rpc('place_ticket', params: {
          'p_draw_id': d['id'],
          'p_lines': widget.lines.map((l) => l.toJson()).toList(),
        });
        ids.add((t as num).toInt());
      } catch (e) {
        err = errMsg(e);
        break;
      }
    }
    if (!mounted) return;
    setState(() => busy = false);
    if (err != null) toast(context, err);
    if (ids.isNotEmpty) Navigator.pop(context, ids);
  }

  @override
  Widget build(BuildContext context) {
    final chosen = draws.where((d) => sel.contains(d['id'])).toList();
    final groups = <String, List<Line>>{};
    for (final l in widget.lines) {
      groups.putIfAbsent(l.game, () => []).add(l);
    }
    return Scaffold(
      body: SafeArea(
        child: loading
            ? const Center(child: CircularProgressIndicator())
            : Column(children: [
                SizedBox(
                  height: 74,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.all(6),
                    children: [
                      for (final d in draws)
                        Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(8),
                            onTap: () {
                              if (!(d['is_open'] == true)) return toast(context, 'Tiraj sa a fèmen');
                              setState(() => sel.contains(d['id']) ? sel.remove(d['id']) : sel.add(d['id'] as int));
                            },
                            child: Container(
                              width: 150,
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                              decoration: BoxDecoration(
                                color: sel.contains(d['id']) ? kBlue : kCard,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Opacity(
                                opacity: (d['is_open'] == true) ? 1 : 0.35,
                                child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                                  Text(d['name'],
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                                  Text(hm(d['close_local'] as String),
                                      style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w600)),
                                ]),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                Expanded(
                  child: ListView(padding: const EdgeInsets.all(14), children: [
                    if (chosen.isEmpty)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 20),
                        child: Center(
                            child: Text('Peze sou youn oswa plizyè tiraj pou chwazi yo',
                                style: TextStyle(fontStyle: FontStyle.italic))),
                      ),
                    for (final d in chosen)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Row(children: [
                          Text(d['name'], style: const TextStyle(fontSize: 16, fontStyle: FontStyle.italic)),
                          const Spacer(),
                          Text(_n(lineTotal), style: const TextStyle(fontSize: 16, fontStyle: FontStyle.italic)),
                        ]),
                      ),
                    const SizedBox(height: 10),
                    for (final g in groups.entries) ...[
                      Text(games[g.key]!['label'] as String == 'BÒLÈT' ? 'Bòlèt' : games[g.key]!['label'] as String,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      const SizedBox(height: 6),
                      for (final l in g.value)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Row(children: [
                            SizedBox(
                              width: 90,
                              child: Row(children: [
                                for (final p in l.number.split('-')) ball(p, games[g.key]!['color'] as Color)
                              ]),
                            ),
                            Expanded(child: Center(child: Text(money(l.amount), style: const TextStyle(fontSize: 16)))),
                          ]),
                        ),
                      const SizedBox(height: 8),
                    ],
                    Container(
                      margin: const EdgeInsets.only(top: 8),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(color: kDark, borderRadius: BorderRadius.circular(8)),
                      child: Row(children: [
                        const Text('Total', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                        const Spacer(),
                        Text(money(lineTotal * chosen.length),
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      ]),
                    ),
                  ]),
                ),
                Padding(
                  padding: const EdgeInsets.all(10),
                  child: Row(children: [
                    Expanded(
                      flex: 3,
                      child: SizedBox(
                        height: 52,
                        child: FilledButton(
                          style: FilledButton.styleFrom(backgroundColor: kGreen),
                          onPressed: busy ? null : _confirm,
                          child: busy
                              ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2))
                              : const Text('Konfime', style: TextStyle(fontSize: 18)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      flex: 1,
                      child: SizedBox(
                        height: 52,
                        child: FilledButton(
                          style: FilledButton.styleFrom(backgroundColor: const Color(0xFFE5575B), padding: EdgeInsets.zero),
                          onPressed: busy ? null : () => Navigator.pop(context),
                          child: const Text('Anile', style: TextStyle(fontSize: 16)),
                        ),
                      ),
                    ),
                  ]),
                ),
              ]),
      ),
    );
  }
}
