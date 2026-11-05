import 'package:flutter/material.dart';
import 'package:print_bluetooth_thermal/print_bluetooth_thermal.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../config.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});
  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  List<BluetoothInfo> devices = [];
  String? current;
  bool connected = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final p = await SharedPreferences.getInstance();
    current = p.getString('printer_mac');
    connected = await PrintBluetoothThermal.connectionStatus;
    try {
      devices = await PrintBluetoothThermal.pairedBluetooths;
    } catch (_) {}
    if (mounted) setState(() {});
  }

  Future<void> _connect(BluetoothInfo d) async {
    final ok = await PrintBluetoothThermal.connect(macPrinterAddress: d.macAdress);
    if (ok) {
      final p = await SharedPreferences.getInstance();
      await p.setString('printer_mac', d.macAdress);
    }
    if (mounted) toast(context, ok ? 'Enprimant konekte' : 'Pa ka konekte');
    _load();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Paramèt aplikasyon')),
        body: ListView(padding: const EdgeInsets.all(14), children: [
          const Text('Enprimant ki konekte', style: TextStyle(fontSize: 16)),
          const SizedBox(height: 8),
          if (devices.isEmpty)
            const ListTile(
                tileColor: kCard,
                title: Text('Okenn aparèy'),
                subtitle: Text('Parye enprimant lan nan Bluetooth telefòn lan anvan'),
                trailing: Icon(Icons.print, color: Colors.redAccent)),
          for (final d in devices)
            ListTile(
              tileColor: kCard,
              title: Text(d.name),
              subtitle: Text(d.macAdress),
              trailing: Icon(Icons.print,
                  color: (connected && current == d.macAdress) ? kGreen : Colors.redAccent),
              onTap: () => _connect(d),
            ),
          const SizedBox(height: 20),
          SizedBox(
            height: 48,
            child: FilledButton.icon(
              style: FilledButton.styleFrom(backgroundColor: const Color(0xFFF5EEF8), foregroundColor: const Color(0xFF5E4BA0)),
              icon: const Icon(Icons.logout),
              label: const Text('Dekonekte'),
              onPressed: () async {
                await sb.auth.signOut();
                if (context.mounted) Navigator.popUntil(context, (r) => r.isFirst);
              },
            ),
          ),
        ]),
      );
}
