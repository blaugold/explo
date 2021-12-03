import 'package:flutter/rendering.dart';

class RenderObjectInfo {
  RenderObjectInfo({
    required this.type,
    required this.paintBounds,
  });

  final Rect paintBounds;
  final String type;
  RenderObjectInfo? parent;
  final List<RenderObjectInfo> children = [];

  RenderObjectInfo flattenWithPaintBounds() {
    if (children.length == 1 && children.first.paintBounds == paintBounds) {
      return children.first.flattenWithPaintBounds();
    }

    return this;
  }

  int get level => parent == null ? 0 : parent!.level + 1;

  factory RenderObjectInfo.fromJson(Map<String, dynamic> map) {
    final paintBounds = (map['pb'] as List<dynamic>).cast<double>();

    final info = RenderObjectInfo(
      paintBounds: Rect.fromLTRB(
        paintBounds[0],
        paintBounds[1],
        paintBounds[2],
        paintBounds[3],
      ),
      type: map['t'] as String,
    );

    final children =
        (map['c'] as List<dynamic>?)?.cast<Map<String, dynamic>>() ?? [];

    for (var json in children) {
      final child = RenderObjectInfo.fromJson(json);
      info.children.add(child);
      child.parent = info;
    }

    return info;
  }

  Map<String, dynamic> toJson() {
    // ignore: unnecessary_cast
    return {
      'pb': [
        paintBounds.left,
        paintBounds.top,
        paintBounds.right,
        paintBounds.bottom,
      ],
      't': type,
      'c': children.isEmpty ? null : children.map((c) => c.toJson()).toList(),
    } as Map<String, dynamic>;
  }

  @override
  String toString() {
    return 'RenderObjectInfo{paintBounds: $paintBounds, type: $type, children: $children}';
  }
}

RenderObjectInfo captureRenderObjectInfo(RenderObject renderObject) {
  final transform = renderObject.getTransformTo(null);
  final info = RenderObjectInfo(
    type: renderObject.runtimeType.toString(),
    paintBounds: MatrixUtils.transformRect(transform, renderObject.paintBounds),
  );

  renderObject.visitChildren((child) {
    final childInfo = captureRenderObjectInfo(child);
    info.children.add(childInfo);
    childInfo.parent = info;
  });

  return info;
}
