import 'dart:collection';
import 'dart:developer';

import 'package:flutter/rendering.dart';

/// Data of a [RenderObject] and its [children], that is used to render the
/// render tree in 3D.
class RenderObjectData {
  /// Creates the data for a [RenderObject].
  ///
  /// Does not populate [children]. Use [capture] to create a fully populated
  /// [RenderObjectData] from a [RenderObject].
  RenderObjectData({
    required this.type,
    required this.paintBounds,
  });

  /// Captures the [RenderObjectData] for the given [renderObject] and its
  /// children.
  factory RenderObjectData.capture(RenderObject renderObject) {
    // Note on performance: If this function becomes a bottleneck, we can
    // consider capturing geometry data only for render objects we are going
    // to display. For all others, we would not need to calculate the transform
    // and paint bounds in global coordinates.

    Timeline.startSync('RenderObjectData.capture', arguments: <String, Object?>{
      'renderObject': renderObject.runtimeType.toString(),
    });

    // The RenderObjects for which to capture data, mapped to the data of their
    // parents.
    final workingSet = HashMap<RenderObject, RenderObjectData>();

    RenderObjectData createData(
      RenderObject renderObject,
      RenderObjectData? parent,
    ) {
      var transform = renderObject.getTransformTo(parent?._renderObject);
      if (parent != null) {
        transform = (parent._transform * transform) as Matrix4;
      }

      final data = RenderObjectData(
        type: renderObject.runtimeType.toString(),
        paintBounds:
            MatrixUtils.transformRect(transform, renderObject.paintBounds),
      )
        .._renderObject = renderObject
        .._transform = transform;

      if (parent != null) {
        parent.addChild(data);
      }

      renderObject.visitChildren((child) {
        workingSet[child] = data;
      });

      return data;
    }

    final rootData = createData(renderObject, null);

    while (workingSet.isNotEmpty) {
      final renderObject = workingSet.keys.first;
      final parentData = workingSet.remove(renderObject);
      createData(renderObject, parentData);
    }

    Timeline.finishSync();

    return rootData;
  }

  /// Deserializes a [RenderObjectData] and its children from the given [json].
  factory RenderObjectData.fromJson(Map<String, Object?> json) {
    final paintBounds = (json['pb'] as List<Object?>).cast<double>();

    final data = RenderObjectData(
      paintBounds: Rect.fromLTRB(
        paintBounds[0],
        paintBounds[1],
        paintBounds[2],
        paintBounds[3],
      ),
      type: json['t'] as String,
    );

    final children =
        (json['c'] as List<Object?>?)?.cast<Map<String, Object?>>() ?? [];

    for (var json in children) {
      data.addChild(RenderObjectData.fromJson(json));
    }

    return data;
  }

  // Internal state, used while capturing the render tree.
  late final RenderObject _renderObject;
  late final Matrix4 _transform;

  /// The runtime type of the [RenderObject].
  final String type;

  /// The paint bounds of the [RenderObject] in the global coordinate system.
  final Rect paintBounds;

  /// The data of the [RenderObject]'s parent.
  RenderObjectData? get parent => _parent;
  RenderObjectData? _parent;

  /// The level of the [RenderObject] in the render tree.
  int get level => parent == null ? 0 : parent!.level + 1;

  /// The data of the [RenderObject]'s children.
  List<RenderObjectData> get children => _children;
  final List<RenderObjectData> _children = [];

  /// Adds the given [RenderObjectData] as a [child] of this [RenderObjectData].
  void addChild(RenderObjectData child) {
    assert(child.parent == null);
    assert(!children.contains(child));
    child._parent = this;
    children.add(child);
  }

  /// The data of the [RenderObject]'s descendants.
  List<RenderObjectData> get descendants {
    final workingSet = [this];
    final result = <RenderObjectData>[];

    while (workingSet.isNotEmpty) {
      final renderObject = workingSet.removeLast();
      result.add(renderObject);
      workingSet.addAll(renderObject.children);
    }

    return result;
  }

  /// The JSON representation of this instance.
  Map<String, Object?> toJson() => {
        'pb': [
          paintBounds.left,
          paintBounds.top,
          paintBounds.right,
          paintBounds.bottom,
        ],
        't': type,
        'c': children.isEmpty ? null : children.map((c) => c.toJson()).toList(),
      };

  @override
  String toString() => 'RenderObjectData('
      'paintBounds: $paintBounds, '
      'type: $type, '
      'children: $children'
      ')';
}
