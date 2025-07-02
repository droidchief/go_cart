import 'package:flutter/material.dart';
import 'package:go_cart/config.dart';

void main() {
  final config = AppConfig(appName: 'Instance A', localDbName: 'instance_a_db');
  runApp(MyApp(config: config));
}

class MyApp extends StatelessWidget {
  final AppConfig config;
  const MyApp({super.key, required this.config});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
      ),
      home: const Text('Flutter Demo Home Page'),
    );
  }
}
