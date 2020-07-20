import 'package:flutter/material.dart';

import 'render_object_info.dart';
import 'transform_widgets.dart';

class ExplodedTreeViewer extends StatefulWidget {
  const ExplodedTreeViewer({
    @required this.root,
    this.includedTypes,
  });

  final RenderObjectInfo root;

  final List<String> includedTypes;

  @override
  _ExplodedTreeViewerState createState() => _ExplodedTreeViewerState();
}

class _ExplodedTreeViewerState extends State<ExplodedTreeViewer> {
  double _scale = 1;
  double _scaleLowerLimit = .25;
  double _scaleUpperLimit = 4;

  @override
  Widget build(BuildContext context) {
    return ClipRect(
      child: Stack(
        children: [
          CameraTransform(builder: (context, cameraTransform) {
            return InteractiveModelTransform(
              modelSize: widget.root.paintBounds.size,
              scale: _scale,
              scaleChanged: (scale) => setState(() => _scale = scale),
              scaleLowerLimit: _scaleLowerLimit,
              scaleUpperLimit: _scaleUpperLimit,
              builder: (context, modelTransform) {
                return SizedBox.expand(
                  child: Stack(
                    overflow: Overflow.clip,
                    alignment: Alignment.topLeft,
                    clipBehavior: Clip.hardEdge,
                    children: _buildRenderObjectRepresentations(
                        cameraTransform * modelTransform),
                  ),
                );
              },
            );
          }),
          _buildScaleSlider(),
        ],
      ),
    );
  }

  Widget _buildScaleSlider() {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: Slider(
        value: _scale,
        onChanged: (value) => setState(() => _scale = value),
        min: _scaleLowerLimit,
        max: _scaleUpperLimit,
      ),
    );
  }

  List<Widget> _buildRenderObjectRepresentations(Matrix4 transformStack) {
    final lowerRenderObjects = <RenderObjectInfo>[];

    void collectRenderObjects(RenderObjectInfo info) {
      final topRenderObject = info;
      lowerRenderObjects.add(topRenderObject);
      topRenderObject.children.forEach(collectRenderObjects);
    }

    collectRenderObjects(widget.root);

    final treeLevelToVisualLevel =
        (lowerRenderObjects.map((it) => it.level).toSet().toList()..sort())
            .asMap()
            .map((visualLevel, treeLevel) => MapEntry(treeLevel, visualLevel));

    return lowerRenderObjects
        .where((it) => widget.includedTypes?.contains(it.type) ?? true)
        .map((it) {
      return _RenderObjectRepresentation(
        info: it,
        level: treeLevelToVisualLevel[it.level],
        transformStack: transformStack.clone(),
      );
    }).toList()
          ..sort((a, b) => a.level - b.level);
  }
}

class _RenderObjectRepresentation extends StatefulWidget {
  const _RenderObjectRepresentation({
    @required this.info,
    @required this.level,
    @required this.transformStack,
  });

  final RenderObjectInfo info;
  final int level;
  final Matrix4 transformStack;

  @override
  _RenderObjectRepresentationState createState() =>
      _RenderObjectRepresentationState();
}

class _RenderObjectRepresentationState
    extends State<_RenderObjectRepresentation> {
  bool _hovered = false;
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    return OverflowBox(
      minHeight: 0,
      maxHeight: double.infinity,
      minWidth: 0,
      maxWidth: double.infinity,
      alignment: Alignment.topLeft,
      child: Transform(
        transform: widget.transformStack.clone()
          ..translate(
            widget.info.paintBounds.left,
            widget.info.paintBounds.top,
            widget.level * 40.0,
          ),
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
                  size: widget.info.paintBounds.size,
                  child: Container(
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: Colors.blue,
                        width: _hovered || _focused ? 2 : 0,
                      ),
                    ),
                  ),
                ),
                if (_hovered || _focused)
                  FractionalTranslation(
                    translation: Offset(0, -1),
                    child: Text(
                      widget.info.type,
                      style: TextStyle(fontSize: 12),
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
