import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:vm_service/vm_service.dart';

import 'render_object_data.dart';
import 'service_extension.dart';

/// Client for the service extensions added by `flutter_exploded`.
///
/// The client needs to be initialized by calling [init] before it can be used.
///
/// When you are done with it you should call [dispose] to free up resources.
class FlutterExplodedServiceClient {
  /// Creates a client for the service extensions added by `flutter_exploded`.
  FlutterExplodedServiceClient({
    required this.vmService,
    required this.isolateId,
    required this.onExtensionRegistered,
  });

  /// The VM service client.
  final VmService vmService;

  /// The id of the main isolate.
  final String isolateId;

  /// The callback which is invoked when the service extensions has been
  /// registered in the isolate. Before this callback is invoked, this client
  /// cannot be used.
  final VoidCallback onExtensionRegistered;

  /// Whether the service extensions have been registered in the isolate.
  bool get extensionIsRegistered => _extensionIsRegistered;
  bool _extensionIsRegistered = false;

  late final StreamSubscription _isolateEventSub;

  /// Initializes this client. This method must be called before this client
  /// can be used.
  Future<void> init() async {
    Future<void> _listenToStream(String eventType) async {
      try {
        await vmService.streamListen(eventType);
      } on RPCError catch (e) {
        if (e.code == 103) {
          // The service client is already subscribed to events of the given type.
        } else {
          rethrow;
        }
      }
    }

    await _listenToStream(EventStreams.kIsolate);
    await _listenToStream(EventStreams.kExtension);

    void _onExtensionRegistered() {
      if (_extensionIsRegistered) {
        return;
      }
      _extensionIsRegistered = true;
      _isolateEventSub.cancel();
      onExtensionRegistered();
    }

    _isolateEventSub = vmService.onIsolateEvent.listen((event) {
      if (event.isolate?.id == isolateId &&
          event.kind == EventKind.kServiceExtensionAdded &&
          event.extensionRPC == updateRenderTreeChangeListenersMethod) {
        _onExtensionRegistered();
      }
    });

    final isolate = await vmService.getIsolate(isolateId);
    final extensionRPCs = isolate.extensionRPCs;
    if (extensionRPCs != null &&
        extensionRPCs.contains(updateRenderTreeChangeListenersMethod)) {
      _onExtensionRegistered();
    }
  }

  void _checkExtensionIsRegistered() {
    if (!_extensionIsRegistered) {
      throw StateError('Extension is not registered');
    }
  }

  /// Disposes this client.
  Future<void> dispose() async {
    await _isolateEventSub.cancel();
  }

  /// Returns the current state of the render tree if one is available for
  /// capture.
  Future<RenderObjectData?> getRenderTree() async {
    _checkExtensionIsRegistered();

    final result = await vmService.callServiceExtension(
      getRenderTreeMethod,
      isolateId: isolateId,
    );
    return renderTreeFromJson(result.json);
  }

  /// Emits the latest state of the render tree each time it changes.
  ///
  /// Emits `null`, if none is available for capture.
  Stream<RenderObjectData?> renderTreeChanged() {
    _checkExtensionIsRegistered();

    late final StreamController<RenderObjectData?> controller;
    late final StreamSubscription _extensionEventSub;

    controller = StreamController(onListen: () async {
      _extensionEventSub = vmService.onExtensionEvent.listen((event) {
        if (event.extensionKind == renderTreeChangedEvent) {
          controller.add(renderTreeFromJson(event.extensionData!.data));
        }
      });
      await _updateRenderTreeChangeListeners(1);
    }, onCancel: () async {
      await _updateRenderTreeChangeListeners(-1);
      await _extensionEventSub.cancel();
    });

    return controller.stream;
  }

  Future<void> _updateRenderTreeChangeListeners(int delta) async {
    await vmService.callServiceExtension(
      updateRenderTreeChangeListenersMethod,
      isolateId: isolateId,
      args: <String, Object?>{'delta': delta},
    );
  }
}
