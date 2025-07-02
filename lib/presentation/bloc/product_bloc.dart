import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_cart/config.dart';
import 'package:go_cart/data/services/database_services.dart';
import 'package:go_cart/logic/connectivity_service.dart';
import 'package:go_cart/logic/sync_service.dart';
import 'package:go_cart/presentation/bloc/product_event.dart';
import 'package:go_cart/presentation/bloc/product_state.dart';
import 'package:go_cart/data/models/product.dart';
import 'package:isar/isar.dart';



class ProductBloc extends Bloc<ProductEvent, ProductState> {
  final DatabaseService databaseService;
  final ConnectivityService connectivityService;
  final SyncService syncService;
  final AppConfig config;
  StreamSubscription? _dbSubscription;
  StreamSubscription? _connectivitySubscription;

  ProductBloc({
    required this.databaseService,
    required this.connectivityService,
    required this.syncService,
    required this.config,
  }) : super(ProductsLoadInProgress()) {
    on<ProductsLoadStarted>(_onLoadStarted);
    on<ProductsUpdatedFromDb>(_onProductsUpdated);
    on<ProductLocalUpdateRequested>(_onProductLocalUpdate);
    on<SaveChangesRequested>(_onSaveChanges);
    on<ConnectivityChanged>(_onConnectivityChanged);

    // Start listening to connectivity changes immediately
    _connectivitySubscription = connectivityService.onConnectivityChanged.listen((isOnline) {
        add(ConnectivityChanged(isOnline));
    });
  }

  Future<void> _onLoadStarted(ProductsLoadStarted event, Emitter<ProductState> emit) async {
    emit(ProductsLoadInProgress());
    try {
      // Perform an initial sync
      await syncService.performSync();

      // Always listen to the COMMON database for real-time changes
      _dbSubscription?.cancel();
      _dbSubscription = databaseService.commonDb.products.where().watch(fireImmediately: true).listen((products) {
        add(ProductsUpdatedFromDb(products));
      });
    } catch (e) {
      emit(ProductsLoadFailure(e.toString()));
    }
  }
  
  void _onProductsUpdated(ProductsUpdatedFromDb event, Emitter<ProductState> emit) async {
      final online = await connectivityService.isOnline();
      emit(ProductsLoadSuccess(products: event.products, isOnline: online));
  }

  void _onProductLocalUpdate(ProductLocalUpdateRequested event, Emitter<ProductState> emit) {
    if (state is ProductsLoadSuccess) {
      final currentState = state as ProductsLoadSuccess;
      final updatedList = currentState.products.map((p) {
        return p.id == event.updatedProduct.id ? event.updatedProduct : p;
      }).toList();
      emit(ProductsLoadSuccess(products: updatedList, isOnline: currentState.isOnline));
    }
  }

  Future<void> _onSaveChanges(SaveChangesRequested event, Emitter<ProductState> emit) async {
    if (state is ProductsLoadSuccess) {
      final currentState = state as ProductsLoadSuccess;
      final productsToSave = currentState.products;

      // Update timestamps and 'updatedBy' before saving
      final now = DateTime.now();
      final updatedProducts = productsToSave.map((p) => p.copyWith(
          lastUpdated: now,
          updatedBy: config.appName
      )).toList();

      try {
        if (currentState.isOnline) {
          // ONLINE: Save directly to the common database
          await databaseService.commonDb.writeTxn(() async {
            await databaseService.commonDb.products.putAll(updatedProducts);
          });
          // Also update local DB to be in sync
           await databaseService.localDb.writeTxn(() async {
            await databaseService.localDb.products.putAll(updatedProducts);
          });
          debugPrint("SAVED ONLINE to Common DB");
        } else {
          // OFFLINE: Save only to the local database
          await databaseService.localDb.writeTxn(() async {
            await databaseService.localDb.products.putAll(updatedProducts);
          });
          debugPrint("SAVED OFFLINE to Local DB");
        }
      } catch (e) {
        emit(ProductsLoadFailure(e.toString()));
      }
    }
  }

  void _onConnectivityChanged(ConnectivityChanged event, Emitter<ProductState> emit) {
    if (state is ProductsLoadSuccess) {
        final currentState = state as ProductsLoadSuccess;
        emit(ProductsLoadSuccess(products: currentState.products, isOnline: event.isOnline));
        if (event.isOnline) {
            // Came back online? Trigger a sync
            syncService.performSync();
        }
    }
  }

  @override
  Future<void> close() {
    _dbSubscription?.cancel();
    _connectivitySubscription?.cancel();
    return super.close();
  }
}