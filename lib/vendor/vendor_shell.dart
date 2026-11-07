import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import '../config.dart';
import 'home_page.dart';
import 'results_page.dart';
import 'report_page.dart';
import 'tickets_page.dart';
import 'settings_page.dart';

class VendorShell extends StatefulWidget {
  const VendorShell({super.key});
  @override
  State<VendorShell> createState() => _VendorShellState();
}

class _VendorShellState extends State<VendorShell> {
  int tab = 1;
  String? error;
  bool ready = false;
  String dev = '';

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    try {
      dev = await deviceId();
      await sb.rpc('register_device', params: {'p_device': dev});
      await syncClock();
      final s = await sb.from('director_settings').select().maybeSingle();
      appSettings = Map<String, dynamic>.from(s ?? {});
      final me = await sb.from('profiles').select().eq('id', sb.auth.currentUser!.id).single();
      appSettings['vendor_name'] = me['full_name'] ?? me['username'];
      appSettings['vendor_user'] = me['username'];
      appSettings['tid'] = dev.substring(0, 8).toUpperCase();
    } catch (e) {
      error = errMsg(e);
    }
    if (mounted) setState(() => ready = true);
  }

  void _go(Widget w) {
    Navigator.pop(context);
    Navigator.push(context, MaterialPageRoute(builder: (_) => w));
  }

  @override
  Widget build(BuildContext context) {
    if (!ready) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    if (error != null) {
      return Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Text(error!, textAlign: TextAlign.center),
              const SizedBox(height: 12),
              FilledButton(onPressed: () => sb.auth.signOut(), child: const Text('Dekonekte')),
            ]),
          ),
        ),
      );
    }
    final phone = appSettings['support_phone'] as String?;
    return Scaffold(
      appBar: AppBar(title: const Text('HAITI LOTO')),
      drawer: Drawer(
        backgroundColor: kDark,
        child: SafeArea(
          child: Column(children: [
            ListTile(
              title: const Text('HAITI LOTO', style: TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Text('ID: $dev'),
              trailing: IconButton(
                  icon: const Icon(Icons.copy, size: 18),
                  onPressed: () => Clipboard.setData(ClipboardData(text: dev))),
            ),
            const Divider(),
            ListTile(
                leading: const Icon(Icons.history, color: kBlue),
                title: const Text('Fiche mwen yo'),
                onTap: () => _go(const TicketsPage())),
            ListTile(
                leading: const Icon(Icons.block, color: kOrange),
                title: const Text('Anile fich'),
                onTap: () => _go(const CancelPage())),
            ListTile(
                leading: const Icon(Icons.settings, color: kPink),
                title: const Text('Paramèt aplikasyon'),
                onTap: () => _go(const SettingsPage())),
            const Spacer(),
            if (phone != null && phone.isNotEmpty)
              ListTile(
                title: const Text('Sipò Administratè', style: TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text('Tel: $phone', style: const TextStyle(color: kBlue)),
                onTap: () => launchUrl(Uri.parse('tel:$phone')),
              ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text('Version $kVersion',
                      style: const TextStyle(fontStyle: FontStyle.italic))),
            ),
          ]),
        ),
      ),
      body: IndexedStack(index: tab, children: const [
        ResultsPage(),
        HomePage(),
        ReportPage(),
      ]),
      bottomNavigationBar: NavigationBar(
        selectedIndex: tab,
        onDestinationSelected: (i) => setState(() => tab = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.description), label: 'Rezilta'),
          NavigationDestination(icon: Icon(Icons.home), label: 'Jwèt'),
          NavigationDestination(icon: Icon(Icons.show_chart), label: 'Rapò'),
        ],
      ),
    );
  }
}
