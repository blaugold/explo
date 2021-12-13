/// The config properties in this library have to be set in the browser
/// environment, before the Flutter app is loaded.
///
/// ```js
/// window.explo = {
///   config: {
///     vmServiceUri: ...,
///     themeMode: ...,
///   }
/// }
/// ```
@JS('explo.config')
library config;

import 'package:flutter/material.dart';
import 'package:js/js.dart';

/// The VM Service URI of the target.
Uri get vmServiceUri => Uri.parse(_vmServiceUri);

@JS('vmServiceUri')
external String get _vmServiceUri;

/// The theme mode to use for the view.
ThemeMode get themeMode => parseThemeMode(_themeMode);

@JS('themeMode')
external String get _themeMode;

ThemeMode parseThemeMode(String value) {
  switch (value) {
    case 'dark':
      return ThemeMode.dark;
    case 'light':
      return ThemeMode.light;
    default:
      throw ArgumentError.value(value, 'value', 'Unknown theme mode');
  }
}
