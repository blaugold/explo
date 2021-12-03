import 'package:flutter/cupertino.dart';

import 'service_extension.dart';

/// Marks the [child] subtree to be available for visualization.
///
/// If multiple widgets are marked, only the last one will be visualized.
class ExplodedTreeMarker extends StatefulWidget {
  const ExplodedTreeMarker({
    Key? key,
    required this.child,
  }) : super(key: key);

  /// The root of the widget tree to be marked for visualization.
  final Widget child;

  @override
  _ExplodedTreeMarkerState createState() => _ExplodedTreeMarkerState();
}

class _ExplodedTreeMarkerState extends State<ExplodedTreeMarker> {
  @override
  void initState() {
    super.initState();
    addMarkedElement(context as Element);
  }

  @override
  void dispose() {
    removeMarkedElement(context as Element);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
