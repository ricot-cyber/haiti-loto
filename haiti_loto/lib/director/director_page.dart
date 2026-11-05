import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../config.dart';
import '../vendor/report_page.dart';

class DirectorPage extends StatelessWidget {
  const DirectorPage({super.key});
  @override
  Widget build(BuildContext context) => DefaultTabController(
        length: 6,
        child: Scaffold(
          appBar: AppBar(
            title: const Text('DIREKTÈ'),
            actions: [IconButton(icon: const Icon(Icons.logout), onPressed: () => sb.auth.signOut())],
            bottom: const TabBar(isScrollable: true, tabs: [
              Tab(text: 'Vandè'),
              Tab(text: 'Blokaj'),
              Tab(text: 'Limit'),
              Tab(text: 'Rezilta'),
              Tab(text: 'Rapò'),
              Tab(text: 'Konfig'),
            ]),
          ),
          body: const TabBarView(children: [
            VendorsTab(),
            RuleTab(table: 'blocked_numbers', amount: false),
            RuleTab(table: 'number_limits', amount: true),
            ResultsTab(),
            ReportPage(director: true),
            ConfigTab(),
          ]),
        ),
      );
}

Future<List<Map<String, dynamic>>> _draws() async =>
    List<Map<String, dynamic>>.from(await sb.from('draws').select().order('close_time'));

// ---------------- VANDÈ ----------------
class VendorsTab extends StatefulWidget {
  const VendorsTab({super.key});
  @override
  State<VendorsTab> createState() => _VendorsTabState();
}

class _VendorsTabState extends State<VendorsTab> {
  List<Map<String, dynamic>> items = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final r = await sb.from('profiles').select().eq('role', 'vendor').order('created_at');
    if (mounted) setState(() => items = List<Map<String, dynamic>>.from(r));
  }

  Future<void> _create() async {
    final r = await askFields(context, 'Nouvo vandè', ['Username', 'Password (6+)', 'Non', 'Komisyon %'],
        initial: ['', '', '', '10'], kb: TextInputType.text);
    if (r == null) return;
    try {
      final res = await sb.functions.invoke('create-vendor', body: {
        'username': r[0],
        'password': r[1],
        'full_name': r[2],
        'commission_pct': double.tryParse(r[3]) ?? 10,
      });
      if (res.status != 200) throw Exception(res.data?['error'] ?? 'Erè');
      if (mounted) toast(context, 'Vandè kreye');
      _load();
    } catch (e) {
      if (mounted) toast(context, errMsg(e));
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        floatingActionButton: FloatingActionButton.extended(
            onPressed: _create, icon: const Icon(Icons.person_add), label: const Text('Vandè')),
        body: RefreshIndicator(
          onRefresh: _load,
          child: ListView(children: [
            for (final v in items)
              ListTile(
                title: Text('${v['username']}  •  ${v['full_name'] ?? ''}'),
                subtitle: Text(
                    'Komisyon ${v['commission_pct']}%  •  Aparèy: ${v['device_id'] ?? 'pa lye'}'),
                trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                  IconButton(
                    tooltip: 'Reyinisyalize aparèy',
                    icon: const Icon(Icons.phonelink_erase),
                    onPressed: () async {
                      await sb.from('profiles').update({'device_id': null}).eq('id', v['id']);
                      _load();
                    },
                  ),
                  Switch(
                    value: v['active'] == true,
                    onChanged: (x) async {
                      await sb.from('profiles').update({'active': x}).eq('id', v['id']);
                      _load();
                    },
                  ),
                ]),
              ),
          ]),
        ),
      );
}

// ------------- BLOKAJ / LIMIT -------------
class RuleTab extends StatefulWidget {
  final String table;
  final bool amount;
  const RuleTab({super.key, required this.table, required this.amount});
  @override
  State<RuleTab> createState() => _RuleTabState();
}

class _RuleTabState extends State<RuleTab> {
  List<Map<String, dynamic>> draws = [], items = [];
  int? drawId;
  String game = 'BOLET';
  final numC = TextEditingController();
  final amtC = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    draws = await _draws();
    if (widget.amount && drawId == null && draws.isNotEmpty) drawId = draws.first['id'] as int;
    final r = await sb.from(widget.table).select('*, draws(name)').order('id', ascending: false);
    if (mounted) setState(() => items = List<Map<String, dynamic>>.from(r));
  }

  Future<void> _add() async {
    final n = numC.text.trim();
    if (n.isEmpty) return;
    final row = <String, dynamic>{
      'director_id': sb.auth.currentUser!.id,
      'draw_id': drawId,
      'game': game,
      'number': n,
    };
    if (widget.amount) {
      final a = double.tryParse(amtC.text.replaceAll(',', '.'));
      if (a == null) return toast(context, 'Antre montan maksimòm lan');
      row['max_amount'] = a;
    }
    try {
      await sb.from(widget.table).insert(row);
      numC.clear();
      amtC.clear();
      _load();
    } catch (e) {
      if (mounted) toast(context, errMsg(e));
    }
  }

  @override
  Widget build(BuildContext context) => Column(children: [
        Padding(
          padding: const EdgeInsets.all(10),
          child: Column(children: [
            Row(children: [
              Expanded(
                child: DropdownButtonFormField<int?>(
                  value: drawId,
                  decoration: const InputDecoration(labelText: 'Tiraj', border: OutlineInputBorder()),
                  items: [
                    if (!widget.amount) const DropdownMenuItem<int?>(value: null, child: Text('Tout tiraj')),
                    for (final d in draws) DropdownMenuItem<int?>(value: d['id'] as int, child: Text(d['name'])),
                  ],
                  onChanged: (v) => setState(() => drawId = v),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: game,
                  decoration: const InputDecoration(labelText: 'Jwèt', border: OutlineInputBorder()),
                  items: [
                    for (final e in games.entries)
                      DropdownMenuItem(value: e.key, child: Text(e.value['label'] as String)),
                  ],
                  onChanged: (v) => setState(() => game = v!),
                ),
              ),
            ]),
            const SizedBox(height: 8),
            Row(children: [
              Expanded(
                child: TextField(
                  controller: numC,
                  decoration: const InputDecoration(
                      labelText: 'Nimero (Maryaj: 00-11)', border: OutlineInputBorder()),
                ),
              ),
              if (widget.amount) ...[
                const SizedBox(width: 8),
                SizedBox(
                  width: 110,
                  child: TextField(
                    controller: amtC,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Max G', border: OutlineInputBorder()),
                  ),
                ),
              ],
              const SizedBox(width: 8),
              FilledButton(onPressed: _add, child: const Icon(Icons.add)),
            ]),
          ]),
        ),
        const Divider(),
        Expanded(
          child: ListView(children: [
            for (final i in items)
              ListTile(
                title: Text(
                    '${games[i['game']]!['label']}  ${i['number']}${widget.amount ? '   max ${i['max_amount']}' : ''}'),
                subtitle: Text(i['draws']?['name'] ?? 'Tout tiraj'),
                trailing: IconButton(
                  icon: const Icon(Icons.delete, color: Colors.redAccent),
                  onPressed: () async {
                    await sb.from(widget.table).delete().eq('id', i['id']);
                    _load();
                  },
                ),
              ),
          ]),
        ),
      ]);
}

// ---------------- REZILTA ----------------
class ResultsTab extends StatefulWidget {
  const ResultsTab({super.key});
  @override
  State<ResultsTab> createState() => _ResultsTabState();
}

class _ResultsTabState extends State<ResultsTab> {
  List<Map<String, dynamic>> draws = [];
  int? drawId;
  DateTime date = DateTime.now();
  final keys = ['first', 'second', 'third', 'loto3', 'loto4', 'loto5'];
  final labels = ['1ye lo (2 chif)', '2yèm lo (2 chif)', '3yèm lo (2 chif)', 'Loto 3', 'Loto 4', 'Loto 5'];
  late final ctl = List.generate(6, (_) => TextEditingController());

  @override
  void initState() {
    super.initState();
    _draws().then((d) {
      if (mounted) {
        setState(() {
          draws = d;
          if (d.isNotEmpty) drawId = d.first['id'] as int;
        });
      }
    });
  }

  Future<void> _save() async {
    if (drawId == null) return;
    final row = <String, dynamic>{
      'draw_id': drawId,
      'draw_date': DateFormat('yyyy-MM-dd').format(date),
    };
    for (var i = 0; i < 6; i++) {
      row[keys[i]] = ctl[i].text.trim().isEmpty ? null : ctl[i].text.trim();
    }
    try {
      await sb.from('results').upsert(row, onConflict: 'draw_id,draw_date');
      if (mounted) toast(context, 'Rezilta anrejistre');
    } catch (e) {
      if (mounted) toast(context, errMsg(e));
    }
  }

  @override
  Widget build(BuildContext context) => ListView(padding: const EdgeInsets.all(14), children: [
        DropdownButtonFormField<int?>(
          value: drawId,
          decoration: const InputDecoration(labelText: 'Tiraj', border: OutlineInputBorder()),
          items: [for (final d in draws) DropdownMenuItem<int?>(value: d['id'] as int, child: Text(d['name']))],
          onChanged: (v) => setState(() => drawId = v),
        ),
        const SizedBox(height: 10),
        InkWell(
          onTap: () async {
            final d = await showDatePicker(
                context: context,
                initialDate: date,
                firstDate: DateTime(2024),
                lastDate: DateTime.now().add(const Duration(days: 1)));
            if (d != null) setState(() => date = d);
          },
          child: InputDecorator(
            decoration: const InputDecoration(labelText: 'Dat', border: OutlineInputBorder()),
            child: Text(DateFormat('yyyy-MM-dd').format(date)),
          ),
        ),
        for (var i = 0; i < 6; i++)
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: TextField(
              controller: ctl[i],
              keyboardType: TextInputType.number,
              decoration: InputDecoration(labelText: labels[i], border: const OutlineInputBorder()),
            ),
          ),
        const SizedBox(height: 14),
        SizedBox(height: 48, child: FilledButton(onPressed: _save, child: const Text('Anrejistre'))),
      ]);
}

// ---------------- KONFIG ----------------
class ConfigTab extends StatefulWidget {
  const ConfigTab({super.key});
  @override
  State<ConfigTab> createState() => _ConfigTabState();
}

class _ConfigTabState extends State<ConfigTab> {
  final bank = TextEditingController(), phone = TextEditingController(), cancel = TextEditingController(text: '5');

  @override
  void initState() {
    super.initState();
    sb.from('director_settings').select().maybeSingle().then((s) {
      if (s != null && mounted) {
        bank.text = s['bank_name'] ?? '';
        phone.text = s['support_phone'] ?? '';
        cancel.text = '${s['cancel_minutes'] ?? 5}';
      }
    });
  }

  Future<void> _save() async {
    try {
      await sb.from('director_settings').upsert({
        'director_id': sb.auth.currentUser!.id,
        'bank_name': bank.text.trim(),
        'support_phone': phone.text.trim(),
        'cancel_minutes': int.tryParse(cancel.text) ?? 5,
      });
      if (mounted) toast(context, 'Anrejistre');
    } catch (e) {
      if (mounted) toast(context, errMsg(e));
    }
  }

  @override
  Widget build(BuildContext context) => ListView(padding: const EdgeInsets.all(14), children: [
        TextField(controller: bank, decoration: const InputDecoration(labelText: 'Non bank', border: OutlineInputBorder())),
        const SizedBox(height: 10),
        TextField(controller: phone, decoration: const InputDecoration(labelText: 'Telefòn sipò (+509...)', border: OutlineInputBorder())),
        const SizedBox(height: 10),
        TextField(
            controller: cancel,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'Delè pou anile fich (minit)', border: OutlineInputBorder())),
        const SizedBox(height: 14),
        SizedBox(height: 48, child: FilledButton(onPressed: _save, child: const Text('Anrejistre'))),
      ]);
}
