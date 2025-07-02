import 'package:go_cart/data/models/product.dart';

abstract class ProductState {
  final List<Product> products;
  final bool isOnline;
  ProductState({this.products = const [], this.isOnline = true});
}

class ProductsLoadInProgress extends ProductState {}

class ProductsLoadSuccess extends ProductState {
  ProductsLoadSuccess({required List<Product> products, required bool isOnline}) 
  : super(products: products, isOnline: isOnline);
}

class ProductsLoadFailure extends ProductState {
  final String error;
  ProductsLoadFailure(this.error);
}