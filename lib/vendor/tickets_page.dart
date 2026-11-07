import 'package:flutter/material.dart';
import '../config.dart';
import 'play_page.dart';
import 'print_page.dart';

class TicketsPage extends StatefulWidget {
  const TicketsPage({super.key});
  @override
  State<TicketsPage> createState() => _TicketsPageState();
}

class _TicketsPageState extends State<TicketsPage> {
  List<Map<String, dynamic>> items = [];
  bool loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final r = await sb
        .from('tickets')
        .select('*, draws(name), ticket_lines(*)')
        .order('created_at', ascending: false)
        .limit(50);
    if (mounted) {
      setState(() {
        items = List<Map<String, dynamic>>.from(r);
        loading = false;
      });
    }
  }

  void _replay(Map<String, dynamic> t) {
    final ls = (t['ticket_lines'] as List)
        .map((l) => Line(l['game'], l['number'], (l['amount'] as num).toDouble()))
        .toList();
    Navigator.push(context, MaterialPageRoute(builder: (_) => PlayPage(initial: ls)));
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Fiche mwen yo')),
        body: loading
            ? const Center(child: CircularProgressIndicator())
            : RefreshIndicator(
                onRefresh: _load,
                child: ListView(children: [
                  for (final t in items)
                    ListTile(
                      title: Text('${t['public_id']}'),
                      subtitle: Text('${t['draws']['name']} • ${ThermalPrinter.dtFmt(t['created_at'])}'),
                      leading: Icon(t['status'] == 'cancelled' ? Icons.cancel : Icons.receipt,
                          color: t['status'] == 'cancelled' ? Colors.redAccent : kGreen),
                      trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                        Text('${money(t['total'] as num)} $cur'),
                        PopupMenuButton<String>(
                          onSelected: (v) => v == 'print'
                              ? Navigator.push(context,
                                  MaterialPageRoute(builder: (_) => PrintPage(ids: [t['id'] as int])))
                              : _replay(t),
                          itemBuilder: (_) => const [
                            PopupMenuItem(value: 'print', child: Text('Enprime ankò')),
                            PopupMenuItem(value: 'replay', child: Text('Rejwe')),
                          ],
                        ),
                      ]),
                    ),
                  if (items.isEmpty) const Padding(padding: EdgeInsets.all(24), child: Center(child: Text('Pa gen fich'))),
                ]),
              ),
      );
}

class CancelPage extends StatefulWidget {
  const CancelPage({super.key});
  @override
  State<CancelPage> createState() => _CancelPageState();
}

class _CancelPageState extends State<CancelPage> {
  final c = TextEditingController();
  Map<String, dynamic>? t;
  bool searched = false;

  Future<void> _search() async {
    final r = await sb
        .from('tickets')
        .select('*, draws(name)')
        .eq('public_id', c.text.trim())
        .maybeSingle();
    setState(() {
      t = r;
      searched = true;
    });
  }

  Future<void> _cancel() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (d) => AlertDialog(
        title: const Text('Anile fich sa a ?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(d, false), child: const Text('Non')),
          FilledButton(onPressed: () => Navigator.pop(d, true), child: const Text('Wi, anile')),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await sb.rpc('cancel_ticket_by_public', params: {'p_public': t!['public_id']});
      if (mounted) toast(context, 'Fich anile');
      await _search();
    } catch (e) {
      if (mounted) toast(context, errMsg(e));
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Anile fich')),
        body: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(children: [
            TextField(
              controller: c,
              onSubmitted: (_) => _search(),
              decoration: InputDecoration(
                filled: true,
                fillColor: Colors.white,
                prefixIcon: const Icon(Icons.search),
                hintText: 'ID fich la',
                hintStyle: const TextStyle(color: Colors.black54),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(20)),
              ),
              style: const TextStyle(color: Colors.black),
            ),
            const SizedBox(height: 14),
            if (searched && t == null) const Text('Fich pa jwenn'),
            if (t != null)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(color: kCard, borderRadius: BorderRadius.circular(8)),
                child: Column(children: [
                  Text('ID: ${t!['public_id']}', style: const TextStyle(color: kBlue)),
                  const SizedBox(height: 8),
                  Text('${t!['draws']['name']}'),
                  Text('DATE : ${ThermalPrinter.dtFmt(t!['created_at'])}',
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                  Text('MIZ : ${money(t!['total'] as num)} $cur',
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 10),
                  if (t!['status'] == 'cancelled')
                    const Text('DEJA ANILE', style: TextStyle(color: Colors.redAccent))
                  else
                    SizedBox(
                      width: double.infinity,
                      height: 46,
                      child: FilledButton(
                          style: FilledButton.styleFrom(backgroundColor: Colors.redAccent),
                          onPressed: _cancel,
                          child: const Text('Anile')),
                    ),
                ]),
              ),
          ]),
        ),
      );
}
