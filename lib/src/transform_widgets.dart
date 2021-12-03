import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:vector_math/vector_math_64.dart' as vm;

typedef TransformWidgetBuilder = Widget Function(BuildContext, Matrix4);

class CameraTransform extends StatelessWidget {
  const CameraTransform({
    Key? key,
    required this.builder,
  }) : super(key: key);

  final TransformWidgetBuilder builder;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      final cameraTransform = _buildCameraTransform(constraints.biggest);
      return builder(context, cameraTransform);
    });
  }

  Matrix4 _buildCameraTransform(Size viewport) {
    final viewportTransform = Matrix4.translationValues(
      viewport.width / 2,
      viewport.height / 2,
      0,
    )..scale(viewport.width / 2, viewport.height / 2, 1);

//    final perspectiveTransform = vm.makePerspectiveMatrix(
//      vm.radians(45),
//      viewport.aspectRatio,
//      .01,
//      100000,
//    );

    final perspectiveTransform = vm.makeOrthographicMatrix(
      -viewport.width / 2,
      viewport.width / 2,
      -viewport.height / 2,
      viewport.height / 2,
      .01,
      100000,
    );

    final viewTransform = vm.makeViewMatrix(
      vm.Vector3(0, 0, 3000),
      vm.Vector3(0, 0, 0),
      vm.Vector3(0, 1, 0),
    );

    return (viewportTransform * perspectiveTransform * viewTransform)
        as Matrix4;
  }
}

class InteractiveModelTransform extends StatefulWidget {
  const InteractiveModelTransform({
    required this.modelSize,
    required this.scale,
    required this.scaleChanged,
    required this.scaleLowerLimit,
    required this.scaleUpperLimit,
    required this.builder,
  });

  final Size modelSize;
  final double scale;
  final ValueChanged<double> scaleChanged;
  final double scaleLowerLimit;
  final double scaleUpperLimit;
  final TransformWidgetBuilder builder;

  @override
  _InteractiveModelTransformState createState() =>
      _InteractiveModelTransformState();
}

class _InteractiveModelTransformState extends State<InteractiveModelTransform> {
  double _rotationY = 15;
  double _rotationX = -15;
  Offset _offset = Offset.zero;

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerSignal: (e) {
        if (e is PointerScrollEvent) {
          if (RawKeyboard.instance.keysPressed.isNotEmpty &&
              LogicalKeySet.fromSet(RawKeyboard.instance.keysPressed) ==
                  LogicalKeySet(LogicalKeyboardKey.altLeft)) {
            final newScale = (widget.scale + e.scrollDelta.dy * .001)
                .clamp(widget.scaleLowerLimit, widget.scaleUpperLimit)
                .toDouble();
            widget.scaleChanged(newScale);
          } else {
            setState(() {
              _offset = _offset + (e.scrollDelta * -1);
            });
          }
        }
      },
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onPanUpdate: (event) {
          setState(() {
            _rotationY += event.delta.dx * .1;
            _rotationX += event.delta.dy * -.1;
          });
        },
        child: widget.builder(context, _buildModelTransform()),
      ),
    );
  }

  Matrix4 _buildModelTransform() =>
      (Matrix4.translationValues(_offset.dx, _offset.dy, 0) *
          Matrix4.rotationX(vm.radians(_rotationX)) *
          Matrix4.rotationY(vm.radians(_rotationY)) *
          (Matrix4.identity()
            ..scale(widget.scale, widget.scale, widget.scale)) *
          Matrix4.translationValues(
            -widget.modelSize.width / 2,
            -widget.modelSize.height / 2,
            0,
          )) as Matrix4;
}
