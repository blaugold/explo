[![pub.dev](https://badgen.net/pub/v/explo_capture)](https://pub.dev/packages/explo_capture)

> ⚠️ This package is **experimental**.

This package allows you to capture render tree data of a Flutter app, for
visualization with [explo].

# Getting Started

The app you want to visualize must capture render tree data and make it
available for visualization.

First add `explo_capture` as a dependency:

```yaml
dependencies:
  explo_capture: ...
```

Then capture the part of the app's render tree that you want to visualize:

```dart
import 'package:explo_capture/explo_capture.dart';

CaptureRenderTree(
    child: MyInterestingAppComponent(),
);
```

[explo]: https://pub.dev/packages/explo
