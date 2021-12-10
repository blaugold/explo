[![pub.dev](https://badgen.net/pub/v/explo)](https://pub.dev/packages/explo)

> ⚠️ This package is **experimental**.

This package allows you to explore the render tree of a Flutter app in 3D,
through an exploded representation.

<img src="https://github.com/blaugold/explo/raw/main/packages/explo/doc/images/flutter_explode_demo.gif">

# Getting Started

You will need to have two Flutter apps running at the same time. One will
display the exploded visualization, the other is the app you want to visualize.

## Instrument your app

The app you want to visualize must be instrumented. First add `explo_capture` as
a dependency:

```yaml
dependencies:
  explo_capture: ...
```

Then capture the render tree of the app's widget tree that you want to
visualize:

```dart
import 'package:explo/explo.dart';

CaptureRenderTree(
    child: MyInterestingAppComponent(),
);
```

## Viewer app

Add `explo` as a dependency:

```yaml
dependencies:
  explo: ...
```

Then display the `ExploPage` somewhere:

```dart
import 'package:flutter/material.dart';
import 'package:explo/explo.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: ExploPage(),
    );
  }
}
```

When you open this page, you will be asked to enter the VM service URL of the
app you want to visualize. This URL is logged early on when an app is launched.
