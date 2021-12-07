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
    final transform = renderObject.getTransformTo(null);
    final data = RenderObjectData(
      type: renderObject.runtimeType.toString(),
      paintBounds:
          MatrixUtils.transformRect(transform, renderObject.paintBounds),
    );

    renderObject.visitChildren((child) {
      final childData = RenderObjectData.capture(child);
      data.children.add(childData);
      childData.parent = data;
    });

    return data;
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
      final child = RenderObjectData.fromJson(json);
      data.children.add(child);
      child.parent = data;
    }

    return data;
  }

  /// The runtime type of the [RenderObject].
  final String type;

  /// The paint bounds of the [RenderObject] in the global coordinate system.
  final Rect paintBounds;

  /// The data of the [RenderObject]'s parent.
  RenderObjectData? parent;

  /// The level of the [RenderObject] in the render tree.
  int get level => parent == null ? 0 : parent!.level + 1;

  /// The data of the [RenderObject]'s children.
  final List<RenderObjectData> children = [];

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

  RenderObjectData flattenWithPaintBounds() {
    if (children.length == 1 && children.first.paintBounds == paintBounds) {
      return children.first.flattenWithPaintBounds();
    }

    return this;
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
