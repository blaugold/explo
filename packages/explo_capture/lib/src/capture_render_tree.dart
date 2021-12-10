import 'package:flutter/cupertino.dart';

import 'capture_service_extensions.dart';

/// Captures the render tree of the widgets below [child], for visualization
/// with `explo`.
///
/// If multiple [CaptureRenderTree]s are in the widget tree, only the last one
/// inserted will be captured.
class CaptureRenderTree extends StatefulWidget {
  const CaptureRenderTree({
    Key? key,
    required this.child,
  }) : super(key: key);

  /// The root of the widget tree to be captured for visualization.
  final Widget child;

  @override
  _CaptureRenderTreeState createState() => _CaptureRenderTreeState();
}

class _CaptureRenderTreeState extends State<CaptureRenderTree> {
  @override
  void initState() {
    super.initState();
    startCapturingRenderTree(context as Element);
  }

  @override
  void dispose() {
    stopCapturingRenderTree(context as Element);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
