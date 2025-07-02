import 'package:isar/isar.dart';
import 'package:path_provider/path_provider.dart';
import '../models/product.dart';

class DatabaseService {
  late final Isar _localDb;
  late final Isar _commonDb;

  Isar get localDb => _localDb;
  Isar get commonDb => _commonDb;

  Future<void> init(String localDbName) async {
    final dir = await getApplicationDocumentsDirectory();

    // Initialize local DB with a unique name per flavor
    _localDb = await Isar.open(
      [ProductSchema],
      directory: dir.path,
      name: localDbName,
    );

    // Initialize common DB with a shared name
    _commonDb = await Isar.open(
      [ProductSchema],
      directory: dir.path,
      name: 'common_db',
    );
  }
}