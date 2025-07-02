import 'package:flutter/material.dart';
import 'package:go_cart/app.dart';
import 'package:go_cart/config.dart';

void main() {
  final config = AppConfig(appName: 'Instance A', localDbName: 'instance_a_db');
  WidgetsFlutterBinding.ensureInitialized();
  runApp(MyApp(config: config));
}
