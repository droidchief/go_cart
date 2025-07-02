import 'package:flutter/material.dart';
import 'package:go_cart/app.dart';
import 'package:go_cart/config.dart';

void main() {
  final config = AppConfig(appName: 'Instance C', localDbName: 'instance_c_db');
  WidgetsFlutterBinding.ensureInitialized();
  runApp(MyApp(config: config));
}
