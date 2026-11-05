import 'dart:math';

import 'package:flutter/foundation.dart' show TargetPlatform, defaultTargetPlatform, kIsWeb;

import 'token_storage.dart';

const _deviceIdKey = 'tsm_device_id';

/// A stable id for this install, generated once and kept in secure storage
/// — not a hardware identifier, just enough to tell "this session, this
/// device" apart from another one in the Settings "Active sessions" list
/// (device/session management — Phase 03).
Future<String> deviceId(TokenStorage tokenStorage) async {
  final existing = await tokenStorage.read(_deviceIdKey);
  if (existing != null) return existing;
  final random = Random.secure();
  final bytes = List<int>.generate(16, (_) => random.nextInt(256));
  final generated = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  await tokenStorage.write(_deviceIdKey, generated);
  return generated;
}

/// "android" | "ios" | "windows" | "macos" | "linux" | "web" — genuinely
/// what Flutter reports, not a guessed/hardcoded value. Uses
/// `defaultTargetPlatform` (not `dart:io`'s `Platform`, which doesn't
/// compile for the web target) so this is safe on every platform this app
/// ships for.
String devicePlatform() {
  if (kIsWeb) return 'web';
  return switch (defaultTargetPlatform) {
    TargetPlatform.android => 'android',
    TargetPlatform.iOS => 'ios',
    TargetPlatform.windows => 'windows',
    TargetPlatform.macOS => 'macos',
    TargetPlatform.linux => 'linux',
    _ => 'unknown',
  };
}

/// A short, honest label — no device-model lookup (would need a platform
/// plugin this project doesn't otherwise need), just what OS it's running on.
String deviceName() => switch (devicePlatform()) {
  'android' => 'Android device',
  'ios' => 'iPhone/iPad',
  'windows' => 'Windows PC',
  'macos' => 'Mac',
  'linux' => 'Linux PC',
  'web' => 'Web browser',
  _ => 'Device',
};
