import 'package:flutter/material.dart';
import 'package:loader_overlay/loader_overlay.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:test_management_app/utils/dialog_utils.dart';

import 'screens/home.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  SharedPreferences prefs = await SharedPreferences.getInstance();
  bool isLoggedIn = prefs.getBool('stayLoggedIn') ?? false;
  await Supabase.initialize(
    url: 'https://knvnlqxpcrcgdydhcvma.supabase.co',
    anonKey:
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imtudm5scXhwY3JjZ2R5ZGhjdm1hIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTM2MDc0NDAsImV4cCI6MjA2OTE4MzQ0MH0.L_n5uIS_YUKfNn6qAti_EuvvIXxT8X-hBe3jgA5iMIY',
  );
  runApp(ProviderScope(child: MyApp(isLoggedIn: isLoggedIn)));
}

class MyApp extends StatelessWidget {
  final bool isLoggedIn;

  MyApp({required this.isLoggedIn});

  @override
  Widget build(BuildContext context) {
    return GlobalLoaderOverlay(
      child: MaterialApp(
        navigatorKey: rootNavigatorKey,
        debugShowCheckedModeBanner: false,
        home: HomePage(),
        routes: {'/home': (context) => const HomePage()},
      ),
    );
  }
}
