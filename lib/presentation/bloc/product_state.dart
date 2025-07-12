import 'package:equatable/equatable.dart';
import 'package:go_cart/data/models/product.dart';


/// Base class for all product-related states
/// Represents the current state of products in the application
abstract class ProductState extends Equatable {
  const ProductState();

  @override
  List<Object?> get props => [];
}


class ProductInitial extends ProductState {
  const ProductInitial();

  @override
  String toString() => 'ProductInitial';
}


class ProductLoading extends ProductState {
  final String message; 
  final double? progress; 

  const ProductLoading({
    this.message = 'Loading products...',
    this.progress,
  });

  @override
  List<Object?> get props => [message, progress];

  @override
  String toString() => 'ProductLoading { message: $message, progress: $progress }';
}


class ProductLoadSuccess extends ProductState {
  final List<Product> products;
  final DateTime lastUpdated; 
  final String instanceId; 
  final bool hasPendingChanges; 
  final double totalAmount; 
  final Map<String, dynamic> syncStatus; 

  const ProductLoadSuccess({
    required this.products,
    required this.lastUpdated,
    required this.instanceId,
    this.hasPendingChanges = false,
    required this.totalAmount,
    this.syncStatus = const {},
  });

  static double calculateTotal(List<Product> products) {
    return products
        .where((product) => !product.isDeleted)
        .fold(0.0, (sum, product) => sum + (product.pp * product.count));
  }

  
  ProductLoadSuccess copyWith({
    List<Product>? products,
    DateTime? lastUpdated,
    String? instanceId,
    bool? hasPendingChanges,
    double? totalAmount,
    Map<String, dynamic>? syncStatus,
  }) {
    final updatedProducts = products ?? this.products;
    return ProductLoadSuccess(
      products: updatedProducts,
      lastUpdated: lastUpdated ?? this.lastUpdated,
      instanceId: instanceId ?? this.instanceId,
      hasPendingChanges: hasPendingChanges ?? this.hasPendingChanges,
      totalAmount: totalAmount ?? calculateTotal(updatedProducts),
      syncStatus: syncStatus ?? this.syncStatus,
    );
  }

  @override
  List<Object?> get props => [products, lastUpdated, instanceId, hasPendingChanges, totalAmount, syncStatus];

  @override
  String toString() => 'ProductLoadSuccess { count: ${products.length}, total: \$${totalAmount.toStringAsFixed(2)}, pending: $hasPendingChanges, instance: $instanceId }';
}


class ProductError extends ProductState {
  final String message; 
  final String? details; 
  final String errorCode; 
  final bool isRecoverable; 
  final DateTime timestamp; 
  final List<Product>? lastKnownProducts; 

  const ProductError({
    required this.message,
    this.details,
    required this.errorCode,
    this.isRecoverable = true,
    required this.timestamp,
    this.lastKnownProducts,
  });

  @override
  List<Object?> get props => [message, details, errorCode, isRecoverable, timestamp, lastKnownProducts];

  @override
  String toString() => 'ProductError { message: $message, code: $errorCode, recoverable: $isRecoverable, timestamp: $timestamp }';
}


class ProductSaving extends ProductState {
  final List<Product> products; 
  final String operation; 
  final double? progress; 
  final bool isSyncingToShared; 

  const ProductSaving({
    required this.products,
    this.operation = 'Saving products...',
    this.progress,
    this.isSyncingToShared = false,
  });

  @override
  List<Object?> get props => [products, operation, progress, isSyncingToShared];

  @override
  String toString() => 'ProductSaving { count: ${products.length}, operation: $operation, syncingShared: $isSyncingToShared }';
}


class ProductSaveSuccess extends ProductState {
  final List<Product> products;
  final DateTime savedAt;
  final String instanceId;
  final bool syncedToShared; 
  final String message; 

  const ProductSaveSuccess({
    required this.products,
    required this.savedAt,
    required this.instanceId,
    this.syncedToShared = false,
    this.message = 'Products saved successfully',
  });

  @override
  List<Object?> get props => [products, savedAt, instanceId, syncedToShared, message];

  @override
  String toString() => 'ProductSaveSuccess { count: ${products.length}, synced: $syncedToShared, instance: $instanceId }';
}


class ProductSyncing extends ProductState {
  final String operation; 
  final String? sourceInstance; 
  final double? progress; 
  final List<Product> currentProducts; 

  const ProductSyncing({
    required this.operation,
    this.sourceInstance,
    this.progress,
    required this.currentProducts,
  });

  @override
  List<Object?> get props => [operation, sourceInstance, progress, currentProducts];

  @override
  String toString() => 'ProductSyncing { operation: $operation, source: $sourceInstance, progress: $progress }';
}


class ProductSyncSuccess extends ProductState {
  final List<Product> products; 
  final DateTime syncedAt;
  final String instanceId;
  final int itemsSynced; 
  final String message; 
  final Map<String, dynamic> syncDetails; 

  const ProductSyncSuccess({
    required this.products,
    required this.syncedAt,
    required this.instanceId,
    required this.itemsSynced,
    this.message = 'Sync completed successfully',
    this.syncDetails = const {},
  });

  @override
  List<Object?> get props => [products, syncedAt, instanceId, itemsSynced, message, syncDetails];

  @override
  String toString() => 'ProductSyncSuccess { count: ${products.length}, synced: $itemsSynced, instance: $instanceId }';
}


class ProductValidating extends ProductState {
  final List<Product> products;
  final String validationType; 
  final double? progress; 

  const ProductValidating({
    required this.products,
    required this.validationType,
    this.progress,
  });

  @override
  List<Object?> get props => [products, validationType, progress];

  @override
  String toString() => 'ProductValidating { count: ${products.length}, type: $validationType }';
}


class ProductValidationError extends ProductState {
  final List<Product> products;
  final Map<int, List<String>> validationErrors; 
  final String generalError; 

  const ProductValidationError({
    required this.products,
    required this.validationErrors,
    required this.generalError,
  });

  @override
  List<Object?> get props => [products, validationErrors, generalError];

  @override
  String toString() => 'ProductValidationError { count: ${products.length}, errors: ${validationErrors.length} }';
}


class ProductConnectivityChanged extends ProductState {
  final bool isOnline;
  final DateTime timestamp;
  final List<Product> products;
  final bool hasPendingSync; 

  const ProductConnectivityChanged({
    required this.isOnline,
    required this.timestamp,
    required this.products,
    this.hasPendingSync = false,
  });

  @override
  List<Object?> get props => [isOnline, timestamp, products, hasPendingSync];

  @override
  String toString() => 'ProductConnectivityChanged { online: $isOnline, pending: $hasPendingSync }';
}