import 'package:go_cart/config.dart';
import 'package:isar/isar.dart';
import 'package:path_provider/path_provider.dart';
import '../models/product.dart';

class DatabaseService {
  late final Isar _localDb;
  late final Isar _commonDb;
  final AppConfig config;

  Isar get localDb => _localDb;
  Isar get commonDb => _commonDb;

  DatabaseService({required this.config});

  Future<void> init() async {
    final dir = await getApplicationDocumentsDirectory();
    _localDb = await Isar.open([ProductSchema], directory: dir.path, name: config.localDbName);
    _commonDb = await Isar.open([ProductSchema], directory: dir.path, name: 'common_db');
    await _seedInitialData();
  }

   // Seed some data for demonstration when the DB is empty
  Future<void> _seedInitialData() async {
      if (await _commonDb.products.count() == 0) {
          final initialProducts = List.generate(5, (index) => Product(
              name: 'Panadol',
              imagePath: 'https://via.placeholder.com/150/92c952/FFFFFF?Text=Medicine',
              count: 1,
              packagingType: 'Packs',
              mrp: 10.0,
              pp: 20.0,
              lastUpdated: DateTime.now(),
              updatedBy: 'Seed'
          ));
          await _commonDb.writeTxn(() async {
              await _commonDb.products.putAll(initialProducts);
          });
          await _localDb.writeTxn(() async {
              await _localDb.products.putAll(initialProducts);
          });
      }
  }

  // Future<void> inite(String localDbName) async {
  //   final dir = await getApplicationDocumentsDirectory();

  //   // Initialize local DB with a unique name per flavor
  //   _localDb = await Isar.open(
  //     [ProductSchema],
  //     directory: dir.path,
  //     name: localDbName,
  //   );

  //   // Initialize common DB with a shared name
  //   _commonDb = await Isar.open(
  //     [ProductSchema],
  //     directory: dir.path,
  //     name: 'common_db',
  //   );
  // }

}
