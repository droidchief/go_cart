import 'package:isar/isar.dart';

part 'product.g.dart'; 

@collection
class Product {
  Id id = Isar.autoIncrement;
  late String name;
  late String imagePath;
  late int count;
  late String packagingType; 
  late double mrp; 
  late double pp;  
  late DateTime lastUpdated;
  late String updatedBy; 

  Product({
    this.id = Isar.autoIncrement,
    required this.name,
    required this.imagePath,
    this.count = 1,
    this.packagingType = 'Packs',
    this.mrp = 0.0,
    this.pp = 0.0,
    required this.lastUpdated,
    required this.updatedBy,
  });

  Product copyWith({
    int? count,
    String? packagingType,
    double? mrp,
    double? pp,
    DateTime? lastUpdated,
    String? updatedBy,
  }) {
    return Product(
      id: this.id,
      name: this.name,
      imagePath: this.imagePath,
      count: count ?? this.count,
      packagingType: packagingType ?? this.packagingType,
      mrp: mrp ?? this.mrp,
      pp: pp ?? this.pp,
      lastUpdated: lastUpdated ?? this.lastUpdated,
      updatedBy: updatedBy ?? this.updatedBy,
    );
  }

}