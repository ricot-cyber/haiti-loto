import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../config.dart';
import 'print_page.dart';

class ReportPage extends StatefulWidget {
  final bool director;
  const ReportPage({super.key, this.director = false});
  @override
  State<ReportPage> createState() => _ReportPageState();
}

class _ReportPageState extends State<ReportPage> {
  DateTime from = DateTime.now(), to = DateTime.now();
  int? drawId;
  String? vendorId;
  List<Map<String, dynamic>> draws = [], vendors = [];
  Map<String, dynamic>? rep;
  bool busy = false;
  final df = DateFormat('yyyy-MM-dd');

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    final d = await sb.from('draws').select().order('close_time');
    var v = <dynamic>[];
    if (widget.director) v = await sb.from('profiles').select().eq('role', 'vendor');
    if (mounted) {
      setState(() {
        draws = List<Map<String, dynamic>>.from(d);
        vendors = List<Map<String, dynamic>>.from(v);
      });
    }
  }

  Future<void> _pick(bool isFrom) async {
    final d = await showDatePicker(
        context: context,
        initialDate: isFrom ? from : to,
        firstDate: DateTime(2024),
        lastDate: DateTime.now().add(const Duration(days: 1)));
    if (d != null) setState(() => isFrom ? from = d : to = d);
  }

  Future<void> _run() async {
    setState(() => busy = true);
    try {
      final params = <String, dynamic>{'p_from': df.format(from), 'p_to': df.format(to)};
      if (drawId != null) params['p_draw'] = drawId;
      if (vendorId != null) params['p_vendor'] = vendorId;
      final r = await sb.rpc('sales_report', params: params);
      setState(() => rep = Map<String, dynamic>.from(r as Map));
    } catch (e) {
      if (mounted) toast(context, errMsg(e));
    }
    if (mounted) setState(() => busy = false);
  }

  List<String> _lines() {
    final r = rep!;
    String g(String k) => money(r[k] as num);
    final dn = drawId == null ? 'Tout' : draws.firstWhere((d) => d['id'] == drawId)['name'];
    return [
      'Date Rapport : ${DateFormat('yy-MM-dd HH:mm:ss').format(DateTime.now())}',
      'Bank : ${appSettings['bank_name'] ?? 'HAITI LOTO'}',
      'Tirage : $dn',
      'Date range : ${df.format(from)} au ${df.format(to)}',
      'Ticket Gain: ${r['win']}',
      'Ticket Pert: ${r['lost']}',
      'Ticket Total: ${r['tickets']}',
      'Vente: ${g('sales')} $cur',
      'Perte: ${g('payout')} $cur',
      'Balans: ${g('balance')} $cur',
      'Commission: ${g('commission')} $cur',
    ];
  }

  Widget _dateBox(String label, DateTime d, bool isFrom) => Expanded(
        child: InkWell(
          onTap: () => _pick(isFrom),
          child: InputDecorator(
            decoration: InputDecoration(labelText: label, border: const OutlineInputBorder()),
            child: Text(df.format(d)),
          ),
        ),
      );

  @override
  Widget build(BuildContext context) => ListView(padding: const EdgeInsets.all(14), children: [
        Row(children: [
          _dateBox('Dat Kòmanse', from, true),
          const SizedBox(width: 8),
          _dateBox('Dat fini', to, false),
        ]),
        const SizedBox(height: 12),
        DropdownButtonFormField<int?>(
          value: drawId,
          decoration: const InputDecoration(labelText: 'Chwazi tiraj', border: OutlineInputBorder()),
          items: [
            const DropdownMenuItem<int?>(value: null, child: Text('Tout')),
            for (final d in draws) DropdownMenuItem<int?>(value: d['id'] as int, child: Text(d['name'])),
          ],
          onChanged: (v) => setState(() => drawId = v),
        ),
        if (widget.director) ...[
          const SizedBox(height: 12),
          DropdownButtonFormField<String?>(
            value: vendorId,
            decoration: const InputDecoration(labelText: 'Vandè', border: OutlineInputBorder()),
            items: [
              const DropdownMenuItem<String?>(value: null, child: Text('Tout vandè')),
              for (final v in vendors)
                DropdownMenuItem<String?>(value: v['id'] as String, child: Text(v['username'])),
            ],
            onChanged: (v) => setState(() => vendorId = v),
          ),
        ],
        const SizedBox(height: 12),
        SizedBox(
          height: 48,
          child: FilledButton(
              style: FilledButton.styleFrom(backgroundColor: kBlue),
              onPressed: busy ? null : _run,
              child: const Text('Fè rapò')),
        ),
        if (rep != null) ...[
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: kCard, borderRadius: BorderRadius.circular(14)),
            child: Text(_lines().join('\n'), style: const TextStyle(fontSize: 18, height: 1.4)),
          ),
          const SizedBox(height: 14),
          SizedBox(
            height: 48,
            child: FilledButton(
                style: FilledButton.styleFrom(backgroundColor: kBlue),
                onPressed: () async =>
                    ThermalPrinter.write(context, await ThermalPrinter.textDoc(_lines(), title: 'RAPO')),
                child: const Text('Enprime rapò')),
          ),
        ],
      ]);
}
