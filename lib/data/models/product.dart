import 'package:isar/isar.dart';

part 'product.g.dart';

@collection
class Product {
  Id id = Isar.autoIncrement;

  @Index(unique: true)
  late String sharedId; // Used for sync across instances

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
    required this.sharedId, // Make required
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
    int? id,
    String? sharedId,
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
      sharedId: sharedId ?? this.sharedId,
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
    )..id = id ?? this.id; // Allow ID override
  }

  /// Factory constructor to create Product with auto-generated sharedId
  factory Product.create({
    required String name,
    required String imagePath,
    required int count,
    required String packagingType,
    required double mrp,
    required double pp,
    required DateTime lastUpdated,
    required String updatedBy,
    required int version,
    bool isDeleted = false,
  }) {
    return Product(
      sharedId: DateTime.now().millisecondsSinceEpoch.toString(),
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

  double get subTotal => pp * count;

  @override
  String toString() {
    return 'Product(id: $id, sharedId: $sharedId, name: $name, count: $count, packagingType: $packagingType, mrp: $mrp, pp: $pp, lastUpdated: $lastUpdated, updatedBy: $updatedBy, version: $version, isDeleted: $isDeleted)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Product &&
        other.sharedId == sharedId &&
        other.version == version &&
        other.lastUpdated == lastUpdated;
  }

  @override
  int get hashCode =>
      sharedId.hashCode ^ version.hashCode ^ lastUpdated.hashCode;
}