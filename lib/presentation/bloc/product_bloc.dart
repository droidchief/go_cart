import 'dart:async';
import 'package:bloc/bloc.dart';
import 'package:flutter/foundation.dart';
import 'package:go_cart/config.dart';
import 'package:go_cart/data/models/product.dart';
import 'package:go_cart/data/services/database_service.dart';
import 'product_event.dart';
import 'product_state.dart';

/// ProductBloc manages the state of products and handles all product-related operations
/// This includes local storage, shared database synchronization, and UI state management
class ProductBloc extends Bloc<ProductEvent, ProductState> {
  final DatabaseService _databaseService;
  final AppConfig _config;

  StreamSubscription<List<Product>>? _productsSubscription;
  List<Product> _currentProducts = [];
  bool _hasPendingChanges = false;
  Timer? _autoSaveTimer;
  Timer? _syncRetryTimer;
  int _syncRetryCount = 0;
  static const int _maxSyncRetries = 3;

  ProductBloc({
    required DatabaseService databaseService,
    required AppConfig config,
  }) : _databaseService = databaseService,
       _config = config,
       super(const ProductInitial()) {
    // Register event handlers
    on<LoadProducts>(_onLoadProducts);
    on<UpdateProduct>(_onUpdateProduct);
    on<UpdateProducts>(_onUpdateProducts);
    on<SaveProduct>(_onSaveProduct);
    on<SaveProducts>(_onSaveProducts);
    on<DeleteProduct>(_onDeleteProduct);
    on<SyncWithSharedDatabase>(_onSyncWithSharedDatabase);
    on<SharedDatabaseChanged>(_onSharedDatabaseChanged);
    on<ResetProducts>(_onResetProducts);
    on<ConnectivityChanged>(_onConnectivityChanged);
    on<AddProduct>(_onAddProduct);
    on<ValidateProducts>(_onValidateProducts);
    on<PrintDebugLogs>(_onPrintDebugLogs);

    _initializeBloc();
  }

  void _initializeBloc() {
    debugPrint(
      'PRODUCT_BLOC: Initializing ProductBloc for ${_config.instanceId}',
    );

    _startWatchingProducts();

    add(const LoadProducts());
  }

  void _startWatchingProducts() {
    _productsSubscription = _databaseService.watchProducts().listen(
      (products) {
        debugPrint(
          'PRODUCT_BLOC: Database products changed - ${products.length} products',
        );
        _currentProducts = products;

        if (state is ProductLoadSuccess || state is ProductSyncSuccess) {
          add(UpdateProducts(products: products, reason: 'Database changed'));
        }
      },
      onError: (error) {
        debugPrint('PRODUCT_BLOC: Error watching products: $error');
        add(const LoadProducts());
      },
    );
  }

  Future<void> _onLoadProducts(
    LoadProducts event,
    Emitter<ProductState> emit,
  ) async {
    try {
      debugPrint('PRODUCT_BLOC: Loading products for ${_config.instanceId}');
      emit(const ProductLoading(message: 'Loading products...'));

      final products = _databaseService.getAllProducts();
      _currentProducts = products;

      final totalAmount = ProductLoadSuccess.calculateTotal(products);
      final syncStatus = _databaseService.getSyncStatus();

      emit(
        ProductLoadSuccess(
          products: products,
          lastUpdated: DateTime.now(),
          instanceId: _config.instanceId,
          hasPendingChanges: _hasPendingChanges,
          totalAmount: totalAmount,
          syncStatus: syncStatus,
        ),
      );

      debugPrint(
        'PRODUCT_BLOC: Loaded ${products.length} products, total: \$${totalAmount.toStringAsFixed(2)}',
      );
    } catch (error) {
      debugPrint('PRODUCT_BLOC: Error loading products: $error');
      emit(
        ProductError(
          message: 'Failed to load products',
          details: error.toString(),
          errorCode: 'LOAD_ERROR',
          timestamp: DateTime.now(),
        ),
      );
    }
  }

  Future<void> _onUpdateProduct(
    UpdateProduct event,
    Emitter<ProductState> emit,
  ) async {
    try {
      debugPrint(
        'PRODUCT_BLOC: Updating product ${event.product.name} - ${event.fieldName}: ${event.oldValue} -> ${event.newValue}',
      );

      final updatedProducts =
          _currentProducts.map((p) {
            return p.id == event.product.id ? event.product : p;
          }).toList();

      _currentProducts = updatedProducts;
      _hasPendingChanges = true;

      final totalAmount = ProductLoadSuccess.calculateTotal(updatedProducts);
      final syncStatus = _databaseService.getSyncStatus();

      emit(
        ProductLoadSuccess(
          products: updatedProducts,
          lastUpdated: DateTime.now(),
          instanceId: _config.instanceId,
          hasPendingChanges: _hasPendingChanges,
          totalAmount: totalAmount,
          syncStatus: syncStatus,
        ),
      );

      _startAutoSaveTimer();

      debugPrint(
        'PRODUCT_BLOC: Product updated, total: \$${totalAmount.toStringAsFixed(2)}',
      );
    } catch (error) {
      debugPrint('PRODUCT_BLOC: Error updating product: $error');
      emit(
        ProductError(
          message: 'Failed to update product',
          details: error.toString(),
          errorCode: 'UPDATE_ERROR',
          timestamp: DateTime.now(),
          lastKnownProducts: _currentProducts,
        ),
      );
    }
  }

  Future<void> _onUpdateProducts(
    UpdateProducts event,
    Emitter<ProductState> emit,
  ) async {
    try {
      debugPrint(
        'PRODUCT_BLOC: Updating ${event.products.length} products - ${event.reason}',
      );

      _currentProducts = event.products;

      final totalAmount = ProductLoadSuccess.calculateTotal(event.products);
      final syncStatus = _databaseService.getSyncStatus();

      emit(
        ProductLoadSuccess(
          products: event.products,
          lastUpdated: DateTime.now(),
          instanceId: _config.instanceId,
          hasPendingChanges: _hasPendingChanges,
          totalAmount: totalAmount,
          syncStatus: syncStatus,
        ),
      );

      debugPrint(
        'PRODUCT_BLOC: Updated ${event.products.length} products, total: \$${totalAmount.toStringAsFixed(2)}',
      );
    } catch (error) {
      debugPrint('PRODUCT_BLOC: Error updating products: $error');
      emit(
        ProductError(
          message: 'Failed to update products',
          details: error.toString(),
          errorCode: 'BATCH_UPDATE_ERROR',
          timestamp: DateTime.now(),
          lastKnownProducts: _currentProducts,
        ),
      );
    }
  }

  Future<void> _onSaveProduct(
    SaveProduct event,
    Emitter<ProductState> emit,
  ) async {
    try {
      debugPrint('PRODUCT_BLOC: Saving single product ${event.product.name}');

      emit(
        ProductSaving(
          products: [event.product],
          operation: 'Saving ${event.product.name}...',
          isSyncingToShared: _databaseService.isOnline,
        ),
      );

      await _databaseService.saveProduct(event.product);

      final updatedProducts =
          _currentProducts.map((p) {
            return p.id == event.product.id ? event.product : p;
          }).toList();

      _currentProducts = updatedProducts;
      _hasPendingChanges = false;

      // Cancel auto-save timer since we just saved
      _autoSaveTimer?.cancel();

      final totalAmount = ProductLoadSuccess.calculateTotal(updatedProducts);
      final syncStatus = _databaseService.getSyncStatus();

      emit(
        ProductSaveSuccess(
          products: [event.product],
          savedAt: DateTime.now(),
          instanceId: _config.instanceId,
          syncedToShared: _databaseService.isOnline,
          message: '${event.product.name} saved successfully',
        ),
      );

      emit(
        ProductLoadSuccess(
          products: updatedProducts,
          lastUpdated: DateTime.now(),
          instanceId: _config.instanceId,
          hasPendingChanges: false,
          totalAmount: totalAmount,
          syncStatus: syncStatus,
        ),
      );

      debugPrint(
        'PRODUCT_BLOC: Successfully saved product ${event.product.name}',
      );
    } catch (error) {
      debugPrint('PRODUCT_BLOC: Error saving product: $error');
      emit(
        ProductError(
          message: 'Failed to save ${event.product.name}',
          details: error.toString(),
          errorCode: 'SAVE_PRODUCT_ERROR',
          timestamp: DateTime.now(),
          lastKnownProducts: _currentProducts,
        ),
      );
    }
  }

  Future<void> _onSaveProducts(
    SaveProducts event,
    Emitter<ProductState> emit,
  ) async {
    try {
      debugPrint(
        'PRODUCT_BLOC: Saving ${event.products.length} products, forceSync: ${event.forceSyncToShared}',
      );

      emit(
        ProductSaving(
          products: event.products,
          operation: 'Saving products...',
          isSyncingToShared: event.forceSyncToShared,
        ),
      );

      await _databaseService.saveProducts(event.products);
      _hasPendingChanges = false;

      // Cancel auto-save timer since we just saved
      _autoSaveTimer?.cancel();

      emit(
        ProductSaveSuccess(
          products: event.products,
          savedAt: DateTime.now(),
          instanceId: _config.instanceId,
          syncedToShared: event.forceSyncToShared,
          message: 'Products saved successfully',
        ),
      );

      // Force sync to shared database if requested
      if (event.forceSyncToShared) {
        add(const SyncWithSharedDatabase(isManualSync: true));
      }

      debugPrint(
        'PRODUCT_BLOC: Successfully saved ${event.products.length} products',
      );
    } catch (error) {
      debugPrint('PRODUCT_BLOC: Error saving products: $error');
      emit(
        ProductError(
          message: 'Failed to save products',
          details: error.toString(),
          errorCode: 'SAVE_ERROR',
          timestamp: DateTime.now(),
          lastKnownProducts: event.products,
        ),
      );
    }
  }

  Future<void> _onDeleteProduct(
    DeleteProduct event,
    Emitter<ProductState> emit,
  ) async {
    try {
      debugPrint(
        'PRODUCT_BLOC: Deleting product ${event.productId} - ${event.reason}',
      );

      await _databaseService.deleteProduct(event.productId);

      _currentProducts =
          _currentProducts.where((p) => p.id != event.productId).toList();

      final totalAmount = ProductLoadSuccess.calculateTotal(_currentProducts);
      final syncStatus = _databaseService.getSyncStatus();

      emit(
        ProductLoadSuccess(
          products: _currentProducts,
          lastUpdated: DateTime.now(),
          instanceId: _config.instanceId,
          hasPendingChanges: false,
          totalAmount: totalAmount,
          syncStatus: syncStatus,
        ),
      );

      debugPrint(
        'PRODUCT_BLOC: Successfully deleted product ${event.productId}',
      );
    } catch (error) {
      debugPrint('PRODUCT_BLOC: Error deleting product: $error');
      emit(
        ProductError(
          message: 'Failed to delete product',
          details: error.toString(),
          errorCode: 'DELETE_ERROR',
          timestamp: DateTime.now(),
          lastKnownProducts: _currentProducts,
        ),
      );
    }
  }

  Future<void> _onSyncWithSharedDatabase(
    SyncWithSharedDatabase event,
    Emitter<ProductState> emit,
  ) async {
    try {
      debugPrint(
        'PRODUCT_BLOC: Starting sync with shared database - manual: ${event.isManualSync}',
      );

      emit(
        ProductSyncing(
          operation:
              event.isManualSync
                  ? 'Manual sync in progress...'
                  : 'Auto sync in progress...',
          currentProducts: _currentProducts,
        ),
      );

      await _databaseService.forceSyncWithShared();

      final updatedProducts = _databaseService.getAllProducts();
      _currentProducts = updatedProducts;

      final syncStatus = _databaseService.getSyncStatus();

      emit(
        ProductSyncSuccess(
          products: updatedProducts,
          syncedAt: DateTime.now(),
          instanceId: _config.instanceId,
          itemsSynced: updatedProducts.length,
          message: 'Sync completed successfully',
          syncDetails: syncStatus,
        ),
      );

      debugPrint(
        'PRODUCT_BLOC: Sync completed successfully - ${updatedProducts.length} products',
      );

      // Immediately reload to reflect any changes
      add(const LoadProducts());
    } catch (error) {
      debugPrint('PRODUCT_BLOC: Error syncing with shared database: $error');
      // Implement retry logic for manual syncs
      if (event.isManualSync && _syncRetryCount < _maxSyncRetries) {
        _syncRetryCount++;
        debugPrint(
          'PRODUCT_BLOC: Retrying sync (attempt $_syncRetryCount/$_maxSyncRetries)',
        );

        _syncRetryTimer = Timer(Duration(seconds: _syncRetryCount * 2), () {
          add(SyncWithSharedDatabase(isManualSync: true));
        });

        emit(
          ProductSyncing(
            operation:
                'Retrying sync (attempt $_syncRetryCount/$_maxSyncRetries)...',
            currentProducts: _currentProducts,
          ),
        );
      } else {
        _syncRetryCount = 0;
        emit(
          ProductError(
            message: 'Failed to sync with shared database',
            details: error.toString(),
            errorCode: 'SYNC_ERROR',
            timestamp: DateTime.now(),
            lastKnownProducts: _currentProducts,
          ),
        );
      }
    }
  }

  /// React to changes from other instances
  Future<void> _onSharedDatabaseChanged(
    SharedDatabaseChanged event,
    Emitter<ProductState> emit,
  ) async {
    try {
      debugPrint(
        'PRODUCT_BLOC: Shared database changed by ${event.sourceInstance} at ${event.timestamp}',
      );

      // Trigger sync to get latest changes
      add(const SyncWithSharedDatabase(isManualSync: false));
    } catch (error) {
      debugPrint('PRODUCT_BLOC: Error handling shared database change: $error');
    }
  }

  /// Reset products to initial state
  Future<void> _onResetProducts(
    ResetProducts event,
    Emitter<ProductState> emit,
  ) async {
    try {
      debugPrint(
        'PRODUCT_BLOC: Resetting products - keepLocal: ${event.keepLocalChanges}',
      );

      if (!event.keepLocalChanges) {
        _currentProducts = [];
        _hasPendingChanges = false;
        _autoSaveTimer?.cancel();
      }

      // Reload products from database
      add(const LoadProducts());
    } catch (error) {
      debugPrint('PRODUCT_BLOC: Error resetting products: $error');
      emit(
        ProductError(
          message: 'Failed to reset products',
          details: error.toString(),
          errorCode: 'RESET_ERROR',
          timestamp: DateTime.now(),
        ),
      );
    }
  }

  Future<void> _onConnectivityChanged(
    ConnectivityChanged event,
    Emitter<ProductState> emit,
  ) async {
    try {
      debugPrint(
        'PRODUCT_BLOC: Connectivity changed - online: ${event.isOnline}',
      );

      emit(
        ProductConnectivityChanged(
          isOnline: event.isOnline,
          timestamp: event.timestamp,
          products: _currentProducts,
          hasPendingSync: _hasPendingChanges,
        ),
      );

      if (event.isOnline) {
        debugPrint('PRODUCT_BLOC: Back online, scheduling sync...');
        Timer(const Duration(seconds: 3), () {
          if (state is! ProductSyncing) {
            // Don't interrupt ongoing sync
            add(const SyncWithSharedDatabase(isManualSync: false));
          }
        });
      }

    } catch (error) {
      debugPrint('PRODUCT_BLOC: Error handling connectivity change: $error');
    }
  }

  ///Add a new product
  Future<void> _onAddProduct(
    AddProduct event,
    Emitter<ProductState> emit,
  ) async {
    try {
      debugPrint('PRODUCT_BLOC: Adding new product ${event.product.name}');

      await _databaseService.saveProduct(event.product);

      // Product will be automatically added to _currentProducts via the stream
      _hasPendingChanges = false;

      debugPrint(
        'PRODUCT_BLOC: Successfully added product ${event.product.name}',
      );
    } catch (error) {
      debugPrint('PRODUCT_BLOC: Error adding product: $error');
      emit(
        ProductError(
          message: 'Failed to add product',
          details: error.toString(),
          errorCode: 'ADD_ERROR',
          timestamp: DateTime.now(),
          lastKnownProducts: _currentProducts,
        ),
      );
    }
  }

  Future<void> _onValidateProducts(
    ValidateProducts event,
    Emitter<ProductState> emit,
  ) async {
    try {
      debugPrint('PRODUCT_BLOC: Validating ${event.products.length} products');

      emit(
        ProductValidating(
          products: event.products,
          validationType: 'Data integrity check',
        ),
      );

      final validationErrors = <int, List<String>>{};

      for (final product in event.products) {
        final errors = <String>[];

        if (product.name.trim().isEmpty) {
          errors.add('Product name cannot be empty');
        }

        if (product.count < 0) {
          errors.add('Count cannot be negative');
        }

        if (product.mrp < 0) {
          errors.add('MRP cannot be negative');
        }

        if (product.pp < 0) {
          errors.add('Purchase price cannot be negative');
        }

        if (product.pp > product.mrp) {
          errors.add('Purchase price cannot be higher than MRP');
        }

        if (errors.isNotEmpty) {
          validationErrors[product.id] = errors;
        }
      }

      if (validationErrors.isNotEmpty) {
        emit(
          ProductValidationError(
            products: event.products,
            validationErrors: validationErrors,
            generalError: 'Please fix the validation errors before saving',
          ),
        );
      } else {
        add(SaveProducts(products: event.products));
      }

      debugPrint(
        'PRODUCT_BLOC: Validation completed - ${validationErrors.length} products with errors',
      );
    } catch (error) {
      debugPrint('PRODUCT_BLOC: Error validating products: $error');
      emit(
        ProductError(
          message: 'Failed to validate products',
          details: error.toString(),
          errorCode: 'VALIDATION_ERROR',
          timestamp: DateTime.now(),
          lastKnownProducts: event.products,
        ),
      );
    }
  }

  /// Start auto-save timer to save changes after a delay
  void _startAutoSaveTimer() {
    _autoSaveTimer?.cancel();
    _autoSaveTimer = Timer(const Duration(seconds: 3), () {
      if (_hasPendingChanges && _currentProducts.isNotEmpty) {
        debugPrint('PRODUCT_BLOC: Auto-saving products');
        add(SaveProducts(products: _currentProducts, forceSyncToShared: false));
      }
    });
  }

  List<Product> get currentProducts => _currentProducts;

  bool get hasPendingChanges => _hasPendingChanges;

  String get instanceId => _config.instanceId;

  Future<void> _onPrintDebugLogs(
    PrintDebugLogs event,
    Emitter<ProductState> emit,
  ) async {
    await printDebugLogs();
  }

  Future<void> printDebugLogs() async {
    await _databaseService.printAllLogs();
  }

  @override
  Future<void> close() {
    debugPrint('PRODUCT_BLOC: Closing ProductBloc for ${_config.instanceId}');
    _productsSubscription?.cancel();
    _autoSaveTimer?.cancel();
    _syncRetryTimer?.cancel();
    return super.close();
  }
}
