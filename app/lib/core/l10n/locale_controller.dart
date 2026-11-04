import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Null means "follow the system locale" (resolved against supportedLocales
/// by Flutter itself). A non-null value is an explicit user choice made in
/// Settings, which overrides the system default for this app only.
final localeProvider = NotifierProvider<LocaleController, Locale?>(LocaleController.new);

class LocaleController extends Notifier<Locale?> {
  @override
  Locale? build() => null;

  void setLocale(Locale? locale) => state = locale;
}
