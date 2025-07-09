import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:isar/isar.dart';
import 'package:path_provider/path_provider.dart';
import '../../config.dart';
import '../models/product.dart';
import '../models/shared_product.dart';
import 'content_provider_service.dart';

/// Enhanced database service that manages both local Isar database and shared ContentProvider
/// This implements the dual-database architecture required by the specifications
class EnhancedDatabaseService {
  final AppConfig config;
  
  late final Isar _localDb;
  late final ContentProviderService _contentProviderService;
  
  Timer? _syncTimer;
  StreamSubscription? _contentProviderSubscription;
  DateTime _lastSyncTimestamp = DateTime.fromMillisecondsSinceEpoch(0);
  
  bool _isInitialized = false;
  bool _isSyncing = false;

  EnhancedDatabaseService({required this.config});

  // Getters
  Isar get localDb => _localDb;
  ContentProviderService get contentProviderService => _contentProviderService;
  bool get isInitialized => _isInitialized;

  /// Initialize both local Isar database and ContentProvider service
  Future<void> init() async {
    debugPrint('ENHANCED_DB: Initializing Enhanced Database Service for ${config.instanceId}');
    
    try {
      // Initialize Isar core
      await Isar.initializeIsarCore(download: true);
      debugPrint('ENHANCED_DB: Isar core initialized');

      // Initialize local Isar database
      await _initLocalDatabase();
      
      // Initialize ContentProvider service for shared database
      await _initContentProvider();
      
      // Seed initial data if needed
      await _seedInitialData();
      
      // Start periodic sync
      _startPeriodicSync();
      
      _isInitialized = true;
      debugPrint('ENHANCED_DB: Initialization complete for ${config.instanceId}');
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
    
    debugPrint('ENHANCED_DB: Local Isar database opened at: ${dir.path}/${config.localDbName}');
  }

  /// Initialize ContentProvider service for shared database access
  Future<void> _initContentProvider() async {
    _contentProviderService = ContentProviderService();
    await _contentProviderService.init();
    
    // Listen for changes in shared database
    _contentProviderSubscription = _contentProviderService.onDataChanged.listen((_) {
      debugPrint('ENHANCED_DB: ContentProvider data changed, triggering sync');
      _performSync();
    });
    
    debugPrint('ENHANCED_DB: ContentProvider service initialized');
  }

  /// Seed initial data if local database is empty
  Future<void> _seedInitialData() async {
    final localProductCount = await _localDb.products.count();
    
    if (localProductCount == 0) {
      final initialProduct = Product(
        name: 'Panadol',
        imagePath: 'https://via.placeholder.com/150/92c952/FFFFFF?Text=Medicine',
        count: 1,
        packagingType: 'Packs',
        mrp: 10.0,
        pp: 20.0,
        lastUpdated: DateTime.now(),
        updatedBy: config.instanceId,
        version: 1,
        isDeleted: false,
      );
      
      await _localDb.writeTxn(() async {
        await _localDb.products.put(initialProduct);
      });
      
      debugPrint('ENHANCED_DB: Seeded initial data for ${config.instanceId}');
    }
  }

  /// Start periodic sync with shared database
  void _startPeriodicSync() {
    _syncTimer = Timer.periodic(const Duration(seconds: 10), (_) async {
      if (!_isSyncing) {
        await _performSync();
      }
    });
    
    debugPrint('ENHANCED_DB: Started periodic sync every 10 seconds');
  }

  /// Perform bidirectional sync between local and shared databases
  Future<void> _performSync() async {
    if (_isSyncing) {
      debugPrint('ENHANCED_DB: Sync already in progress, skipping');
      return;
    }

    _isSyncing = true;
    
    try {
      debugPrint('ENHANCED_DB: Starting sync for ${config.instanceId}');
      
      // Step 1: Push local changes to shared database
      await _pushLocalChangesToShared();
      
      // Step 2: Pull changes from shared database
      await _pullChangesFromShared();
      
      debugPrint('ENHANCED_DB: Sync completed for ${config.instanceId}');
    } catch (e) {
      debugPrint('ENHANCED_DB: Sync error for ${config.instanceId}: $e');
    } finally {
      _isSyncing = false;
    }
  }

  /// Push local database changes to shared ContentProvider database
  Future<void> _pushLocalChangesToShared() async {
    try {
      // Get products that have been modified since last sync
      final localProducts = await _localDb.products
          .where()
          .filter()
          .lastUpdatedGreaterThan(_lastSyncTimestamp)
          .and()
          .updatedByEqualTo(config.instanceId)
          .findAll();
      
      if (localProducts.isEmpty) {
        debugPrint('ENHANCED_DB: No local changes to push');
        return;
      }

      debugPrint('ENHANCED_DB: Pushing ${localProducts.length} local changes to shared DB');
      
      final sharedProducts = <SharedProduct>[];
      
      for (final localProduct in localProducts) {
        try {
          // Check if product exists in shared database
          final existingSharedProduct = await _contentProviderService.getProduct(localProduct.id.toString());
          
          if (existingSharedProduct == null || 
              localProduct.lastUpdated.isAfter(existingSharedProduct.lastUpdated)) {
            // Local version is newer, add to push list
            sharedProducts.add(SharedProduct.fromIsarProduct(localProduct));
          } else if (existingSharedProduct.lastUpdated.isAfter(localProduct.lastUpdated)) {
            // Shared version is newer, update local with shared data
            final updatedLocalProduct = existingSharedProduct.toIsarProduct();
            await _localDb.writeTxn(() async {
              await _localDb.products.put(updatedLocalProduct);
            });
            
            debugPrint('ENHANCED_DB: Updated local ${existingSharedProduct.name} from shared DB');
          }
        } catch (e) {
          debugPrint('ENHANCED_DB: Error processing product ${localProduct.id}: $e');
        }
      }
      
      // Batch insert/update to shared database
      if (sharedProducts.isNotEmpty) {
        final success = await _contentProviderService.insertOrUpdateProducts(sharedProducts);
        if (success) {
          debugPrint('ENHANCED_DB: Successfully pushed ${sharedProducts.length} products to shared DB');
        } else {
          debugPrint('ENHANCED_DB: Failed to push products to shared DB');
        }
      }
      
    } catch (e) {
      debugPrint('ENHANCED_DB: Error pushing local changes: $e');
    }
  }

  /// Pull changes from shared ContentProvider database to local database
  Future<void> _pullChangesFromShared() async {
    try {
      // Get products updated after our last sync timestamp
      final updatedSharedProducts = await _contentProviderService.getProductsUpdatedAfter(_lastSyncTimestamp);
      
      if (updatedSharedProducts.isEmpty) {
        debugPrint('ENHANCED_DB: No changes to pull from shared DB');
        return;
      }

      debugPrint('ENHANCED_DB: Pulling ${updatedSharedProducts.length} changes from shared DB');
      
      final productsToUpdate = <Product>[];
      
      for (final sharedProduct in updatedSharedProducts) {
        // Skip if this product was updated by current instance
        if (sharedProduct.updatedBy == config.instanceId) {
          continue;
        }
        
        try {
          final localProduct = await _localDb.products.get(int.parse(sharedProduct.id));
          
          if (localProduct == null || 
              sharedProduct.lastUpdated.isAfter(localProduct.lastUpdated)) {
            // Shared version is newer or product doesn't exist locally
            productsToUpdate.add(sharedProduct.toIsarProduct());
            debugPrint('ENHANCED_DB: Will update local ${sharedProduct.name} from shared DB');
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
      }
      
      // Update last sync timestamp
      _lastSyncTimestamp = DateTime.now();
      
    } catch (e) {
      debugPrint('ENHANCED_DB: Error pulling changes from shared DB: $e');
    }
  }

  /// Save product to local database and mark for sync
  /// This is called when user makes changes in the UI
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
      
      // Trigger immediate sync if online
      if (!_isSyncing) {
        _performSync();
      }
    } catch (e) {
      debugPrint('ENHANCED_DB: Error saving product: $e');
      rethrow;
    }
  }

  /// Save multiple products to local database
  Future<void> saveProducts(List<Product> products) async {
    try {
      final now = DateTime.now();
      final updatedProducts = products.map((p) => p.copyWith(
        lastUpdated: now,
        updatedBy: config.instanceId,
        version: p.version + 1,
      )).toList();
      
      await _localDb.writeTxn(() async {
        await _localDb.products.putAll(updatedProducts);
      });
      
      debugPrint('ENHANCED_DB: Saved ${products.length} products locally');
      
      // Trigger immediate sync if online
      if (!_isSyncing) {
        _performSync();
      }
    } catch (e) {
      debugPrint('ENHANCED_DB: Error saving products: $e');
      rethrow;
    }
  }

  /// Get all products from local database
  List<Product> getAllProducts() {
    try {
      return _localDb.products.where().filter().isDeletedEqualTo(false).findAllSync();
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
        
        // Trigger immediate sync
        if (!_isSyncing) {
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
    debugPrint('ENHANCED_DB: Force sync triggered for ${config.instanceId}');
    await _performSync();
  }

  /// Get sync status information
  Map<String, dynamic> getSyncStatus() {
    return {
      'instanceId': config.instanceId,
      'isInitialized': _isInitialized,
      'isSyncing': _isSyncing,
      'lastSyncTimestamp': _lastSyncTimestamp.toIso8601String(),
    };
  }

  /// Dispose of the service
  Future<void> dispose() async {
    debugPrint('ENHANCED_DB: Disposing Enhanced Database Service for ${config.instanceId}');
    
    _syncTimer?.cancel();
    await _contentProviderSubscription?.cancel();
    _contentProviderService.dispose();
    await _localDb.close();
  }
}