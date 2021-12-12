import 'package:explo/src/exploded_render_tree.dart';
import 'package:explo/src/scene_viewport.dart';
import 'package:explo_capture/internal.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vector_math/vector_math_64.dart';

void main() {
  testWidgets(
    'Golden: Front view',
    (tester) async {
      final root = buildTestRenderTree();

      await tester.pumpWidget(TestViewer(root: root));

      expect(
        find.byType(SceneViewport),
        matchesGoldenFile('goldens/ExplodedRenderTree/front_view.png'),
      );
    },
  );

  testWidgets(
    'Golden: Rotated view',
    (tester) async {
      final root = buildTestRenderTree();

      await tester.pumpWidget(TestViewer(
        root: root,
        transform: Matrix4.identity()
          ..rotateX(radians(-15))
          ..rotateY(radians(15)),
        style: ExplodedRenderTreeStyle.fallback().copyWith(
          zAxisSpacing: 40,
        ),
      ));

      expect(
        find.byType(SceneViewport),
        matchesGoldenFile('goldens/ExplodedRenderTree/rotated_view.png'),
      );
    },
  );
}

class TestViewer extends StatelessWidget {
  const TestViewer({
    Key? key,
    required this.root,
    this.transform,
    this.style,
  }) : super(key: key);

  final RenderObjectData root;

  final Matrix4? transform;

  final ExplodedRenderTreeStyle? style;

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.ltr,
      child: SceneViewport(
        children: [
          MatrixTransform(
            transform: transform ?? Matrix4.identity(),
            child: CenterTransform(
              size: Vector3(
                root.paintBounds.width,
                root.paintBounds.height,
                0.0,
              ),
              child: ExplodedRenderTree(
                root: root,
                style: style,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

RenderObjectData buildTestRenderTree() {
  final root = RenderObjectData(
    type: 'RenderTest',
    paintBounds: const Rect.fromLTWH(0, 0, 250, 500),
  );

  final level1 =
      root.addTestChild(paintBounds: const Rect.fromLTWH(0, 50, 250, 450));

  level1.addTestChild(paintBounds: const Rect.fromLTWH(75, 75, 100, 100));
  level1.addTestChild(paintBounds: const Rect.fromLTWH(-100, 300, 450, 100));

  return root;
}

extension on RenderObjectData {
  RenderObjectData addTestChild({
    required Rect paintBounds,
    bool relative = true,
  }) {
    final child = RenderObjectData(
      type: 'RenderTest',
      paintBounds: relative
          ? Rect.fromLTWH(
              this.paintBounds.left + paintBounds.left,
              this.paintBounds.top + paintBounds.top,
              paintBounds.width,
              paintBounds.height,
            )
          : paintBounds,
    );
    addChild(child);
    return child;
  }
}
