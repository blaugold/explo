import 'dart:convert';

import 'package:explo_capture/src/render_object_data.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'capture render tree data',
    (tester) async {
      final binding = TestWidgetsFlutterBinding.ensureInitialized()
          as TestWidgetsFlutterBinding;
      await binding.setSurfaceSize(const Size.square(200));

      await tester.pumpWidget(
        Center(
          child: SizedBox.fromSize(
            size: const Size.square(100),
            child: const SizedBox(),
          ),
        ),
      );

      final root = tester.firstRenderObject(find.byType(Center));
      final rootData = RenderObjectData.capture(root);
      expect(rootData.parent, isNull);
      expect(rootData.type, 'RenderPositionedBox');
      expect(rootData.level, 0);
      expect(rootData.paintBounds, const Rect.fromLTWH(0, 0, 200, 200));

      final childData = rootData.children.first;
      expect(childData.parent, rootData);
      expect(childData.type, 'RenderConstrainedBox');
      expect(childData.level, 1);
      expect(childData.paintBounds, const Rect.fromLTWH(50, 50, 100, 100));

      final grandChildData = childData.children.first;
      expect(rootData.children, [childData]);
      expect(childData.children, [grandChildData]);
      expect(grandChildData.parent, childData);
      expect(
        rootData.descendants,
        containsAll(<Object>[childData, grandChildData]),
      );
    },
  );

  test('serialize to and from JSON', () {
    final a = RenderObjectData(
      type: 'a',
      paintBounds: const Rect.fromLTWH(1, 2, 3, 4),
    );
    final b = RenderObjectData(
      type: 'b',
      paintBounds: const Rect.fromLTWH(5, 6, 7, 8),
    );
    a.addChild(b);

    final json = jsonDecode(jsonEncode(a.toJson())) as Map<String, Object?>;

    final a_ = RenderObjectData.fromJson(json);
    expect(a_.type, a.type);
    expect(a_.level, a.level);
    expect(a_.paintBounds, a.paintBounds);

    final b_ = a_.children.first;
    expect(b_.type, b.type);
    expect(b_.level, b.level);
    expect(b_.paintBounds, b.paintBounds);
  });
}
