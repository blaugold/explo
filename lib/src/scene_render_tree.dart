import 'package:flutter/material.dart';

import 'render_object_data.dart';
import 'scene_viewport.dart';
import 'theming_utils.dart';

/// An immutable object, describing how to visualize a [RenderObject].
class RenderObjectStyle {
  /// Creates an immutable object, describing how to visualize a [RenderObject].
  RenderObjectStyle({
    required this.borderColor,
    required this.surfaceColor,
    this.labelStyle,
    required this.zAxisSpacing,
  });

  /// Fallback style that is used when no other style is available.
  factory RenderObjectStyle.fallback() => RenderObjectStyle(
        borderColor: MaterialStateProperty.all(Colors.grey[400]!),
        surfaceColor: MaterialStateProperty.resolveWith((states) {
          final baseColor = Colors.grey[700]!.withOpacity(.1);

          if (states.contains(MaterialState.hovered)) {
            return baseColor.withOpacity(.2);
          }

          return baseColor;
        }),
        labelStyle: const TextStyle(fontSize: 12),
        zAxisSpacing: 20,
      );

  /// The color used to paint a border around the paint bounds of a render
  /// object.
  ///
  /// If the [MaterialStateProperty] resolves to `null`, the won't border be
  /// displayed.
  final MaterialStateProperty<Color?> borderColor;

  /// The color used to fill the area enclosed by the paint bounds of a render
  /// object.
  ///
  /// If the [MaterialStateProperty] resolves to `null`, the surface won't be
  /// displayed.
  final MaterialStateProperty<Color?> surfaceColor;

  /// The [TextStyle] used to paint the label of a render object.
  final TextStyle? labelStyle;

  /// The spacing to use between different levels of the render tree, on the
  /// z-axis.
  ///
  /// In an app, the render tree is painted onto a flat 2D surface. This
  /// property controls how the depth of a render object in the rendert tree,
  /// is visualized in a third dimension.
  final double zAxisSpacing;
}

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
    this.renderObjectStyle,
  }) : super(key: key);

  /// The root of the render tree to display.
  final RenderObjectData root;

  /// The types of render objects to display.
  ///
  /// If null, all render objects will be displayed.
  final List<String>? types;

  /// The style to use for rendering the render tree.
  ///
  /// If none is provided, [RenderObjectStyle.fallback] will be used.
  final RenderObjectStyle? renderObjectStyle;

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
    final renderObjectStyle =
        widget.renderObjectStyle ?? RenderObjectStyle.fallback();

    return SceneGroup(
      children: [
        /// Render objects.
        for (final renderObject in _renderObjects)
          _SceneRenderObject(
            renderObject: renderObject,
            renderObjectStyle: renderObjectStyle,
          )
      ],
    );
  }
}

class _SceneRenderObject extends StatefulWidget {
  const _SceneRenderObject({
    Key? key,
    required this.renderObject,
    required this.renderObjectStyle,
  }) : super(key: key);

  final _VisualLevelRenderObject renderObject;
  final RenderObjectStyle renderObjectStyle;

  @override
  State<_SceneRenderObject> createState() => _SceneRenderObjectState();
}

class _SceneRenderObjectState extends State<_SceneRenderObject> {
  final _states = <MaterialState>{};

  @override
  Widget build(BuildContext context) {
    final showLabel = const HasAnyState({
      MaterialState.hovered,
      MaterialState.focused,
    }).resolve(_states);
    final borderColor = widget.renderObjectStyle.borderColor.resolve(_states);
    final surfaceColor = widget.renderObjectStyle.surfaceColor.resolve(_states);

    Border? border;
    if (borderColor != null) {
      border = Border.all(color: borderColor, width: 0);
    }

    final renderObject = widget.renderObject.renderObject;
    final translation = Matrix4.translationValues(
      renderObject.paintBounds.left,
      renderObject.paintBounds.top,
      widget.renderObject.visualLevel * widget.renderObjectStyle.zAxisSpacing,
    );

    return MatrixTransform(
      transform: translation,
      child: SceneWidget(
        child: GestureDetector(
          child: FocusableActionDetector(
            onShowHoverHighlight: (showHoverHighlight) {
              setState(() {
                if (showHoverHighlight) {
                  _states.add(MaterialState.hovered);
                } else {
                  _states.remove(MaterialState.hovered);
                }
              });
            },
            onShowFocusHighlight: (showFocusHighlight) {
              setState(() {
                if (showFocusHighlight) {
                  _states.add(MaterialState.focused);
                } else {
                  _states.remove(MaterialState.focused);
                }
              });
            },
            child: Stack(
              children: [
                SizedBox.fromSize(
                  size: renderObject.paintBounds.size,
                  child: Container(
                    decoration: BoxDecoration(
                      border: border,
                      color: surfaceColor,
                    ),
                  ),
                ),
                if (showLabel)
                  FractionalTranslation(
                    translation: const Offset(0, -1),
                    child: Text(
                      renderObject.type,
                      style: widget.renderObjectStyle.labelStyle,
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
