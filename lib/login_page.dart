import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'config.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});
  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final u = TextEditingController();
  final p = TextEditingController();
  bool hide = true, busy = false;
  String dev = '';

  @override
  void initState() {
    super.initState();
    deviceId().then((v) {
      if (mounted) setState(() => dev = v);
    });
  }

  Future<void> _login() async {
    setState(() => busy = true);
    try {
      await sb.auth.signInWithPassword(
          email: '${u.text.trim().toLowerCase()}@$kUserDomain', password: p.text);
    } catch (e) {
      if (mounted) toast(context, 'Username oswa password pa bon');
    }
    if (mounted) setState(() => busy = false);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(children: [
                const Icon(Icons.casino, size: 90, color: kBlue),
                const Text('HAITI LOTO',
                    style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: kBlue)),
                const SizedBox(height: 16),
                const Text('Connection', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                const SizedBox(height: 16),
                TextField(
                  controller: u,
                  decoration: const InputDecoration(labelText: 'Username', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: p,
                  obscureText: hide,
                  decoration: InputDecoration(
                    labelText: 'Password',
                    border: const OutlineInputBorder(),
                    suffixIcon: IconButton(
                        icon: Icon(hide ? Icons.visibility : Icons.visibility_off),
                        onPressed: () => setState(() => hide = !hide)),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: FilledButton(
                    style: FilledButton.styleFrom(backgroundColor: kBlue),
                    onPressed: busy ? null : _login,
                    child: busy ? const CircularProgressIndicator() : const Text('Login'),
                  ),
                ),
                const SizedBox(height: 16),
                Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Text('ID: $dev'),
                  IconButton(
                      icon: const Icon(Icons.copy, size: 18),
                      onPressed: () => Clipboard.setData(ClipboardData(text: dev))),
                ]),
              ]),
            ),
          ),
        ),
      );
}
