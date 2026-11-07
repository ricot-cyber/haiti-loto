import 'package:flutter/material.dart';
import '../config.dart';
import 'choose_draw_page.dart';
import 'print_page.dart';

class Line {
  String game;
  String number;
  double amount;
  Line(this.game, this.number, this.amount);
  Map<String, dynamic> toJson() => {'game': game, 'number': number, 'amount': amount};
}

class PlayPage extends StatefulWidget {
  final String game;
  final List<Line>? initial;
  const PlayPage({super.key, this.game = 'BOLET', this.initial});
  @override
  State<PlayPage> createState() => _PlayPageState();
}

class _PlayPageState extends State<PlayPage> {
  late String game;
  final numC = TextEditingController();
  final kobC = TextEditingController();
  final numF = FocusNode();
  final kobF = FocusNode();
  List<Line> lines = [];

  @override
  void initState() {
    super.initState();
    game = widget.game;
    lines = List.of(widget.initial ?? []);
  }

  double get total => lines.fold(0.0, (s, l) => s + l.amount);
  int get digits => games[game]!['digits'] as int;
  List<String> get _bolets =>
      lines.where((l) => l.game == 'BOLET').map((l) => l.number).toSet().toList();

  void _add() {
    var n = numC.text.trim();
    final a = double.tryParse(kobC.text.replaceAll(',', '.')) ?? 0;
    if (game == 'BOLET' && n.length == 1) n = '0$n';
    if (n.length != digits || int.tryParse(n) == null) {
      toast(context, 'Nimewo a dwe gen $digits chif');
      return;
    }
    if (a <= 0) {
      toast(context, 'Antre kòb la');
      return;
    }
    if (game == 'MARYAJ') n = '${n.substring(0, 2)}-${n.substring(2)}';
    setState(() => lines.add(Line(game, n, a)));
    numC.clear();
    kobC.clear();
    numF.requestFocus();
  }

  void _pairs(List<String> ns, double a) {
    for (var i = 0; i < ns.length; i++) {
      for (var j = i + 1; j < ns.length; j++) {
        lines.add(Line('MARYAJ', '${ns[i]}-${ns[j]}', a));
      }
    }
  }

  Future<void> _menu(String v) async {
    switch (v) {
      case 'maryaj':
        setState(() => _pairs(_bolets, 1.0));
        break;
      case 'marye':
        final r = await askFields(context, 'Marye plizyè boul', ['Boul yo (separe ak espas)', 'Kòb'],
            kb: TextInputType.text);
        if (r == null) return;
        final ns = r[0]
            .split(RegExp(r'[\s,]+'))
            .where((e) => e.isNotEmpty)
            .map((e) => e.padLeft(2, '0'))
            .toSet()
            .toList();
        final a = double.tryParse(r[1].replaceAll(',', '.')) ?? 0;
        if (ns.length < 2 || a <= 0) return toast(context, 'Antre omwen 2 boul ak yon kòb');
        setState(() => _pairs(ns, a));
        break;
      case 'loto4':
        // HIPOTÈZ (pa konfime): Op1 = a+b, Op2 = b+a pou chak pè boul Bòlèt. Op3 poko sipòte.
        final r = await askFields(context, 'Loto 4 auto', ['Op1', 'Op2', 'Op3']);
        if (r == null) return;
        final op = r.map((e) => double.tryParse(e.replaceAll(',', '.')) ?? 0).toList();
        final ns = _bolets;
        setState(() {
          for (var i = 0; i < ns.length; i++) {
            for (var j = i + 1; j < ns.length; j++) {
              if (op[0] > 0) lines.add(Line('LOTO4', '${ns[i]}${ns[j]}', op[0]));
              if (op[1] > 0) lines.add(Line('LOTO4', '${ns[j]}${ns[i]}', op[1]));
            }
          }
        });
        if (op[2] > 0) toast(context, 'Op3 poko sipòte');
        break;
      case 'pe':
        final a = await askAmount(context, 'Jwe boul pè yo', '5');
        if (a == null) return;
        setState(() {
          for (var i = 0; i < 10; i++) {
            lines.add(Line('BOLET', '$i$i', a));
          }
        });
        break;
      case 'grap':
        // HIPOTÈZ: grap = 3 menm chif (000, 111, ... 999)
        final a = await askAmount(context, 'Jwe grap loto3');
        if (a == null) return;
        setState(() {
          for (var i = 0; i < 10; i++) {
            lines.add(Line('LOTO3', '$i$i$i', a));
          }
        });
        break;
    }
  }

  Future<void> _editLine(Line l) async {
    final a = await askAmount(context, 'Modifye kòb', l.amount.toString());
    if (a != null) setState(() => l.amount = a);
  }

  Future<void> _choose() async {
    if (lines.isEmpty) return toast(context, 'Ou poko mize anyen');
    final ids = await Navigator.push<List<int>>(
        context, MaterialPageRoute(builder: (_) => ChooseDrawPage(lines: lines)));
    if (ids == null || ids.isEmpty || !mounted) return;
    await Navigator.push(context, MaterialPageRoute(builder: (_) => PrintPage(ids: ids)));
    if (mounted) setState(() => lines.clear());
  }

  Widget _row(Line l) {
    final c = games[l.game]!['color'] as Color;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(children: [
        SizedBox(
          width: 90,
          child: Row(children: [for (final p in l.number.split('-')) ball(p, c)]),
        ),
        Expanded(child: Center(child: Text(money(l.amount), style: const TextStyle(fontSize: 16)))),
        IconButton(icon: const Icon(Icons.edit, size: 18), onPressed: () => _editLine(l)),
        IconButton(
            icon: const Icon(Icons.delete, size: 18, color: Colors.redAccent),
            onPressed: () => setState(() => lines.remove(l))),
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    final groups = <String, List<Line>>{};
    for (final l in lines) {
      groups.putIfAbsent(l.game, () => []).add(l);
    }
    final canAuto = _bolets.length >= 2;
    return Scaffold(
      appBar: AppBar(
        title: Text(games[game]!['label'] as String),
        actions: [
          PopupMenuButton<String>(
            onSelected: _menu,
            itemBuilder: (_) => [
              PopupMenuItem(value: 'maryaj', enabled: canAuto, child: const Text('Maryaj auto')),
              const PopupMenuItem(value: 'marye', child: Text('Marye Plizyè boul')),
              PopupMenuItem(value: 'loto4', enabled: canAuto, child: const Text('Loto 4 Auto')),
              const PopupMenuItem(value: 'pe', child: Text('Jwe boul pè yo')),
              const PopupMenuItem(value: 'grap', child: Text('Jwe grap loto3')),
            ],
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(children: [
          SizedBox(
            height: 46,
            child: ListView(scrollDirection: Axis.horizontal, children: [
              for (final e in games.entries)
                Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                        backgroundColor: game == e.key ? kGreen : kCard,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6))),
                    onPressed: () => setState(() {
                      game = e.key;
                      numC.clear();
                    }),
                    child: Text(e.value['label'] as String),
                  ),
                ),
            ]),
          ),
          const SizedBox(height: 10),
          Row(children: [
            SizedBox(
              width: 90,
              child: TextField(
                controller: numC,
                focusNode: numF,
                keyboardType: TextInputType.number,
                textInputAction: TextInputAction.next,
                maxLength: digits,
                onSubmitted: (_) => kobF.requestFocus(),
                decoration: InputDecoration(
                    labelText: 'Nimero',
                    hintText: 'X' * digits,
                    counterText: '',
                    border: const OutlineInputBorder()),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: TextField(
                controller: kobC,
                focusNode: kobF,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _add(),
                decoration: const InputDecoration(
                    labelText: 'Kob', hintText: '0', border: OutlineInputBorder()),
              ),
            ),
            const SizedBox(width: 8),
            SizedBox(
              height: 56,
              width: 56,
              child: FilledButton(
                  style: FilledButton.styleFrom(
                      backgroundColor: kBlue, padding: EdgeInsets.zero),
                  onPressed: _add,
                  child: const Icon(Icons.add)),
            ),
          ]),
          const SizedBox(height: 10),
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: kCard, borderRadius: BorderRadius.circular(8)),
              child: Column(children: [
                Expanded(
                  child: lines.isEmpty
                      ? const Center(
                          child: Text('Ou poko mize anyen',
                              style: TextStyle(fontStyle: FontStyle.italic)))
                      : ListView(children: [
                          for (final g in groups.entries) ...[
                            Text(games[g.key]!['label'] as String,
                                style: const TextStyle(fontWeight: FontWeight.bold)),
                            for (final l in g.value) _row(l),
                            const Divider(),
                          ]
                        ]),
                ),
                Row(children: [
                  const Text('Total', style: TextStyle(fontWeight: FontWeight.bold)),
                  const Spacer(),
                  Text(money(total), style: const TextStyle(fontWeight: FontWeight.bold)),
                ]),
              ]),
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: FilledButton(
              style: FilledButton.styleFrom(backgroundColor: kGreen),
              onPressed: _choose,
              child: const Text('CHWAZI TIRAJ OU VLE JWE YO'),
            ),
          ),
        ]),
      )),
    );
  }
}
