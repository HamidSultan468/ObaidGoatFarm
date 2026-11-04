import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Whether the device currently has a network path at all (Wi-Fi/mobile/
/// ethernet present). This is a connectivity *hint*, not proof the backend
/// is reachable — a phone can report Wi-Fi while the router has no
/// internet. The outbox controller treats it only as a trigger to retry;
/// the real test of reachability is still "did the request succeed".
final connectivityProvider = StreamProvider<bool>((ref) async* {
  // onConnectivityChanged only emits on a *change*; yield the current
  // state first so a listener attached after startup isn't left with no
  // value until the next flip.
  yield await currentlyOnline();
  yield* Connectivity().onConnectivityChanged.map(_isOnline);
});

/// Current snapshot, read once (e.g. to decide the initial banner state
/// before the stream has emitted) rather than watched.
Future<bool> currentlyOnline() async => _isOnline(await Connectivity().checkConnectivity());

bool _isOnline(List<ConnectivityResult> results) => results.any((r) => r != ConnectivityResult.none);
