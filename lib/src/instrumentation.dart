import 'dart:convert';
import 'dart:developer';

import 'package:flutter/cupertino.dart';
import 'package:flutter/rendering.dart';

import 'internal.dart';
import 'render_object_info.dart';

List<Element> _renderObjectInspectorElements = [];

void registerFlutterExplodedServiceExtension() {
  assert(() {
    registerExtension(getRenderObjectInfoTreeKey, (method, args) async {
      final element = _renderObjectInspectorElements.isNotEmpty
          ? _renderObjectInspectorElements.last.findRenderObject()
          : RendererBinding.instance.renderView.child;
      final info = captureRenderObjectInfo(element);
      return ServiceExtensionResponse.result(jsonEncode(info.toJson()));
    });

    return true;
  }());
}

class ExplodedTreeMarker extends StatefulWidget {
  const ExplodedTreeMarker({
    @required this.child,
  });

  final Widget child;

  @override
  _ExplodedTreeMarkerState createState() => _ExplodedTreeMarkerState();
}

class _ExplodedTreeMarkerState extends State<ExplodedTreeMarker> {
  @override
  void initState() {
    super.initState();
    _renderObjectInspectorElements.add(context);
  }

  @override
  void dispose() {
    _renderObjectInspectorElements.removeWhere((element) => element == context);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}
