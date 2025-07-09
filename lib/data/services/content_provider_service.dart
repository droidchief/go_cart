import 'dart:async';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import '../models/shared_product.dart';

/// Service to interact with Android ContentProvider for shared database
/// This handles all cross-app database operations via ContentProvider
class ContentProviderService {
  static const String _authority = 'com.example.go_cart.shared.database';
  static const String _productsTable = 'products';
  static const MethodChannel _channel = MethodChannel('content_provider_channel');

  /// Initialize the ContentProvider service
  Future<void> init() async {
    if (!Platform.isAndroid) {
      debugPrint('ContentProvider: Only available on Android');
      return;
    }

    try {
      _channel.setMethodCallHandler(_handleMethodCall);
      debugPrint('ContentProvider: Service initialized');
    } catch (e) {
      debugPrint('ContentProvider: Failed to initialize: $e');
      rethrow;
    }
  }

  /// Handle method calls from native Android code
  Future<dynamic> _handleMethodCall(MethodCall call) async {
    switch (call.method) {
      case 'onDataChanged':
        // Notify listeners when ContentProvider data changes
        _dataChangeController.add(null);
        return null;
      default:
        throw PlatformException(
          code: 'Unimplemented',
          details: 'Method ${call.method} not implemented',
        );
    }
  }

  final StreamController<void> _dataChangeController = StreamController<void>.broadcast();
  
  /// Stream that emits when shared database data changes
  Stream<void> get onDataChanged => _dataChangeController.stream;

  /// Insert or update a product in the shared database
  Future<bool> insertOrUpdateProduct(SharedProduct product) async {
    if (!Platform.isAndroid) return false;

    try {
      final result = await _channel.invokeMethod('insertProduct', {
        'authority': _authority,
        'table': _productsTable,
        'data': product.toMap(),
      });

      debugPrint('ContentProvider: Inserted/Updated product ${product.name} - Result: $result');
      return result == true;
    } catch (e) {
      debugPrint('ContentProvider: Failed to insert/update product ${product.name}: $e');
      return false;
    }
  }

  /// Insert or update multiple products in the shared database
  Future<bool> insertOrUpdateProducts(List<SharedProduct> products) async {
    if (!Platform.isAndroid) return false;

    try {
      final productsData = products.map((p) => p.toMap()).toList();
      
      final result = await _channel.invokeMethod('insertProducts', {
        'authority': _authority,
        'table': _productsTable,
        'dataList': productsData,
      });

      debugPrint('ContentProvider: Batch inserted/updated ${products.length} products - Result: $result');
      return result == true;
    } catch (e) {
      debugPrint('ContentProvider: Failed to batch insert/update products: $e');
      return false;
    }
  }

  /// Get all products from the shared database
  Future<List<SharedProduct>> getAllProducts() async {
    if (!Platform.isAndroid) return [];

    try {
      final result = await _channel.invokeMethod('queryProducts', {
        'authority': _authority,
        'table': _productsTable,
        'selection': 'is_deleted = ?',
        'selectionArgs': ['0'],
      });

      if (result is List) {
        final products = result
            .cast<Map<dynamic, dynamic>>()
            .map((map) => SharedProduct.fromMap(Map<String, dynamic>.from(map)))
            .toList();

        debugPrint('ContentProvider: Retrieved ${products.length} products');
        return products;
      }

      return [];
    } catch (e) {
      debugPrint('ContentProvider: Failed to get all products: $e');
      return [];
    }
  }

  /// Get a specific product by ID from the shared database
  Future<SharedProduct?> getProduct(String id) async {
    if (!Platform.isAndroid) return null;

    try {
      final result = await _channel.invokeMethod('queryProducts', {
        'authority': _authority,
        'table': _productsTable,
        'selection': 'id = ? AND is_deleted = ?',
        'selectionArgs': [id, '0'],
      });

      if (result is List && result.isNotEmpty) {
        final map = Map<String, dynamic>.from(result.first);
        final product = SharedProduct.fromMap(map);
        debugPrint('ContentProvider: Retrieved product ${product.name}');
        return product;
      }

      return null;
    } catch (e) {
      debugPrint('ContentProvider: Failed to get product $id: $e');
      return null;
    }
  }

  /// Get products updated after a specific timestamp
  Future<List<SharedProduct>> getProductsUpdatedAfter(DateTime timestamp) async {
    if (!Platform.isAndroid) return [];

    try {
      final result = await _channel.invokeMethod('queryProducts', {
        'authority': _authority,
        'table': _productsTable,
        'selection': 'last_updated > ? AND is_deleted = ?',
        'selectionArgs': [timestamp.millisecondsSinceEpoch.toString(), '0'],
      });

      if (result is List) {
        final products = result
            .cast<Map<dynamic, dynamic>>()
            .map((map) => SharedProduct.fromMap(Map<String, dynamic>.from(map)))
            .toList();

        debugPrint('ContentProvider: Retrieved ${products.length} products updated after $timestamp');
        return products;
      }

      return [];
    } catch (e) {
      debugPrint('ContentProvider: Failed to get products updated after $timestamp: $e');
      return [];
    }
  }

  /// Soft delete a product (mark as deleted)
  Future<bool> deleteProduct(String id) async {
    if (!Platform.isAndroid) return false;

    try {
      final result = await _channel.invokeMethod('updateProduct', {
        'authority': _authority,
        'table': _productsTable,
        'data': {'is_deleted': 1},
        'selection': 'id = ?',
        'selectionArgs': [id],
      });

      debugPrint('ContentProvider: Soft deleted product $id - Result: $result');
      return result == true;
    } catch (e) {
      debugPrint('ContentProvider: Failed to delete product $id: $e');
      return false;
    }
  }

  /// Clear all products from the shared database
  Future<bool> clearAllProducts() async {
    if (!Platform.isAndroid) return false;

    try {
      final result = await _channel.invokeMethod('deleteProducts', {
        'authority': _authority,
        'table': _productsTable,
        'selection': null,
        'selectionArgs': null,
      });

      debugPrint('ContentProvider: Cleared all products - Result: $result');
      return result == true;
    } catch (e) {
      debugPrint('ContentProvider: Failed to clear all products: $e');
      return false;
    }
  }

  /// Dispose of the service
  void dispose() {
    _dataChangeController.close();
  }
}