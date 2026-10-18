import 'package:flutter/material.dart';

import 'screens/home_shell.dart';
import 'services/session_store.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final store = SessionStore();
  await store.load();
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
