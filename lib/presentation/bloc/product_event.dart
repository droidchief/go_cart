import 'package:equatable/equatable.dart';
import 'package:go_cart/data/models/product.dart';


/// Base class for all product-related events
/// These events trigger state changes in the ProductBloc
abstract class ProductEvent extends Equatable {
  const ProductEvent();

  @override
  List<Object?> get props => [];
}


class LoadProducts extends ProductEvent {
  const LoadProducts();

  @override
  String toString() => 'LoadProducts';
}


class UpdateProduct extends ProductEvent {
  final Product product;
  final String fieldName; 
  final dynamic oldValue; 
  final dynamic newValue; 

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



class UpdateProducts extends ProductEvent {
  final List<Product> products;
  final String reason; 

  const UpdateProducts({
    required this.products,
    required this.reason,
  });

  @override
  List<Object?> get props => [products, reason];

  @override
  String toString() => 'UpdateProducts { count: ${products.length}, reason: $reason }';
}



class SaveProducts extends ProductEvent {
  final List<Product> products;
  final bool forceSyncToShared; 

  const SaveProducts({
    required this.products,
    this.forceSyncToShared = true,
  });

  @override
  List<Object?> get props => [products, forceSyncToShared];

  @override
  String toString() => 'SaveProducts { count: ${products.length}, forceSync: $forceSyncToShared }';
}


class SaveProduct extends ProductEvent {
  final Product product;
  
  const SaveProduct({required this.product});
  
  @override
  List<Object> get props => [product];
}



class DeleteProduct extends ProductEvent {
  final int productId;
  final String reason; 

  const DeleteProduct({
    required this.productId,
    required this.reason,
  });

  @override
  List<Object?> get props => [productId, reason];

  @override
  String toString() => 'DeleteProduct { productId: $productId, reason: $reason }';
}



class SyncWithSharedDatabase extends ProductEvent {
  final bool isManualSync; 

  const SyncWithSharedDatabase({
    this.isManualSync = false,
  });

  @override
  List<Object?> get props => [isManualSync];

  @override
  String toString() => 'SyncWithSharedDatabase { manual: $isManualSync }';
}



class SharedDatabaseChanged extends ProductEvent {
  final DateTime timestamp;
  final String sourceInstance; 

  const SharedDatabaseChanged({
    required this.timestamp,
    required this.sourceInstance,
  });

  @override
  List<Object?> get props => [timestamp, sourceInstance];

  @override
  String toString() => 'SharedDatabaseChanged { timestamp: $timestamp, source: $sourceInstance }';
}



class ResetProducts extends ProductEvent {
  final bool keepLocalChanges; 

  const ResetProducts({
    this.keepLocalChanges = false,
  });

  @override
  List<Object?> get props => [keepLocalChanges];

  @override
  String toString() => 'ResetProducts { keepLocal: $keepLocalChanges }';
}



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


class PrintDebugLogs extends ProductEvent {
  const PrintDebugLogs();
  
  @override
  List<Object> get props => [];
}