import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:taskinspect/core/network/connectivity_monitor.dart';

class _MockConnectivity extends Mock implements Connectivity {}

void main() {
  late _MockConnectivity connectivity;
  late DeviceConnectivityMonitor monitor;

  setUp(() {
    connectivity = _MockConnectivity();
    monitor = DeviceConnectivityMonitor(connectivity);
  });

  test('online with Wi-Fi, mobile data or both', () async {
    for (final results in [
      [ConnectivityResult.wifi],
      [ConnectivityResult.mobile],
      [ConnectivityResult.wifi, ConnectivityResult.vpn],
    ]) {
      when(connectivity.checkConnectivity).thenAnswer((_) async => results);

      expect(await monitor.isOnline(), isTrue, reason: '$results');
    }
  });

  test('offline without a network', () async {
    when(connectivity.checkConnectivity).thenAnswer((_) async => [ConnectivityResult.none]);

    expect(await monitor.isOnline(), isFalse);
  });

  test('reports going offline and back online, without repeats', () async {
    when(() => connectivity.onConnectivityChanged).thenAnswer((_) => Stream.fromIterable([
          [ConnectivityResult.wifi],
          [ConnectivityResult.mobile],
          [ConnectivityResult.none],
          [ConnectivityResult.none],
          [ConnectivityResult.wifi],
        ]));

    expect(await monitor.onlineChanges.toList(), [true, false, true]);
  });
}
