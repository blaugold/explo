import 'package:explo_capture/internal.dart';
import 'package:flutter/material.dart';
import 'package:vector_math/vector_math_64.dart' as vm;

import 'exploded_render_tree.dart';
import 'render_tree_loader.dart';
import 'scene_viewport.dart';
import 'theming_.dart';

/// A widget that connects to the target app via the [vmServiceUri] and
/// visualizes the render tree captured by the app.
class ExploView extends StatefulWidget {
  const ExploView({
    Key? key,
    required this.vmServiceUri,
    this.onFailedToConnect,
    this.onBack,
    this.themeMode,
  }) : super(key: key);

  /// The URI of the VM Service of the app to connect to.
  final Uri vmServiceUri;

  /// Callback that is invoked when connecting to the app fails.
  final VoidCallback? onFailedToConnect;

  final VoidCallback? onBack;

  final ThemeMode? themeMode;

  @override
  State<ExploView> createState() => _ExploViewState();
}

class _ExploViewState extends State<ExploView> {
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
    return ExploTheme(
      themeMode: widget.themeMode,
      child: AnimatedBuilder(
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
                onBack: widget.onBack,
              );
            case RenderTreeLoaderStatus.disconnected:
              return _message(context, 'App disconnected');
            default:
              throw UnsupportedError('unreachable');
          }
        },
      ),
    );
  }

  Widget _message(BuildContext context, String s, {bool spinner = false}) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: ThemingUtils.spacingPadding,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (spinner) const CircularProgressIndicator(),
              ThemingUtils.spacer,
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
    this.onBack,
  }) : super(key: key);

  final RenderTreeLoader renderTreeLoader;

  final VoidCallback? onBack;

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

  var _selectedAllTypes = false;
  var _selectedTypes = kDefaultIncludedTypes;

  RenderObjectData? _hoveredRenderObject;

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
            renderTreeLoader: widget.renderTreeLoader,
            onBack: widget.onBack,
            controller: _modelController,
            hoveredRenderObject: _hoveredRenderObject,
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
                    types: _selectedAllTypes
                        ? widget.renderTreeLoader.allTypes
                        : _selectedTypes,
                    onHoveredRenderObjectChanged: (value) {
                      setState(() {
                        _hoveredRenderObject = value;
                      });
                    },
                  ),
                ),
              )
            ]),
          ),
        ),
        const VerticalDivider(width: 0),
        _RenderObjectTypeFilter(
          types: widget.renderTreeLoader.allTypes,
          selectedAll: _selectedAllTypes,
          onSelectedAllChanged: (selectedAll) {
            setState(() => _selectedAllTypes = selectedAll);
          },
          selected: _selectedTypes,
          onSelectedChanged: (selected) =>
              setState(() => _selectedTypes = selected),
          onResetSelection: () => setState(() {
            _selectedAllTypes = false;
            _selectedTypes = kDefaultIncludedTypes;
          }),
        )
      ],
    );
  }
}

class _RenderObjectTypeFilter extends StatefulWidget {
  const _RenderObjectTypeFilter({
    Key? key,
    required this.types,
    required this.selectedAll,
    required this.onSelectedAllChanged,
    required this.selected,
    required this.onSelectedChanged,
    required this.onResetSelection,
  }) : super(key: key);

  final List<String> types;
  final bool selectedAll;
  final ValueChanged<bool> onSelectedAllChanged;
  final List<String> selected;
  final ValueChanged<List<String>> onSelectedChanged;
  final VoidCallback onResetSelection;

  @override
  State<_RenderObjectTypeFilter> createState() =>
      _RenderObjectTypeFilterState();
}

class _RenderObjectTypeFilterState extends State<_RenderObjectTypeFilter> {
  List<String>? _filteredTypes;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 250,
      child: Column(
        children: [
          Padding(
            padding: ThemingUtils.spacingPadding,
            child: TextField(
              decoration: const InputDecoration.collapsed(
                hintText: 'Filter types',
              ),
              onChanged: _onFilterChanged,
            ),
          ),
          const Divider(height: 0),
          ListTile(
            title: const Text('Reset selection'),
            dense: true,
            onTap: () => widget.onResetSelection(),
          ),
          const Divider(height: 0),
          CheckboxListTile(
            value: widget.selectedAll,
            title: const Text('All'),
            dense: true,
            onChanged: (value) => widget.onSelectedAllChanged(value!),
          ),
          const Divider(height: 0),
          Expanded(
            child: ListView.builder(
              itemCount: _filteredTypes?.length ?? widget.types.length,
              itemBuilder: (context, i) {
                final type = (_filteredTypes ?? widget.types)[i];
                return CheckboxListTile(
                  key: ValueKey(type),
                  dense: true,
                  title: Text(
                    type,
                    overflow: TextOverflow.ellipsis,
                  ),
                  value: widget.selectedAll
                      ? true
                      : widget.selected.contains(type),
                  onChanged: widget.selectedAll
                      ? null
                      : (included) {
                          final newSelected = widget.selected.toList();
                          if (included!) {
                            newSelected.add(type);
                          } else {
                            newSelected.remove(type);
                          }
                          widget.onSelectedChanged(newSelected);
                        },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  void _onFilterChanged(String value) {
    if (value.isEmpty) {
      setState(() => _filteredTypes = null);
    } else {
      setState(() {
        _filteredTypes = widget.types
            .where((type) => type.toLowerCase().contains(value.toLowerCase()))
            .toList();
      });
    }
  }
}

class _ViewportControls extends StatefulWidget {
  const _ViewportControls({
    Key? key,
    required this.renderTreeLoader,
    required this.controller,
    this.onBack,
    this.hoveredRenderObject,
    required this.child,
  }) : super(key: key);

  final RenderTreeLoader renderTreeLoader;

  final TransformController controller;

  final VoidCallback? onBack;

  final RenderObjectData? hoveredRenderObject;

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
    var textButtonStyle = TextButton.styleFrom(
      primary: Theme.of(context).colorScheme.onSurface,
    );
    return Stack(
      children: [
        ModelInteraction(
          scaleMin: .01,
          scaleMax: 2,
          rotationMin: vm.Vector2(-45, -45),
          rotationMax: vm.Vector2(45, 45),
          controller: widget.controller,
          child: widget.child,
        ),
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: Padding(
            padding: ThemingUtils.spacingPadding,
            child: Row(
              children: [
                if (widget.onBack != null)
                  TextButton(
                    style: textButtonStyle,
                    child: Row(
                      children: const [
                        Icon(Icons.arrow_back),
                        Text('Back'),
                      ],
                    ),
                    onPressed: widget.onBack,
                  ),
                const Spacer(),
                Builder(builder: (context) {
                  return TextButton(
                    style: textButtonStyle,
                    child: const Text('View'),
                    onPressed: () {
                      _showMenuAtContext(
                        context,
                        items: [
                          PopupMenuItem(
                            value: _frontViewRotation,
                            child: const Text('Front'),
                          ),
                          PopupMenuItem(
                            value: _rotatedViewRotation,
                            child: const Text('Rotated'),
                          ),
                        ],
                      ).then((rotation) {
                        if (rotation == null) {
                          return;
                        }
                        _animateToRotation(rotation);
                      });
                    },
                  );
                }),
              ],
            ),
          ),
        ),
        Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          child: _ViewportStatusBar(
            renderTreeLoader: widget.renderTreeLoader,
            hoveredRenderObject: widget.hoveredRenderObject,
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

Future<T?> _showMenuAtContext<T>(
  BuildContext context, {
  required List<PopupMenuEntry<T>> items,
}) {
  final navRenderObject =
      Navigator.of(context).context.findRenderObject() as RenderBox;
  final renderObject = context.findRenderObject() as RenderBox;

  final transform = renderObject.getTransformTo(navRenderObject);
  final rect =
      MatrixUtils.transformRect(transform, Offset.zero & renderObject.size);
  final position = RelativeRect.fromSize(rect, navRenderObject.size);

  return showMenu(
    context: context,
    position: position,
    items: items,
  );
}

class _ViewportStatusBar extends StatelessWidget {
  const _ViewportStatusBar({
    Key? key,
    required this.hoveredRenderObject,
    required this.renderTreeLoader,
  }) : super(key: key);

  final RenderObjectData? hoveredRenderObject;
  final RenderTreeLoader renderTreeLoader;

  @override
  Widget build(BuildContext context) {
    Widget? hoveredRenderObjectType;
    if (hoveredRenderObject != null) {
      final type = hoveredRenderObject!.type;
      hoveredRenderObjectType = Row(
        children: [
          Text(type),
          ThemingUtils.spacer,
          Container(
            padding: ThemingUtils.spacingPaddingX(.25),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primary,
              borderRadius: BorderRadius.circular(ThemingUtils.spacing),
            ),
            child: Text(
              renderTreeLoader.typeCounts[type]!.toString(),
              style: TextStyle(
                color: Theme.of(context).colorScheme.onPrimary,
              ),
            ),
          )
        ],
      );
    }

    return Padding(
      padding: ThemingUtils.spacingPadding,
      child: hoveredRenderObjectType,
    );
  }
}
