import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:isar/isar.dart';
import 'package:path_provider/path_provider.dart';
import '../../config.dart';
import '../models/product.dart';
import '../models/shared_product.dart';
import 'content_provider_service.dart';
import 'connectivity_service.dart';

/// Enhanced database service that manages both local Isar database and shared ContentProvider
/// This implements the dual-database architecture with offline-first approach
class EnhancedDatabaseService {
  final AppConfig config;

  late final Isar _localDb;
  late final ContentProviderService _contentProviderService;
  late final ConnectivityService _connectivityService;

  Timer? _syncTimer;
  Timer? _networkRetryTimer;
  StreamSubscription? _contentProviderSubscription;
  StreamSubscription? _connectivitySubscription;
  DateTime _lastSyncTimestamp = DateTime.fromMillisecondsSinceEpoch(0);

  bool _isInitialized = false;
  bool _isSyncing = false;
  bool _isOnline = false;
  bool _hasPendingOfflineChanges = false;

  EnhancedDatabaseService({required this.config});

  // Getters
  Isar get localDb => _localDb;
  ContentProviderService get contentProviderService => _contentProviderService;
  bool get isInitialized => _isInitialized;
  bool get isOnline => _isOnline;

  /// Initialize both local Isar database and ContentProvider service
  Future<void> init() async {
    debugPrint(
      'ENHANCED_DB: Initializing Enhanced Database Service for ${config.instanceId}',
    );

    try {
      // Initialize connectivity service first
      _connectivityService = ConnectivityService();
      _isOnline = await _connectivityService.isOnline();
      debugPrint(
        'ENHANCED_DB: Initial connectivity status: ${_isOnline ? "Online" : "Offline"}',
      );

      // Initialize Isar core
      await Isar.initializeIsarCore(download: true);
      debugPrint('ENHANCED_DB: Isar core initialized');

      // Initialize local Isar database
      await _initLocalDatabase();

      // Initialize ContentProvider service for shared database
      await _initContentProvider();

      // Start connectivity monitoring
      _startConnectivityMonitoring();

      // Seed initial data if needed (offline-first approach)
      await _seedInitialDataOfflineFirst();

      // Start periodic sync only if online
      if (_isOnline) {
        _startPeriodicSync();
      }

      _isInitialized = true;
      debugPrint(
        'ENHANCED_DB: Initialization complete for ${config.instanceId}',
      );
    } catch (e) {
      debugPrint('ENHANCED_DB: Initialization failed: $e');
      rethrow;
    }
  }

  /// Initialize local Isar database for offline storage
  Future<void> _initLocalDatabase() async {
    final dir = await getApplicationDocumentsDirectory();

    _localDb = await Isar.open(
      [ProductSchema],
      directory: dir.path,
      name: config.localDbName,
    );

    debugPrint(
      'ENHANCED_DB: Local Isar database opened at: ${dir.path}/${config.localDbName}',
    );
  }

  /// Initialize ContentProvider service for shared database access
  Future<void> _initContentProvider() async {
    _contentProviderService = ContentProviderService();

    if (Platform.isAndroid) {
      await _contentProviderService.init();

      // Listen for changes in shared database (only when online)
      _contentProviderSubscription = _contentProviderService.onDataChanged
          .listen((_) {
            if (_isOnline) {
              debugPrint(
                'ENHANCED_DB: ContentProvider data changed, triggering sync',
              );
              _performSync();
            }
          });
    }

    debugPrint('ENHANCED_DB: ContentProvider service initialized');
  }

  /// Start monitoring connectivity changes
  void _startConnectivityMonitoring() {
    _connectivitySubscription = _connectivityService.onConnectivityChanged.listen(
      (isOnline) {
        final wasOnline = _isOnline;
        _isOnline = isOnline;

        debugPrint(
          'ENHANCED_DB: Connectivity changed - was: $wasOnline, now: $isOnline',
        );

        if (!wasOnline && isOnline) {
          // Just came online - start sync and periodic sync
          debugPrint('ENHANCED_DB: App came online, starting sync...');
          _performSync();
          _startPeriodicSync();
        } else if (wasOnline && !isOnline) {
          // Just went offline - stop periodic sync
          debugPrint('ENHANCED_DB: App went offline, stopping periodic sync');
          _stopPeriodicSync();
        }
      },
    );
  }

  /// Seed initial data with offline-first approach
 Future<void> _seedInitialDataOfflineFirst() async {
    final localProductCount = await _localDb.products.count();

    if (localProductCount > 0) {
      debugPrint('ENHANCED_DB: Local database already has $localProductCount products');
      if (_isOnline) {
        // Force sync to ensure we have latest data
        await _performSync();
      }
      return;
    }

    debugPrint('ENHANCED_DB: Local database is empty, checking for seed strategy...');

    if (_isOnline) {
      // Check shared database first
      try {
        final sharedProducts = await _contentProviderService.getAllProducts();

        if (sharedProducts.isNotEmpty) {
          debugPrint('ENHANCED_DB: Found ${sharedProducts.length} products in shared DB, syncing to local...');
          await _pullChangesFromShared();
          return;
        }
        
        // Race condition protection - wait and check again
        debugPrint('ENHANCED_DB: Shared DB empty, waiting 1000ms and rechecking...');
        await Future.delayed(const Duration(milliseconds: 1000));
        
        final sharedProductsRecheck = await _contentProviderService.getAllProducts();
        if (sharedProductsRecheck.isNotEmpty) {
          debugPrint('ENHANCED_DB: Found ${sharedProductsRecheck.length} products in shared DB on recheck, syncing...');
          await _pullChangesFromShared();
          return;
        }
        
      } catch (e) {
        debugPrint('ENHANCED_DB: Error checking shared database: $e, falling back to seed data');
      }
    }

    // Only create seed data if we're confident both local and shared are empty
    debugPrint('ENHANCED_DB: Creating seed data as both local and shared databases appear empty');
    await _createSeedData();
  }
  
  Future<void> _createSeedData() async {
    // Use the factory constructor
    final seedProduct = Product.create(
      name: 'Panadol Extra',
      imagePath:
          'https://images.unsplash.com/photo-1584308666744-24d5c474f2ae?w=300&h=300&fit=crop',
      count: 10,
      packagingType: 'Packs',
      mrp: 25.50,
      pp: 18.75,
      lastUpdated: DateTime.now(),
      updatedBy: config.instanceId,
      version: 1,
    );

    await _localDb.writeTxn(() async {
      await _localDb.products.put(seedProduct);
    });

    debugPrint(
      'ENHANCED_DB: Created seed data locally for ${config.instanceId}',
    );

    // If online, also push seed data to shared database
    if (_isOnline) {
      try {
        final sharedProduct = SharedProduct.fromIsarProduct(seedProduct);
        await _contentProviderService.insertOrUpdateProduct(sharedProduct);
        debugPrint('ENHANCED_DB: Pushed seed data to shared database');
      } catch (e) {
        debugPrint(
          'ENHANCED_DB: Failed to push seed data to shared database: $e',
        );
      }
    }
  }

  /// Start periodic sync with shared database (only when online)
  void _startPeriodicSync() {
    if (!_isOnline) return;

    _syncTimer?.cancel();
    _syncTimer = Timer.periodic(const Duration(seconds: 15), (_) async {
      if (_isOnline && !_isSyncing) {
        await _performSync();
      }
    });

    debugPrint('ENHANCED_DB: Started periodic sync every 15 seconds');
  }

  /// Stop periodic sync
  void _stopPeriodicSync() {
    _syncTimer?.cancel();
    debugPrint('ENHANCED_DB: Stopped periodic sync');
  }

  /// Schedule network connectivity retry
  void _scheduleNetworkRetry() {
    _networkRetryTimer?.cancel();
    _networkRetryTimer = Timer(const Duration(seconds: 5), () async {
      final isOnline = await _connectivityService.isOnline();
      if (isOnline != _isOnline) {
        _onConnectivityChanged(isOnline);
      }
    });
  }

    /// Handle connectivity changes with retry logic
  void _onConnectivityChanged(bool isOnline) async {
    final wasOffline = !_isOnline;
    _isOnline = isOnline;
    
    debugPrint('ENHANCED_DB: Connectivity changed to ${isOnline ? "ONLINE" : "OFFLINE"}');
    
    if (isOnline && wasOffline) {
      // Just came back online - wait a bit for network to stabilize
      debugPrint('ENHANCED_DB: Came back online, starting network stabilization wait...');
      
      _networkRetryTimer?.cancel();
      _networkRetryTimer = Timer(const Duration(seconds: 2), () async {
        // Double-check connectivity after delay
        final actuallyOnline = await _connectivityService.isOnline();
        _isOnline = actuallyOnline;
        
        if (actuallyOnline) {
          debugPrint('ENHANCED_DB: Network stabilized, performing recovery sync...');
          await _performRecoverySync();
        } else {
          debugPrint('ENHANCED_DB: Network still unstable, will retry...');
          // Retry in a few more seconds
          _scheduleNetworkRetry();
        }
      });
    } else if (isOnline) {
      _startPeriodicSync();
    } else {
      _stopPeriodicSync();
    }
  }

  /// Perform recovery sync when coming back online
  Future<void> _performRecoverySync() async {
    try {
      debugPrint('ENHANCED_DB: Starting recovery sync for ${config.instanceId}');
      
      // Force a comprehensive sync
      await _performSync();
      
      // Notify listeners that sync completed
      _notifyOtherInstances();
      
      // Start regular periodic sync
      _startPeriodicSync();
      
      debugPrint('ENHANCED_DB: Recovery sync completed successfully');
    } catch (e) {
      debugPrint('ENHANCED_DB: Recovery sync failed: $e');
      // Retry after a delay
      _scheduleNetworkRetry();
    }
  }
  
  /// Perform bidirectional sync between local and shared databases (only when online)
  Future<void> _performSync() async {
    if (!_isOnline) {
      debugPrint('ENHANCED_DB: Skipping sync - app is offline');
      return;
    }

    if (_isSyncing) {
      debugPrint('ENHANCED_DB: Sync already in progress, skipping');
      return;
    }

    _isSyncing = true;

    try {
      debugPrint('ENHANCED_DB: Starting sync for ${config.instanceId}');

      // Step 1: Push local changes to shared database
      final pushSuccess = await _pushLocalChangesToShared();

      // Step 2: Pull changes from shared database
      final pullSuccess = await _pullChangesFromShared();

       if (pushSuccess || pullSuccess) {
        // Something changed, notify other instances
        _notifyOtherInstances();
      }


      debugPrint('ENHANCED_DB: Sync completed for ${config.instanceId}');
    } catch (e) {
      debugPrint('ENHANCED_DB: Sync error for ${config.instanceId}: $e');
      rethrow;
    } finally {
      _isSyncing = false;
    }
  }

  /// Push local database changes to shared ContentProvider database
  Future<bool> _pushLocalChangesToShared() async {
    if (!_isOnline) return false;

    try {
      // Get products that have been modified since last sync by this instance
      final localProducts =
          await _localDb.products
              .where()
              .filter()
              .lastUpdatedGreaterThan(_lastSyncTimestamp)
              .and()
              .updatedByEqualTo(config.instanceId)
              .findAll();

      if (localProducts.isEmpty) {
        debugPrint('ENHANCED_DB: No local changes to push');
        return false;
      }

      debugPrint(
        'ENHANCED_DB: Pushing ${localProducts.length} local changes to shared DB',
      );

      final sharedProducts = <SharedProduct>[];

      for (final localProduct in localProducts) {
        try {
          final existingSharedProduct = await _contentProviderService
              .getProduct(localProduct.sharedId);

          if (existingSharedProduct == null) {
            // New product, add to push list
            sharedProducts.add(SharedProduct.fromIsarProduct(localProduct));
            debugPrint(
              'ENHANCED_DB: Will push new product ${localProduct.name}',
            );
          } else if (localProduct.lastUpdated.isAfter(
            existingSharedProduct.lastUpdated,
          )) {
            // Local version is newer, add to push list
            sharedProducts.add(SharedProduct.fromIsarProduct(localProduct));
            debugPrint(
              'ENHANCED_DB: Will push updated product ${localProduct.name} (local newer)',
            );
          } else if (existingSharedProduct.lastUpdated.isAfter(
            localProduct.lastUpdated,
          )) {
            // Shared version is newer, handle conflict
            await _handleConflict(localProduct, existingSharedProduct);
          }
        } catch (e) {
          debugPrint(
            'ENHANCED_DB: Error processing product ${localProduct.sharedId}: $e',
          );
        }
      }

      // Batch insert/update to shared database
      if (sharedProducts.isNotEmpty) {
        final success = await _contentProviderService.insertOrUpdateProducts(sharedProducts);
        if (success) {
          debugPrint('ENHANCED_DB: Successfully pushed ${sharedProducts.length} products to shared DB');
          return true;
        } else {
          debugPrint('ENHANCED_DB: Failed to push products to shared DB');
          return false;
        }
      }

        return false;

    } catch (e) {
      debugPrint('ENHANCED_DB: Error pushing local changes: $e');
      return false;
    }
  }

  /// Pull changes from shared ContentProvider database to local database
  Future<bool> _pullChangesFromShared() async {
    if (!_isOnline) return false;

    try {
      // Get products updated after our last sync timestamp
      final updatedSharedProducts = await _contentProviderService.getProductsUpdatedAfter(_lastSyncTimestamp);
      
      if (updatedSharedProducts.isEmpty) {
        debugPrint('ENHANCED_DB: No changes to pull from shared DB');
        return false;
      }

      debugPrint('ENHANCED_DB: Pulling ${updatedSharedProducts.length} changes from shared DB');
      
      final productsToUpdate = <Product>[];
      
      for (final sharedProduct in updatedSharedProducts) {
        // Skip if this product was updated by current instance
        if (sharedProduct.updatedBy == config.instanceId) {
          continue;
        }
        
        try {
          // Find local product by sharedId
          final localProduct = await _localDb.products
              .where()
              .sharedIdEqualTo(sharedProduct.id)
              .findFirst();
          
          if (localProduct == null) {
            // Product doesn't exist locally, add it
            productsToUpdate.add(sharedProduct.toIsarProduct());
            debugPrint('ENHANCED_DB: Will add new product ${sharedProduct.name} from shared DB');
          } else if (sharedProduct.lastUpdated.isAfter(localProduct.lastUpdated)) {
            // Shared version is newer, update local
            final updatedProduct = sharedProduct.toIsarProduct();
            // Keep the local Isar ID but update sharedId and all other fields
            final productToUpdate = updatedProduct.copyWith(id: localProduct.id);
            productsToUpdate.add(productToUpdate);
            debugPrint('ENHANCED_DB: Will update local ${sharedProduct.name} from shared DB');
          } else if (localProduct.lastUpdated.isAfter(sharedProduct.lastUpdated)) {
            // Local version is newer, handle conflict
            await _handleConflict(localProduct, sharedProduct);
          }
        } catch (e) {
          debugPrint('ENHANCED_DB: Error processing shared product ${sharedProduct.id}: $e');
        }
      }
      
      // Batch update local database
      if (productsToUpdate.isNotEmpty) {
        await _localDb.writeTxn(() async {
          await _localDb.products.putAll(productsToUpdate);
        });
        
        debugPrint('ENHANCED_DB: Updated ${productsToUpdate.length} products in local DB');
        
        // Update last sync timestamp
        _lastSyncTimestamp = DateTime.now();
        return true;
      }
      
      // Update last sync timestamp even if no products were updated
      _lastSyncTimestamp = DateTime.now();
      return false;
      
    } catch (e) {
      debugPrint('ENHANCED_DB: Error pulling changes from shared DB: $e');
      return false;
    }
  }

    void _notifyOtherInstances() {
    try {
      // This could be implemented by writing a special "notification" record
      // or using a broadcast mechanism if available
      debugPrint('ENHANCED_DB: Notifying other instances of data changes');
    } catch (e) {
      debugPrint('ENHANCED_DB: Failed to notify other instances: $e');
    }
  }
  /// Handle conflicts between local and shared versions gracefully
  Future<void> _handleConflict(
    Product localProduct,
    SharedProduct sharedProduct,
  ) async {
    debugPrint(
      'ENHANCED_DB: Handling conflict for product ${localProduct.name}',
    );
    debugPrint(
      'ENHANCED_DB: Local version: ${localProduct.version}, updated: ${localProduct.lastUpdated}',
    );
    debugPrint(
      'ENHANCED_DB: Shared version: ${sharedProduct.version}, updated: ${sharedProduct.lastUpdated}',
    );

    try {
      // Conflict resolution strategy: Merge changes intelligently
      final mergedProduct = _mergeProducts(localProduct, sharedProduct);

      // Update local database with merged version
      await _localDb.writeTxn(() async {
        await _localDb.products.put(mergedProduct);
      });

      // If online, also update shared database with merged version
      if (_isOnline) {
        final mergedSharedProduct = SharedProduct.fromIsarProduct(
          mergedProduct,
        );
        await _contentProviderService.insertOrUpdateProduct(
          mergedSharedProduct,
        );
      }

      debugPrint(
        'ENHANCED_DB: Successfully merged conflicting versions for ${localProduct.name}',
      );
    } catch (e) {
      debugPrint('ENHANCED_DB: Error handling conflict: $e');
      // Fallback: Keep the version with higher version number
      if (sharedProduct.version > localProduct.version) {
        final fallbackProduct = sharedProduct.toIsarProduct();
        await _localDb.writeTxn(() async {
          await _localDb.products.put(fallbackProduct);
        });
        debugPrint(
          'ENHANCED_DB: Fallback: Used shared version (higher version number)',
        );
      }
    }
  }

  /// Merge two product versions intelligently
  Product _mergeProducts(Product localProduct, SharedProduct sharedProduct) {
    // Create a merged version with the latest timestamp and incremented version
    final mergedVersion =
        [
          localProduct.version,
          sharedProduct.version,
        ].reduce((a, b) => a > b ? a : b) +
        1;
    final now = DateTime.now();

    // Use the most recent non-zero/non-empty values for each field
    return localProduct.copyWith(
      name: _chooseLatestValue(
        localProduct.name,
        localProduct.lastUpdated,
        sharedProduct.name,
        sharedProduct.lastUpdated,
      ),
      imagePath: _chooseLatestValue(
        localProduct.imagePath,
        localProduct.lastUpdated,
        sharedProduct.imagePath,
        sharedProduct.lastUpdated,
      ),
      count: _chooseLatestValue(
        localProduct.count,
        localProduct.lastUpdated,
        sharedProduct.count,
        sharedProduct.lastUpdated,
      ),
      packagingType: _chooseLatestValue(
        localProduct.packagingType,
        localProduct.lastUpdated,
        sharedProduct.packagingType,
        sharedProduct.lastUpdated,
      ),
      mrp: _chooseLatestValue(
        localProduct.mrp,
        localProduct.lastUpdated,
        sharedProduct.mrp,
        sharedProduct.lastUpdated,
      ),
      pp: _chooseLatestValue(
        localProduct.pp,
        localProduct.lastUpdated,
        sharedProduct.pp,
        sharedProduct.lastUpdated,
      ),
      lastUpdated: now,
      updatedBy: '${config.instanceId}_merged',
      version: mergedVersion,
      isDeleted: localProduct.isDeleted || sharedProduct.isDeleted,
    );
  }

  /// Choose the latest value between two timestamped values
  T _chooseLatestValue<T>(
    T localValue,
    DateTime localTime,
    T sharedValue,
    DateTime sharedTime,
  ) {
    return sharedTime.isAfter(localTime) ? sharedValue : localValue;
  }

  /// Save product to local database ONLY (no auto-sync)
  /// This is called when user makes changes in the UI but hasn't clicked "Save Changes"
  Future<void> saveProductLocally(Product product) async {
    try {
      final updatedProduct = product.copyWith(
        lastUpdated: DateTime.now(),
        updatedBy: config.instanceId,
        version: product.version + 1,
      );

      await _localDb.writeTxn(() async {
        await _localDb.products.put(updatedProduct);
      });

      debugPrint(
        'ENHANCED_DB: Saved product ${product.name} locally only (no sync)',
      );
    } catch (e) {
      debugPrint('ENHANCED_DB: Error saving product locally: $e');
      rethrow;
    }
  }

  /// Save product to local database and trigger sync if online
  /// This is called when user clicks "Save Changes"
  Future<void> saveProduct(Product product) async {
    try {
      final updatedProduct = product.copyWith(
        lastUpdated: DateTime.now(),
        updatedBy: config.instanceId,
        version: product.version + 1,
      );

      await _localDb.writeTxn(() async {
        await _localDb.products.put(updatedProduct);
      });

      debugPrint('ENHANCED_DB: Saved product ${product.name} locally');

      // Trigger sync if online
      if (_isOnline && !_isSyncing) {
        debugPrint('ENHANCED_DB: Triggering sync after save');
        _performSync();
      } else if (!_isOnline) {
        debugPrint(
          'ENHANCED_DB: Offline - will sync when connection is restored',
        );
      }
    } catch (e) {
      debugPrint('ENHANCED_DB: Error saving product: $e');
      rethrow;
    }
  }

  /// Save multiple products to local database and trigger sync if online
  Future<void> saveProducts(List<Product> products) async {
    try {
      final now = DateTime.now();
      final updatedProducts =
          products
              .map(
                (p) => p.copyWith(
                  lastUpdated: now,
                  updatedBy: config.instanceId,
                  version: p.version + 1,
                ),
              )
              .toList();

      await _localDb.writeTxn(() async {
        await _localDb.products.putAll(updatedProducts);
      });

      debugPrint('ENHANCED_DB: Saved ${products.length} products locally');

      // Trigger sync if online
      if (_isOnline && !_isSyncing) {
        debugPrint('ENHANCED_DB: Triggering sync after batch save');
        _performSync();
      } else if (!_isOnline) {
        debugPrint(
          'ENHANCED_DB: Offline - will sync when connection is restored',
        );
      }
    } catch (e) {
      debugPrint('ENHANCED_DB: Error saving products: $e');
      rethrow;
    }
  }

  /// Get all products from local database
  List<Product> getAllProducts() {
    try {
      return _localDb.products
          .where()
          .filter()
          .isDeletedEqualTo(false)
          .findAllSync();
    } catch (e) {
      debugPrint('ENHANCED_DB: Error getting all products: $e');
      return [];
    }
  }

  /// Get a specific product from local database
  Future<Product?> getProduct(int id) async {
    try {
      final product = await _localDb.products.get(id);
      return (product != null && !product.isDeleted) ? product : null;
    } catch (e) {
      debugPrint('ENHANCED_DB: Error getting product $id: $e');
      return null;
    }
  }

  /// Watch products in local database for real-time updates
  Stream<List<Product>> watchProducts() {
    return _localDb.products
        .where()
        .filter()
        .isDeletedEqualTo(false)
        .watch(fireImmediately: true);
  }

  /// Soft delete a product
  Future<void> deleteProduct(int id) async {
    try {
      final product = await _localDb.products.get(id);
      if (product != null) {
        final deletedProduct = product.copyWith(
          isDeleted: true,
          lastUpdated: DateTime.now(),
          updatedBy: config.instanceId,
          version: product.version + 1,
        );

        await _localDb.writeTxn(() async {
          await _localDb.products.put(deletedProduct);
        });

        debugPrint('ENHANCED_DB: Soft deleted product $id');

        // Trigger sync if online
        if (_isOnline && !_isSyncing) {
          _performSync();
        }
      }
    } catch (e) {
      debugPrint('ENHANCED_DB: Error deleting product $id: $e');
      rethrow;
    }
  }

  /// Force immediate sync (called from UI)
  Future<void> forceSyncWithShared() async {
    final actuallyOnline = await _connectivityService.isOnline();
    _isOnline = actuallyOnline;
    
    if (!_isOnline) {
      debugPrint('ENHANCED_DB: Cannot force sync - app is confirmed offline');
      throw Exception('Cannot sync while offline');
    }

    debugPrint('ENHANCED_DB: Force sync triggered for ${config.instanceId}');
    await _performSync();
  }

  /// Get sync status information
  Map<String, dynamic> getSyncStatus() {
    return {
      'instanceId': config.instanceId,
      'isInitialized': _isInitialized,
      'isOnline': _isOnline,
      'isSyncing': _isSyncing,
      'lastSyncTimestamp': _lastSyncTimestamp.toIso8601String(),
    };
  }

  /// Print detailed logs of local database contents
  Future<void> printLocalDatabaseLogs() async {
    try {
      debugPrint(
        '🔍 ======== LOCAL DATABASE LOGS [${config.instanceId}] ========',
      );
      debugPrint(
        '📍 Database Path: ${_localDb.directory}/${config.localDbName}',
      );

      final allProducts = await _localDb.products.where().findAll();
      final activeProducts = allProducts.where((p) => !p.isDeleted).toList();
      final deletedProducts = allProducts.where((p) => p.isDeleted).toList();

      debugPrint('📊 Total Products: ${allProducts.length}');
      debugPrint('✅ Active Products: ${activeProducts.length}');
      debugPrint('🗑️  Deleted Products: ${deletedProducts.length}');
      debugPrint('💾 Database Size: ${await _getDatabaseSize()}');

      debugPrint('\n📋 ACTIVE PRODUCTS:');
      if (activeProducts.isNotEmpty) {
        for (int i = 0; i < activeProducts.length; i++) {
          final product = activeProducts[i];
          debugPrint('  ${i + 1}. ${_formatProductLog(product)}');
        }
      } else {
        debugPrint('  (No active products)');
      }

      if (deletedProducts.isNotEmpty) {
        debugPrint('\n🗑️  DELETED PRODUCTS:');
        for (int i = 0; i < deletedProducts.length; i++) {
          final product = deletedProducts[i];
          debugPrint('  ${i + 1}. ${_formatProductLog(product)}');
        }
      }

      debugPrint(
        '🔍 ======== END LOCAL DATABASE LOGS [${config.instanceId}] ========\n',
      );
    } catch (e) {
      debugPrint('❌ Error printing local database logs: $e');
    }
  }

  /// Print detailed logs of shared ContentProvider database
  Future<void> printSharedDatabaseLogs() async {
    try {
      debugPrint('🌐 ======== SHARED DATABASE LOGS (ContentProvider) ========');

      if (!Platform.isAndroid) {
        debugPrint('⚠️  ContentProvider only available on Android');
        debugPrint('🌐 ======== END SHARED DATABASE LOGS ========\n');
        return;
      }

      final allSharedProducts = await _contentProviderService.getAllProducts();
      final activeSharedProducts =
          allSharedProducts.where((p) => !p.isDeleted).toList();
      final deletedSharedProducts =
          allSharedProducts.where((p) => p.isDeleted).toList();

      debugPrint('📊 Total Shared Products: ${allSharedProducts.length}');
      debugPrint('✅ Active Shared Products: ${activeSharedProducts.length}');
      debugPrint(
        '🗑️  Deleted Shared Products: ${deletedSharedProducts.length}',
      );
      debugPrint('🔗 Authority: com.example.go_cart.shared.database');

      debugPrint('\n📋 ACTIVE SHARED PRODUCTS:');
      if (activeSharedProducts.isNotEmpty) {
        for (int i = 0; i < activeSharedProducts.length; i++) {
          final product = activeSharedProducts[i];
          debugPrint('  ${i + 1}. ${_formatSharedProductLog(product)}');
        }
      } else {
        debugPrint('  (No active shared products)');
      }

      if (deletedSharedProducts.isNotEmpty) {
        debugPrint('\n🗑️  DELETED SHARED PRODUCTS:');
        for (int i = 0; i < deletedSharedProducts.length; i++) {
          final product = deletedSharedProducts[i];
          debugPrint('  ${i + 1}. ${_formatSharedProductLog(product)}');
        }
      }

      debugPrint('🌐 ======== END SHARED DATABASE LOGS ========\n');
    } catch (e) {
      debugPrint('❌ Error printing shared database logs: $e');
    }
  }

  /// Print comparison between local and shared databases
  Future<void> printDatabaseComparison() async {
    try {
      debugPrint(
        '⚖️  ======== DATABASE COMPARISON [${config.instanceId}] ========',
      );

      final localProducts =
          await _localDb.products
              .where()
              .filter()
              .isDeletedEqualTo(false)
              .findAll();
      final sharedProducts =
          Platform.isAndroid
              ? await _contentProviderService.getAllProducts().then(
                (products) => products.where((p) => !p.isDeleted).toList(),
              )
              : <SharedProduct>[];

      debugPrint('📱 Local DB Count: ${localProducts.length}');
      debugPrint('🌐 Shared DB Count: ${sharedProducts.length}');

      final localOnlyProducts = <Product>[];
      final sharedOnlyProducts = <SharedProduct>[];
      final conflictingProducts = <Map<String, dynamic>>[];

      for (final localProduct in localProducts) {
        // ✅ FIX: Use sharedId for matching
        final matchingShared =
            sharedProducts
                .where((sp) => sp.id == localProduct.sharedId)
                .firstOrNull;
        if (matchingShared == null) {
          localOnlyProducts.add(localProduct);
        } else {
          // Check for conflicts
          if (localProduct.lastUpdated != matchingShared.lastUpdated ||
              localProduct.version != matchingShared.version) {
            conflictingProducts.add({
              'local': localProduct,
              'shared': matchingShared,
            });
          }
        }
      }

      for (final sharedProduct in sharedProducts) {
        // ✅ FIX: Use sharedId for matching
        final matchingLocal =
            localProducts
                .where((lp) => lp.sharedId == sharedProduct.id)
                .firstOrNull;
        if (matchingLocal == null) {
          sharedOnlyProducts.add(sharedProduct);
        }
      }

      // ... rest of the method remains the same
    } catch (e) {
      debugPrint('❌ Error printing database comparison: $e');
    }
  }

  /// Print comprehensive sync status
  Future<void> printSyncStatus() async {
    try {
      debugPrint('📊 ======== SYNC STATUS [${config.instanceId}] ========');
      debugPrint('🔧 Instance ID: ${config.instanceId}');
      debugPrint('🏗️  Initialized: ${_isInitialized ? "✅" : "❌"}');
      debugPrint('🌐 Online: ${_isOnline ? "✅" : "❌"}');
      debugPrint('🔄 Currently Syncing: ${_isSyncing ? "✅" : "❌"}');
      debugPrint('⏰ Last Sync: ${_formatDateTime(_lastSyncTimestamp)}');
      debugPrint('📦 Local DB Name: ${config.localDbName}');

      if (_isOnline) {
        debugPrint('🔗 ContentProvider Status: Connected');
      } else {
        debugPrint('🔗 ContentProvider Status: Offline');
      }

      // Get recent activity
      final recentProducts =
          await _localDb.products
              .where()
              .sortByLastUpdatedDesc()
              .limit(5)
              .findAll();

      debugPrint('\n📝 RECENT ACTIVITY (Last 5 updates):');
      for (int i = 0; i < recentProducts.length; i++) {
        final product = recentProducts[i];
        debugPrint(
          '  ${i + 1}. ${product.name} - ${_formatDateTime(product.lastUpdated)} by ${product.updatedBy}',
        );
      }

      debugPrint('📊 ======== END SYNC STATUS ========\n');
    } catch (e) {
      debugPrint('❌ Error printing sync status: $e');
    }
  }

  /// Print all logs - comprehensive overview
  Future<void> printAllLogs() async {
    await printSyncStatus();
    await printLocalDatabaseLogs();
    await printSharedDatabaseLogs();
    await printDatabaseComparison();
  }

  // Helper methods for formatting logs
  String _formatProductLog(Product product) {
    return 'ID:${product.id} | ${product.name} | Count:${product.count} | '
        'MRP:₹${product.mrp.toStringAsFixed(2)} | PP:₹${product.pp.toStringAsFixed(2)} | '
        'v${product.version} | ${_formatDateTime(product.lastUpdated)} | '
        'by:${product.updatedBy}${product.isDeleted ? " [DELETED]" : ""}';
  }

  String _formatSharedProductLog(SharedProduct product) {
    return 'ID:${product.id} | ${product.name} | Count:${product.count} | '
        'MRP:₹${product.mrp.toStringAsFixed(2)} | PP:₹${product.pp.toStringAsFixed(2)} | '
        'v${product.version} | ${_formatDateTime(product.lastUpdated)} | '
        'by:${product.updatedBy}${product.isDeleted ? " [DELETED]" : ""}';
  }

  String _formatDateTime(DateTime dateTime) {
    if (dateTime.millisecondsSinceEpoch == 0) return 'Never';
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inSeconds < 60) {
      return '${difference.inSeconds}s ago';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else {
      return '${difference.inDays}d ago';
    }
  }

  Future<String> _getDatabaseSize() async {
    try {
      final dbFile = File('${_localDb.directory}/${config.localDbName}');
      if (await dbFile.exists()) {
        final size = await dbFile.length();
        if (size < 1024) {
          return '${size}B';
        } else if (size < 1024 * 1024) {
          return '${(size / 1024).toStringAsFixed(1)}KB';
        } else {
          return '${(size / (1024 * 1024)).toStringAsFixed(1)}MB';
        }
      }
      return 'Unknown';
    } catch (e) {
      return 'Error: $e';
    }
  }

  /// Dispose of the service
  Future<void> dispose() async {
    debugPrint(
      'ENHANCED_DB: Disposing Enhanced Database Service for ${config.instanceId}',
    );

    _stopPeriodicSync();
    _networkRetryTimer?.cancel();
    await _connectivitySubscription?.cancel();
    await _contentProviderSubscription?.cancel();
    _contentProviderService.dispose();
    await _localDb.close();
  }

}
