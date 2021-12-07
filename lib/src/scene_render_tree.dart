import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import 'render_object_data.dart';
import 'scene_viewport.dart';

/// A widget that displays a render tree, represented by the [root]
/// [RenderObjectData] in a 3D scene.
///
/// Render objects are placed along the z axis, according to their depth in the
/// render tree.
class SceneRenderTree extends StatefulWidget {
  /// Creates a widget that displays a render tree, represented by the [root]
  /// [RenderObjectData] in a 3D scene.
  const SceneRenderTree({
    Key? key,
    required this.root,
    this.types,
  }) : super(key: key);

  /// The root of the render tree to display.
  final RenderObjectData root;

  /// The types of render objects to display.
  ///
  /// If null, all render objects will be displayed.
  final List<String>? types;

  @override
  State<SceneRenderTree> createState() => _SceneRenderTreeState();
}

class _SceneRenderTreeState extends State<SceneRenderTree> {
  late List<_VisualLevelRenderObject> _renderObjects;

  @override
  void initState() {
    super.initState();
    _buildRenderObjects();
  }

  @override
  void didUpdateWidget(covariant SceneRenderTree oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.root != oldWidget.root || widget.types != oldWidget.types) {
      _buildRenderObjects();
    }
  }

  void _buildRenderObjects() {
    _renderObjects = _buildVisualLevelRenderObject(
      widget.root,
      widget.types,
    );
  }

  @override
  Widget build(BuildContext context) {
    return SceneGroup(
      children: [
        // Marker to show the root of the render tree.
        SceneWidget(
            child: SizedBox(
          width: _renderObjects.first.renderObject.paintBounds.width,
          height: _renderObjects.first.renderObject.paintBounds.height,
          child: Center(
            child: Container(
              width: 20,
              height: 20,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.red,
              ),
            ),
          ),
        )),

        /// Render objects.
        for (final renderObject in _renderObjects)
          _SceneRenderObject(renderObject: renderObject)
      ],
    );
  }
}

class _SceneRenderObject extends StatefulWidget {
  const _SceneRenderObject({
    Key? key,
    required this.renderObject,
  }) : super(key: key);

  final _VisualLevelRenderObject renderObject;

  @override
  State<_SceneRenderObject> createState() => _SceneRenderObjectState();
}

class _SceneRenderObjectState extends State<_SceneRenderObject> {
  bool _hovered = false;
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final highlighted = _hovered || _focused;
    final renderObject = widget.renderObject.renderObject;
    final translation = Matrix4.translationValues(
      renderObject.paintBounds.left,
      renderObject.paintBounds.top,
      widget.renderObject.visualLevel * 40.0,
    );

    return MatrixTransform(
      transform: translation,
      child: SceneWidget(
        child: GestureDetector(
          child: FocusableActionDetector(
            onShowHoverHighlight: (showHoverHighlight) {
              setState(() {
                _hovered = showHoverHighlight;
              });
            },
            onShowFocusHighlight: (showFocusHighlight) {
              setState(() {
                _focused = showFocusHighlight;
              });
            },
            child: Stack(
              children: [
                SizedBox.fromSize(
                  size: renderObject.paintBounds.size,
                  child: Container(
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: Theme.of(context).colorScheme.primary,
                        width: 0,
                      ),
                      color: Theme.of(context)
                          .colorScheme
                          .primaryVariant
                          .withOpacity(highlighted ? .25 : .1),
                    ),
                  ),
                ),
                if (highlighted)
                  FractionalTranslation(
                    translation: const Offset(0, -1),
                    child: Text(
                      renderObject.type,
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _VisualLevelRenderObject {
  _VisualLevelRenderObject(this.renderObject, this.visualLevel);

  final RenderObjectData renderObject;
  final int visualLevel;
}

List<_VisualLevelRenderObject> _buildVisualLevelRenderObject(
  RenderObjectData root,
  List<String>? includedTypes,
) {
  final renderObjects = root.descendants;

  final sorterRenderObjectLevels =
      (renderObjects.map((it) => it.level).toSet().toList()..sort());

  final treeLevelToVisualLevelMapping = sorterRenderObjectLevels
      .asMap()
      .map((visualLevel, treeLevel) => MapEntry(treeLevel, visualLevel));

  final filteredRenderObjects = includedTypes == null
      ? renderObjects
      : renderObjects.where((it) => includedTypes.contains(it.type));

  return filteredRenderObjects
      .map((renderObject) => _VisualLevelRenderObject(
            renderObject,
            treeLevelToVisualLevelMapping[renderObject.level]!,
          ))
      .toList()
    ..sort((a, b) => a.visualLevel - b.visualLevel);
}
