import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'config.dart';
import 'login_page.dart';
import 'vendor/vendor_shell.dart';
import 'director/director_page.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Supabase.initialize(url: kSupabaseUrl, anonKey: kSupabaseKey);
  runApp(const HaitiLotoApp());
}

class HaitiLotoApp extends StatelessWidget {
  const HaitiLotoApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'Haiti Loto',
        debugShowCheckedModeBanner: false,
        theme: ThemeData.dark(useMaterial3: true).copyWith(
          scaffoldBackgroundColor: kBg,
          appBarTheme: const AppBarTheme(backgroundColor: kDark, centerTitle: true),
        ),
        home: const AuthGate(),
      );
}

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});
  @override
  Widget build(BuildContext context) => StreamBuilder<AuthState>(
        stream: sb.auth.onAuthStateChange,
        builder: (context, _) {
          final session = sb.auth.currentSession;
          if (session == null) return const LoginPage();
          return FutureBuilder<Map<String, dynamic>?>(
            future: sb.from('profiles').select().eq('id', session.user.id).maybeSingle(),
            builder: (context, snap) {
              if (snap.connectionState != ConnectionState.done) {
                return const Scaffold(body: Center(child: CircularProgressIndicator()));
              }
              final p = snap.data;
              if (p == null || p['active'] != true) return const NoAccess();
              return p['role'] == 'director' ? const DirectorPage() : const VendorShell();
            },
          );
        },
      );
}

class NoAccess extends StatelessWidget {
  const NoAccess({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
        body: Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Text('Kont sa a pa aktif. Kontakte direktè a.'),
            const SizedBox(height: 12),
            FilledButton(onPressed: () => sb.auth.signOut(), child: const Text('Dekonekte')),
          ]),
        ),
      );
}
