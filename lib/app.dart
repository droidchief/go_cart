import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_cart/config.dart';
import 'package:go_cart/data/services/database_services.dart';
import 'package:go_cart/logic/connectivity_service.dart';
import 'package:go_cart/logic/sync_service.dart';
import 'package:go_cart/presentation/bloc/product_bloc.dart';
import 'package:go_cart/presentation/bloc/product_event.dart';
import 'package:go_cart/presentation/screens/item_list_page.dart';

class MyApp extends StatelessWidget {
  final AppConfig config;
  const MyApp({super.key, required this.config});

  @override
  Widget build(BuildContext context) {
    //TODO: These services would typically be provided by a dependency injection framework
    final databaseService = DatabaseService(config: config);
    final connectivityService = ConnectivityService();
    final syncService = SyncService(databaseService);

    return FutureBuilder(
      future: databaseService.init(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.done) {
          return BlocProvider(
            create: (context) => ProductBloc(
              databaseService: databaseService,
              connectivityService: connectivityService,
              syncService: syncService,
              config: config,
            )..add(ProductsLoadStarted()),
            child: MaterialApp(
              title: config.appName,
              theme: ThemeData(
                primarySwatch: Colors.blue,
                scaffoldBackgroundColor: Colors.grey[200],
                appBarTheme: AppBarTheme(
                  backgroundColor: Colors.white,
                  foregroundColor: Colors.black,
                  elevation: 1,
                ),
              ),
              home: ItemListPage(appName: config.appName),
            ),
          );
        }
        return const Center(child: CircularProgressIndicator());
      },
    );
  }
}