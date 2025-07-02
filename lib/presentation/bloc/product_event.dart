import 'package:go_cart/data/models/product.dart';

abstract class ProductEvent {}

class ProductsLoadStarted extends ProductEvent {}

class ProductsUpdatedFromDb extends ProductEvent {
  final List<Product> products;
  ProductsUpdatedFromDb(this.products);
}

class ProductLocalUpdateRequested extends ProductEvent {
  final Product updatedProduct;
  ProductLocalUpdateRequested(this.updatedProduct);
}

class SaveChangesRequested extends ProductEvent {}

class ConnectivityChanged extends ProductEvent {
    final bool isOnline;
    ConnectivityChanged(this.isOnline);
}