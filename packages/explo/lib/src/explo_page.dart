import 'package:explo_capture/internal.dart';
import 'package:flutter/material.dart';
import 'package:vector_math/vector_math_64.dart' as vm;

import 'render_tree_loader.dart';
import 'exploded_render_tree.dart';
import 'scene_viewport.dart';
import 'theming_utils.dart';

/// A widget that connects to the target app via the [vmServiceUri] and
/// visualizes the render tree captured by the app.
class ExploPage extends StatefulWidget {
  const ExploPage({
    Key? key,
    required this.vmServiceUri,
    this.onFailedToConnect,
  }) : super(key: key);

  /// The URI of the VM Service of the app to connect to.
  final Uri vmServiceUri;

  /// Callback that is invoked when connecting to the app fails.
  final VoidCallback? onFailedToConnect;

  @override
  State<ExploPage> createState() => _ExploPageState();
}

class _ExploPageState extends State<ExploPage> {
  final _renderTreeLoader = RenderTreeLoader();

  @override
  void initState() {
    super.initState();
    _renderTreeLoader.connectToApp(widget.vmServiceUri);
    _renderTreeLoader.addListener(() {
      if (_renderTreeLoader.status == RenderTreeLoaderStatus.connectingFailed) {
        widget.onFailedToConnect?.call();
      }
    });
  }

  @override
  void dispose() {
    _renderTreeLoader.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _renderTreeLoader,
      builder: (context, _) {
        switch (_renderTreeLoader.status) {
          case RenderTreeLoaderStatus.connecting:
            return _message(context, 'Connecting...', spinner: true);
          case RenderTreeLoaderStatus.connectingFailed:
            return _message(context, 'Failed to connect to App');
          case RenderTreeLoaderStatus.connected:
            return _RenderTreeViewerPage(
              renderTreeLoader: _renderTreeLoader,
            );
          case RenderTreeLoaderStatus.disconnected:
            return _message(context, 'App disconnected');
          default:
            throw UnsupportedError('unreachable');
        }
      },
    );
  }

  Widget _message(BuildContext context, String s, {bool spinner = false}) {
    return Scaffold(
      appBar: AppBar(),
      body: Center(
        child: Padding(
          padding: ThemingConstants.spacingPadding,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (spinner) const CircularProgressIndicator(),
              ThemingConstants.spacer,
              Text(s),
            ],
          ),
        ),
      ),
    );
  }
}

class _RenderTreeViewerPage extends StatefulWidget {
  const _RenderTreeViewerPage({
    Key? key,
    required this.renderTreeLoader,
  }) : super(key: key);

  final RenderTreeLoader renderTreeLoader;

  @override
  _RenderTreeViewerPageState createState() => _RenderTreeViewerPageState();
}

class _RenderTreeViewerPageState extends State<_RenderTreeViewerPage> {
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
  void dispose() {
    _modelController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.renderTreeLoader,
      builder: (context, _) {
        final tree = widget.renderTreeLoader.tree;

        return Scaffold(
          appBar: AppBar(
            actions: [
              IconButton(
                icon: const Icon(Icons.refresh),
                onPressed: () => widget.renderTreeLoader.loadTree(),
              ),
              IconButton(
                icon: Icon(
                  widget.renderTreeLoader.isWatching
                      ? Icons.stop
                      : Icons.play_arrow,
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
                  child: ExplodedRenderTree(
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
          types: widget.renderTreeLoader.allTypes,
          selected: _types,
          onChanged: (selected) => setState(() {
            _types = selected;
          }),
        )
      ],
    );
  }

  void _toggleAutoRefresh() {
    if (!widget.renderTreeLoader.isWatching) {
      widget.renderTreeLoader.startWatchingTree();
    } else {
      widget.renderTreeLoader.stopWatchingTree();
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
              padding: ThemingConstants.spacingPadding,
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
