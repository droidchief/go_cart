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
}