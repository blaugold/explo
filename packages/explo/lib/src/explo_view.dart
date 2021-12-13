import 'dart:async';

import 'package:explo_capture/internal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vector_math/vector_math_64.dart' as vm;

import 'exploded_render_tree.dart';
import 'render_tree_loader.dart';
import 'scene_viewport.dart';
import 'theming_.dart';

/// A widget that connects to the target app via the [vmServiceUri] and
/// visualizes the render tree captured by the app.
class ExploView extends StatelessWidget {
  const ExploView({
    Key? key,
    required this.vmServiceUri,
    this.onFailedToConnect,
    this.onBackPressed,
    this.themeMode,
  }) : super(key: key);

  /// The URI of the VM Service of the app to connect to.
  final Uri vmServiceUri;

  /// Callback that is invoked when connecting to the app fails.
  final VoidCallback? onFailedToConnect;

  /// Callback that is invoked when the user presses the back button.
  ///
  /// The back button is only displayed if this callback is not `null`.
  final VoidCallback? onBackPressed;

  /// The mode to use for theming.
  final ThemeMode? themeMode;

  @override
  Widget build(BuildContext context) {
    return ExploTheme(
      themeMode: themeMode,
      child: _Providers(
        child: _ConnectToApp(
          vmServiceUri: vmServiceUri,
          onFailedToConnect: onFailedToConnect,
          child: _RenderTreeViewer(
            onBackPressed: onBackPressed,
          ),
        ),
      ),
    );
  }
}

T lateProvider<T>(Ref ref) => throw UnimplementedError();

final _renderTreeLoader =
    ChangeNotifierProvider.autoDispose<RenderTreeLoader>(lateProvider);

final _renderObjectTypesController =
    ChangeNotifierProvider.autoDispose<_RenderObjectTypesController>(
        lateProvider);

final _modelController =
    Provider.autoDispose<TransformController>(lateProvider);

final _hoveredRenderObject = StateProvider<RenderObjectData?>((_) => null);

class _Providers extends StatefulWidget {
  const _Providers({Key? key, required this.child}) : super(key: key);

  final Widget child;

  @override
  State<_Providers> createState() => _ProvidersState();
}

class _ProvidersState extends State<_Providers> {
  final _renderTreeLoaderProvider =
      ChangeNotifierProvider.autoDispose((_) => RenderTreeLoader());

  final _modelControllerProvider = Provider.autoDispose((ref) {
    final controller = createModelTransformController();
    ref.onDispose(controller.dispose);
    return controller;
  });

  final _renderObjectTypesControllerProvider =
      ChangeNotifierProvider.autoDispose((_) => _RenderObjectTypesController());

  final _hoveredRenderObjectProvider =
      StateProvider<RenderObjectData?>((_) => null);

  @override
  Widget build(BuildContext context) {
    return ProviderScope(
      overrides: [
        _renderTreeLoader.overrideWithProvider(_renderTreeLoaderProvider),
        _modelController.overrideWithProvider(_modelControllerProvider),
        _renderObjectTypesController
            .overrideWithProvider(_renderObjectTypesControllerProvider),
        _hoveredRenderObject.overrideWithProvider(_hoveredRenderObjectProvider),
      ],
      child: widget.child,
    );
  }
}

class _ConnectToApp extends ConsumerStatefulWidget {
  const _ConnectToApp({
    Key? key,
    required this.vmServiceUri,
    this.onFailedToConnect,
    required this.child,
  }) : super(key: key);

  final Uri vmServiceUri;

  final VoidCallback? onFailedToConnect;

  final Widget child;

  @override
  __ExploViewState createState() => __ExploViewState();
}

class __ExploViewState extends ConsumerState<_ConnectToApp> {
  @override
  void initState() {
    super.initState();
    final renderTreeLoader = ref.read(_renderTreeLoader);

    renderTreeLoader.addListener(() {
      if (renderTreeLoader.status == RenderTreeLoaderStatus.connectingFailed) {
        widget.onFailedToConnect?.call();
      }
    });

    scheduleMicrotask(() {
      renderTreeLoader.connectToApp(widget.vmServiceUri);
    });
  }

  @override
  Widget build(BuildContext context) {
    final renderTreeLoader = ref.watch(_renderTreeLoader);

    switch (renderTreeLoader.status) {
      case RenderTreeLoaderStatus.initial:
      case RenderTreeLoaderStatus.connecting:
        return _message(context, 'Connecting...', spinner: true);
      case RenderTreeLoaderStatus.connectingFailed:
        return _message(context, 'Failed to connect to App');
      case RenderTreeLoaderStatus.connected:
        return widget.child;
      case RenderTreeLoaderStatus.disconnected:
        return _message(context, 'App disconnected');
      default:
        throw UnsupportedError('unreachable');
    }
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

class _RenderObjectTypesController extends ChangeNotifier {
  // The types in this list have been chosen because they paint something onto
  // the screen. Those are usually the most interesting types of render objects
  // to visualize, because they correspond to something visual in the app.
  //
  // Just visualizing all types is not very useful. Because of Flutter's pattern
  // of composing widgets, there are a lot of render objects.
  static const defaultTypes = [
    'RenderCustomPaint',
    'RenderDecoratedBox',
    'RenderImage',
    'RenderParagraph',
    'RenderPhysicalModel',
    'RenderPhysicalShape',
    'RenderPhysicalShape',
    '_RenderColoredBox',
  ];

  bool get viewAllTypes => _viewAllTypes;
  var _viewAllTypes = false;

  set viewAllTypes(bool value) {
    if (value != _viewAllTypes) {
      _viewAllTypes = value;
      notifyListeners();
    }
  }

  List<String> get selectedTypes => _selectedTypes;
  var _selectedTypes = defaultTypes.toList();

  void setSelected(String type, bool selected) {
    if (selected) {
      _selectedTypes = _selectedTypes.toList()..add(type);
    } else {
      _selectedTypes = _selectedTypes.toList()..remove(type);
    }
    notifyListeners();
  }

  void resetSelection() {
    _selectedTypes = defaultTypes.toList();
    _viewAllTypes = false;
    notifyListeners();
  }
}

class _RenderTreeViewer extends ConsumerStatefulWidget {
  const _RenderTreeViewer({
    Key? key,
    this.onBackPressed,
  }) : super(key: key);

  final VoidCallback? onBackPressed;

  @override
  _RenderTreeViewerPageState createState() => _RenderTreeViewerPageState();
}

class _RenderTreeViewerPageState extends ConsumerState<_RenderTreeViewer> {
  @override
  Widget build(BuildContext context) {
    final tree = ref.watch(_renderTreeLoader).tree;

    return Scaffold(
      body: tree == null
          ? const Center(child: CircularProgressIndicator())
          : _buildContent(),
    );
  }

  Row _buildContent() {
    final renderTreeLoader = ref.watch(_renderTreeLoader);
    final tree = renderTreeLoader.tree!;

    return Row(
      children: [
        Expanded(
          child: _ViewportControls(
            onBackPressed: widget.onBackPressed,
            child: SceneViewport(children: [
              ControllerTransform(
                controller: ref.watch(_modelController),
                child: CenterTransform(
                  size: vm.Vector3(
                    tree.paintBounds.width,
                    tree.paintBounds.height,
                    1,
                  ),
                  child: Consumer(
                    builder: (context, ref, _) {
                      final typesController =
                          ref.watch(_renderObjectTypesController);
                      final types = typesController.viewAllTypes
                          ? renderTreeLoader.allTypes
                          : typesController.selectedTypes;

                      return ExplodedRenderTree(
                        root: tree,
                        types: types,
                        onHoveredRenderObjectChanged: (value) =>
                            ref.read(_hoveredRenderObject.state).state = value,
                      );
                    },
                  ),
                ),
              )
            ]),
          ),
        ),
        const VerticalDivider(width: 0),
        const _RenderObjectTypeFilter()
      ],
    );
  }
}

class _RenderObjectTypeFilter extends ConsumerStatefulWidget {
  const _RenderObjectTypeFilter({Key? key}) : super(key: key);

  @override
  _RenderObjectTypeFilterState createState() => _RenderObjectTypeFilterState();
}

class _RenderObjectTypeFilterState
    extends ConsumerState<_RenderObjectTypeFilter> {
  List<String>? _filteredTypes;

  @override
  Widget build(BuildContext context) {
    final controller = ref.watch(_renderObjectTypesController);
    final allTypes = ref.watch(_renderTreeLoader).allTypes;

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
            onTap: controller.resetSelection,
          ),
          const Divider(height: 0),
          CheckboxListTile(
            value: controller.viewAllTypes,
            title: const Text('All'),
            dense: true,
            onChanged: (value) => controller.viewAllTypes = value!,
          ),
          const Divider(height: 0),
          Expanded(
            child: ListView.builder(
              itemCount: _filteredTypes?.length ?? allTypes.length,
              itemBuilder: (context, i) {
                final type = (_filteredTypes ?? allTypes)[i];
                return CheckboxListTile(
                  key: ValueKey(type),
                  dense: true,
                  title: Text(
                    type,
                    overflow: TextOverflow.ellipsis,
                  ),
                  value: controller.viewAllTypes
                      ? true
                      : controller.selectedTypes.contains(type),
                  onChanged: controller.viewAllTypes
                      ? null
                      : (included) => controller.setSelected(type, included!),
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
        final allTypes = ref.read(_renderTreeLoader).allTypes;
        _filteredTypes = allTypes
            .where((type) => type.toLowerCase().contains(value.toLowerCase()))
            .toList();
      });
    }
  }
}

const _initialModelScale = .4;
final _frontViewRotation = vm.Vector3(0, 0, 0);
final _rotatedViewRotation = vm.Vector3(-20, 20, 0);

TransformController createModelTransformController() => TransformController()
  ..scale = _initialModelScale
  ..rotation = _rotatedViewRotation;

class _ViewportControls extends ConsumerStatefulWidget {
  const _ViewportControls({
    Key? key,
    this.onBackPressed,
    required this.child,
  }) : super(key: key);

  final VoidCallback? onBackPressed;

  final Widget child;

  @override
  _ViewportControlsState createState() => _ViewportControlsState();
}

class _ViewportControlsState extends ConsumerState<_ViewportControls>
    with SingleTickerProviderStateMixin {
  late final _rotationAnimationController = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 250),
  );
  final _rotationTween = Tween(begin: vm.Vector3.zero());

  @override
  void initState() {
    super.initState();

    // Setup the rotation animation.
    final _rotationAnimation = _rotationAnimationController
        .drive(CurveTween(curve: Curves.easeOutCubic))
        .drive(_rotationTween);

    _rotationAnimation.addListener(() {
      final rotation = _rotationAnimation.value;
      ref.read(_modelController).rotation = rotation;
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
          controller: ref.watch(_modelController),
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
                if (widget.onBackPressed != null)
                  TextButton(
                    style: textButtonStyle,
                    child: Row(
                      children: const [
                        Icon(Icons.arrow_back),
                        Text('Back'),
                      ],
                    ),
                    onPressed: widget.onBackPressed,
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
        const Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          child: _ViewportStatusBar(),
        )
      ],
    );
  }

  void _animateToRotation(vm.Vector3 newRotation) {
    final controller = ref.read(_modelController);

    final currentRotation = vm.Vector3(
      controller.rotationX,
      controller.rotationY,
      controller.rotationZ,
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

class _ViewportStatusBar extends ConsumerWidget {
  const _ViewportStatusBar({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hoveredRenderObject = ref.watch(_hoveredRenderObject);
    final renderTreeLoader = ref.watch(_renderTreeLoader);

    Widget? hoveredRenderObjectType;
    if (hoveredRenderObject != null) {
      final type = hoveredRenderObject.type;
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
              renderTreeLoader.typeCounts[type].toString(),
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
