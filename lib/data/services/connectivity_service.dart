import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';


class ConnectivityService {
  final Connectivity _connectivity = Connectivity();
  
  Future<bool> isOnline() async {
    final result = await _connectivity.checkConnectivity();
    return result == ConnectivityResult.mobile || result == ConnectivityResult.wifi;
  }

  Stream<bool> get onConnectivityChanged {
    return _connectivity.onConnectivityChanged.map((results) {
        return results == ConnectivityResult.mobile || results == ConnectivityResult.wifi;
    });
  }
}

