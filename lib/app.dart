import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_cart/config.dart';
import 'package:go_cart/data/services/database_service.dart';
import 'package:go_cart/presentation/bloc/product_bloc.dart';
import 'package:go_cart/presentation/screens/home_screen.dart';


  class MyApp extends StatelessWidget {
  final AppConfig config;
  final DatabaseService databaseService;

  const MyApp({
    super.key,
    required this.config,
    required this.databaseService,
  });

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Go Cart - ${config.instanceId}',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        useMaterial3: true,
      ),
      home: BlocProvider(
        create: (context) => ProductBloc(
          databaseService: databaseService,
          config: config,
        ),
        child: HomeScreen(),
      ),
      debugShowCheckedModeBanner: false,
    );
  }
}