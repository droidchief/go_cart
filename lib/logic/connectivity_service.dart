import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'sync_service.dart';

class ConnectivityService {
  final SyncService _syncService;
  late StreamSubscription<ConnectivityResult> _subscription;

  ConnectivityService(this._syncService);

  void listen() {
    _subscription = Connectivity().onConnectivityChanged.listen((ConnectivityResult result) {
      if (result == ConnectivityResult.mobile || result == ConnectivityResult.wifi) {
        debugPrint("Device is back online. Starting sync...");
        _syncService.performSync();
      } else {
        debugPrint("Device is offline.");
      }
    });
  }

  void dispose() {
    _subscription.cancel();
  }
}