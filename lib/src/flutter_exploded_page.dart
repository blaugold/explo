import 'dart:async';

import 'package:flutter/material.dart';
import 'package:vector_math/vector_math_64.dart' as vm;
import 'package:vm_service/vm_service.dart' as vms;

import 'render_object_data.dart';
import 'scene_render_tree.dart';
import 'scene_viewport.dart';
import 'service_extension_client.dart';
import 'vm_service_utils.dart';

/// A widget that presents the visualization of the render tree, as well
/// as a page to connect to the target app.
class FlutterExplodedPage extends StatefulWidget {
  const FlutterExplodedPage({Key? key}) : super(key: key);

  @override
  _FlutterExplodedPageState createState() => _FlutterExplodedPageState();
}

class _FlutterExplodedPageState extends State<FlutterExplodedPage> {
  @override
  Widget build(BuildContext context) => _ConnectToVmPage();
}

class _ExplodedAppManager extends ChangeNotifier {
  bool _isConnecting = false;

  bool get isConnection => _isConnecting;

  bool get isConnected => _vmService != null;

  vms.VmService? _vmService;

  FlutterExplodedServiceClient? _client;

  RenderObjectData? _tree;

  RenderObjectData? get tree => _tree;

  List<String> _allTypes = [];

  List<String> get allTypes => List.unmodifiable(_allTypes);

  StreamSubscription? _watchSub;

  bool get isWatching => _watchSub != null;

  Future<void> connectToClient(String uri) async {
    if (_isConnecting) return;

    setState(() {
      _isConnecting = true;
    });

    try {
      _vmService = await vmServiceConnectUri(uri);

      final vm = await _vmService!.getVM();
      final isolateId = vm.isolates!.first.id!;

      _client = FlutterExplodedServiceClient(
        vmService: _vmService!,
        isolateId: isolateId,
        onExtensionRegistered: () async {
          await loadTree();
          startWatchingTree();
          setState(() {
            _isConnecting = false;
          });
        },
      );
      await _client!.init();
    } catch (e) {
      // ignore: avoid_print
      print(e);
      setState(() {
        _isConnecting = false;
      });
    }
  }

  void disconnect() async {
    if (isConnected) {
      await stopWatchingTree();
      await _client!.dispose();
      await _vmService!.dispose();

      setState(() {
        _client = null;
        _vmService = null;
        _tree = null;
        _allTypes.clear();
      });
    }
  }

  Future<void> loadTree() async {
    final tree = await _client!.getRenderTree();
    _updateTree(tree);
  }

  void startWatchingTree() {
    if (!isWatching) {
      setState(() {
        _watchSub = _client!.renderTreeChanged().listen(_updateTree);
      });
    }
  }

  Future<void> stopWatchingTree() async {
    if (isWatching) {
      await _watchSub?.cancel();
      setState(() {
        _watchSub = null;
      });
    }
  }

  void setState(void Function() cb) {
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

class _ConnectToVmPage extends StatefulWidget {
  @override
  _ConnectToVmPageState createState() => _ConnectToVmPageState();
}

class _ConnectToVmPageState extends State<_ConnectToVmPage> {
  final _appManager = _ExplodedAppManager();
  String? _uri;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _appManager,
      builder: (context, _) {
        return Scaffold(
          appBar: AppBar(
            title: const Text('Connect to App'),
          ),
          body: Stack(
            children: [
              Center(
                child: Container(
                  padding: const EdgeInsets.all(20),
                  constraints: const BoxConstraints(maxWidth: 500),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(
                        child: TextFormField(
                          decoration: const InputDecoration(
                            labelText: 'VM Service URI',
                            border: OutlineInputBorder(),
                          ),
                          onChanged: (uri) => setState(() => _uri = uri),
                        ),
                      ),
                      const SizedBox(width: 20),
                      ElevatedButton(
                        child: const Text('Connect'),
                        onPressed:
                            (_uri?.isNotEmpty ?? false) ? _connect : null,
                      ),
                    ],
                  ),
                ),
              ),
              if (_appManager.isConnected)
                const Center(child: CircularProgressIndicator())
            ],
          ),
        );
      },
    );
  }

  void _connect() async {
    await _appManager.connectToClient(_uri!);

    await Navigator.push<void>(context, MaterialPageRoute(builder: (_) {
      return _ExplodedTreeViewerPage(appManager: _appManager);
    }));

    _appManager.disconnect();
  }
}

class _ExplodedTreeViewerPage extends StatefulWidget {
  const _ExplodedTreeViewerPage({
    required this.appManager,
  });

  final _ExplodedAppManager appManager;

  @override
  _ExplodedTreeViewerPageState createState() => _ExplodedTreeViewerPageState();
}

class _ExplodedTreeViewerPageState extends State<_ExplodedTreeViewerPage> {
  static const kDefaultIncludedTypes = [
    'RenderCustomPaint',
    'RenderDecoratedBox',
    'RenderImage',
    'RenderParagraph',
    'RenderPhysicalModel',
    'RenderPhysicalShape',
    'RenderPhysicalShape',
    '_RenderColoredBox',
  ];

  var _types = kDefaultIncludedTypes;

  final _modelController = TransformController(
    rotationX: -15,
    rotationY: 15,
  )..scale = .4;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.appManager,
      builder: (context, _) {
        final tree = widget.appManager.tree;

        return Scaffold(
          appBar: AppBar(
            actions: [
              IconButton(
                icon: const Icon(Icons.refresh),
                onPressed: () => widget.appManager.loadTree(),
              ),
              IconButton(
                icon: Icon(
                  widget.appManager.isWatching ? Icons.stop : Icons.play_arrow,
                ),
                onPressed: _toggleAutoRefresh,
              )
            ],
          ),
          body: tree == null
              ? const Center(child: CircularProgressIndicator())
              : Row(
                  children: [
                    Expanded(
                      child: ModelInteraction(
                        scaleMin: .01,
                        scaleMax: 2,
                        controller: _modelController,
                        child: SceneViewport(children: [
                          ControllerTransform(
                            controller: _modelController,
                            child: CenterTransform(
                              size: vm.Vector3(
                                tree.paintBounds.width,
                                tree.paintBounds.height,
                                1,
                              ),
                              child: SceneRenderTree(
                                root: tree,
                                types: _types,
                              ),
                            ),
                          )
                        ]),
                      ),
                    ),
                    _RenderObjectTypeFilter(
                      types: widget.appManager.allTypes,
                      selected: _types,
                      onChanged: (selected) => setState(() {
                        _types = selected;
                      }),
                    )
                  ],
                ),
        );
      },
    );
  }

  void _toggleAutoRefresh() {
    if (!widget.appManager.isWatching) {
      widget.appManager.startWatchingTree();
    } else {
      widget.appManager.stopWatchingTree();
    }
  }
}

class _RenderObjectTypeFilter extends StatelessWidget {
  const _RenderObjectTypeFilter({
    Key? key,
    required this.types,
    required this.selected,
    required this.onChanged,
  }) : super(key: key);

  final List<String> types;
  final List<String> selected;
  final ValueChanged<List<String>> onChanged;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 250,
      child: Column(
        children: [
          CheckboxListTile(
            value: types.length == selected.length,
            title: const Text('All'),
            dense: true,
            onChanged: (all) {
              onChanged(all! ? types : []);
            },
          ),
          Expanded(
            child: ListView.builder(
              itemCount: types.length,
              itemBuilder: (context, i) {
                final type = types[i];
                return CheckboxListTile(
                  dense: true,
                  title: Text(
                    type,
                    overflow: TextOverflow.ellipsis,
                  ),
                  value: selected.contains(type),
                  onChanged: (included) {
                    final newSelected = selected.toList();
                    if (included!) {
                      newSelected.add(type);
                    } else {
                      newSelected.remove(type);
                    }
                    onChanged(newSelected);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
