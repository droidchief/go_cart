import 'package:flutter/material.dart';
import 'package:go_cart/app.dart';
import 'package:go_cart/config.dart';
import 'package:go_cart/data/services/enhanced_database_service.dart';
import 'package:go_cart/data/services/connectivity_service.dart';
import 'package:go_cart/utils/permission_helper.dart';
import 'package:isar/isar.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final config = AppConfig(
    appName: 'Instance A',
    localDbName: 'instance_a_db',
    instanceId: 'instance_a',
  );

  final databaseService = EnhancedDatabaseService(config: config);

try {
    await databaseService.init();
    debugPrint('MAIN: Database service initialized successfully');
  } catch (e) {
    debugPrint('MAIN: Failed to initialize database service: $e');
    // TODO:Show an error screen here
  }

  runApp(
    MyApp(
      config: config,
      databaseService: databaseService,
    ),
  );

}
