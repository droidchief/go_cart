import 'dart:async';
import 'dart:io';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';

class ConnectivityService {
  final Connectivity _connectivity = Connectivity();
  
  Future<bool> isOnline() async {
    try {
      final result = await _connectivity.checkConnectivity();
      final hasConnection = result == ConnectivityResult.mobile || 
                           result == ConnectivityResult.wifi;
      
      if (!hasConnection) return false;
      
      return await _verifyInternetAccess();
    } catch (e) {
      debugPrint('ConnectivityService: Error checking connectivity: $e');
      return false;
    }
  }

  /// Verify actual internet access by pinging a reliable endpoint
  Future<bool> _verifyInternetAccess() async {
    try {
      final result = await InternetAddress.lookup('google.com')
          .timeout(const Duration(seconds: 5));
      return result.isNotEmpty && result[0].rawAddress.isNotEmpty;
    } catch (e) {
      debugPrint('ConnectivityService: Internet verification failed: $e');
      return false;
    }
  }

  Stream<bool> get onConnectivityChanged {
    return _connectivity.onConnectivityChanged
        .asyncMap((result) async {
          final hasConnection = result == ConnectivityResult.mobile || 
                               result == ConnectivityResult.wifi;
          
          if (!hasConnection) return false;
          
          return await _verifyInternetAccess();
        })
        .distinct() // Remove duplicate events
        .debounce(const Duration(seconds: 2)); // Debounce rapid changes
  }
}

extension StreamDebounce<T> on Stream<T> {
  Stream<T> debounce(Duration duration) {
    Timer? timer;
    late StreamController<T> controller;
    
    controller = StreamController<T>(
      onListen: () {
        listen((data) {
          timer?.cancel();
          timer = Timer(duration, () {
            controller.add(data);
          });
        });
      },
      onCancel: () {
        timer?.cancel();
      },
    );
    
    return controller.stream;
  }
}