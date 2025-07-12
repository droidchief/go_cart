import 'package:flutter/material.dart';
import 'package:go_cart/app.dart';
import 'package:go_cart/config.dart';
import 'package:go_cart/data/services/database_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final config = AppConfig(
    appName: 'Instance B',
    localDbName: 'instance_b_db',
    instanceId: 'instance_b',
  );

  final databaseService = DatabaseService(config: config);

  try {
    await databaseService.init();
    debugPrint('MAIN: Database service initialized successfully');
  } catch (e) {
    debugPrint('MAIN: Failed to initialize database service: $e');
    // TODO:Show an error screen here
  }

  runApp(MyApp(config: config, databaseService: databaseService));
}
