import 'dart:math';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const kSupabaseUrl = 'https://jhbfthiuwzuycqociumh.supabase.co';
const kSupabaseKey = 'sb_publishable_X9ZsP_ViWaJsILgl-F5qAw_r_EvCsYM';
const kUserDomain = 'haitiloto.app';
const kVersion = '1.0.0';

SupabaseClient get sb => Supabase.instance.client;

const kBg = Color(0xFF3F4349);
const kCard = Color(0xFF4F5258);
const kDark = Color(0xFF2F3237);
const kGreen = Color(0xFF5CB85C);
const kBlue = Color(0xFF1CA3D8);
const kPink = Color(0xFFDD3B94);
const kGold = Color(0xFFC9A227);
const kOrange = Color(0xFFF39528);

const Map<String, Map<String, dynamic>> games = {
  'BOLET': {'label': 'BÒLÈT', 'digits': 2, 'color': kGreen},
  'MARYAJ': {'label': 'MARYAJ', 'digits': 4, 'color': kBlue},
  'LOTO3': {'label': '3 CHIF', 'digits': 3, 'color': kPink},
  'LOTO4': {'label': '4 CHIF', 'digits': 4, 'color': kGold},
  'LOTO5': {'label': '5 CHIF', 'digits': 5, 'color': kOrange},
};

/// Paramèt direktè a (non bank, telefòn sipò, ...) chaje apre koneksyon.
Map<String, dynamic> appSettings = {};

String money(num v) => v.toStringAsFixed(1);

void toast(BuildContext c, String m) =>
    ScaffoldMessenger.of(c).showSnackBar(SnackBar(content: Text(m)));

String errMsg(Object e) {
  if (e is PostgrestException) return e.message;
  if (e is AuthException) return e.message;
  return e.toString().replaceFirst('Exception: ', '');
}

Future<String> deviceId() async {
  final p = await SharedPreferences.getInstance();
  var id = p.getString('device_id');
  if (id == null) {
    final r = Random.secure();
    id = List.generate(16, (_) => r.nextInt(16).toRadixString(16)).join();
    await p.setString('device_id', id);
  }
  return id;
}

Duration _clockOffset = Duration.zero;

/// Lè Ayiti (soti nan sèvè a), pa lè telefòn lan.
DateTime haitiNow() => DateTime.now().add(_clockOffset);

/// Konvèti yon timestamp sèvè (UTC) an lè Ayiti.
DateTime toHaiti(DateTime t) => t.toLocal().add(_clockOffset);

Future<void> syncClock() async {
  try {
    final s = await sb.rpc('haiti_now') as String;
    _clockOffset = DateTime.parse(s).difference(DateTime.now());
  } catch (_) {}
}

DateTime closeToday(String t) {
  final p = t.split(':');
  final n = haitiNow();
  return DateTime(n.year, n.month, n.day, int.parse(p[0]), int.parse(p[1]));
}

bool drawOpen(Map<String, dynamic> d) =>
    haitiNow().isBefore(closeToday(d['close_time'] as String));

Future<List<String>?> askFields(BuildContext c, String title, List<String> labels,
    {List<String>? initial, TextInputType kb = TextInputType.number}) {
  final ctl = List.generate(
      labels.length, (i) => TextEditingController(text: initial != null ? initial[i] : ''));
  return showDialog<List<String>>(
    context: c,
    builder: (dc) => AlertDialog(
      title: Text(title),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        for (var i = 0; i < labels.length; i++)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: TextField(
              controller: ctl[i],
              keyboardType: kb,
              decoration: InputDecoration(labelText: labels[i], border: const OutlineInputBorder()),
            ),
          ),
      ]),
      actions: [
        TextButton(onPressed: () => Navigator.pop(dc), child: const Text('Anile')),
        FilledButton(
            onPressed: () => Navigator.pop(dc, ctl.map((e) => e.text.trim()).toList()),
            child: const Text('OK')),
      ],
    ),
  );
}

Future<double?> askAmount(BuildContext c, String title, [String initial = '']) async {
  final r = await askFields(c, title, ['Kòb'], initial: [initial]);
  if (r == null) return null;
  final v = double.tryParse(r[0].replaceAll(',', '.'));
  return (v == null || v <= 0) ? null : v;
}

Widget ball(String n, Color c) => Container(
      width: 34,
      height: 34,
      margin: const EdgeInsets.only(right: 4),
      alignment: Alignment.center,
      decoration: BoxDecoration(color: c, shape: BoxShape.circle),
      child: Text(n, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
    );
