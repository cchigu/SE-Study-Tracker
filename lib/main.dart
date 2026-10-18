import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import 'firebase_options.dart';
import 'screens/home_shell.dart';
import 'services/session_store.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  final store = SessionStore();
  await store.load();

  // Firebase remembers who's signed in, so this fires right away on launch
  // with the saved user (or null), and again on every sign in / sign out.
  FirebaseAuth.instance.authStateChanges().listen((user) => store.attachUser(user?.uid));

  runApp(SeStudyApp(store: store));
}

class SeStudyApp extends StatelessWidget {
  final SessionStore store;
  const SeStudyApp({super.key, required this.store});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SE Exam Study Tracker',
      debugShowCheckedModeBanner: false,
      themeMode: ThemeMode.system,
      theme: ThemeData(colorSchemeSeed: Colors.indigo, useMaterial3: true),
      darkTheme: ThemeData(
        colorSchemeSeed: Colors.indigo,
        brightness: Brightness.dark,
        useMaterial3: true,
      ),
      home: HomeShell(store: store),
    );
  }
}
