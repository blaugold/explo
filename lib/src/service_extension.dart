import 'dart:convert';
import 'dart:developer';

import 'package:collection/collection.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';
import 'package:vm_service/vm_service.dart';

import 'render_object_data.dart';

/// Name of the service extension method to get the current render tree.
const getRenderTreeMethod = 'ext.flutter_exploded.getRenderTree';

/// Name of the service extension method to update the count of current
/// render tree change listeners.
const updateRenderTreeChangeListenersMethod =
    'ext.flutter_exploded.updateRenderTreeChangeListeners';

/// Name of the service extension event that is posted when the render
/// tree changes.
const renderTreeChangedEvent = 'ext.flutter_exploded.renderTreeChanged';

/// The count of current render tree change listeners. Only if the count is
/// above zero, the render tree will be captured after each frame.
var _renderTreeChangeListeners = 0;

List<Element> _capturedElementsStack = [];

/// Starts capturing the render tree of [element].
///
/// Only one render tree is being captured at a time. Elements are pushed onto
/// and popped off of a stack, when capturing is started and stopped.
/// The element which is at the top of the stack will be the one
/// whose render tree is captured.
///
/// This is a noop in release builds.
void startCapturingRenderTree(Element element) {
  assert(() {
    _ensureServiceExtensionIsRegistered();
    _capturedElementsStack.add(element);
    return true;
  }());
}

/// Stops capturing the render tree of [element].
///
/// This is a noop in release builds.
void stopCapturingRenderTree(Element element) {
  assert(() {
    _capturedElementsStack.remove(element);
    return true;
  }());
}

var _serviceExtensionIsRegistered = false;

void _ensureServiceExtensionIsRegistered() {
  if (_serviceExtensionIsRegistered) {
    return;
  }
  _serviceExtensionIsRegistered = true;

  _registerServiceExtension();
}

void _registerServiceExtension() {
  registerExtension(
    getRenderTreeMethod,
    (_, __) async => ServiceExtensionResponse.result(
      jsonEncode(_captureRenderTreeAsJson()),
    ),
  );

  // Must be registered last, because its registration signals that the
  // service extension is available.
  registerExtension(updateRenderTreeChangeListenersMethod, (_, args) async {
    final int delta;

    try {
      delta = int.parse(args['delta']!);
    } catch (e) {
      return ServiceExtensionResponse.error(
        RPCError.kInvalidParams,
        '{"message":"Invalid arguments: $args"}',
      );
    }

    _renderTreeChangeListeners += delta;
    return ServiceExtensionResponse.result('{}');
  });

  // Capture a render tree after each frame and post a renderTreeChangedEvent.
  SchedulerBinding.instance!.addPersistentFrameCallback((_) {
    if (_renderTreeChangeListeners > 0) {
      SchedulerBinding.instance!.addPostFrameCallback((_) {
        postEvent(renderTreeChangedEvent, _captureRenderTreeAsJson());
      });
    }
  });
}

Map<String, Object?> _captureRenderTreeAsJson() {
  final renderObject = _capturedElementsStack.lastOrNull?.findRenderObject();
  var data =
      renderObject == null ? null : RenderObjectData.capture(renderObject);
  return renderTreeToJson(data);
}

Map<String, Object?> renderTreeToJson(RenderObjectData? data) {
  if (data == null) {
    // Null is returned if no element has been marked for visualization.
    return {};
  }

  return data.toJson();
}

RenderObjectData? renderTreeFromJson(Map<String, dynamic>? json) {
  if (json == null || json.isEmpty) {
    // Null is returned if no element has been marked for visualization.
    return null;
  }

  return RenderObjectData.fromJson(json);
}
