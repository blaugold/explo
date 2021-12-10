import 'dart:async';

import 'package:explo_capture/internal.dart';
import 'package:flutter/material.dart';
import 'package:vm_service/vm_service.dart' as vms;

import 'capture_service_client.dart';
import 'vm_service_utils.dart';

/// The status of a [RenderTreeLoader].
enum RenderTreeLoaderStatus {
  initial,
  connecting,
  connectingFailed,
  connected,
  disconnected,
  disposed,
}

/// A loader which connects to an app and loads the render tree.
class RenderTreeLoader extends ChangeNotifier {
  vms.VmService? _vmService;
  CaptureServiceClient? _client;

  /// The current status of this loader.
  RenderTreeLoaderStatus get status => _status;
  RenderTreeLoaderStatus _status = RenderTreeLoaderStatus.initial;

  /// The current render tree, captured by the app.
  ///
  /// Is `null` if the app is not capturing a render tree.
  RenderObjectData? get tree => _tree;
  RenderObjectData? _tree;

  /// A list of all the render object types in the captured render tree.
  List<String> get allTypes => List.unmodifiable(_allTypes);
  List<String> _allTypes = [];

  /// Whether the loader is currently watching the captured render tree.
  ///
  /// While watching, the loader will automatically receive the latest version
  /// of the render tree after the app paints a frame.
  bool get isWatching => _watchSub != null;
  StreamSubscription? _watchSub;

  /// Connects to the app, loads the render tree and starts watching it.
  void connectToApp(Uri uri) async {
    assert(_status == RenderTreeLoaderStatus.initial);

    _setState(() {
      _status = RenderTreeLoaderStatus.connecting;
    });

    try {
      _vmService = vmServiceConnectUri(uri);
      _vmService!.onDone.then((dynamic _) {
        if (_status == RenderTreeLoaderStatus.connected) {
          _setState(() {
            _status = RenderTreeLoaderStatus.disconnected;
          });
        }
      });

      final vm = await _vmService!.getVM();
      final isolateId = vm.isolates!.first.id!;

      _setState(() {
        _status = RenderTreeLoaderStatus.connected;
      });

      _client = CaptureServiceClient(
        vmService: _vmService!,
        isolateId: isolateId,
        onExtensionRegistered: () async {
          loadTree();
          startWatchingTree();
        },
      );
      await _client!.init();
    } catch (error, stackTrace) {
      FlutterError.reportError(FlutterErrorDetails(
        exception: error,
        stack: stackTrace,
        library: 'explo',
        context: ErrorDescription('Failed to connect to App.'),
      ));
      _setState(() {
        _status = RenderTreeLoaderStatus.connectingFailed;
      });
    }
  }

  @override
  void dispose() async {
    assert(_status != RenderTreeLoaderStatus.disposed);

    _setState(() {
      _status = RenderTreeLoaderStatus.disposed;
    });

    super.dispose();

    if (isWatching) {
      await _watchSub!.cancel();
    }
    await _client?.dispose();
    await _vmService?.dispose();

    _watchSub = null;
    _client = null;
    _vmService = null;
    _tree = null;
    _allTypes.clear();
  }

  /// Loads the render tree from the app.
  void loadTree() async {
    final tree = await _client!.getRenderTree();
    _updateTree(tree);
  }

  /// Starts watching the render tree.
  void startWatchingTree() {
    if (!isWatching) {
      _setState(() {
        _watchSub = _client!.renderTreeChanged().listen(_updateTree);
      });
    }
  }

  /// Stops watching the render tree.
  void stopWatchingTree() async {
    if (isWatching) {
      _watchSub?.cancel();
      _setState(() {
        _watchSub = null;
      });
    }
  }

  void _setState(void Function() cb) {
    cb();
    notifyListeners();
  }

  void _updateTree(RenderObjectData? tree) {
    _tree = tree;

    if (tree == null) {
      // It's possible that no CaptureRenderTree is currently in the app.
      notifyListeners();
      return;
    }

    final nodes = <RenderObjectData>[];
    void collectNode(RenderObjectData node) {
      nodes.add(node);
      node.children.forEach(collectNode);
    }

    collectNode(_tree!);
    _allTypes = nodes.map((e) => e.type).toSet().toList()..sort();

    notifyListeners();
  }
}
