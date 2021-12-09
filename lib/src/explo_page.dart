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
class ExploPage extends StatefulWidget {
  const ExploPage({Key? key}) : super(key: key);

  @override
  _ExploPageState createState() => _ExploPageState();
}

class _ExploPageState extends State<ExploPage> {
  @override
  Widget build(BuildContext context) => _ConnectToVmPage();
}

class _ExploAppManager extends ChangeNotifier {
  bool _isConnecting = false;

  bool get isConnection => _isConnecting;

  bool get isConnected => _vmService != null;

  vms.VmService? _vmService;

  ExploServiceClient? _client;

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

      _client = ExploServiceClient(
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
  final _appManager = _ExploAppManager();
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

  final _ExploAppManager appManager;

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

  final _modelController = TransformController();

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
              : _buildContent(tree),
        );
      },
    );
  }

  Row _buildContent(RenderObjectData tree) {
    return Row(
      children: [
        Expanded(
          child: _ViewportControls(
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
        const VerticalDivider(width: 0),
        _RenderObjectTypeFilter(
          types: widget.appManager.allTypes,
          selected: _types,
          onChanged: (selected) => setState(() {
            _types = selected;
          }),
        )
      ],
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

class _ViewportControls extends StatefulWidget {
  const _ViewportControls({
    Key? key,
    required this.controller,
    required this.child,
  }) : super(key: key);

  final TransformController controller;

  final Widget child;

  @override
  State<_ViewportControls> createState() => _ViewportControlsState();
}

class _ViewportControlsState extends State<_ViewportControls>
    with SingleTickerProviderStateMixin {
  static const _initialScale = .4;
  static final _frontViewRotation = vm.Vector3(0, 0, 0);
  static final _rotatedViewRotation = vm.Vector3(-20, 20, 0);

  late final _rotationAnimationController = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 250),
  );
  final _rotationTween = Tween(begin: vm.Vector3.zero());

  @override
  void initState() {
    super.initState();

    // Init the transform controller to the initial values.
    widget.controller.scale = _initialScale;
    widget.controller.rotation = _rotatedViewRotation;

    // Setup the rotation animation.
    final _rotationAnimation = _rotationAnimationController
        .drive(CurveTween(curve: Curves.easeOutCubic))
        .drive(_rotationTween);

    _rotationAnimation.addListener(() {
      final rotation = _rotationAnimation.value;
      widget.controller.rotation = rotation;
    });
  }

  @override
  void dispose() {
    _rotationAnimationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        ModelInteraction(
          scaleMin: .01,
          scaleMax: 2,
          controller: widget.controller,
          child: widget.child,
        ),
        Positioned(
          top: 0,
          right: 0,
          child: PopupMenuButton(
            child: const Padding(
              padding: EdgeInsets.all(16.0),
              child: Text(
                'View',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            onSelected: _animateToRotation,
            itemBuilder: (context) => [
              PopupMenuItem(
                value: _frontViewRotation,
                child: const Text('Front'),
              ),
              PopupMenuItem(
                value: _rotatedViewRotation,
                child: const Text('Rotated'),
              ),
            ],
          ),
        )
      ],
    );
  }

  void _animateToRotation(vm.Vector3 newRotation) {
    final currentRotation = vm.Vector3(
      widget.controller.rotationX,
      widget.controller.rotationY,
      widget.controller.rotationZ,
    );
    _rotationTween.begin = currentRotation;
    _rotationTween.end = newRotation;
    _rotationAnimationController.forward(from: 0);
  }
}
