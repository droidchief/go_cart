import 'package:go_cart/data/models/product.dart';

/// SharedProduct model for ContentProvider operations
/// This represents the structure stored in the SQLite common database
class SharedProduct {
  final String id;
  final String name;
  final String imagePath;
  final int count;
  final String packagingType;
  final double mrp;
  final double pp;
  final DateTime lastUpdated;
  final String updatedBy;
  final int version;
  final bool isDeleted;

  const SharedProduct({
    required this.id,
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

  factory SharedProduct.fromMap(Map<String, dynamic> map) {
    return SharedProduct(
      id: map['id']?.toString() ?? '', 
      name: map['name'] as String,
      imagePath: map['image_path'] as String? ?? '',
      count: map['count'] as int,
      packagingType: map['packaging_type'] as String? ?? 'Packs',
      mrp: (map['mrp'] as num).toDouble(),
      pp: (map['pp'] as num).toDouble(),
      lastUpdated: DateTime.fromMillisecondsSinceEpoch(map['last_updated'] as int),
      updatedBy: map['updated_by'] as String,
      version: map['version'] as int,
      isDeleted: (map['is_deleted'] as int) == 1,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'image_path': imagePath,
      'count': count,
      'packaging_type': packagingType,
      'mrp': mrp,
      'pp': pp,
      'last_updated': lastUpdated.millisecondsSinceEpoch,
      'updated_by': updatedBy,
      'version': version,
      'is_deleted': isDeleted ? 1 : 0,
    };
  }

 Product toIsarProduct() {
    return Product(
      sharedId: id, 
      name: name,
      imagePath: imagePath,
      count: count,
      packagingType: packagingType,
      mrp: mrp,
      pp: pp,
      lastUpdated: lastUpdated,
      updatedBy: updatedBy,
      version: version,
      isDeleted: isDeleted,
    );
  }

  factory SharedProduct.fromIsarProduct(Product product) {
    return SharedProduct(
      id: product.sharedId,
      name: product.name,
      imagePath: product.imagePath,
      count: product.count,
      packagingType: product.packagingType,
      mrp: product.mrp,
      pp: product.pp,
      lastUpdated: product.lastUpdated,
      updatedBy: product.updatedBy,
      version: product.version,
      isDeleted: product.isDeleted,
    );
  }

  SharedProduct copyWith({
    String? id,
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
    return SharedProduct(
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

  @override
  String toString() {
    return 'SharedProduct(id: $id, name: $name, count: $count, packagingType: $packagingType, mrp: ₹${mrp.toStringAsFixed(2)}, pp: ₹${pp.toStringAsFixed(2)}, updatedBy: $updatedBy, version: $version, isDeleted: $isDeleted)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is SharedProduct && 
           other.id == id && 
           other.version == version &&
           other.lastUpdated == lastUpdated;
  }

  @override
  int get hashCode => id.hashCode ^ version.hashCode ^ lastUpdated.hashCode;
}