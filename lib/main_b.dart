import 'package:flutter/material.dart';
import 'package:go_cart/app.dart';
import 'package:go_cart/config.dart';
import 'package:isar/isar.dart';

Future<void> main() async{
  WidgetsFlutterBinding.ensureInitialized();

  await Isar.initializeIsarCore(download: true);
  
  final config = AppConfig(appName: 'Instance B', localDbName: 'instance_b_db');
  WidgetsFlutterBinding.ensureInitialized();
  runApp(MyApp(config: config));
}

