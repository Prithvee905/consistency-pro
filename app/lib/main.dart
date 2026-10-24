import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'cloud.dart';
import 'config.dart';
import 'notifications.dart';
import 'screens/home_screen.dart';
import 'store.dart';
import 'theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final prefs = await SharedPreferences.getInstance();
  final notifications = NotificationService();
  await notifications.init();
  final cloud = CloudService();
  await cloud.init();

  final store = AppStore.load(prefs, notifications, cloud);
  // Re-plan the next two weeks of alarms every time the app opens.
  await store.rescheduleAlarms();

  runApp(StoreScope(store: store, child: const ConsistencyApp()));
}

class ConsistencyApp extends StatelessWidget {
  const ConsistencyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: kAppName,
      debugShowCheckedModeBanner: false,
      theme: buildTheme(Brightness.light),
      darkTheme: buildTheme(Brightness.dark),
      themeMode: ThemeMode.system,
      home: const HomeScreen(),
    );
  }
}
