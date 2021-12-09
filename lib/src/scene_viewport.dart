import 'dart:math';

import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';
import 'package:vector_math/vector_math_64.dart' as vm;

/// Widget which establishes or pushes onto the transform stack of its subtree.
///
/// To establish a transform stack in the widget tree, use [root] to provide an
/// identity transform.
///
/// Once a transform stack is established, [push] can be used to push a
/// transform onto the stack.
///
/// To get the current transform stack, at any point in the widget tree, use
/// [TransformStack.of].
class TransformStack extends InheritedWidget {
  /// Establishes a transform stack with an identity transform, for its subtree.
  TransformStack.root({
    Key? key,
    required Widget child,
  })  : _transform = Matrix4.identity(),
        super(key: key, child: child);

  /// Pushes a [transform] onto the transform stack, for its subtree.
  TransformStack.push({
    Key? key,
    required BuildContext context,
    required Matrix4 transform,
    required Widget child,
  })  : _transform = (TransformStack.of(context) * transform) as Matrix4,
        super(key: key, child: child);

  final Matrix4 _transform;

  /// Returns the transform stack for the location in the widget tree with the
  /// given [context].
  static Matrix4 of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<TransformStack>()!._transform;

  @override
  bool updateShouldNotify(TransformStack oldWidget) =>
      _transform != oldWidget._transform;
}

/// A type of camera projection.
enum Projection {
  /// A projection that represents lengths without distortions.
  orthographic,

  /// A projection that represents lengths with a perspective effect.
  perspective,
}

/// Widget that establishes a camera perspective for its subtree.
///
/// The view of the camera is currently fixed. It is looking at the origin,
/// along the z-axis, from a distance of 3000.
class CameraTransform extends StatelessWidget {
  const CameraTransform({
    Key? key,
    this.projection = Projection.orthographic,
    required this.child,
  }) : super(key: key);

  /// The projection type of the camera.
  final Projection projection;

  /// The widget subtree.
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      return TransformStack.push(
        context: context,
        transform: _buildCameraTransform(constraints.biggest),
        child: child,
      );
    });
  }

  Matrix4 _buildCameraTransform(Size viewport) {
    // Center the viewport and scale to the aspect ratio of the viewport.
    final viewportTransform = Matrix4.translationValues(
      viewport.width / 2,
      viewport.height / 2,
      0,
    )..scale(viewport.width / 2, viewport.height / 2, 1);

    // Setup the camera perspective.
    Matrix4 perspectiveTransform;
    switch (projection) {
      case Projection.orthographic:
        perspectiveTransform = vm.makeOrthographicMatrix(
          -viewport.width / 2,
          viewport.width / 2,
          -viewport.height / 2,
          viewport.height / 2,
          .01,
          100000,
        );
        break;
      case Projection.perspective:
        perspectiveTransform = vm.makePerspectiveMatrix(
          // 45 degrees view of field.
          vm.radians(45),
          viewport.aspectRatio,
          .01,
          100000,
        );
        break;
    }

    // The camera is looking at the origin, along the z-axis, from a distance of
    // 3000.
    final viewTransform = vm.makeViewMatrix(
      vm.Vector3(0, 0, 3000),
      vm.Vector3(0, 0, 0),
      vm.Vector3(0, 1, 0),
    );

    return (viewportTransform * perspectiveTransform * viewTransform)
        as Matrix4;
  }
}

/// A widget in wich a 3D scene is displayed.
///
/// Widgets can be displayed in the scene using the [SceneWidget].
///
/// To position widgets, use the various transform widgets:
///
/// - [MatrixTransform]
/// - [ControllerTransform]
/// - [CenterTransform]
class SceneViewport extends StatelessWidget {
  const SceneViewport({
    Key? key,
    required this.children,
  }) : super(key: key);

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return TransformStack.root(
      child: CameraTransform(
        // We need the ClipRect, because Stack only clips if its children if
        // they overflow. The direct children of this Stack below never
        // overflow, because the actual widgets displayed in the scene are
        // positioned by a Transform and layed out by an OverflowBox.
        child: ClipRect(
          child: Stack(
            alignment: Alignment.topLeft,
            children: children,
          ),
        ),
      ),
    );
  }
}

/// A widget that displays a [child] widget in a 3D scene.
///
/// See also:
///
///   - [SceneViewport]
class SceneWidget extends StatelessWidget {
  const SceneWidget({
    Key? key,
    required this.child,
  }) : super(key: key);

  /// The widget to display in the scene.
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return OverflowBox(
      minHeight: 0,
      maxHeight: double.infinity,
      minWidth: 0,
      maxWidth: double.infinity,
      alignment: Alignment.topLeft,
      child: Transform(
        transform: TransformStack.of(context),
        child: child,
      ),
    );
  }
}

/// A widget that groups its children in a 3D scene.
///
/// You can use it for example to apply a transform to all of its children:
///
/// ```dart
/// MatrixTransform(
///   transform: Matrix4.translationValues(10, 0, -50),
///   child: SceneGroup(
///     children: [
///       ...
///     ],
///   ),
/// );
/// ```
///
/// See also:
///
///   - [SceneViewport]
///   - [SceneWidget]
class SceneGroup extends StatelessWidget {
  const SceneGroup({
    Key? key,
    required this.children,
  }) : super(key: key);

  /// The widgets to group in the scene.
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.topLeft,
      children: children,
    );
  }
}

/// A widget that applies a [transform], represented by a [Matrix4], to its
/// widget subtree.
class MatrixTransform extends StatelessWidget {
  const MatrixTransform({
    Key? key,
    required this.transform,
    required this.child,
  }) : super(key: key);

  /// The transform to apply to the widget subtree.
  final Matrix4 transform;

  /// The widget subtree.
  final Widget child;

  @override
  Widget build(BuildContext context) => TransformStack.push(
        context: context,
        transform: transform,
        child: child,
      );
}

/// A controller that supports manipulation of individual transform components.
///
/// Scale, rotation and translation can be individually controlled for all
/// 3 axes.
///
/// Each time a component is changed, the [transform] is updated and the
/// listeners are notified.
class TransformController extends ChangeNotifier {
  /// Creates a controller that supports manipulation of individual transform
  /// components.
  TransformController({
    double scaleX = 1,
    double scaleY = 1,
    double scaleZ = 1,
    double rotationX = 0,
    double rotationY = 0,
    double rotationZ = 0,
    double translationX = 0,
    double translationY = 0,
    double translationZ = 0,
  })  : _scaleX = scaleX,
        _scaleY = scaleY,
        _scaleZ = scaleZ,
        _rotationX = rotationX,
        _rotationY = rotationY,
        _rotationZ = rotationZ,
        _translationX = translationX,
        _translationY = translationY,
        _translationZ = translationZ;

  /// The overall scale of the transform.
  ///
  /// The getter throws an exception if the scales of the different axes is not
  /// uniform.
  double get scale {
    if (scaleX != scaleY || scaleX != scaleZ) {
      throw Exception('Scale is not uniform.');
    }
    return _scaleX;
  }

  set scale(double value) {
    scaleX = value;
    scaleY = value;
    scaleZ = value;
  }

  /// The scale of the transform in the x-axis.
  double get scaleX => _scaleX;
  double _scaleX;

  set scaleX(double value) {
    if (value == _scaleX) {
      return;
    }
    _scaleX = value;
    notifyListeners();
  }

  /// The scale of the transform in the y-axis.
  double get scaleY => _scaleY;
  double _scaleY;

  set scaleY(double value) {
    if (value == _scaleY) {
      return;
    }
    _scaleY = value;
    notifyListeners();
  }

  /// The scale of the transform in the z-axis.
  double get scaleZ => _scaleZ;
  double _scaleZ;

  set scaleZ(double value) {
    if (value == _scaleZ) {
      return;
    }
    _scaleZ = value;
    notifyListeners();
  }

  /// The rotation of the transform as a [vm.Vector3].
  vm.Vector3 get rotation => vm.Vector3(_rotationX, _rotationY, _rotationZ);

  set rotation(vm.Vector3 value) {
    rotationX = value.x;
    rotationY = value.y;
    rotationZ = value.z;
  }

  /// The rotation of the transform in the x-axis.
  double get rotationX => _rotationX;
  double _rotationX;

  set rotationX(double value) {
    if (value == _rotationX) {
      return;
    }
    _rotationX = value;
    notifyListeners();
  }

  /// The rotation of the transform in the y-axis.
  double get rotationY => _rotationY;
  double _rotationY;

  set rotationY(double value) {
    if (value == _rotationY) {
      return;
    }
    _rotationY = value;
    notifyListeners();
  }

  /// The rotation of the transform in the z-axis.
  double get rotationZ => _rotationZ;
  double _rotationZ;

  set rotationZ(double value) {
    if (value == _rotationZ) {
      return;
    }
    _rotationZ = value;
    notifyListeners();
  }

  /// The translation of the transform in the x-axis.
  double get translationX => _translationX;
  double _translationX;

  set translationX(double value) {
    if (value == _translationX) {
      return;
    }
    _translationX = value;
    notifyListeners();
  }

  /// The translation of the transform in the y-axis.
  double get translationY => _translationY;
  double _translationY;

  set translationY(double value) {
    if (value == _translationY) {
      return;
    }
    _translationY = value;
    notifyListeners();
  }

  /// The translation of the transform in the z-axis.
  double get translationZ => _translationZ;
  double _translationZ;

  set translationZ(double value) {
    if (value == _translationZ) {
      return;
    }
    _translationZ = value;
    notifyListeners();
  }

  /// The transform represented by this controller.
  Matrix4 get transform => _transform ??= _buildTransform();

  Matrix4? _transform;

  Matrix4 _buildTransform() {
    final transform = Matrix4.identity();
    if (scaleX != 1 || scaleY != 1 || scaleZ != 1) {
      transform.scale(scaleX, scaleY, scaleZ);
    }
    if (rotationX != 0) {
      transform.rotateX(vm.radians(rotationX));
    }
    if (rotationY != 0) {
      transform.rotateY(vm.radians(rotationY));
    }
    if (rotationZ != 0) {
      transform.rotateZ(vm.radians(rotationZ));
    }
    if (translationX != 0 || translationY != 0 || translationZ != 0) {
      transform.translate(translationX, translationY, translationZ);
    }
    return transform;
  }

  @override
  void notifyListeners() {
    _transform = null;
    super.notifyListeners();
  }
}

/// A widget that applies the transform of a [TransformController] to its
/// widget subtree.
class ControllerTransform extends StatelessWidget {
  const ControllerTransform({
    Key? key,
    required this.controller,
    required this.child,
  }) : super(key: key);

  /// The controller that controls the transform.
  final TransformController controller;

  /// The widget subtree.
  final Widget child;

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: controller,
        builder: (context, _) => TransformStack.push(
          context: context,
          transform: controller._buildTransform(),
          child: child,
        ),
      );
}

/// A widget that centers its widget subtree around the origin, based on a
/// [size].
class CenterTransform extends StatelessWidget {
  const CenterTransform({
    Key? key,
    required this.size,
    required this.child,
  }) : super(key: key);

  /// The size to use for centering the widget subtree.
  final vm.Vector3 size;

  /// The widget subtree.
  final Widget child;

  @override
  Widget build(BuildContext context) => TransformStack.push(
        context: context,
        transform: Matrix4.translationValues(
          -size.x / 2,
          -size.y / 2,
          -size.z / 2,
        ),
        child: child,
      );
}

/// Widget that updates a [TransformController] based on gestures, to allow
/// interaction with a model in a 3D scene.
///
/// The model is scaled, and rotated around the x and y axes based on the user's
/// gestures.
///
/// Scaling is done on a curve, to give better control.
class ModelInteraction extends StatelessWidget {
  /// Creates a widget that updates a [TransformController] based on gestures,
  /// to allow interaction with a model in a 3D scene.
  const ModelInteraction({
    Key? key,
    this.scaleMin = double.minPositive,
    this.scaleMax = double.maxFinite,
    required this.controller,
    required this.child,
  }) : super(key: key);

  /// The minimum scale of the model.
  final double scaleMin;

  /// The maximum scale of the model.
  final double scaleMax;

  /// The controller that controls the model's transform.
  final TransformController controller;

  /// The widget subtree that defines the interaction area.
  final Widget child;

  static const _scrollScaleFactor = 0.001;
  static const _pinchScaleFactor = 1.0;
  static const _rotationFactor = 0.1;

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerSignal: (event) {
        if (event is PointerScrollEvent) {
          _updateScaleWithDelta(event.scrollDelta.dy * _scrollScaleFactor);
        }
      },
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onScaleUpdate: (details) {
          final scaleDelta = (details.scale - 1);
          _updateScaleWithDelta(scaleDelta * _pinchScaleFactor);

          controller.rotationY += details.focalPointDelta.dx * _rotationFactor;
          controller.rotationX += details.focalPointDelta.dy * -_rotationFactor;
        },
        child: child,
      ),
    );
  }

  void _updateScaleWithDelta(double delta) {
    final scale = _reverseScaleCurve(controller.scale);
    final newScale = _applyScaleCurve(scale + delta);
    controller.scale = newScale.clamp(scaleMin, scaleMax);
  }

  double _reverseScaleCurve(double scale) {
    return sqrt(scale);
  }

  double _applyScaleCurve(double scale) {
    return scale * scale;
  }
}
