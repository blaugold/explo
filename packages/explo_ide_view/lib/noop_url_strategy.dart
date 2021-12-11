// ignore: avoid_web_libraries_in_flutter
import 'dart:html';
import 'dart:ui' as ui;

import 'package:flutter_web_plugins/flutter_web_plugins.dart';

/// No-op [UrlStrategy] implementation.
///
/// Navigation is not supported in IDE web views.
class NoopUrlStrategy extends HashUrlStrategy {
  Object? _state;

  @override
  ui.VoidCallback addPopStateListener(EventListener fn) {
    // No-op
    return () {};
  }

  @override
  Future<void> go(int count) async {
    // No-op
  }

  @override
  String prepareExternalUrl(String internalUrl) {
    throw UnimplementedError();
  }

  @override
  Object? getState() {
    return _state;
  }

  @override
  void pushState(Object? state, String title, String url) {
    _state = state;
    // No-op
  }

  @override
  void replaceState(Object? state, String title, String url) {
    _state = state;
    // No-op
  }
}
