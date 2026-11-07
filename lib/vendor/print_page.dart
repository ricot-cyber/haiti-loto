import 'package:esc_pos_utils_plus/esc_pos_utils_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:print_bluetooth_thermal/print_bluetooth_thermal.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../config.dart';

String ascii(String s) {
  const m = {'ò': 'o', 'è': 'e', 'é': 'e', 'à': 'a', 'Ò': 'O', 'È': 'E', 'É': 'E', 'À': 'A', 'ç': 'c'};
  var o = s;
  m.forEach((k, v) => o = o.replaceAll(k, v));
  return o;
}

class ThermalPrinter {
  static Future<bool> ensure(BuildContext c) async {
    if (await PrintBluetoothThermal.connectionStatus) return true;
    final p = await SharedPreferences.getInstance();
    final mac = p.getString('printer_mac');
    if (mac != null && await PrintBluetoothThermal.connect(macPrinterAddress: mac)) return true;
    if (c.mounted) toast(c, 'Konekte enprimant lan nan Paramèt aplikasyon');
    return false;
  }

  static Future<void> write(BuildContext c, List<int> bytes) async {
    if (!await ensure(c)) return;
    await PrintBluetoothThermal.writeBytes(bytes);
  }

  static Future<List<int>> textDoc(List<String> lines, {String? title}) async {
    final g = Generator(PaperSize.mm58, await CapabilityProfile.load());
    List<int> b = [];
    if (title != null) {
      b += g.text(ascii(title), styles: const PosStyles(align: PosAlign.center, bold: true));
    }
    for (final l in lines) {
      b += g.text(ascii(l));
    }
    b += g.feed(3);
    return b;
  }

  static const _short = {'BOLET': 'BOR', 'MARYAJ': 'MAR', 'LOTO3': 'L3', 'LOTO4': 'L4', 'LOTO5': 'L5'};

  static Future<List<int>> receipt(Map<String, dynamic> t) async {
    final g = Generator(PaperSize.mm58, await CapabilityProfile.load());
    const w = 32;
    const center = PosStyles(align: PosAlign.center);
    String two(int n) => n.toString().padLeft(2, '0');
    String lr(String l, String r) {
      final sp = w - l.length - r.length;
      return l + ' ' * (sp < 1 ? 1 : sp) + r;
    }

    final d = toHaiti(DateTime.parse(t['created_at'].toString()));
    final bank = ascii((appSettings['bank_name'] ?? 'HAITI LOTO').toString().toUpperCase());
    final vname = ascii((appSettings['vendor_name'] ?? '').toString().toUpperCase());
    final phone = (appSettings['support_phone'] ?? '').toString();
    final pid = (t['public_id'] ?? '').toString();
    final sq = (t['sq'] ?? 0).toString().padLeft(4, '0');
    final tno = (t['t_no'] ?? 0).toString().padLeft(4, '0');

    List<int> b = [];
    b += g.text(bank,
        styles: const PosStyles(align: PosAlign.center, bold: true, height: PosTextSize.size2));
    if (vname.isNotEmpty) b += g.text(vname, styles: center);
    if (phone.isNotEmpty) b += g.text('Tel: $phone', styles: center);
    b += g.text(lr('Ref: ${appSettings['vendor_user'] ?? ''}', 'TID: ${appSettings['tid'] ?? ''}'));
    b += g.text('SQ.: $sq');
    b += g.text('Serial: $pid');
    b += g.text(lr('Date: ${two(d.day)}-${two(d.month)}-${d.year}',
        'Heure: ${two(d.hour)}:${two(d.minute)}:${two(d.second)}'));
    b += g.hr();
    b += g.text(lr(ascii(t['draws']['name'].toString().toUpperCase()), 'T. No.$tno'),
        styles: const PosStyles(bold: true));
    b += g.hr();
    for (final l in (t['ticket_lines'] as List)) {
      final sh = (_short[l['game']] ?? l['game']).toString();
      b += g.text(lr('${sh.padRight(5)}${l['number'].toString().padLeft(5)} >',
          (l['amount'] as num).toStringAsFixed(2)));
    }
    b += g.hr();
    b += g.text('TOTAL => $cur ${(t['total'] as num).toStringAsFixed(2)}',
        styles: const PosStyles(align: PosAlign.center, bold: true, height: PosTextSize.size2));
    b += g.hr();
    b += g.text(pid, styles: center);
    b += g.text(
        'Fich la peyab bay pote a selman. Li valab pandan 90 jou. '
        'Se selman nimewo ki ekri klèman sou fich sa a ki pral peye.'
            .replaceAll('è', 'e'));
    if (vname.isNotEmpty) b += g.text('Mesi "$vname"');
    b += g.feed(3);
    return b;
  }

  static String _dt(dynamic s) {
    final d = toHaiti(DateTime.parse(s.toString()));
    String two(int n) => n.toString().padLeft(2, '0');
    return '${d.year}-${two(d.month)}-${two(d.day)} ${two(d.hour)}:${two(d.minute)}:${two(d.second)}';
  }

  static Map<String, List<Map<String, dynamic>>> _grouped(Map<String, dynamic> t) {
    final m = <String, List<Map<String, dynamic>>>{};
    for (final l in (t['ticket_lines'] as List)) {
      m.putIfAbsent(l['game'], () => []).add(Map<String, dynamic>.from(l));
    }
    return m;
  }

  static String asText(Map<String, dynamic> t) {
    final b = StringBuffer('${t['draws']['name']}\nID: ${t['public_id']}\nDate: ${_dt(t['created_at'])}\n');
    for (final e in _grouped(t).entries) {
      b.writeln(games[e.key]!['label']);
      for (final l in e.value) {
        b.writeln('${l['number']}  ${money(l['amount'] as num)}');
      }
    }
    b.write('TOTAL: ${money(t['total'] as num)} $cur');
    return b.toString();
  }

  static String dtFmt(dynamic s) => _dt(s);
  static Map<String, List<Map<String, dynamic>>> grouped(Map<String, dynamic> t) => _grouped(t);
}

class PrintPage extends StatefulWidget {
  final List<int> ids;
  const PrintPage({super.key, required this.ids});
  @override
  State<PrintPage> createState() => _PrintPageState();
}

class _PrintPageState extends State<PrintPage> {
  List<Map<String, dynamic>> tickets = [];
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
        .inFilter('id', widget.ids);
    if (mounted) {
      setState(() {
        tickets = List<Map<String, dynamic>>.from(r);
        loading = false;
      });
    }
  }

  Future<void> _print() async {
    try {
      for (final t in tickets) {
        await ThermalPrinter.write(context, await ThermalPrinter.receipt(t));
      }
    } catch (e) {
      if (mounted) toast(context, errMsg(e));
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Paj enpresyon')),
        body: loading
            ? const Center(child: CircularProgressIndicator())
            : Column(children: [
                Expanded(
                  child: ListView(padding: const EdgeInsets.all(16), children: [
                    const Row(children: [
                      Icon(Icons.warning_amber, color: kOrange),
                      SizedBox(width: 6),
                      Text('Verifye papye avan ou enprime',
                          style: TextStyle(fontStyle: FontStyle.italic, color: kOrange)),
                    ]),
                    for (final t in tickets) ...[
                      const SizedBox(height: 16),
                      Text(t['draws']['name'],
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      Row(children: [
                        Text('ID: ${t['public_id']}'),
                        IconButton(
                            icon: const Icon(Icons.copy, size: 16, color: kBlue),
                            onPressed: () =>
                                Clipboard.setData(ClipboardData(text: t['public_id'] ?? ''))),
                      ]),
                      Text('Date: ${ThermalPrinter.dtFmt(t['created_at'])}'),
                      const SizedBox(height: 8),
                      for (final e in ThermalPrinter.grouped(t).entries) ...[
                        Text(games[e.key]!['label'] as String,
                            style: const TextStyle(fontWeight: FontWeight.bold)),
                        for (final l in e.value)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 3),
                            child: Row(children: [
                              SizedBox(
                                  width: 90,
                                  child: Row(children: [
                                    for (final p in (l['number'] as String).split('-'))
                                      ball(p, games[e.key]!['color'] as Color)
                                  ])),
                              Expanded(child: Center(child: Text(money(l['amount'] as num)))),
                            ]),
                          ),
                      ],
                      Container(
                        margin: const EdgeInsets.only(top: 8),
                        padding: const EdgeInsets.all(10),
                        decoration:
                            BoxDecoration(color: kDark, borderRadius: BorderRadius.circular(8)),
                        child: Row(children: [
                          const Text('Total', style: TextStyle(fontWeight: FontWeight.bold)),
                          const Spacer(),
                          Text(money(t['total'] as num),
                              style: const TextStyle(fontWeight: FontWeight.bold)),
                        ]),
                      ),
                    ],
                  ]),
                ),
                SafeArea(
                  child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(children: [
                    Expanded(
                      child: SizedBox(
                        height: 48,
                        child: FilledButton(
                            style: FilledButton.styleFrom(backgroundColor: kGreen),
                            onPressed: _print,
                            child: const Text('Enprime')),
                      ),
                    ),
                    const SizedBox(width: 8),
                    SizedBox(
                      height: 48,
                      width: 56,
                      child: FilledButton(
                          style: FilledButton.styleFrom(
                              backgroundColor: Colors.blue, padding: EdgeInsets.zero),
                          onPressed: () => Share.share(tickets.map(ThermalPrinter.asText).join('\n\n')),
                          child: const Icon(Icons.share)),
                    ),
                  ]),
                )),
              ]),
      );
}
