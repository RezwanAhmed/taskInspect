import 'package:connectivity_plus/connectivity_plus.dart';

/// Whether the phone has a network connection (Wi-Fi, mobile data, ...).
///
/// It only tells that a network is there, not that the server can be
/// reached, so requests can still fail with a NetworkFailure. The sync
/// manager uses it to send queued changes as soon as the phone is back
/// online.
abstract interface class ConnectivityMonitor {
  Future<bool> isOnline();

  /// Emits `true` / `false` whenever the phone goes online or offline.
  Stream<bool> get onlineChanges;
}

/// [ConnectivityMonitor] on the connectivity_plus package (Android + iOS;
/// no permission dialog on either).
class DeviceConnectivityMonitor implements ConnectivityMonitor {
  DeviceConnectivityMonitor([Connectivity? connectivity]) : _connectivity = connectivity ?? Connectivity();

  final Connectivity _connectivity;

  @override
  Future<bool> isOnline() async => _hasNetwork(await _connectivity.checkConnectivity());

  @override
  Stream<bool> get onlineChanges => _connectivity.onConnectivityChanged.map(_hasNetwork).distinct();

  static bool _hasNetwork(List<ConnectivityResult> results) =>
      results.any((result) => result != ConnectivityResult.none);
}
