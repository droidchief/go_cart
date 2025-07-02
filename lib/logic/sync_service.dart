import 'package:go_cart/data/services/database_services.dart';
import 'package:isar/isar.dart';
import '../data/models/product.dart';

class SyncService {
  final DatabaseService _dbService;

  SyncService(this._dbService);

  Future<void> performSync() async {
    final localProducts = await _dbService.localDb.products.where().findAll();
    final commonProducts = await _dbService.commonDb.products.where().findAll();

    // TODO: Use maps for efficient lookup
    final localMap = {for (var p in localProducts) p.id: p};
    final commonMap = {for (var p in commonProducts) p.id: p};

    for (final localProduct in localProducts) {
      final commonProduct = commonMap[localProduct.id];
      if (commonProduct == null || localProduct.lastUpdated.isAfter(commonProduct.lastUpdated)) {
        // Write to common DB if newer or doesn't exist
        await _dbService.commonDb.writeTxn(() async {
          await _dbService.commonDb.products.put(localProduct);
        });
      }
    }

    for (final commonProduct in commonProducts) {
      final localProduct = localMap[commonProduct.id];
      if (localProduct == null || commonProduct.lastUpdated.isAfter(localProduct.lastUpdated)) {
        // Write to local DB if newer or doesn't exist
        await _dbService.localDb.writeTxn(() async {
          await _dbService.localDb.products.put(commonProduct);
        });
      }
    }
  }
}