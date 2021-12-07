import 'dart:convert';
import 'dart:developer';

import 'package:collection/collection.dart';
import 'package:flutter/widgets.dart';

import 'render_object_data.dart';

const getRenderObjectDataTreeMethod =
    'ext.flutter_exploded.getRenderObjectDataTree';

List<Element> _markedElements = [];

void addMarkedElement(Element element) {
  _ensureServiceExtensionIsRegistered();
  _markedElements.add(element);
}

void removeMarkedElement(Element element) {
  _markedElements.remove(element);
}

var _serviceExtensionIsRegistered = false;

void _ensureServiceExtensionIsRegistered() {
  if (_serviceExtensionIsRegistered) {
    return;
  }
  _serviceExtensionIsRegistered = true;

  assert(() {
    _registerServiceExtension();
    return true;
  }());
}

void _registerServiceExtension() {
  registerExtension(getRenderObjectDataTreeMethod, (method, args) async {
    final renderObject = _markedElements.lastOrNull?.findRenderObject();

    if (renderObject == null) {
      return ServiceExtensionResponse.result('{}');
    }

    final data = RenderObjectData.capture(renderObject);
    return ServiceExtensionResponse.result(jsonEncode(data.toJson()));
  });
}
