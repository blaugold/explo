import 'dart:async';

import 'package:explo_capture/internal.dart';
import 'package:flutter/material.dart';

import 'scene_viewport.dart';

/// A style, which defines the look of an [ExplodedRenderTree].
class ExplodedRenderTreeStyle {
  /// Creates a style, which defines the look of an [ExplodedRenderTree].
  ExplodedRenderTreeStyle({
    required this.borderColor,
    required this.surfaceColor,
    required this.zAxisSpacing,
  });

  /// Fallback style that is used when no other style is available.
  factory ExplodedRenderTreeStyle.fallback() => ExplodedRenderTreeStyle(
        borderColor: MaterialStateProperty.all(Colors.grey[400]!),
        surfaceColor: MaterialStateProperty.resolveWith((states) {
          final baseColor = Colors.grey[700]!.withOpacity(.1);

          if (states.contains(MaterialState.hovered)) {
            return baseColor.withOpacity(.2);
          }

          return baseColor;
        }),
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

  /// The spacing to use between different levels of the render tree, on the
  /// z-axis.
  ///
  /// In an app, the render tree is painted onto a flat 2D surface. This
  /// property controls how the depth of a render object in the rendert tree,
  /// is visualized in a third dimension.
  final double zAxisSpacing;

  /// Creates a copy of this style, optionally overriding some of its
  /// properties.
  ExplodedRenderTreeStyle copyWith({
    MaterialStateProperty<Color?>? borderColor,
    MaterialStateProperty<Color?>? surfaceColor,
    double? zAxisSpacing,
  }) {
    return ExplodedRenderTreeStyle(
      borderColor: borderColor ?? this.borderColor,
      surfaceColor: surfaceColor ?? this.surfaceColor,
      zAxisSpacing: zAxisSpacing ?? this.zAxisSpacing,
    );
  }
}

/// A widget for use in a [SceneViewport], that displays an exploded
/// visualization of a Flutter render tree.
///
/// Render objects are placed along the z axis, according to their depth in the
/// render tree.
class ExplodedRenderTree extends StatefulWidget {
  /// Creates a widget for use in a [SceneViewport], that displays an exploded
  /// visualization of a Flutter render tree.
  const ExplodedRenderTree({
    Key? key,
    required this.root,
    this.types,
    this.style,
    this.onHoveredRenderObjectChanged,
  }) : super(key: key);

  /// The root of the render tree to display.
  final RenderObjectData root;

  /// The types of render objects to display.
  ///
  /// If null, all render objects will be displayed.
  final List<String>? types;

  /// The style to use for rendering the render tree.
  ///
  /// If none is provided, [ExplodedRenderTreeStyle.fallback] will be used.
  final ExplodedRenderTreeStyle? style;

  /// Callback that is invoked when the render object that is currently hovered
  /// changes.
  final ValueChanged<RenderObjectData?>? onHoveredRenderObjectChanged;

  @override
  State<ExplodedRenderTree> createState() => _ExplodedRenderTreeState();
}

class _ExplodedRenderTreeState extends State<ExplodedRenderTree> {
  late List<_VisualLevelRenderObject> _renderObjects;
  RenderObjectData? _hoveredRenderObject;

  @override
  void initState() {
    super.initState();
    _buildRenderObjects();
  }

  @override
  void didUpdateWidget(covariant ExplodedRenderTree oldWidget) {
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
        widget.style ?? ExplodedRenderTreeStyle.fallback();

    return SceneGroup(
      children: [
        /// Render objects.
        for (final renderObject in _renderObjects)
          _SceneRenderObject(
            renderObject: renderObject,
            renderObjectStyle: renderObjectStyle,
            onIsHoveredChanged: (isHovered) {
              if (isHovered) {
                _hoveredRenderObject = renderObject.renderObject;
                widget.onHoveredRenderObjectChanged?.call(_hoveredRenderObject);
              } else {
                scheduleMicrotask(() {
                  if (_hoveredRenderObject == renderObject.renderObject) {
                    _hoveredRenderObject = null;
                    widget.onHoveredRenderObjectChanged?.call(null);
                  }
                });
              }
            },
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
    required this.onIsHoveredChanged,
  }) : super(key: key);

  final _VisualLevelRenderObject renderObject;
  final ExplodedRenderTreeStyle renderObjectStyle;
  final ValueChanged<bool> onIsHoveredChanged;

  @override
  State<_SceneRenderObject> createState() => _SceneRenderObjectState();
}

class _SceneRenderObjectState extends State<_SceneRenderObject> {
  final _states = <MaterialState>{};

  @override
  Widget build(BuildContext context) {
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
              widget.onIsHoveredChanged(showHoverHighlight);
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
            child: SizedBox.fromSize(
              size: renderObject.paintBounds.size,
              child: Container(
                decoration: BoxDecoration(
                  border: border,
                  color: surfaceColor,
                ),
              ),
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
