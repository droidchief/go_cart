import 'package:equatable/equatable.dart';
import 'package:go_cart/data/models/product.dart';

/// Base class for all product-related events
/// These events trigger state changes in the ProductBloc
abstract class ProductEvent extends Equatable {
  const ProductEvent();

  @override
  List<Object?> get props => [];
}

/// Event to load all products from local database
/// Triggered when app starts or when user refreshes the product list
class LoadProducts extends ProductEvent {
  const LoadProducts();

  @override
  String toString() => 'LoadProducts';
}

/// Event to update a specific product
/// Triggered when user changes product details (count, price, etc.)
class UpdateProduct extends ProductEvent {
  final Product product;
  final String fieldName; // For tracking which field was updated
  final dynamic oldValue; // For potential undo functionality
  final dynamic newValue; // For tracking the change

  const UpdateProduct({
    required this.product,
    required this.fieldName,
    this.oldValue,
    this.newValue,
  });

  @override
  List<Object?> get props => [product, fieldName, oldValue, newValue];

  @override
  String toString() => 'UpdateProduct { product: ${product.name}, field: $fieldName, oldValue: $oldValue, newValue: $newValue }';
}

/// Event to update multiple products at once
/// Useful for batch operations or when syncing from shared database
class UpdateProducts extends ProductEvent {
  final List<Product> products;
  final String reason; // Why this batch update is happening

  const UpdateProducts({
    required this.products,
    required this.reason,
  });

  @override
  List<Object?> get props => [products, reason];

  @override
  String toString() => 'UpdateProducts { count: ${products.length}, reason: $reason }';
}

/// Event to save all current changes to databases
/// Triggered when user presses save button
class SaveProducts extends ProductEvent {
  final List<Product> products;
  final bool forceSyncToShared; // Whether to immediately sync to shared DB

  const SaveProducts({
    required this.products,
    this.forceSyncToShared = true,
  });

  @override
  List<Object?> get props => [products, forceSyncToShared];

  @override
  String toString() => 'SaveProducts { count: ${products.length}, forceSync: $forceSyncToShared }';
}

// For saving products (triggered by "Save Changes" button)
class SaveProduct extends ProductEvent {
  final Product product;
  
  const SaveProduct({required this.product});
  
  @override
  List<Object> get props => [product];
}

/// Event to delete a product
/// Triggered when user deletes a product (soft delete)
class DeleteProduct extends ProductEvent {
  final int productId;
  final String reason; // Why this product is being deleted

  const DeleteProduct({
    required this.productId,
    required this.reason,
  });

  @override
  List<Object?> get props => [productId, reason];

  @override
  String toString() => 'DeleteProduct { productId: $productId, reason: $reason }';
}

/// Event to force synchronization with shared database
/// Triggered when user manually requests sync or when app comes online
class SyncWithSharedDatabase extends ProductEvent {
  final bool isManualSync; // Whether user manually triggered this sync

  const SyncWithSharedDatabase({
    this.isManualSync = false,
  });

  @override
  List<Object?> get props => [isManualSync];

  @override
  String toString() => 'SyncWithSharedDatabase { manual: $isManualSync }';
}

/// Event triggered when shared database changes are detected
/// This is fired by the ContentProvider when other instances make changes
class SharedDatabaseChanged extends ProductEvent {
  final DateTime timestamp;
  final String sourceInstance; // Which instance made the change

  const SharedDatabaseChanged({
    required this.timestamp,
    required this.sourceInstance,
  });

  @override
  List<Object?> get props => [timestamp, sourceInstance];

  @override
  String toString() => 'SharedDatabaseChanged { timestamp: $timestamp, source: $sourceInstance }';
}

/// Event to reset all products to initial state
/// Useful for testing or clearing all data
class ResetProducts extends ProductEvent {
  final bool keepLocalChanges; // Whether to preserve local modifications

  const ResetProducts({
    this.keepLocalChanges = false,
  });

  @override
  List<Object?> get props => [keepLocalChanges];

  @override
  String toString() => 'ResetProducts { keepLocal: $keepLocalChanges }';
}

/// Event to handle connectivity changes
/// Triggered when device goes online/offline
class ConnectivityChanged extends ProductEvent {
  final bool isOnline;
  final DateTime timestamp;

  const ConnectivityChanged({
    required this.isOnline,
    required this.timestamp,
  });

  @override
  List<Object?> get props => [isOnline, timestamp];

  @override
  String toString() => 'ConnectivityChanged { online: $isOnline, timestamp: $timestamp }';
}

/// Event to add a new product
/// Triggered when user creates a new product
class AddProduct extends ProductEvent {
  final Product product;

  const AddProduct({
    required this.product,
  });

  @override
  List<Object?> get props => [product];

  @override
  String toString() => 'AddProduct { product: ${product.name} }';
}

/// Event to validate product data
/// Triggered before saving to ensure data integrity
class ValidateProducts extends ProductEvent {
  final List<Product> products;

  const ValidateProducts({
    required this.products,
  });

  @override
  List<Object?> get props => [products];

  @override
  String toString() => 'ValidateProducts { count: ${products.length} }';
}

/// Event to print debug logs
class PrintDebugLogs extends ProductEvent {
  const PrintDebugLogs();
  
  @override
  List<Object> get props => [];
}