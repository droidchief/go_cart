// ignore_for_file: public_member_api_docs, sort_constructors_first
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
  late int version;
  late bool isDeleted;

  Product({
    this.id = Isar.autoIncrement,
    required this.name,
    required this.imagePath,
    required this.count,
    required this.packagingType,
    required this.mrp,
    required this.pp,
    required this.lastUpdated,
    required this.updatedBy,
    required this.version,
    this.isDeleted = false,
  });

  Product copyWith({
    Id? id,
    String? name,
    String? imagePath,
    int? count,
    String? packagingType,
    double? mrp,
    double? pp,
    DateTime? lastUpdated,
    String? updatedBy,
    int? version,
    bool? isDeleted,
  }) {
    return Product(
      id: id ?? this.id,
      name: name ?? this.name,
      imagePath: imagePath ?? this.imagePath,
      count: count ?? this.count,
      packagingType: packagingType ?? this.packagingType,
      mrp: mrp ?? this.mrp,
      pp: pp ?? this.pp,
      lastUpdated: lastUpdated ?? this.lastUpdated,
      updatedBy: updatedBy ?? this.updatedBy,
      version: version ?? this.version,
      isDeleted: isDeleted ?? this.isDeleted,
    );
  }

  double get subTotal => pp * count;

  @override
  String toString() {
    return 'Product(id: $id, name: $name, count: $count, packagingType: $packagingType, mrp: $mrp, pp: $pp, lastUpdated: $lastUpdated, updatedBy: $updatedBy, version: $version, isDeleted: $isDeleted)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Product && 
           other.id == id && 
           other.version == version &&
           other.lastUpdated == lastUpdated;
  }

  @override
  int get hashCode => id.hashCode ^ version.hashCode ^ lastUpdated.hashCode;
}